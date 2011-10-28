use v6;

BEGIN { @*INC.push: './lib'; }

use Test;
use Esquel;

plan 6;

my $sql = Esquel.new(:table<test>);
my $sel;  ## We will set this on each test.
my @bind; ## Ditto, when bind is in use.

## 1
$sel = $sql.where(:id(1)).update(:name<The Boss>);
is $sel, "UPDATE test SET name='The Boss' WHERE ((id = 1));", "Basic UPDATE statement";

## 2
$sel = $sql.in('users').where(*).update(:salary(0));
is $sel, "UPDATE users SET salary=0;", "UPDATE on specific table, with no where clause";

## 3 and 4
($sel, @bind) = $sql.bind.where(*).update(:salary(0), :note<fired>);
is $sel, "UPDATE users SET salary=?, note=?;", "UPDATE with binding and no where clause";
is @bind, [0, 'fired'], "UPDATE binding parameters with no where clause.";

## 5 and 6
($sel, @bind) = $sql.where(:name<Bob>).update(:job<none>);
is $sel, "UPDATE users SET job=? WHERE ((name = ?));",
  "UPDATE with binding and WHERE";
is @bind, ['none', 'Bob'], "UPDATE binding parameters with WHERE.";

