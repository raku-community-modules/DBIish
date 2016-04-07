use v6;
use Test;

#DBIsh should can load the following, 'cus shipped
my \drvs = <Oracle Pg SQLite TestMock mysql>;

plan drvs.elems * 5 + 17;

use-ok 'DBIish', 'DBIish can be use-d';

my \DBIish = ::('DBIish');
ok DBIish !~~ Failure, "Class is available";

for <connect install-driver> {
    ok DBIish.^method_table{$_}:exists, "Method $_";
}

given DBIish.^ver {
    ok $_, 'DBIish Has version';
    ok $_ gt v0.0.0, "Greter than v.0.0.0, (v$_)";
}

# DBIish should load the following
for < DBIish::SQLType
      DBDish DBDish::Driver DBDish::Connection
      DBDish::StatementHandle DBDish::ErrorHandling
      X::DBDish::DBError X::DBDish::ConnectionFailed
  >
{
    ok ::("$_") !~~ Failure, "Loaded $_";
}

for drvs {
    my $drv;
    lives-ok {
	$drv = DBIish.install-driver($_);
    }, "Can install driver for '$_'";
    ok $drv.defined, "Is an instance '$drv'";
    ok $drv ~~ ::('DBDish::Driver'), "{$drv.^name} indeed a driver";
    with $drv.^ver {
	ok $_,  "Is version $_";
    } else { flunk  'version declared' };
    ok $drv.Connections.elems == 0, "Without connections";
}
throws-like {
    DBIish.install-driver('BogusDriver');
}, ::('X::DBIish::DriverNotFound'), "Detected bogus driver install attempt";

my $installed = DBIish.installed-drivers;
is $installed.elems, drvs.elems, "{ drvs.elems} installed drivers";
is $installed>>.key.sort, drvs, 'The expected five';
