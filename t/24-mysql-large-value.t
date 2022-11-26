use v6;
use Test;
use DBIish::CommonTesting;

plan 3;
my %con-parms = :database<dbdishtest>, :user<testuser>, :password<testpass>;
%con-parms<host> = %*ENV<MYSQL_HOST> if %*ENV<MYSQL_HOST>;

# Test buffer size scaling
my $dbh = DBIish::CommonTesting.connect-or-skip('mysql', |%con-parms);
ok $dbh,    'Connected';

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
    CREATE TEMPORARY TABLE test_long_number (
	col1 numeric(64)
    )|)
    }, 'Table created';

    my @values = 2**63 - 1, -2**63 + 1,
                 2**63, -2**63,
                 2**64 - 1, -2**64 + 1,
                 2**64, -2**64,
                 2**80, -2**80;
    my $sth = $dbh.prepare('INSERT INTO test_long_number (col1) VALUES(?)');
    for @values -> $num {
        lives-ok {
            $sth.execute($num);
        }, 'Add value: %d digits'.sprintf($num.chars);
    }
    $sth.dispose;

    $sth = $dbh.execute('SELECT col1 FROM test_long_number ORDER BY col1');

    is $sth.rows, @values.elems, '%d row'.sprintf(@values.elems);

    # Compare both source and DB long strings in order by length.
    for @values.sort -> $num {
        my ($col1) = $sth.row;

        isa-ok $col1, FatRat;
        is $col1, $num, 'Value: %d digits'.sprintf($num.chars);
    }
}