# MiniDBI/t/20-CSV-common.t

use Test;
use MiniDBI;

# Define the only database specific values used by the common tests.
my ( $mdriver, $test_dsn, $test_user, $test_password );
{
    # Define values that are relevant only to CSV
    # Set up the common variables with the CSV specific values
    $mdriver       = 'CSV';
    $test_dsn      = "MiniDBI:$mdriver:"; # TODO remove last :
    $test_user     = '';
    $test_password = '';
}

# Detect and report possible errors from eval of the common test script
warn $! if "ok 99-common.pl6" ne eval slurp 't/99-common.pl6';
