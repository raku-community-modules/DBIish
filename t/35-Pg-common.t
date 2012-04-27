# DBIish/t/35-Pg-common.t
use v6;
use Test;
use DBIish;

# Define the only database specific values used by the common tests.
my ( $*mdriver, %*opts ) = 'Pg';
%*opts<host>     = 'localhost';
%*opts<port>     = 5432;
%*opts<database> = 'zavolaj';
%*opts<user>     = 'testuser';
%*opts<password> = 'testpass';
my $dbh;

my $post_connect_cb = {
    my $dbh = @_.shift;
    $dbh.do('SET client_min_messages = warning');
};

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
