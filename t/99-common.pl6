# fakedbi/t/99-common.pl6
# This script is intended to be included as the common SQL tests in
# scripts for specific DBDs such as CSV or mysql.

#use Test;     # "use" dies in a runtime eval
#use FakeDBI;

diag "Testing FakeDBD::$mdriver";
plan 9;

# Verify that the driver loads before attempting a connect
my $drh = FakeDBI.install_driver($mdriver);
ok $drh, 'Install driver'; # test 1
my $drh_version;
$drh_version = $drh.Version;
ok $drh_version > 0, "FakeDBD::$mdriver version $drh_version"; # test 2

# Connect to the data source
my $dbh = FakeDBI.connect( $test_dsn, $test_user, $test_password );
ok $dbh, "connect to $test_dsn"; # test 3

# Test .prepare() and .execute() a few times while setting things up.
# Drop a table of the same name so that the following create can work.
my $sth = $dbh.prepare("DROP TABLE nom");
my $rc = $sth.execute();
isnt $rc, Bool::True, "do: drop table gave an expected error"; # test 4

# Create a table
$sth = $dbh.prepare( "
    CREATE TABLE nom (
        name char(4),
        description char(30),
        quantity int,
        price numeric(5,2)
    )
");
$rc = $sth.execute();
is $rc, Bool::True, "do: create table nom"; # test 5
skip 1, "err after successful create should be 0";
#is $dbh.err, 0, "err after successful create should be 0"; # test 6
is $dbh.errstr, Any, "errstr after successful create should be Any"; # test 7

ok $dbh.do("DROP TABLE nom"), "final cleanup";

ok $dbh.disconnect, "disconnect";

# Return an unabiguous sign of successful completion
"ok 99-common.pl6";
