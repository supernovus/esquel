## JSON Database Engine
##
## Probably not useful (or recommended) for production systems,
## but it is useful for testing. 
## This will eventually be split off as it's own project,
## and made into a DBD for MiniDBI once that project is working again.
##
## Basic usage: my $dbh = JD::DBH($path_to_json_file);
## That's it. Now use it like a standard DBI database handler. Easy eh?
##

## The Statement Handler. This is returned from a DBH prepare() method.

grammar JD::SQL::Grammar {
  ## TODO: actually make this grammar work.
  ## Based on the grammar from MiniDBD::CSV
  regex TOP { ^ [ <create_table> | <drop_table> | <insert> | <update>
              | <delete> | <select> ] }
  rule create_table {:i create table <table_name> '(' <col_defs> }
  rule col_defs {<col_def>}
  rule col_def {<column_name> <column_opts>?}
  rule drop_table {:i drop table <table_name>}
  rule insert {:i insert <table_name>}
  rule update {:i update <table_name>}
  rule delete {:i delete <table_name>}
  rule select {:i select <sel_what> from <table_name>}
  token sel_what { '*' }
  token table_name { <alpha><alnum>+ }
  token column_name { <alpha><alnum>+ }
  token column_opts { <column_type> <column_opts>? }
  token column_size { '(' \d+ ')' }
  token column_type {:i int|char|numeric}
}

class JD::SQL::Actions {

  has $.data; ## A reference to the data.

  ## TODO: implement the real actions.
  method create_table(Match $m) {
    print "doing CREATE TABLE ";
    my $table_name = ~$m<table_name>;
    say $table_name;
  }
  method drop_table(Match $m) {
    print "doing DROP TABLE ";
    my $table_name = ~$m<table_name>;
    say $table_name;
  }
  method insert(Match $m) { say "doing INSERT" }
  method update(Match $m) { say "doing UPDATE" }
  method delete(Match $m) { say "doing DELETE" }
  method select(Match $m) { say "doing SELECT" }

}  

class JD::STH {
  has $.dbh;    ## A reference to the DBH which we are associated with.
  has $.stmt;   ## The SQL statement we represent.
  has $!errstr; ## Error messages.

  method errstr {
    return $!errstr;
  }

  method rows {
    return 0; ## NYI.
  }

  method execute (*@params) {
    my $stmt  = $!stmt;
    my $cur   = 0;
    my $last  = @params.end;
    while $cur < $last and $stmt.index('?').defined {
      my $param = @params[$cur++];
      if $param !~~ Numeric {
        $stmt.=subst('?', "'$param'");
      }
      else {
        $stmt.=subst('?', $param);
      }
    }
    my $parse = JD::SQL::Grammar.parse($stmt, :actions($.dbh.actions));
    if ! $parse {
      warn "invalid SQL: $stmt";
      return;
    }
    else {
      return self.rows;
    }
  }

}

class JD::DBH {
  use JSON::Tiny;

  has $.file;    ## The JSON file we represent.
  has $.data;    ## The JSON data, decoded from the file.
  has $.actions; ## The actions object.
  has $!auto;    ## Auto-commit?
  has $!errstr;  ## Error messages.
  
  method new ( Str $file ) {
    if $file.IO !~~ :f {
      die "file does not exist '$file'.";
    }
    my $data = from-json(slurp($file));
    my $actions = JD::SQL::Actions.new(:$data);
    return self.bless(*, :$file, :$data, :$actions);
  }

  ## Toggle auto-commit
  method auto {
    $!auto = True;
  }
  method noauto {
    $!auto = False;
  }

  method prepare ( Str $stmt ) {
    JD::STH.new(:dbh(self), :$stmt);
  }

  method do ( Str $statement, *@params ) {
    my $sth = self.prepare($statement);
    if $sth !~~ JD::STH { 
      ## Something failed.
      $!errstr = $sth; 
      return;
    }
    $sth.execute(@params);
  }

  ## Save the changes.
  method commit {
    my $file = open($.file, :w) or 
      return self!err('could not open file to write');
    $file.say: to-json($.data);
    $file.close;
    return True;
  }

  ## Auto-save depending on our auto-commit settings.
  method autosave {
    if $!auto {
      self.commit;
    }
  }

  ## Compatibility wrapper.
  method disconnect {
    self.autosave;
  }

  ## Set our error message.
  method !err ($message) {
    $!errmsg = $message;
    return;
  }

  ## Return any error messages.
  method errstr {
    return $!errstr;
  }
}
