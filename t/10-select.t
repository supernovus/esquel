use v6;

BEGIN { @*INC.push: './lib'; }

use Test;
use Esquel;

plan 10;

my $sql = Esquel.new(:table<test>);
my $sel;  ## We will set this on each test.
my @bind; ## Ditto, when bind is in use.

## 1
$sel = $sql.select;
is $sel, "SELECT * FROM test;", "Basic SELECT statement";

## 2
$sel = $sql.from('users').select('name','age');
is $sel, "SELECT name,age FROM users;", "SELECT specific fields, with specific table.";

## 3
$sel = $sql.where(:id(17)).select(*);
is $sel, "SELECT * FROM users WHERE ((id = 17));", "Simple WHERE CLAUSE, and Whatever SELECT.";

## 4 & 5
($sel, @bind) = $sql.bind.where(:id(25), :job(['CEO', 'COO'])).select;
is $sel,
 "SELECT * FROM users WHERE ((id = ?) AND ((job = ?) OR (job = ?)));",
 "SELECT with multiple choices on a field, and parameter binding.";
is @bind, [25, 'CEO', 'COO'], 'bind parameters on WHERE statement.';

## 6
$sel = $sql.nobind.where("id=27 AND this='that'").select(:job);
is $sel, "SELECT job FROM users WHERE id=27 AND this='that';",
  "WHERE as a string, and named parameters to select.";

## 7
$sel = $sql.where(:id(:gt(100))).select;
is $sel, "SELECT * FROM users WHERE ((id > 100));", 
  "Comparison operators in WHERE statements.";

## 8 & 9
($sel, @bind) = $sql.bind.where(:name(:like('Bob'))).select(:name);
is $sel, "SELECT name FROM users WHERE ((name LIKE ?));",
  "Like comparison, with binding.";
is @bind, ['Bob'], "Bound parameters from like comparison.";

## 10
$sel = $sql.nobind.where(:name('Bob')).select('*');
is $sel, "SELECT * FROM users WHERE ((name = 'Bob'));",
  "String comparison, and '*' select parameter.";
