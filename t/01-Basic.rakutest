use v6;
use Test;

#DBIsh should can load the following, 'cus shipped
my \drvs = <Oracle Pg SQLite TestMock mysql>;

plan drvs.elems * 6 + 6;

use DBIish;
use DBDish;

my \DBIish-class = ::('DBIish');
ok DBIish-class !~~ Failure, "Class is available";

for <connect install-driver> {
    ok DBIish.^method_table{$_}:exists, "Method $_";
}

for drvs {
    my $drv;
    lives-ok {
	$drv = DBIish.install-driver($_);
    }, "Can install driver for '$_'";
    ok $drv.defined, "Is an instance '$drv'";
    ok $drv ~~ DBDish::Driver, "{$drv.^name} indeed a driver";
    with $drv.^ver {
	ok $_,  "Driver version $_";
    } else { flunk  'version declared' };
    with $drv.version {
	pass "Client version $_";
    } else {
	pass "Library not installed";
    }
    ok $drv.Connections.elems == 0, "Without connections";
}
throws-like {
    DBIish.install-driver('BogusDriver');
}, ::('X::DBIish::DriverNotFound'), "Detected bogus driver install attempt";

my $installed = DBIish.installed-drivers;
is $installed.elems, drvs.elems, "{ drvs.elems} installed drivers";
is $installed>>.key.sort, drvs, 'The expected five';
