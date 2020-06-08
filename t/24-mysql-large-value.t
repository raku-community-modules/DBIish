use v6;
use Test;
use DBIish;

plan 21;
my %con-parms = :database<dbdishtest>, :user<testuser>, :password<testpass>;
my $dbh;

# Test buffer size scaling

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
    is $col1, $string, 'Value: %d chars'.sprintf($string.chars) ;
}



