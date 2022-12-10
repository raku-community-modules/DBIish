use v6;
use Test;
use DBIish::CommonTesting;

plan 18;

# Convert to TEMPORARY table instead?
without %*ENV<DBIISH_WRITE_TEST> {
    skip-rest 'Set environment variable DBIISH_WRITE_TEST=YES to run this test';
    exit;
}

my %con-parms;
%con-parms = :database<XE>, :username<TESTUSER>, :password<Testpass>;
my $dbh = DBIish::CommonTesting.connect-or-skip('Oracle', |%con-parms);

my $dropper = q|
    BEGIN
       EXECUTE IMMEDIATE 'DROP TABLE test_blob';
    EXCEPTION
       WHEN OTHERS THEN
	  IF SQLCODE != -942 THEN
	     RAISE;
	  END IF;
    END;|;

ok $dbh,    'Connected';
lives-ok { $dbh.execute($dropper) }, 'Clean';
lives-ok {
    $dbh.execute(q|CREATE TABLE test_blob (id NUMBER, name RAW(300) )|)
}, 'Table created';
my $blob = Buf.new(^256);
my $query = 'INSERT INTO test_blob VALUES(?, ?)';
ok (my $sth = $dbh.prepare($query)),	 "Prepared '$query'";
ok $sth.execute(1, $blob),		 'Executed with buf';
ok $sth.execute(2, Buf),		 'Executed without buf';
ok $sth = $dbh.prepare('SELECT name FROM test_blob WHERE id = ?'), 'SELECT prepared';
ok $sth.execute(1), 'Executed for 1';
ok (my @res = $sth.row), 'Get a row';
is @res.elems,  1,	 'One field';
ok (my $data = @res[0]), 'With data at 0';
ok $data ~~ Buf,         'Data is-a Buf';
is $data, $blob,         'Data in Buf match with original';
ok $sth.execute(2),      'Executed for 2';
ok (@res = $sth.row),	 'Get a row';
is @res.elems,  1,	 'One field';
$data = @res[0];
ok $data ~~ Buf,         'Data is-a Buf';
ok not $data.defined,    'But is NULL';
$dbh.execute($dropper);
