# DBIish/t/99-common.pl6
# This script is intended to be included as the common SQL tests in
# scripts for specific DBDs such as CSV or mysql.

#use Test;     # "use" dies in a runtime EVAL
#use DBIish;
diag "Testing MiniDBD::$*mdriver";
plan 42;

sub magic_cmp(@a, @b) {
    my $res =  @a[0] eq @b[0]
            && @a[1] eq @b[1]
            && @a[2] == @b[2]
            && @a[3] == @b[3];
    unless $res {
        diag "     Got: @a[]";
        diag "Expected: @b[]";
    }
    $res;
}

sub hash-str(%h) {
    %h.sort.for({ join '', .key, '=«', .value, '»' }).join('; ');
}

# Verify that the driver loads before attempting a connect
my $drh = DBIish.install_driver($*mdriver);
ok $drh, 'Install driver'; # test 1
my $drh_version;
$drh_version = $drh.Version;
ok $drh_version > 0, "MiniDBD::$*mdriver version $drh_version"; # test 2

# Connect to the data sourcequantity*price AS amount FROM nom
my $dbh;
try {
    $dbh = DBIish.connect( $*mdriver, |%*opts, :RaiseError<1> );
    CATCH {
        default {
            diag "Connect failed with error $_";
            skip_rest 'connect failed -- maybe the prerequisites are not installed?';
            exit;
        }
    }
}
ok $dbh, "connect to %*opts<database>"; # test 3

try EVAL '$*post_connect_cb.($dbh)';

# Test .prepare() and .execute() a few times while setting things up.
# Drop a table of the same name so that the following create can work.
my $sth = $dbh.prepare("DROP TABLE IF EXISTS nom");
my $rc = $sth.execute();
isnt $rc, Bool::True, "drop table gave an expected error " ~
    "(did a previous test not clean up?)"; # test 4
$sth.finish;

