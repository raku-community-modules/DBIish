use v6;
use Test;
use DBIish::CommonTesting;

plan 17;

my %con-parms;
# If env var set, no parameter needed.
%con-parms<database> = 'dbdishtest' unless %*ENV<PGDATABASE>;
%con-parms<user> = 'postgres' unless %*ENV<PGUSER>;
my $dbh = DBIish::CommonTesting.connect-or-skip('Pg', |%con-parms);

ok $dbh,    'Connected';
lives-ok {
    $dbh.execute(q|
    CREATE TEMPORARY TABLE test_blob (
	id INT NOT NULL DEFAULT 0, 
	name bytea)|)
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
