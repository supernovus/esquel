## OOSQL: Allows you to create classes that represent a table
## in an SQL-based database. One class per table. This is for
## simple object oriented database obstraction, no cross-joins, etc.
##
## The class must define an attribute called $!table which must contain
## a string, which is the name of the database table this object represents.
##
## It must also define a method called 'execute-sql()' which takes a string
## of SQL and sends it to the active database. It must return an object (of
## a real class, or an anonymous class) that has at least the following 
## methods or attributes (implementation is up to you):
##
##  $result.errors  contains mysql errors if they happened, otherwise Nil.
##  $result.count   if supported, contains the number of rows affected, or Nil.
##  $result.rows    the returned rows from select, otherwise empty array.
##
## Read the role to see what attributes and methods it defines.

role OOSQL;

has $!keep    is rw; ## If set to true, the below items aren't cleared.
has $!where   is rw;
has $!limit   is rw; ## TODO
has $!orderby is rw; ## TODO
has $!groupby is rw; ## TODO
has $!having  is rw; ## TODO

## When using all named parameters, assume AND rules.
## If values are array, they will be ORed in an inner statement.
multi method where (*%rules) {
  $!where = self!parse-where(%rules);
}

## When using positional parameters, it's either a single string
## in which case it's a specific SQL WHERE statement, or it's
## an array of Hashes (AND statements) to be chained by OR statements.
## e.g.
##    $this.where({:id(15,17)},{:type<admin>, :job(:like<manage>)});
## will generate:
##    WHERE ((id = 15) OR (id = 17)) OR 
##     ((type = "admin") AND (job LIKE "manage"))
multi method where (*@rules) {
  if @rules.elems == 1 && @rules[0] ~~ Str {
    $!where = @rules[0];
  }
  else {
    $!where = self!parse-where(|@rules);
  }
}

## parse-query: private method to parse where and having clauses.
method !parse-query (*@rules) {
  my $where;
  for @rules -> $rule {
    if $rule !~~ Hash { next; } ## Skip non-hashes.
    if ! defined $where { $where = '('; }
    else { $where ~= ' OR ('; }
    $where ~= self!parse-query-hash($rule) ~ ')';
  }
  return $where;
}

method !parse-query-hash(%hash) {
  my $where;
  for %hash.kv -> $key, $val {
    if ! defined $where { $where = '('; }
    else { $where ~= ' AND ('; }
    if $val ~~ Seq || $val ~~ Array {
      my $subwhere;
      for @($val) -> $subval {
        if ! defined $subwhere { $subwhere = '('; }
        else { $subwhere ~= ' OR ('; }
        $subwhere ~= self!parse-query-statement($key, $subval) ~ ')';
      }
      $where ~= $subwhere;
    }
    else {
      $where ~= self!parse-query-statement($key, $val) ~ ')';
    }
  }
  return $where;
}

method !parse-query-statement ($key, $val) {
  my $comp = '=';
  my ($item, $want) = self!parse-aggregate-key($key, $val);
  if $want ~~ Pair {
    my $subkey = $want.key;
    $want = $want.value;
    given $subkey {
      when 'like' { $comp = 'LIKE'; }
      when 'gt'   { $comp = '>';    }
      when 'lt'   { $comp = '<';    }
      when 'gte'  { $comp = '>=';   }
      when 'lte'  { $comp = '<=';   }
      when 'not'  { $comp = '!=';   }
    }
  }
  elsif ($val ~~ Bool) {
    if $val {
      $want = 0;
      $comp = '!=';
    }
    else {
      $want = 0;
    }
  }

  if ($want !~~ Numeric) {
    $want = "'$want'";
  }

  my $statement = "$key $comp $want";
  return $statement;
}

method !parse-aggregate-key($key is copy, $def) {
  my $item = $key;
  my $what = $def;
  if $def ~~ Pair {
    given $key {
      when 'MAX'   { $what = $def.value; $item = "MAX({$def.key})";   }
      when 'MIN'   { $what = $def.value; $item = "MIN({$def.key})";   }
      when 'SUM'   { $what = $def.value; $item = "SUM({$def.key})";   }
      when 'COUNT' { $what = $def.value; $item = "COUNT({$def.key})"; }
    }
  }
  return ($item, $what);
}

## Clear specific query modifiers.
## Normal usage: $this.clear(:where, :having); # clears where and having.
## Keep usage: $this.clear(:keep, :where); # clears everything but where.
## All usage: $this.clear(:all); # clears everything, no exceptions.
method clear (:$keep, :$all, *%mods) {
  my %clear-rules = {
    'where'   => sub { undefine($!where);   },
    'limit'   => sub { undefine($!limit);   },
    'having'  => sub { undefine($!having);  },
    'orderby' => sub { undefine($!orderby); },
    'groupby' => sub { undefine($!groupby); },
  };
  for %clear-rules.kv -> $rule, &clearit {
    if self!check-clear(%mods, $rule, :$keep, :$all) { clearit(); }
  }
}

## Should we clear this or not?
method !check-clear (%mods, $which, :$keep, :$all) {
  ( $all || ($keep && !%mods{$which}) || (!$keep && %mods{$which}))
}

## Represents a select query.
method select (*%fields, *@fields) {
  @fields.push: %fields.pairs;
  my $select;
  for @fields -> $field {
    ... ## TO BE FINISHED
  }
}

