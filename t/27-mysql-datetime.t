use v6;
use Test;
use DBIish::CommonTesting;

plan 11;

my %con-parms = :database<dbdishtest>, :user<testuser>, :password<testpass>;
%con-parms<host> = %*ENV<MYSQL_HOST> if %*ENV<MYSQL_HOST>;
my $dbh = DBIish::CommonTesting.connect-or-skip('mysql', |%con-parms);

ok $dbh,    'Connected';
my $subsec = $dbh.drv.version after v5.6.4;
my $field = 'TIMESTAMP'; $field ~= '(6)' if $subsec;
diag "Using $field";
lives-ok {
    $dbh.execute(qq|
    CREATE TEMPORARY TABLE test_datetime (
	adate DATE,
	atime TIME,
	atimestamp $field 
    )|);
}, 'Table created';

my $now = DateTime.now;
$now .= truncated-to('second') unless $subsec;
lives-ok {
    $dbh.execute('INSERT INTO test_datetime (adate, atimestamp) VALUES(?, ?)', $now.Date, $now);
}, 'Insert Perl6 values';
my $sth = $dbh.execute('SELECT adate, atimestamp FROM test_datetime');
my @coltype = $sth.column-types;
ok @coltype eqv [Date, DateTime],	    'Column-types';
is $sth.rows, 1,			    'One row';
my ($date, $datetime) = $sth.row;
isa-ok $date, Date;
isa-ok $datetime,  DateTime;
is $date, $now.Date,			    'Today';
is $datetime, $now,			    'Right now';
$sth.dispose;
$sth = $dbh.prepare('SELECT NOW()');
is $sth.execute.rows, 1,			    'One now';
$datetime = $sth.row[0];
if $subsec {
    isnt $datetime, $now,		    'Server drift';
} else {
    skip "Without subsecond precision",  1;
}
diag $now.Instant - $datetime.Instant;
