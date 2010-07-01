use v6;
use Test;
plan *;

use FakeDBI;

my $mdriver  = 'PgPir';
my $host     = 'localhost';
my $port     = 5432;
my $database = 'testdb';
my $user     = 'testuser';
my $password = 'Cho5thae';

my $test_dsn = "FakeDBI:{$mdriver}:dbname=$database;host=$host;port=$port";

my $drh = FakeDBI.install_driver($mdriver);
ok $drh, 'Install driver';

my $dbh;
lives_ok { $dbh = FakeDBI.connect($test_dsn, $user, $password,
        RaiseError => 1, PrintError => 1, AutoCommit => 1) },
    'Connecting lives';

ok defined($dbh), 'DBH is defined';
ok $dbh, 'DBH is true';
# lives_ok { $dbh.finish }, 'Can finish DBH';
#nok $dbh, 'finished DBH is false';


done_testing;
