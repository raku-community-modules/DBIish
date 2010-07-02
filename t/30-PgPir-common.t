# MiniDBI/t/30-PgPir-common.t
use v6;
use Test;
use MiniDBI;

# Define the only database specific values used by the common tests.
my ( $mdriver, $test_dsn, $test_user, $test_password );
{
    # Define values that are relevant only to MySQL
    my $hostname   = 'localhost';
    my $database   = 'zavolaj';
    # Set up the common variables with the MySQL specific values
    $mdriver       = 'PgPir';
    $test_dsn      = "MiniDBI:$mdriver" ~ ":database=$database;"
                     ~ "host=$hostname";
    $test_user     = 'testuser';
    $test_password = 'testpass';
}

# Detect and report possible errors from eval of the common test script
warn $! if "ok 99-common.pl6" ne eval slurp 't/99-common.pl6';

=begin pod

=head1 PREREQUISITES
Your system should already have libpq-dev installed.  Change to the
postgres user and connect to the postgres server as follows:

 sudo -u postgres psql

Then set up a test environment with the following:

 CREATE DATABASE zavolaj;
 CREATE ROLE testuser LOGIN PASSWORD 'testpass';
 GRANT ALL PRIVILEGES ON DATABASE zavolaj TO testuser;

The '\l' psql command output should include zavolaj as a database name.
Exit the psql client with a ^D, then try to use the new account:

 psql --host=localhost --dbname=zavolaj --username=testuser --password
 SELECT * FROM pg_database;

=end pod
