use v6;
use Test;
use DBIish;

plan 9;

my $TDB = IO::Path.new('dbdishtest.sqlite3');
my %con-parms;
%con-parms<database> = ~$TDB;
my $dbh;

try {
  $dbh = DBIish.connect('SQLite', |%con-parms);
  CATCH {
	    when X::DBIish::LibraryMissing | X::DBDish::ConnectionFailed {
		diag "$_\nCan't continue.";
	    }
            default { .throw; }
  }
}
without $dbh {
    skip-rest 'prerequisites failed';
    exit;
}

ok $dbh,    'Connected';
lives-ok { $dbh.do('DROP TABLE IF EXISTS test') }, 'Clean';
lives-ok {
    $dbh.do(q|
    CREATE TABLE test (
	adate timestamp,
	atimestamp timestamp
	)|)
}, 'Table created';

my $sth = $dbh.prepare(
    q|INSERT INTO test (adate, atimestamp) VALUES(?, ?)|);
my $now = DateTime.now;

lives-ok {
    $sth.execute(
	$now.Date, # Need a date
	$now,
    );
},                                           'Can insert Perl6 values';
$sth.dispose;

$sth = $dbh.prepare('SELECT adate, atimestamp FROM test');
my @coltype = $sth.column-types;
ok @coltype eqv [Date, DateTime],	    'Column-types match';

$sth.execute;
my ($date, $datetime) = $sth.row;
isa-ok $date, Date;
isa-ok $datetime,  DateTime;

is $date, $now.Date,			    'Today';
is $datetime, $now,			    'Right now';
$sth.dispose;
$TDB.unlink
