use v6;
use Test;
use DBIish::CommonTesting;

plan 5;

my %con-parms = :database<dbdishtest>, :user<testuser>, :password<testpass>;
%con-parms<host> = %*ENV<MYSQL_HOST> if %*ENV<MYSQL_HOST>;
my $dbh = DBIish::CommonTesting.connect-or-skip('mysql', |%con-parms);

subtest 'Very large string' => {
    lives-ok {
        $dbh.execute(qq|
    CREATE TEMPORARY TABLE test_long_string (
	col1 varchar(16383)
    )|)
    }, 'Table created';

    my @string-lengths = 100, 8191, 8192, 8193, 10_000, 16383;
    my @long-strings;
    for @string-lengths -> $length {
        @long-strings.push('x' x $length);
    }

    my $sth = $dbh.prepare('INSERT INTO test_long_string (col1) VALUES(?)');
    for @long-strings -> $string {
        lives-ok {
            $sth.execute($string);
        }, 'Add value: %d chars'.sprintf($string.chars);
    }
    $sth.dispose;

    $sth = $dbh.execute('SELECT col1 FROM test_long_string ORDER BY length(col1)');

    is $sth.rows, @long-strings.elems, '%d row'.sprintf(@long-strings.elems);

    # Compare both source and DB long strings in order by length.
    for @long-strings -> $string {
        my ($col1) = $sth.row;

        isa-ok $col1, Str;
        is $col1, $string, 'Value: %d chars'.sprintf($string.chars);
    }
}

# Very large integer test
subtest 'Very large integers' => {
    lives-ok {
        $dbh.execute(qq|
    CREATE TEMPORARY TABLE test_long_integer (
	col1 numeric(64)
    )|)
    }, 'Table created';

    my @values = 2 ** 63 - 1, -2 ** 63 + 1,
                 2 ** 63, -2 ** 63,
                 2 ** 64 - 1, -2 ** 64 + 1,
                 2 ** 64, -2 ** 64,
                 2 ** 80, -2 ** 80;

    my $sth = $dbh.prepare('INSERT INTO test_long_integer (col1) VALUES(?)');
    for @values -> $num {
        lives-ok {
            $sth.execute($num);
        }, 'Add value: %d digits'.sprintf($num.chars);
    }
    $sth.dispose;

    $sth = $dbh.execute('SELECT col1 FROM test_long_integer ORDER BY col1');

    is $sth.rows, @values.elems, '%d row'.sprintf(@values.elems);
    # Compare both source and DB long strings in order by value.
    for @values.sort -> $num {
        my ($col1) = $sth.row;

        isa-ok $col1, Rat;
        is $col1, $num, 'Value: %d digits'.sprintf($num.chars);
    }
}

subtest 'Numbers are transmitted as numbers' => {
    $dbh.execute(
            'CREATE TEMPORARY TABLE tmp_num_test AS SELECT ? as num, ? as intrat, ? as decimalrat, ? as fatrat, ? as unspecified',
            2.0.Num, 2.0.Rat, 2.2.Rat, 2.2.FatRat, 2.0);

    my $sth = $dbh.execute('describe tmp_num_test');
    while my $row = $sth.row {
        my ($col-name, $datatype-buf) = $row;
        my $datatype = $datatype-buf.decode;
        if $col-name eq 'fatrat' {
            like $datatype, /^decimal/, "$col-name type is decimal";
        } else {
            is $datatype, 'double', "$col-name type is double";
        }
    }

    $sth = $dbh.execute('SELECT * FROM tmp_num_test');
    my ($num, $intrat, $decrat, $fatrat, $unspecified, $string) = $sth.row;
    is $num, 2.0.Num, 'Num value roundtriped';
    is $intrat, 2.0.Rat, 'Rat (integer) value roundtriped';
    is $decrat, 2.2.Rat, 'Rat (decimal) value roundtriped';
    is $fatrat, 2.2.FatRat, 'FatRat value roundtriped';
    is $unspecified, 2.0.Num, 'Unspecified was treated as Num';
}

subtest 'Large Rats' => {
    lives-ok {
        $dbh.execute(qq|
           CREATE TEMPORARY TABLE test_long_rat (
           col1 numeric(64, 30)
           )|)
    }, 'Table created';

    my @values = 10.43, -10.34,
                 '0.123456789012345678901'.FatRat, '-0.123456789012345678901'.FatRat,
                 (2 ** 63 + 0.1).FatRat, (-2 ** 63 + 0.1).FatRat,
                 (2 ** 80 + 0.1).FatRat, (-2 ** 80 + 0.1).FatRat,
                 '0.123456789012345678901'.FatRat, '-0.123456789012345678901'.FatRat;
    my $sth = $dbh.prepare('INSERT INTO test_long_rat (col1) VALUES(?)');

    for @values -> $num {
        lives-ok {
            $sth.execute($num);
        }, 'Add value: %d digits'.sprintf($num.chars);
    }
    $sth.dispose;

    $sth = $dbh.execute('SELECT col1 FROM test_long_rat ORDER BY col1');

    is $sth.rows, @values.elems, '%d row'.sprintf(@values.elems);

    # Compare both source and DB long strings in order by value.
    for @values.sort -> $num {
        my ($col1) = $sth.row;

        isa-ok $col1, Rat;

        # FatRat to ensure stringification of Rat (via is eqv operation) doesn't impact
        # the value.
        is $col1.FatRat, $num.FatRat, 'Value: %d digits'.sprintf($num.chars);
    }
}

subtest 'Special DateTime values' => {
    my $sth = $dbh.execute(q{select cast('0000-00-00T00:00:00' as datetime) as col1});
    my ($col1) = $sth.row;

    isa-ok $col1, DateTime, 'All-zeros DateTime is expected type';

    my DateTime $expected = Nil;
    is $col1, $expected, 'All-zeros DateTime is Nil';
}