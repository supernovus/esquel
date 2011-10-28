## Esquel: Turn Perl 6 method calls and data structures into SQL queries.

class Esquel;

## These are set and not cleared by the clear() command, or by auto-clear.
has $.table   is rw; ## The DB table, (re)set with "from".
has $!keep    is rw; ## Disable auto-clear (runs clear() after action methods.)
has $!bind    is rw; ## If set, we use prepared statements with bound params.

## Stuff below here will be cleared by clear(:all) or by auto-clear.
has $!where   is rw; ## The WHERE clause for "select", "update", "delete".
has $!limit   is rw; ## Limit to this many results.
has $!orderby is rw; ## Order by...
has $!groupby is rw; ## Group by...
has $!having  is rw; ## Similar to WHERE but used with aggregate functions.

## The bound array is used for various portions of replacements.
## It has three nested arrays:
##  [0] Direct statements, such as update, insert, etc.
##  [1] Where clauses.
##  [2] Having clauses.
## The values are put in the proper order and flattened for the @bind
## output.
has @!bound = [],[],[];


## Set the database table.
## We offer from(), into() and in() as alternatives.
## You can also set it in your constructor, using new(:table($name));
method from ($table) {
  $!table = $table;
  return self;
}
method into ($table) {
  $!table = $table;
  return self;
}
method in ($table) {
  $!table = $table;
  return self;
}

## Change the auto-clear settings.
method keep {
  $!keep = True;
  return self;
}
method nokeep {
  $!keep = False;
  return self;
}

## Change the bind settings.
method bind {
  $!bind = True;
  return self;
}
method nobind {
  $!bind = False;
  return self;
}

## When using positional parameters, it's either a single string
## in which case it's a specific SQL WHERE statement, or it's
## an array of Hashes (AND statements) to be chained by OR statements.
## e.g.
##    $this.where({:id(15,17)},{:type<admin>, :job(:like<manage>)});
## will generate:
##    WHERE ((id = 15) OR (id = 17)) OR 
##     ((type = "admin") AND (job LIKE "manage"))
##
## TODO <low priority>  Add optional explicit AND/OR modifiers.
method !query ($type, $bind, *@rules) {
  if @rules.elems == 1  && @rules[0] ~~ Whatever {
    return True; ## Skip the where statement.
  }
  elsif @rules.elems == 1 && @rules[0] ~~ Str {
    return $type ~ ' ' ~ @rules[0];
  }
  else {
    return $type ~ ' ' ~ self!parse-query(@rules, $bind);
  }
}

## WHERE clause
multi method where (*%rules) {
  my $rules = %rules;
  $!where = self!query('WHERE', 1, $rules);
  return self;
}
multi method where (*@rules) {
  $!where = self!query('WHERE', 1, |@rules);
  return self;
}

## HAVING clause
multi method having (*%rules) {
  my $rules = %rules;
  $!having = self!query('HAVING', 2, $rules);
  return self;
}
multi method having (*@rules) {
  $!having = self!query('HAVING', 2, |@rules);
  return self;
}

## parse-query: private method to parse where and having clauses.
method !parse-query (@rules, $bind) {
  my $where;
  for @rules -> $rule {
    #$*ERR.say: "Doing rule: "~$rule.perl;
    if $rule !~~ Hash { next; } ## Skip non-hashes.
    if ! defined $where { $where = '('; }
    else { $where ~= ' OR ('; }
    $where ~= self!parse-query-hash($rule, $bind) ~ ')';
  }
  return $where;
}

## Called by parse-query for each Hash found.
method !parse-query-hash(%hash, $bind) {
  my $where;
  for %hash.kv -> $key, $val {
    if ! defined $where { $where = '('; }
    else { $where ~= ' AND ('; }
    if $val ~~ Seq || $val ~~ Array {
      my $subwhere;
      for @($val) -> $subval {
        if ! defined $subwhere { $subwhere = '('; }
        else { $subwhere ~= ' OR ('; }
        $subwhere ~= self!parse-query-statement($key, $subval, $bind) ~ ')';
      }
      $where ~= $subwhere ~ ')';
    }
    else {
      $where ~= self!parse-query-statement($key, $val, $bind) ~ ')';
    }
  }
  return $where;
}

