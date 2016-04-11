use v6;
use Test;
use DBIish;

plan 13;

my %con-parms = :database<XE>, :username<TESTUSER>, :password<Testpass>;
my $dbh;

try {
  $dbh = DBIish.connect('Oracle', |%con-parms);
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
my $dropper = q|
    BEGIN
       EXECUTE IMMEDIATE 'DROP TABLE test';
    EXCEPTION
       WHEN OTHERS THEN
          IF SQLCODE != -942 THEN
             RAISE;
          END IF;
    END;|;

lives-ok { $dbh.do($dropper) }, 'Clean';
lives-ok {
    $dbh.do(qq|
    CREATE TABLE test (
	adate DATE,
	atimestamp TIMESTAMP(6) WITH TIME ZONE
    )|);
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

$sth = $dbh.prepare('SELECT SYSDATE FROM dual');
isa-ok $sth.column-types[0], Date, 'SYSDATE is Date';
$sth.execute;
is $sth.row[0], Date.today,		    'Today';
$sth.dispose;

$sth = $dbh.prepare('SELECT CURRENT_TIMESTAMP FROM dual');
isa-ok $sth.column-types[0], DateTime, 'CURRENT_TIMESTAMP is DateTime';
$sth.execute;
my $datetime2 = $sth.row[0];
isnt $datetime, $datetime2,		    'Server drift';
diag $datetime2.Instant - $datetime.Instant;

$dbh.do($dropper);
