use v6;

BEGIN { @*INC.push: './lib'; }

use Test;
use Esquel;

plan 3;

my $sql = Esquel.new(:table<test>);
my $sel;  ## We will set this on each test.
my @bind; ## Ditto, when bind is in use.

## 1
$sel = $sql.where(:salary(:lt(50))).delete;
is $sel, "DELETE FROM test WHERE ((salary < 50));", "Basic DELETE statement";

## 2 & 3
($sel, @bind) = $sql.bind.from('users').where({:salary(:lt(50))},{:budget(:gt(100))}).delete;
is $sel, "DELETE FROM users WHERE ((salary < ?)) OR ((budget > ?));", "DELETE from specific table with binding.";
is @bind, [50, 100], "DELETE binding parameters.";