## Process values, adding bindings if $!bind is true, and
## wrapping non-numeric values into single quotes otherwise.
## NOTE: We do NO escaping, so if you are worried about your
## value having special characters, use binding and let the
## DBI handler escape your strings for you.
## This now handles SQL function calls, and LITERAL text too.
method !get-value ($value, $bind=0) {
  my $val;
  if $value ~~ Pair {
    my $func   = $value.key;
    my $subval = $value.value;
    ## We support a literal text syntax, inspired by SQL::Abstract.
    if $func eq 'LITERAL' {
     $val = $subval;
     if $subval ~~ Array {
       my @vals = @($subval);
       $val = @vals.shift;
       @!bound[$bind].push: @vals;
     }
    }
    ## If the key is unknown, it's an SQL function.
    else {
      if $subval ~~ Array {
        my @vals = @($subval);
        $subval = '';
        my $comma = False;
        for @vals -> $rawparam {
          if $comma { $subval ~= ','; }
          else      { $comma = True;  }
          my $param = self!get-value($rawparam);
          $subval ~= $param;
        }
      }
      else {
        $subval = self!get-value($subval);
      }
      $val = $func~"($subval)";
    }
    return $val;
  }
  else {
    if $!bind {
      @!bound[$bind].push: $value;
      return '?';
    }
    elsif $value !~~ Numeric {
      return "'$value'";
    }
  }
  return $value;
}

## Parse a WHERE or HAVING statement, adding in any
## aggregate methods and alternative comparisons.
method !parse-query-statement ($key, $val, $bind) {
  my $comp = '=';
  my $item = $key;
  my $want = $val;
  while $want ~~ Pair {
    my $subkey = $want.key;
    $want = $want.value;
    given $subkey {
      when 'like' { $comp = 'LIKE'; }
      when 'gt'   { $comp = '>';    }
      when 'lt'   { $comp = '<';    }
      when 'gte'  { $comp = '>=';   }
      when 'lte'  { $comp = '<=';   }
      when 'not'  { $comp = '!=';   }
      default     { $item = $subkey~"($item)"; }
    }
  }
  if $want ~~ Bool {
    if $want {
      $want = 0;
      $comp = '!=';
    }
    else {
      $want = 0;
    }
  }

  my $wantval = self!get-value($want, $bind);
  my $statement = "$item $comp $wantval";
  return $statement;
}

## Clear specific query modifiers.
## Normal usage: $this.clear(:where, :having); # clears where and having.
## Keep usage: $this.clear(:keep, :where); # clears everything but where.
## All usage: $this.clear(:all); # clears everything, no exceptions.
method clear (:$keep, :$all, :$check, *%mods) {
  if $check && $!keep { return; } ## Skip if auto-clear is turned off.
  my %clear-rules = {
    'where'   => sub { undefine($!where);   },
    'limit'   => sub { undefine($!limit);   },
    'having'  => sub { undefine($!having);  },
    'orderby' => sub { undefine($!orderby); },
    'groupby' => sub { undefine($!groupby); },
    'bound'   => sub {
      ## This could use splice, but it's not working.
      for 0..@!bound.end -> $c {
        @!bound[$c] = ();
      }
    }, 
  };
  for %clear-rules.kv -> $which, &clearit {
    if ( $all || ($keep && !%mods{$which}) || (!$keep && %mods{$which})) {
      clearit();
    }
  }
}

## A method to return either the statement, or a statement
## and any bound paramters, depending on the $!bind settings.
## It also runs the auto-clear function, if $!keep isn't set.
method !statement ($stmt) {
  my @bound; 
  for 0..@!bound.end -> $c {
    if @!bound[$c].elems > 0 {
      @bound.push: @!bound[$c]; ## Get a flat representation.
    }
  }
  self.clear(:check, :all);
  if $!bind {
    return $stmt, @bound;
  }
  return $stmt;
}

## Ensures that the $!table has been set.
## If :where is passed, it also ensures $!where has been set.
## If either clause fails, the script will die.
method !sanity (:$where) {
  if ! $!table {
    die "No table has been set.";
  }
  if $where && ! $!where {
    die "No where statement on a required field.";
  }
}

