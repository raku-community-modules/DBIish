use v6;
use Test;
use DBIish;

plan 13;

my %con-parms;
# If env var set, no parameter needed.
%con-parms<database> = 'dbdishtest' unless %*ENV<PGDATABASE>;
%con-parms<user> = 'postgres' unless %*ENV<PGUSER>;
my $dbh;

try {
  $dbh = DBIish.connect('Pg', |%con-parms);
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
# Be less verbose;
$dbh.do('SET client_min_messages TO WARNING');
lives-ok { $dbh.do('DROP TABLE IF EXISTS test') }, 'Clean';
lives-ok {
    $dbh.do(q|
    CREATE TABLE test (
	adate DATE,
	atime TIME,
	atimestamp TIMESTAMP WITH TIME ZONE,
	aninterval INTERVAL
    )|)
}, 'Table created';

my $sth = $dbh.prepare('INSERT INTO test (adate, atimestamp) VALUES(?, ?)');
my $now = DateTime.now;
lives-ok {
    $sth.execute($now, $now);
}, 'Insert Perl6 values';
lives-ok {
    $sth.execute('today', 'now');
}, 'Insert PostgreSQL literals';
$sth.dispose;
$sth = $dbh.prepare('SELECT adate, atimestamp FROM test');
my @coltype = $sth.column-types;
ok @coltype eqv [Date, DateTime],	    'Column-types';

is $sth.execute, 2,			    'Two rows';
my ($date, $datetime) = $sth.row;
isa-ok $date, Date;
isa-ok $datetime,  DateTime;
is $date, $now.Date,			    'Today';
is $datetime, $now,			    'Right now';
($date, $datetime) = $sth.row;
is $date, $now.Date,			    'Today';
isnt $datetime, $now,			    'Server drift';
diag $datetime.Instant - $now.Instant;
$dbh.do('DROP TABLE IF EXISTS test');
