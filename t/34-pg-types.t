use v6;
use Test;
use DBIish;

plan 10;

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
$dbh.execute('SET client_min_messages TO WARNING');
lives-ok {
    $dbh.execute(q|
    CREATE TEMPORARY TABLE test_types (
	col1 text
    )|)
}, 'Table created';

my $sth = $dbh.prepare('INSERT INTO test_types (col1) VALUES(?)');
lives-ok {
    $sth.execute('test');
}, 'Insert Perl6 values';
$sth.dispose;
$sth = $dbh.prepare('SELECT col1 FROM test_types');
my @coltype = $sth.column-types;
ok @coltype eqv [Str],	    'Column-types';

$sth.execute;
is $sth.rows, 1,			    '1 row';
my ($col1) = $sth.row;
isa-ok $col1, Str;
is $col1, 'test',			    'Test';


# Change the type conversion and start a new statement handle. Type conversions are fixed
# after the statement handle is prepared.
$dbh.register-type-conversion(db-type => 'text', raku-type => Str, from-db-sub => sub (Str $value) {'changed'});
$sth = $dbh.prepare('SELECT col1 FROM test_types');
$sth.execute;
is $sth.rows, 1,			    '1 row';
($col1) = $sth.row;
is $col1, 'changed',		    'Changed';


# Round-trip a complex type
# See examples/pg_custom_type.p6 for details
subtest 'Roundtrip complex multi-field type' => {
    $dbh.execute(q:to/STATEMENT/);
     CREATE TEMPORARY TABLE tab (
      col point NOT NULL
     );
    STATEMENT

    class Point {
        has Int $.x is required;
        has Int $.y is required;
    }

    # Conversion from the DB to the Raku type.
    my $from-db-sub = sub ($value --> Point) {
        if $value ~~ / "(" $<x>=(<[-]>? \d+) "," $<y>=(<[-]>? \d+)  ")"/ {
            return Point.new(x => Int.new(~$<x>), y => Int.new(~$<y>));
        } else {
            die "Value '$value' is not a point";
        }
    }

    # Conversion routine to create a PostgreSQL string for the Point class.
    my $to-db-sub = sub (Point $obj --> Str) {
        return '(%d,%d)'.sprintf($obj.x.Str, $obj.y.Str);
    };

    $dbh.register-type-conversion(schema => 'pg_catalog', db-type => 'point', raku-type => Point, :$from-db-sub, :$to-db-sub);

    my $point = Point.new(x => 4, y => -8);
    $dbh.execute('INSERT INTO tab VALUES ($1)', $point);

    if $dbh.execute('SELECT col FROM tab').row(:hash) -> $row {
        my $retrieved-point = $row<col>;

        is $point.x, $retrieved-point.x, 'X coord matches';
        is $point.y, $retrieved-point.y, 'Y coord matches';
    } else {
        fail('Record Does not exist');
    }
}
