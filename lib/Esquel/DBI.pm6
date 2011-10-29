## Esquel::DBI - A wrapper for Esquel and a DBI library.

use Esquel;

class Esquel::DBI is Esquel {

  has $.dbh;           ## Database handler. Set at creation.
  has $.sth is rw;     ## Statement handler. Set during actions.
  has $.count is rw;   ## Number of rows affected in last action.

  method new ($dbh) {
    return self.bless(*, :$dbh).bind;
  }
 
  ## Perform a database transaction. 
  method do ($stmt, *@bind) {
    ## First, close any existing statement handlers.
    if $.sth { $.sth.finish; }
    $.sth = $.dbh.prepare($stmt);
    $.count = $.sth.execute(|@bind);
    return self;
  }

  method select (*%fields, *@fields) {
#    if %fields {
#      @fields.unshift: %fields.pairs;
#    }
    my ($stmt, @bind) = callsame; #$.sql.select(|@fields);
    return self.do($stmt, |@bind);
  }

  method update (*%newvalues) {
    my ($stmt, @bind) = callsame; #$.sql.update(|%newvalues);
    return self.do($stmt, |@bind);
  }

  method insert (*%values) {
    my ($stmt, @bind) = callsame; #$.sql.insert(|%values);
    return self.do($stmt, |@bind);
  }

  method delete {
    my ($stmt, @bind) = callsame; #$.sql.delete;
    return self.do($stmt, |@bind);
  }

  method drop-table ($name, :$exists) {
    my $stmt = callsame; #$.sql.drop-table($name, :$exists);
    return self.do($stmt);
  }

  method create-table ($name, @columns, :$drop) {
    my $stmt = callsame; #$.sql.create-table($name, @columns, :$drop);
    return self.do($stmt);
  }

  method finish {
    if $.sth { $.sth.finish; }
  }

  method rows (:$ashash, :$withhash, :$slice) {
    if $.sth {
      if $ashash {
        return $.sth.fetchall_hashref($ashash);
      }
      elsif $withhash {
        my $hash;
        if $withhash ~~ Hash {
          $hash = $withhash;
        }
        else {
          $hash = {};
        }
        return $.sth.fetchall_arrayref($hash);
      }
      elsif $slice && $slice ~~ Array {
        return $.sth.fetchall_arrayref($slice);
      }
      else {
        return $.sth.fetchall_arrayref;
      }
    }
  }

  method row (:$ashash) {
    if $.sth {
      if $ashash {
        return $.sth.fetchrow_hashref;
      }
      else {
        return $.sth.fetchrow_arrayref;
      }
    }
  }

}
