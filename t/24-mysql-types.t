use v6;
use Test;
use DBIish;
use JSON::Tiny;

class JSON {
    # Used only as a marker for converter
}

plan 23;
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
lives-ok { $dbh.do('DROP TABLE IF EXISTS test') }, 'Clean';
my $hasjson = $dbh.drv.version after v5.7.8;
my $field = $hasjson ?? 'JSON' !! 'varchar';
diag "want test '$field'";
lives-ok {
    $dbh.do(qq|
    CREATE TABLE test (
	col1 $field
    )|)
}, 'Table created';

my $sth = $dbh.prepare('INSERT INTO test (col1) VALUES(?)');
lives-ok {
    $sth.execute('{"key1": "value1"}');
}, 'Insert Perl6 values';
$sth.dispose;

$sth = $dbh.prepare('SELECT col1 FROM test');
my @coltype = $sth.column-types;
ok @coltype eqv [Str],			    'Column-types';

is $sth.execute, 1,			    '1 row';
my ($col1) = $sth.row;
isa-ok $col1, Str;
is $col1, '{"key1": "value1"}',		    "Value $col1";

# Install new type handler
nok $dbh.Converter{JSON},		    'No converter';
$dbh.Converter = :JSON(sub ($json) {
    ok so $json,			    'In converter';
    is $json, '{"key1": "value1"}',	    "Got $json";
    from-json($json);
});
ok $dbh.Converter{JSON},		    'Installed';

# Change column type for *this* statement
$sth.column-types[0] = JSON;
ok $sth.execute,			    're execute';
$col1 = $sth.row;
ok $col1[0],		                    'Has value';
isa-ok $col1[0], Hash;

ok $sth.dispose,			    'Dispose';

if $hasjson {
    # Install type
    is $dbh.dynamic-types{245}, Str,	    'Is default';
    $dbh.dynamic-types{245} = JSON;
    is $dbh.dynamic-types{245}, JSON,	    'Changed';

    $sth = $dbh.prepare('SELECT col1 FROM test');
    ok $sth.execute,			    'Executed';
    isa-ok $sth.column-types[0], JSON;
    isa-ok $sth.row[0], Hash,	            'Converted';
} else {
    skip-rest "No suport for JSON type";
}

$dbh.do('DROP TABLE IF EXISTS test');
