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
            default { .rethrow; }
  }
}
without $dbh {
    skip-rest 'prerequisites failed';
    exit;
}

ok $dbh,    'Connected';
# Be less verbose;
$dbh.do('SET client_min_messages TO WARNING');
$dbh.do('SET timezone TO UTC');
lives-ok {
    $dbh.do(q|
    CREATE TEMPORARY TABLE test_datetime (
	adate DATE,
	atime TIME,
	atimestamp TIMESTAMP WITH TIME ZONE,
	aninterval INTERVAL
    )|)
}, 'Table created';

my $sth = $dbh.prepare('INSERT INTO test_datetime (adate, atimestamp) VALUES(?, ?)');
my $now = DateTime.now( timezone => 0 );
lives-ok {
    $sth.execute($now, $now);
}, 'Insert Perl6 values';
lives-ok {
    $sth.execute('today', 'now');
}, 'Insert PostgreSQL literals';
$sth.dispose;
$sth = $dbh.prepare('SELECT adate, atimestamp FROM test_datetime');
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



# Tests for interval to ensure a naive numeric conversion isn't added back
# Pg cannot convert years, months, days to an integer as those vary in length
# Also note intervalStyle variations.
my $sthint = $dbh.prepare(q{SELECT INTERVAL '1 century + 1 month - 5 days 4 hours - 32 minutes' AS intexample});
$sthint.execute();
my $row = $sthint.row(:hash);
is $row<intexample>, '100 years 1 mon -5 days +03:28:00', 'Complex interval';

