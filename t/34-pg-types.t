use v6;
use Test;
use DBIish::CommonTesting;

plan 3;

my %con-parms;
# If env var set, no parameter needed.
%con-parms<database> = 'dbdishtest' unless %*ENV<PGDATABASE>;
%con-parms<user> = 'postgres' unless %*ENV<PGUSER>;
my $dbh = DBIish::CommonTesting.connect-or-skip('Pg', |%con-parms);

ok $dbh, 'Connected';

subtest 'Test changing column type' => {
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
    ok @coltype eqv [Str], 'Column-types';

    $sth.execute;
    is $sth.rows, 1, '1 row';
    my ($col1) = $sth.row;
    isa-ok $col1, Str;
    is $col1, 'test', 'Test';

    # Change the type conversion and start a new statement handle. Type conversions are fixed
    # after the statement handle is prepared.
    $dbh.Converter{Str} = sub ($) {
        'changed'
    };
    $sth = $dbh.prepare('SELECT col1 FROM test_types');
    $sth.execute;
    is $sth.rows, 1, '1 row';
    ($col1) = $sth.row;
    is $col1, 'changed', 'Changed';
}

subtest 'Big Decimals' => {
    my FatRat @values = '0.00000000000000000000123'.FatRat,
                        '1.123456789123456789123456789123456789123456789123456789'.FatRat;
    for @values -> $val {
        my $sth = $dbh.execute('SELECT ?::numeric', $val);
        my ($col1) = $sth.row;
        isa-ok $col1, Rat, 'Rational';

        # Convert to FatRat to prevent comparison issues during stringification that is (via eq) uses.
        is $col1.FatRat, $val.FatRat, 'Expected value roundtripped';
    }
}
