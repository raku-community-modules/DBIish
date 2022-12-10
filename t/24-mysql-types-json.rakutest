use v6;
use Test;
use DBIish::CommonTesting;
our &from-json;
BEGIN {
    require ::('JSON::Tiny');
    &from-json = ::("JSON::Tiny::EXPORT::DEFAULT::&from-json");
    CATCH {
	plan :skip-all<This test need JSON::Tiny installed>;
    }
}

class JSON {
    # Used only as a marker for converter
}

plan 25;
my %con-parms = :database<dbdishtest>, :user<testuser>, :password<testpass>;
%con-parms<host> = %*ENV<MYSQL_HOST> if %*ENV<MYSQL_HOST>;
my $dbh = DBIish::CommonTesting.connect-or-skip('mysql', |%con-parms);

if $dbh.server-version.Str ~~ /"MariaDB"/ {
    skip-rest 'MariaDB returns the JSON as a BLOB type, not as a String type.';
    exit;
}

ok $dbh,    'Connected';
my $hasjson = $dbh.drv.version after v5.7.8;
my $field = $hasjson ?? 'JSON' !! 'varchar';
diag "want test '$field'";
lives-ok {
    $dbh.execute(qq|
    CREATE TEMPORARY TABLE test_types (
	col1 $field
    )|)
}, 'Table created';

my $sth = $dbh.prepare('INSERT INTO test_types (col1) VALUES(?)');
lives-ok {
    $sth.execute('{"key1": "value1"}');
}, 'Insert Perl6 values';
$sth.dispose;

$sth = $dbh.prepare('SELECT col1 FROM test_types').execute();
my @coltype = $sth.column-types;
ok @coltype eqv [Str],			    'prep-exec: Column-types';

is $sth.rows, 1,			    'prep-exec: 1 row';
my ($col1) = $sth.row;
isa-ok $col1, Str;
is $col1, '{"key1": "value1"}',		    "prep-exec: Value $col1";

# Execute without prepare goes through a different type handler
# than prepare($qry).execute
if 0 {
    $sth = $dbh.execute('SELECT col1 FROM test_types');
    @coltype = $sth.column-types;
    ok @coltype eqv [Str], 'exec: Column-types';

    is $sth.rows, 1, 'exec: 1 row';
    ($col1) = $sth.row;
    isa-ok $col1, Str;
    is $col1, '{"key1": "value1"}', "exec: Value $col1";
}
else {
    skip 'Type converter not yet supported for MySQL queries without prepare', 4;
}

# Install new type handler
nok $dbh.Converter{JSON},		    'No converter';
$dbh.Converter = :JSON(sub ($json) {
    ok so $json,			    'In converter';
    is $json, '{"key1": "value1"}',	    "Got $json";
    from-json($json);
});
ok $dbh.Converter{JSON},		    'Installed';

# Change column type for future statements
# Resetup the statement as column type manipulations are only handled once.
$sth = $dbh.execute('SELECT col1 FROM test_types');
$sth.column-types[0] = JSON;
$col1 = $sth.row;
ok $col1[0],		                    'Has value';
isa-ok $col1[0], Hash;

ok $sth.dispose,			    'Dispose';

if $hasjson {
    # Install type
    is $dbh.dynamic-types{245}, Str,	    'Is default';
    $dbh.dynamic-types{245} = JSON;
    is $dbh.dynamic-types{245}, JSON,	    'Changed';

    $sth = $dbh.prepare('SELECT col1 FROM test_types');
    ok $sth.execute,			    'Executed';
    isa-ok $sth.column-types[0], JSON;
    isa-ok $sth.row[0], Hash,	            'Converted';
} else {
    skip-rest "No suport for JSON type";
}
