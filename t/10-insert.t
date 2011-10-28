use v6;

BEGIN { @*INC.push: './lib'; }

use Test;
use Esquel;

plan 3;

my $sql = Esquel.new(:table<test>);
my $sel;  ## We will set this on each test.
my @bind; ## Ditto, when bind is in use.

## 1
$sel = $sql.insert(:name<Joe>, :job<CEO>, :salary(25));
is $sel, "INSERT INTO test (name, job, salary) VALUES ('Joe', 'CEO', 25);", "Basic INSERT statement";

## 2 & 3
($sel, @bind) = $sql.bind.into('users').insert(:name<Mike>, :job<Chef>, :salary(50));
is $sel, "INSERT INTO users (name, job, salary) VALUES (?, ?, ?);", "INSERT into specific table with binding.";
is @bind, ['Mike', 'Chef', 50], "INSERT binding parameters.";

