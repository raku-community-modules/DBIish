use v6;
use Test;
use DBIish;

plan 42;

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
note '## Issue #203 - Timezone not always taken into account';
note '##   As with all things Oracle there is no single solution';
note '##   This test and newly added connect options provide';
note '##   *an* example';
note '#+ -------------------------------------------------------- +';

# use :alter-session-iso8601 (support all DATE & TIMESTAMP types)
# all should work with DateTime($st)
%con-parms = :database<XE>, :username<TESTUSER>, :password<Testpass>, :!AutoCommit, :alter-session-iso8601;

try {
  $dbh = DBIish.connect('Oracle', |%con-parms);
  CATCH {
      when X::DBIish::LibraryMissing | X::DBDish::ConnectionFailed {
          diag "$_\nCan't continue.";
      }
      default { .rethrow; }
  }
}

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
ok $dbh.dispose, 'Close session';

note '#+ -------------------------------------------------------- +';
note '## Issue #204 - ADD Missing TIMESTAMP Support tests (END)';
note '## Issue #203 - Timezone not always taken into account (END)';
note '#+ -------------------------------------------------------- +';
note '## Issue #203 & #204 - Not everyone wants DBHish in their';
note '##         session business!';
note '##   :no-alter-session, :no-datetime-container';
note '#+ -------------------------------------------------------- +';

# use
#  :no-alter-session      # don't alter session
#  :no-datetime-container # return the date/timestamps as stings
%con-parms = :database<XE>, :username<TESTUSER>, :password<Testpass>, :!AutoCommit
  , :no-alter-session, :no-datetime-container;

try {
  $dbh = DBIish.connect('Oracle', |%con-parms);
  CATCH {
      when X::DBIish::LibraryMissing | X::DBDish::ConnectionFailed {
          diag "$_\nCan't continue.";
      }
      default { .rethrow; }
  }
}

# Session: Something arbitrary but predictable
is $dbh.do(qq|ALTER SESSION SET time_zone               = '-02:00'|), 0, 'ALTER SESSION ...';
is $dbh.do(qq|ALTER SESSION SET nls_date_format         = 'YYYY-MM-DD'|), 0, 'ALTER SESSION ...';
is $dbh.do(qq|ALTER SESSION SET nls_timestamp_format    = 'YYYY-MM-DD"T"HH24:MI:SS.FF'|), 0, 'ALTER SESSION ...';
is $dbh.do(qq|ALTER SESSION SET nls_timestamp_tz_format = 'YYYY-MM-DD"T"HH24:MI:SS.FFTZH:TZM'|), 0, 'ALTER SESSION ...';
is $dbh.execute('SELECT * FROM test_datetime').allrows, (), 'Perfect table is empty!';

 $sth = $dbh.prepare(
     q|INSERT INTO test_datetime
     FIELDS (adate, atimestamp0, atimestamp6, atimestamp0tz, atimestamp6tz, atimestamp0ltz, atimestamp6ltz)
     VALUES (?,?,?,?,?,?,?)|);

 lives-ok {
     $sth.execute(
       '2021-06-12',                       # DATE
       '2021-06-12T18:30:00.0',            # TIMESTAMP(0)
       '2021-06-12T18:30:00.019866',       # TIMESTAMP(6)
       '2021-06-12T18:30:00.0-05:00',      # TIMESTAMP(0) WITH TIME ZONE
       '2021-06-12T18:30:00.019866-05:00', # TIMESTAMP(6) WITH TIME ZONE
       '2021-06-12T18:30:00.0',            # TIMESTAMP(0) WITH LOCAL TIME ZONE
       '2021-06-12T18:30:00.019866'        # TIMESTAMP(6) WITH LCOAL TIME ZONE
     );
 },                                           'Can insert Raku values (strings - containerless)';

note '# See what Oracle is formatting for us...';
for $dbh.execute('SELECT * FROM test_datetime').allrows -> $row { say '# ', $row.perl; }

# DATE
is $dbh.execute('SELECT adate FROM test_datetime').allrows, '2021-06-12', 'DATE smells right!';
# TIMESTAMP(0)/(N)
is $dbh.execute('SELECT atimestamp0 FROM test_datetime').allrows, '2021-06-12T18:30:00.',       'TIMESTAMP(0) as a string';
is $dbh.execute('SELECT atimestamp6 FROM test_datetime').allrows, '2021-06-12T18:30:00.019866', 'TIMESTAMP(6) as a string';
# TIMESTAMP(0)/(N) WITH TIME ZONE
is $dbh.execute('SELECT atimestamp0tz FROM test_datetime').allrows, '2021-06-12T18:30:00.-05:00',       'TIMESTAMP(0) W TZ as a string';
is $dbh.execute('SELECT atimestamp6tz FROM test_datetime').allrows, '2021-06-12T18:30:00.019866-05:00', 'TIMESTAMP(6) W TZ as a string';
# TIMESTAMP(0)/(N) WITH LOCAL TIME ZONE
is $dbh.execute('SELECT atimestamp0ltz FROM test_datetime').allrows, '2021-06-12T18:30:00.',       'TIMESTAMP(0) W LTZ as a string';
is $dbh.execute('SELECT atimestamp6ltz FROM test_datetime').allrows, '2021-06-12T18:30:00.019866', 'TIMESTAMP(6) W LTZ as a string';

note '#+ -------------------------------------------------------- +';
note '## Issue #204 - ADD Missing TIMESTAMP Support tests (END)';
note '## Issue #203 - Timezone not always taken into account (END)';
note '#+ -------------------------------------------------------- +';

# Done
ok $dbh.execute($dropper), 'Table Cleanup';
ok $dbh.dispose, 'Say good night!';

# vim: ft=perl6 expandtab
## END
