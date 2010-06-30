# MiniDBI/t/10-mysql-common.t

use Test;
use MiniDBI;

# Define the only database specific values used by the common tests.
my ( $mdriver, $test_dsn, $test_user, $test_password );
{
    # Define values that are relevant only to MySQL
    my $hostname   = 'localhost';
    my $port       = 3306;
    my $database   = 'zavolaj';
    # Set up the common variables with the MySQL specific values
    $mdriver       = 'mysql';
    $test_dsn      = "MiniDBI:$mdriver" ~ ":database=$database;"
                     ~ "host=$hostname;port=$port";
    $test_user     = 'testuser';
    $test_password = 'testpass';
}

# Detect and report possible errors from eval of the common test script
warn $! if "ok 99-common.pl6" ne eval slurp 't/99-common.pl6';
