use v6;
use Test;
use DBIish;

plan 17;

without %*ENV<DBIISH_WRITE_TEST> {
	skip-rest 'Set environment variable DBIISH_WRITE_TEST=YES to run this test';
	exit;
}

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
lives-ok { $dbh.execute('DROP TYPE IF EXISTS yesno') }, 'Clean';
lives-ok {
    $dbh.execute(q|
    CREATE TYPE yesno AS ENUM (
	'Yes',
	'No'
	)|)
}, 'Type created';


lives-ok {
    $dbh.execute(q|
    CREATE TEMPORARY TABLE test_enum (
	id INT NOT NULL DEFAULT 0, 
	yeah yesno)|)
}, 'Table created';

my $query = 'INSERT INTO test_enum VALUES(?, ?)';
ok my $sth = $dbh.prepare($query), "Prepared '$query'";
ok $sth.execute(1, 'Yes'),		 'Executed with Yes';
ok $sth.execute(2, 'No'),		 'Executed with No';
ok $sth.execute(3, Nil),		 'Executed with null';

ok $sth = $dbh.prepare('SELECT yeah FROM test_enum WHERE id = ?'), 'SELECT prepared';
subtest {
    ok $sth.execute(1), 'Executed for 1';
    ok (my @res = $sth.row), 'Get a row';
    # Returns a simple cast to a string by default if a converter isn't configured.
    is @res[0], 'Yes', 'String version of value';
}, 'String value for "1"';
subtest {
    ok $sth.execute(3), 'Executed for 3';
    ok (my @res = $sth.row), 'Get a row';
    not @res[0].defined, 'Nil';
}, 'String value for "3"';

# FIXME: Remove this?
$sth = $dbh.prepare(q|
	SELECT pg_enum.enumlabel AS enumlabel
	 FROM pg_type
	 JOIN pg_enum ON pg_enum.enumtypid = pg_type.oid
	ORDER BY enumsortorder;
|);
ok (my @enum = $sth.execute.allrows(:hash)), 'Get the enumlabels';
my @options;
for @enum -> @option {
	@options.push(@option[0]);
}

{
    # Setup an Enum. Doing this dynamically from DB values is very tricky.
    # FIXME: @options fails to setup the enum correctly
    enum YesNo (Yes => 'Yes', No => 'No');

    lives-ok {
        my $convert-sub = sub ($value) {
            # Returning YesNo(Nil) doesn't quite work with a --> YesNo signature on the function.
            $value.defined ?? YesNo($value) !! Nil;
        }
        $dbh.register-type-conversion(:schema<public>, :db-type<yesno>, raku-type => YesNo,
        from-db-sub => $convert-sub);
    }, 'Install the YesNo converter';

    ok $sth = $dbh.prepare('SELECT yeah FROM test_enum WHERE id = ?'), 'Prepare statement';
    subtest {
        ok $sth.execute(1), 'Executed for 1';
        ok (my @res = $sth.row), 'Get a row';
        is @res.elems, 1, 'One field';
        my $data = @res[0];
        ok $data ~~ YesNo, 'Data is an YesNo enum';
        is $data, Yes, 'Data match with original';
    }, 'Enum value for "1"';

    subtest {
        ok $sth.execute(2), 'Executed for 2';
        ok (my @res = $sth.row), 'Get a row';
        is @res.elems, 1, 'One field';
        my $data = @res[0];
        ok $data ~~ YesNo, 'Data is an YesNo enum';
        is $data, No, 'Data match with original';
    }, 'Enum value for "2"';

    subtest {
        ok $sth.execute(3), 'Executed for 3';
        ok (my @res = $sth.row), 'Get a row';
        is @res.elems, 1, 'One field';
        my $data = @res[0];
        nok $data.defined, 'Data match with original';
    }, 'Enum value for "3"';
}
