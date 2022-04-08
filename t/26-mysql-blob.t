use v6;
use Test;
use DBIish;

plan 9;

my %con-parms = :database<dbdishtest>, :user<testuser>, :password<testpass>;
%con-parms<host> = %*ENV<MYSQL_HOST> if %*ENV<MYSQL_HOST>;
my $dbh;

try {
  $dbh = DBIish.connect('mysql', |%con-parms);
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
lives-ok {
    $dbh.execute(q|
    CREATE TEMPORARY TABLE test_blob (
    id INT(3) NOT NULL DEFAULT 0,
    name BLOB)|)
}, 'Table created';
my $blob = Buf.new(^256);
my $query = 'INSERT INTO test_blob VALUES(?, ?)';

with $dbh.prepare($query) {
    LEAVE { .dispose }
    ok $_,				"Prepared '$query'";
    ok .execute(1, $blob),		'Executed with buf';
    ok .execute(2, Buf),		'Executed without buf';
} else { .fail }

with $dbh.prepare('SELECT name FROM test_blob WHERE id = ?') {
    LEAVE { .dispose }
    ok $_,				'SELECT prepared';
    subtest 'Data is Blob with value' => {
        ok .execute(1), 'Executed for 1';
        ok (my @res = .row), 'Get a row';
        is @res.elems, 2, 'One field';
        ok (my $data = @res[0]), 'With data at 0';
        ok $data ~~ Buf, 'Data is-a Buf';
        is $data, $blob, 'Data in Buf match with original';
    }

    subtest 'Data from Empty buf' => {
        ok .execute(2), 'Executed for 2';
        ok (my @res = .row), 'Get a row';
        is @res.elems, 2, 'One field';
        my $data = @res[0];
        ok $data ~~ Buf, 'Data is-a Buf';
        ok not $data.defined, 'But is NULL';
    }
} else { .fail }

