use v6;

BEGIN { @*INC.push: './lib'; }

use Test;
use Esquel;

plan 3;

my $sql = Esquel.new;
my $sel;  ## We will set this on each test.
my @bind; ## Ditto, when bind is in use.

## 1
$sel = $sql.create-table('test', ['id AUTO_INCREMENT PRIMARY KEY', 'name varchar(255)']);
is $sel, 
  "CREATE TABLE test (id AUTO_INCREMENT PRIMARY KEY, name varchar(255));",
  "CREATE TABLE with string definitions";

$sel = $sql.create-table('users', 
  [
    :id([:AUTO_INCREMENT, 'PRIMARY KEY']), 
    :name({:varchar(255)}),
    :age<int>,
  ]
);
is $sel, 
  "CREATE TABLE users (id AUTO_INCREMENT PRIMARY KEY, name varchar(255), age int);",
  "CREATE TABLE with Perl structure definitions";

## 3
$sel = $sql.create-table(:drop, 'hi', [ :id<int>, :name(:varchar(255)) ]);
is $sel,
  "DROP TABLE IF EXISTS hi; CREATE TABLE hi (id int, name varchar(255));",
  "CREATE TABLE with :drop option.";

