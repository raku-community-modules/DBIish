# fakedbi/t/99-common.pl6
# This script is intended to be included as the common SQL tests in
# scripts for specific DBDs such as CSV or mysql.

#use Test;     # "use" dies in a runtime eval
#use FakeDBI;

#my $program_name = $*PROGRAM_NAME;
#diag "program $program_name";
diag "program $*PROGRAM_NAME";
#$program_name ~~ / \d+ '-' (.+?) '-' common /;
if $*PROGRAM_NAME ~~ / <digit>+ '-' (.+?) '-' common / {
    my $name = ~$0;
    diag "name = $name";
}
diag "Testing FakeDBD::$mdriver";
plan 4;

# Verify that the driver loads before attempting a connect
my $drh = FakeDBI.install_driver($mdriver);
ok $drh, 'Install driver'; # test 1
my $drh_version;
$drh_version = $drh.Version;
ok $drh_version > 0, "FakeDBD::$mdriver version $drh_version"; # test 2

# Connect to the data source
my $dbh = FakeDBI.connect( $test_dsn, $test_user, $test_password );
ok $dbh, "connect to $test_dsn"; # test 3

ok $dbh.disconnect, "disconnect";

# Return an unabiguous sign of successful completion
"ok 99-common.pl6";
