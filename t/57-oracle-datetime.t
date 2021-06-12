use v6;
use Test;
use DBIish;

plan 33;

# Convert to TEMPORARY table instead?
without %*ENV<DBIISH_WRITE_TEST> {
    skip-rest 'Set environment variable DBIISH_WRITE_TEST=YES to run this test';
    exit;
}

my %con-parms = :database<XE>, :username<TESTUSER>, :password<Testpass>;
my $dbh;

try {
    $dbh = DBIish.connect('Oracle', |%con-parms);
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
my $dropper = q|
    BEGIN
    -- Saved for a rainy day -or- spring cleaning
    -- EXECUTE IMMEDIATE 'PURGE RECYCLEBIN';
       EXECUTE IMMEDIATE 'DROP TABLE test_datetime CASCADE CONSTRAINTS PURGE';
    EXCEPTION
       WHEN OTHERS THEN
          IF SQLCODE != -942 THEN
             RAISE;
          END IF;
    END;|;

lives-ok { $dbh.execute($dropper) }, 'Clean';
lives-ok {
    $dbh.execute(qq|
    CREATE TABLE test_datetime (
        adate DATE,
        atimestamp0    TIMESTAMP(0),
        atimestamp6    TIMESTAMP(6),
        atimestamp0tz  TIMESTAMP(0) WITH TIME ZONE,
        atimestamp6tz  TIMESTAMP(6) WITH TIME ZONE,
        atimestamp0ltz TIMESTAMP(0) WITH LOCAL TIME ZONE,
        atimestamp6ltz TIMESTAMP(6) WITH LOCAL TIME ZONE
    )|);
}, 'Table created';

my $sth = $dbh.prepare(
    q|INSERT INTO test_datetime (adate, atimestamp6tz) VALUES(?,?)|);
my $now = DateTime.now;

lives-ok {
    $sth.execute(
        $now.Date, # Need a date
        $now,
    );
},                                           'Can insert Raku values';
$sth.dispose;

$sth = $dbh.prepare('SELECT adate, atimestamp6tz FROM test_datetime');
my @coltype = $sth.column-types;
ok @coltype eqv [Date, DateTime],            'Column-types match';

$sth.execute;
my ($date, $datetime) = $sth.row;
isa-ok $date, Date;
isa-ok $datetime,  DateTime;

is $date, $now.Date,                        'Today';
is $datetime, $now,                         'Right now';
$sth.dispose;

$sth = $dbh.prepare('SELECT SYSDATE FROM dual');
isa-ok $sth.column-types[0], Date, 'SYSDATE is Date';
$sth.execute;
is $sth.row[0], Date.today,                 'Today';
$sth.dispose;

$sth = $dbh.prepare('SELECT CURRENT_TIMESTAMP FROM dual');
isa-ok $sth.column-types[0], DateTime, 'CURRENT_TIMESTAMP is DateTime';
$sth.execute;
my $datetime2 = $sth.row[0];
isnt $datetime, $datetime2,                 'Server drift';

diag $datetime2.Instant - $datetime.Instant;

ok $dbh.execute('DELETE FROM test_datetime WHERE adate IS NOT NULL'), 'Delete rows';
ok $dbh.dispose, 'Close session';

note '#+ -------------------------------------------------------- +';
note '## Issue #204 - ADD Missing TIMESTAMP Support tests (BEGIN)';
note '#+ -------------------------------------------------------- +';

%con-parms = :database<XE>, :username<TESTUSER>, :password<Testpass>, :!AutoCommit;

try {
  $dbh = DBIish.connect('Oracle', |%con-parms);
  CATCH {
      when X::DBIish::LibraryMissing | X::DBDish::ConnectionFailed {
          diag "$_\nCan't continue.";
      }
      default { .rethrow; }
  }
}

# session mgmt comming soon
is $dbh.do('ALTER SESSION SET time_zone               = \'-00:00\''), 0, 'ALTER SESSION ...';
is $dbh.do('ALTER SESSION SET nls_date_format         = \'YYYY-MM-DD"T"HH24:MI:SS"Z"\''), 0, 'ALTER SESSION ...';
is $dbh.do('ALTER SESSION SET nls_timestamp_format    = \'YYYY-MM-DD"T"HH24:MI:SS"Z"\''), 0, 'ALTER SESSION ...';
is $dbh.do('ALTER SESSION SET nls_timestamp_tz_format = \'YYYY-MM-DD"T"HH24:MI:SS"Z"\''), 0, 'ALTER SESSION ...';
is $dbh.execute('SELECT * FROM test_datetime').allrows, (), 'Perfect table is empty!';

$sth = $dbh.prepare(
    q|INSERT INTO test_datetime
    FIELDS (adate, atimestamp0, atimestamp6, atimestamp0tz, atimestamp6tz, atimestamp0ltz, atimestamp6ltz)
    VALUES (?,?,?,?,?,?,?)|);
$now = DateTime.now.truncated-to('second').in-timezone(0);

say '# Tasty timestamp: ', $now;
lives-ok {
    $sth.execute(
        $now, # Need an ISO full date
        $now, $now, $now, $now, $now, $now
    );
},                                           'Can insert Raku values';

is $dbh.execute('SELECT * FROM test_datetime').allrows.elems, 1, 'One row!';

# DATE
is $dbh.execute('SELECT adate FROM test_datetime').allrows, $now.Date.Str, 'DATE is read into Date.new() but lacks the time component!';
# TIMESTAMP(0)/(N)
is $dbh.execute('SELECT atimestamp0 FROM test_datetime').allrows, $now.Str, 'TIMESTAMP(0) is read into DateTime.new()';
is $dbh.execute('SELECT atimestamp6 FROM test_datetime').allrows, $now.Str, 'TIMESTAMP(6) is read into DateTime.new()';
# TIMESTAMP(0)/(N) WITH TIME ZONE
is $dbh.execute('SELECT atimestamp0tz FROM test_datetime').allrows, $now.Str, 'TIMESTAMP(0) W TZ is read into DateTime.new()';
is $dbh.execute('SELECT atimestamp6tz FROM test_datetime').allrows, $now.Str, 'TIMESTAMP(6) W TZ is read into DateTime.new()';
# TIMESTAMP(0)/(N) WITH LOCAL TIME ZONE
is $dbh.execute('SELECT atimestamp0ltz FROM test_datetime').allrows, $now.Str, 'TIMESTAMP(0) W LTZ is read into DateTime.new()';
is $dbh.execute('SELECT atimestamp6ltz FROM test_datetime').allrows, $now.Str, 'TIMESTAMP(6) W LTZ is read into DateTime.new()';

$dbh.rollback;
ok $sth.dispose,  'dispose';
is $dbh.execute('SELECT * FROM test_datetime').allrows.elems, 0, 'Perfect table is empty!';

note '#+ -------------------------------------------------------- +';
note '## Issue #204 - ADD Missing TIMESTAMP Support tests (END)';
note '#+ -------------------------------------------------------- +';

# Done
ok $dbh.execute($dropper), 'Table Cleanup';
ok $dbh.dispose, 'Say good night!';

# vim: ft=perl6 expandtab
## END
