use v6;
use Test;
use DBIish;

plan 27;

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
lives-ok { $dbh.do('DROP TYPE IF EXISTS yesno') }, 'Clean';
lives-ok {
    $dbh.do(q|
    CREATE TYPE yesno AS ENUM (
	'Yes',
	'No'
	)|)
}, 'Type created';


lives-ok { $dbh.do('DROP TABLE IF EXISTS test') }, 'Clean';
lives-ok {
    $dbh.do(q|
    CREATE TABLE test (
	id INT NOT NULL DEFAULT 0, 
	yeah yesno)|)
}, 'Table created';

my $query = 'INSERT INTO test VALUES(?, ?)';
ok my $sth = $dbh.prepare($query), "Prepared '$query'";
ok $sth.execute(1, 'Yes'),		 'Executed with Yes';
ok $sth.execute(2, 'No'),		 'Executed with No';
ok $sth.execute(3, Nil),		 'Executed with null';

ok $sth = $dbh.prepare('SELECT yeah FROM test WHERE id = ?'), 'SELECT prepared';
ok $sth.execute(1), 'Executed for 1';
ok (my @res = $sth.row), 'Get a row';

#
$sth = $dbh.prepare(q|
	SELECT pg_type.typarray AS enumtype, 
	    pg_type.typname AS enumname, 
	    pg_enum.enumtypid AS enumoptid, 
	    pg_enum.enumlabel AS enumlabel
	 FROM pg_type
	 JOIN pg_enum
	     ON pg_enum.enumtypid = pg_type.oid
	ORDER BY enumsortorder;
|);
ok my $res = $sth.execute, 'Find the enum';
ok (my @enum = $sth.allrows(:hash)), 'Get the rows';
my (@enumtypes, @options);
for @enum -> @option {
	@enumtypes.push(@option[2]);	
	@options.push(@option[3]);	
}
{
    # This is required as the compiler sees the empty
    # @options being passed to the enum before it is
    # populated at run-time
    no worries;

    my enum YesNo (@options);
    for @enumtypes -> $type {
        $dbh.dynamic-types{$type} = YesNo;
    }

    my Str $expected = 'Yes';
    my $yesno =  sub (Str $value) {
        is $value, $expected, "Value OK ($value eq $expected)";
        $value;
    };
    ok ($dbh.Converter{YesNo} = $yesno),   'Install the YesNo converter';

    ok $sth = $dbh.prepare('SELECT yeah FROM test WHERE id = ?'), 'SELECT prepared';
    ok $sth.execute(1), 'Executed for 1';
    ok (@res = $sth.row), 'Get a row';
    is @res.elems,  1,	 'One field';
    ok (my $data = @res[0]), 'With data at 0';
    ok $data ~~ Str,         'Data is-a Str';
    is $data, 'Yes',         'Data match with original';

    $expected = 'No';
    ok $sth.execute(2),      'Executed for 2';
    ok (@res = $sth.row),	 'Get a row';
    is @res.elems,  1,	 'One field';
}

$dbh.do('DROP TABLE IF EXISTS test');