# Create a table
$sth = $dbh.prepare( "
    CREATE TABLE nom (
        name        varchar(4),
        description varchar(30),
        quantity    int,
        price       numeric(5,2)
    )
");
$rc = $sth.execute();
is $rc, '0E0', "do: create table nom"; # test 5
if $dbh.^can('err') {
    is $dbh.err, 0, 'err after successful create should be 0'; # test 6
}
else { skip 'err after successful create should be 0', 1 }
nok $dbh.errstr, "errstr after successful create should be false"; # test 7

$sth.finish;

# Insert rows using the various method calls
ok $dbh.do( "
    INSERT INTO nom (name, description, quantity, price)
    VALUES ( 'BUBH', 'Hot beef burrito', 1, 4.95 )
"), "insert without parameters called from do"; # test 8

if $dbh.^can('rows') {
    is $dbh.rows, 1, "simple insert should report 1 row affected"; # test 9
}
else { skip '$dbh.rows not implemented', 1 }

ok $sth = $dbh.prepare( "
    INSERT INTO nom (name, description, quantity, price)
    VALUES ( ?, ?, ?, ? )
"), "prepare an insert command with parameters"; # test 10

ok $sth.execute('TAFM', 'Mild fish taco', 1, 4.85 ) &&
   $sth.execute('BEOM', 'Medium size orange juice', 2, 1.20 ),
   "execute twice with parameters"; # test 11
if $dbh.^can('rows') {
    is $sth.rows, 1, "each insert with parameters also reports 1 row affected"; # test 12
}
else { skip '$dbh.rows not implemented', 1 }


if $sth.^can('bind_param_array') {
    my @tuple_status;
    ok $sth.bind_param_array( 1, [ 'BEOM', 'Medium size orange juice', 2, 1.20 ] ),
       "bind_param_array"; # test 13
    ok $sth.execute_array(  { ArrayTupleStatus => \@tuple_status } ); # test 14
}
else { skip '$sth.bind_param_array() and $sth.execute_array() not implemented', 2 }

# Update some rows

# Delete some rows

# Select data using various method calls
ok $sth = $dbh.prepare( "
    SELECT name, description, quantity, price, quantity*price AS amount
    FROM nom 
"), "prepare a select command without parameters"; # test 15

ok $sth.execute(), "execute a prepared select statement without parameters"; # test 16

if $sth.^can('fetchall_arrayref') {
    my $arrayref = $sth.fetchall_arrayref();
    is $arrayref.elems, 3, "fetchall_arrayref returns 3 rows"; # test 17
    my @ref =
        [ 'BUBH', 'Hot beef burrito', '1', '4.95', '4.95' ],
        [ 'TAFM', 'Mild fish taco', '1', '4.85', '4.85' ],
        [ 'BEOM', 'Medium size orange juice', '2', '1.20', '2.40' ];
    my $ok = True;
    for ^3 -> $i {
        $ok &&= magic_cmp($arrayref[$i], @ref[$i]);
    }
    ok $ok, "selected data matches what was written"; # test 18
    $sth.finish;
}
else { skip 'fetchall_arrayref not implemented', 2 }

ok $sth = $dbh.prepare("SELECT * FROM nom WHERE name='TAFM';"),
'prepare new select for fetchrow_hashref test'; #test 19
ok $sth.execute(), 'execute prepared statement for fetchrow_hashref'; #test 20

if $sth.can('column_names') {
    ok my $hashref = $sth.fetchrow_hashref(), 'called fetchrow_hashref'; #test 21
    is hash-str($hashref), hash-str({ 'name' => 'TAFM', 'description' => 'Mild fish taco', 'quantity'
    => 1, 'price' => '4.85' }), 'selected data matches test hashref'; #test 22
    $sth.finish;
}
else { skip 'fetchrow_hashref not implemented', 2 }

# TODO: weird sth behavior workaround! Any sth concerning call at this point
# will return empty or (properly) fail if something is called on that
# sth - after this, everything works fine again.
if $sth.can('colum_names') {
    $sth.execute;
    my $arrayref = $sth.fetchrow_arrayref(); #'called fetchrow_arrayref'; #test23
    $sth.finish;
    is $arrayref.elems, 4, "fetchrow_arrayref returns 4 fields in a row"; #test 24
    ok magic_cmp($arrayref, [ 'TAFM', 'Mild fish taco', 1, 4.85 ]), 'selected data matches test data'; #test 23
}
else { skip 'fetchrow_arrayref not implemented', 2 }

{
    ok $sth = $dbh.prepare('SELECT NULL'), 'can prepare statement "SELECT NULL"';
    $sth.execute;
    my ($v) = $sth.fetchrow;
    $sth.finish;
    nok $v.defined, 'NULL returns an undefined value'
        or diag "NULL returned as $v.perl()";
}

#TODO: I made piña colada (+U00F1) at first to test unicode. It gets properly
# inserted and selected, but a comparison within arrayref fails.
# Output _looks_ identical.

ok $sth = $dbh.prepare("INSERT INTO nom (name, description, quantity, price)
                         VALUES ('PICO', 'Delish pina colada', '5', '7.9');"), 
                         'insert new value for fetchrow_arrayref test'; #test 25

ok $sth.execute(), 'new insert statement executed'; #test 26
is $sth.?rows, 1, "insert reports 1 row affected"; # test 27
$sth.finish;

ok $sth = $dbh.prepare("SELECT * FROM nom WHERE quantity='5';"),
'prepare new select for fetchrow_arrayref test'; #test 28
ok $sth.execute(), 'execute prepared statement for fetchrow_arrayref'; #test 29

if $sth.^can('fetchrow_arrayref') {
    ok my $arrayref = $sth.fetchrow_arrayref(), 'called fetchrow_arrayref'; #test 30
    is $arrayref.elems, 4, "fetchrow_arrayref returns 4 fields in a row"; #test 31
    ok magic_cmp($arrayref, [ 'PICO', 'Delish pina colada', '5', '7.9' ]),
    'selected data matches test data of fetchrow_arrayref'; #test 32
}
else { skip 'fetchrow_arrayref not implemented', 2 }

# TODO: weird sth/dbh behavior workaround again. 
if $sth.^can('fetchrow_arrayref') {
    my $arrayref = $sth.fetchrow_arrayref(); #'called fetchrow_arrayref'; #test23
}
$sth.finish;

# test quotes and so on 
{
    $sth = $dbh.prepare(q[INSERT INTO nom (name, description) VALUES (?, ?)]);
    my $lived;
    lives_ok { $sth.execute("quot", q["';]); $lived = 1 }, 'can insert single and double quotes';
    $sth.finish;
    if $lived {
        $sth = $dbh.prepare(q[SELECT description FROM nom where name = ?]);
        lives_ok { $sth.execute('quot') }, 'lived while retrieving result';
        is $sth.fetchrow.join, q["';], 'got the right string back';
        $sth.finish;
    }
    else {
        skip('dependent tests', 2);
    }

    $lived = 0;
    lives_ok { $dbh.do(q[INSERT INTO nom (name, description) VALUES(?, '?"')], 'mark'); $lived = 1}, 'can use question mark in quoted strings';
    if $lived {
        my $sth = $dbh.prepare(q[SELECT description FROM nom WHERE name = 'mark']);
        $sth.execute;
        is $sth.fetchrow.join, '?"', 'correctly retrieved question mark';
        $sth.finish;
    }
    else {
        skip('dependent test', 1);
    }
}


# Drop the table when finished, and disconnect
ok $dbh.do("DROP TABLE nom"), "final cleanup";
if $dbh.can('ping') {
    ok $dbh.ping, '.ping is true on a working DB handle';
}
else {
    skip('ping not implemented', 1);
}
ok $dbh.disconnect, "disconnect";

# Return an unabiguous sign of successful completion
"ok 99-common.pl6";
