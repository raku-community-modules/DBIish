# DBIish/t/35-Pg-common.t
use v6;
use Test;
use DBIish;

# Define the only database specific values used by the common tests.
my ( $*mdriver, %*opts ) = 'Oracle';
%*opts<host>     = 'localhost';
%*opts<port>     = 1521;
%*opts<dbname>   = 'zavolaj';
%*opts<username> = 'testuser';
%*opts<password> = 'testpass';
my $dbh;

my $post_connect_cb = {
    my $dbh = @_.shift;
};

# Detect and report possible errors from EVAL of the common test script
warn $! if "ok 99-common.pl6" ne EVAL slurp 't/99-common.pl6';

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
