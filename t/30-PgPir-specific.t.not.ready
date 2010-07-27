use v6;
use Test;
plan *;

use MiniDBI;

my $mdriver  = 'PgPir';
my $host     = 'localhost';
my $port     = 5432;
my $database = 'testdb';
my $user     = 'testuser';
my $password = 'testpass';
# my $password = 'Cho5thae';

my $test_dsn = "MiniDBI:{$mdriver}:dbname=$database;host=$host;port=$port";

my $drh = MiniDBI.install_driver($mdriver);
ok $drh, 'Install driver';

my $dbh;
lives_ok { $dbh = MiniDBI.connect($test_dsn, $user, $password,
        RaiseError => 1, PrintError => 1, AutoCommit => 1) },
    'Connecting lives';

ok defined($dbh), 'DBH is defined';
ok $dbh, 'DBH is true';
# lives_ok { $dbh.finish }, 'Can finish DBH';
#nok $dbh, 'finished DBH is false';


done_testing;

=begin pod

=head1 PREREQUISITES
Your system should already have libpq-dev installed.  Change to the
postgres user and connect to the postgres server as follows:

 sudo -u postgres psql

Then set up a test environment with the following:

 CREATE DATABASE testdb;
 CREATE ROLE testuser LOGIN PASSWORD 'testpass';
 GRANT ALL PRIVILEGES ON DATABASE testdb TO testuser;

The '\l' psql command output should include testdb as a database name.
Exit the psql client with a ^D, then try to use the new account:

 psql --host=localhost --dbname=testdb --username=testuser --password
 SELECT * FROM pg_database;

=end pod
