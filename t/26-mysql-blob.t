v6;
use Test;
use DBIish;

plan 9;

my %con-parms = :database<dbdishtest>, :user<testuser>, :password<testpass>;
my $dbh;

try {
  $dbh = DBIish.connect('mysql', |%con-parms);
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
ok $dbh.do('DROP TABLE IF EXISTS test'), 'Clean';
ok $dbh.do(q|
    CREATE TABLE test (
	id INT(3) NOT NULL DEFAULT 0, 
	name BLOB
)|), 'Table created';
my $blob = Blob.new(^256);
diag $blob.gist;
my $query = 'INSERT INTO test VALUES(?, ?)';
ok (my $sth = $dbh.prepare($query)),	 "Prepared '$query'";
ok $sth.execute(1, $blob),		 'Executed';
ok $sth = $dbh.prepare('SELECT name FROM test WHERE id = ?'), 'SELECT prepared';
ok $sth.execute(1), 'Executed';
my @res = $sth.row;
$sth.finish;
is @res[0], $blob, 'Data Match';
ok $dbh.do('DROP TABLE IF EXISTS test'), 'Clean again';