## Add WHERE statements where needed.
method !parse-where ($stmt is rw) {
  if $!where && $!where !~~ Bool {
    $stmt ~= " $!where";
  }
}

## SELECT query
method select (*%fields, *@fields) {
  self!sanity;
  if %fields {
    @fields.push: %fields.pairs;
  }

  my $stmt = 'SELECT ';
  if @fields.elems == 0 || @fields[0] ~~ Whatever || @fields[0] eq '*' {
    $stmt ~= '*';
  }
  else {
    my $comma = False;
    for @fields -> $field {
      my $name = $field;
      if $field ~~ Pair {
        $name = $field.key;
        ## TODO: aggregate methods, AS statements, etc.
      }
      if $comma { $stmt ~= ','; }
      else      { $comma = True;  }
      $stmt ~= "$name";
    }
  }
  $stmt ~= " FROM $!table";
  self!parse-where($stmt);
  ## TODO: GROUP BY and ORDER BY
  ## TODO: HAVING
  $stmt ~= ';';
  return self!statement($stmt);
}

## UPDATE statement
method update (*%newvalues) {
  self!sanity(:where);
  my $stmt = "UPDATE $!table SET ";
  my $comma = False;
  for %newvalues.kv -> $field, $value {
    if $comma { $stmt ~= ', '; }
    else      { $comma = True;   }
    my $val = self!get-value($value);
    $stmt ~= "$field=$val";
  }
  self!parse-where($stmt);
  $stmt ~= ';';
  return self!statement($stmt);
}

## INSERT statement
method insert (*%values) {
  self!sanity;
  my $stmt = "INSERT INTO $!table (";
  my $comma = False;
  ## Sorting the keys and values into arrays.
  ## There's probably a faster, better way to do this,
  ## but for now, this will work.
  my (@keys, @vals);
  for %values.kv -> $k, $v {
    @keys.push: $k;
    @vals.push: $v;
  }
  for @keys -> $field {
    if $comma { $stmt ~= ', '; }
    else      { $comma = True; }
    $stmt ~= $field;
  }
  $stmt ~= ') VALUES (';
  $comma = False;
  for @vals -> $value {
    if $comma { $stmt ~= ', '; }
    else      { $comma = True; }
    my $val = self!get-value($value);
    $stmt ~= $val;
  }
  $stmt ~= ');';
  return self!statement($stmt);
}

## DELETE statement, as easy as it gets.
method delete {
  self!sanity(:where);
  my $stmt = "DELETE FROM $!table";
  self!parse-where($stmt);
  $stmt ~= ';';
  return self!statement($stmt);
}

## CREATE TABLE statement.
## It doesn't use a slurpy array, but a normal one.
## You can pass strings, which will be used as is, or
## pairs, which can use a nicer Perl 6 syntax.
## Don't pass the commas, they'll be added automatically.
method create-table ($name, @columns) {
  my $stmt = "CREATE TABLE $name (";
  my $comma = False;
  for @columns -> $column {
    if $comma { $stmt ~= ', '; }
    else      { $comma = True; }
    if $column ~~ Pair {
      my $name = $column.key;
      $stmt ~= $name;
      my $hasval  = $column.value;
      my $val; ## This will be set depending on the value format.
      if $hasval ~~ Hash {
        $val = '';
        for $hasval.kv -> $k,$v {
          if $v ~~ Bool && $v {
            $val ~= " $k";
          }
          else {
            $val ~= " $k"~"($v)";
          }
        }
      }
      elsif $hasval ~~ Array {
        $val = '';
        for @($hasval) -> $subval {
          if $subval ~~ Pair {
            my $k = $subval.key;
            my $v = $subval.value;
            if $v ~~ Bool && $v {
              $val ~= " $k";
            }
            else {
              $val ~= " $k"~"($v)";
            }
          }
          else {
            $val ~= " $subval";
          }
        }
      }
      else {
        $val = " $hasval";
      }
      $stmt ~= $val;
    }
    else {
      $stmt ~= $column;
    }
  }
  $stmt ~= ");";
  return $stmt;
}

