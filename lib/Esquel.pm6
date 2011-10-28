## Esquel: Turn Perl 6 method calls and data structures into SQL queries.

class Esquel;

## These are set and not cleared by the clear() command, or by auto-clear.
has $.table   is rw; ## The DB table, (re)set with "from".
has $!keep    is rw; ## Disable auto-clear (runs clear() after action methods.)
has $!bind    is rw; ## If set, we use prepared statements with bound params.

## Stuff below here will be cleared by clear(:all) or by auto-clear.
has $!where   is rw; ## The WHERE clause for "select", "update", "delete".
has @!bound   is rw; ## Used by where is bind is true.
has $!limit   is rw; ## Limit to this many results.
has $!orderby is rw; ## Order by...
has $!groupby is rw; ## Group by...
has $!having  is rw; ## Similar to WHERE but used with aggregate functions.

## Set the database table.
method from ($table) {
  $!table = $table;
}

## Change the auto-clear settings.
method keep {
  $!keep = True;
}
method nokeep {
  $!keep = False;
}

## Change the bind settings.
method bind {
  $!bind = True;
}
method nobind {
  $!bind = False;
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
method !query ($type, *@rules) {
  if @rules.elems == 1 && @rules[0] ~~ Str {
    return @rules[0];
  }
  else {
    return $type ~ ' ' ~ self!parse-query(|@rules);
  }
}

## WHERE clause
multi method where (*%rules) {
  $!where = self!query('WHERE', %rules);
  return self;
}
multi method where (*@rules) {
  $!where = self!query('WHERE', |@rules);
  return self;
}

## HAVING clause
multi method having (*%rules) {
  $!having = self!query('HAVING', %rules);
  return self;
}
multi method having (*@rules) {
  $!having = self!query('HAVING', |@rules);
  return self;
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

  if $!bind {
    @!bound.push: $want;
    $want = '?';
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
method clear (:$keep, :$all, :$check, *%mods) {
  if $check && $!keep { return; } ## Skip if auto-clear is turned off.
  my %clear-rules = {
    'where'   => sub { undefine($!where);   },
    'limit'   => sub { undefine($!limit);   },
    'having'  => sub { undefine($!having);  },
    'orderby' => sub { undefine($!orderby); },
    'groupby' => sub { undefine($!groupby); },
    'bound'   => sub { @!bound = ();        }, ## splice when it works again.
  };
  for %clear-rules.kv -> $rule, &clearit {
    if ( $all || ($keep && !%mods{$which}) || (!$keep && %mods{$which})) {
      clearit();
    }
  }
}

## Represents a select query.
method select (*%fields, *@fields) {
  if %fields {
    @fields.push: %fields.pairs;
  }

  my $select = 'SELECT ';
  if @fields.elems == 0 || @fields[0] ~~ Whatever || @fields[0] eq '*' {
    $select ~= '*';
  }
  else {
    my $comma = False;
    for @fields -> $field {
      my $name = $field;
      if $field ~~ Pair {
        $name = $field.key;
        ## TODO: aggregate methods, AS statements, etc.
      }
      if $comma { $select ~= ','; }
      else      { $comma = True;  }
      $select ~= "$name";
    }
  }
  $select ~= " FROM $!table";
  if $!where {
    $select ~= " $!where";
  }
  ## TODO: GROUP BY and ORDER BY
  ## TODO: HAVING
  my $return = [ $select, @!bound ];
  my @bound = @!bound; ## Save prior to clearing.
  self.clear(:check, :all);
  if $!bind {
    return $select, @bound;
  }
  return $select;
}

