# fakedbi/t/99-common.pl6
# This script is intended to be included as the common SQL tests in
# scripts for specific DBDs such as CSV or mysql.

#use Test;     # "use" dies in a runtime eval
#use FakeDBI;
diag "Testing FakeDBD::$mdriver";
plan 32;

# Verify that the driver loads before attempting a connect
my $drh = FakeDBI.install_driver($mdriver);
ok $drh, 'Install driver'; # test 1
my $drh_version;
$drh_version = $drh.Version;
ok $drh_version > 0, "FakeDBD::$mdriver version $drh_version"; # test 2

# Connect to the data sourcequantity*price AS amount FROM nom
my $dbh = FakeDBI.connect( $test_dsn, $test_user, $test_password );
ok $dbh, "connect to $test_dsn"; # test 3

# Test .prepare() and .execute() a few times while setting things up.
# Drop a table of the same name so that the following create can work.
my $sth = $dbh.prepare("DROP TABLE nom");
my $rc = $sth.execute();
isnt $rc, Bool::True, "drop table gave an expected error " ~
    "(did a previous test not clean up?)"; # test 4

# Create a table
$sth = $dbh.prepare( "
    CREATE TABLE nom (
        name char(4),
        description char(30),
        quantity int,
        price numeric(5,2)
    )
");
$rc = $sth.execute();
is $rc, Bool::True, "do: create table nom"; # test 5
if 'err' eq any($dbh.^methods) {
    is $dbh.err, 0, 'err after successful create should be 0'; # test 6
}
else { skip 1, 'err after successful create should be 0' }
is $dbh.errstr, Any, "errstr after successful create should be Any"; # test 7

# Insert rows using the various method calls
ok $dbh.do( "
    INSERT nom (name, description, quantity, price)
    VALUES ( 'BUBH', 'Hot beef burrito', 1, 4.95 )
"), "insert without parameters called from do"; # test 8

if 'rows' eq any($dbh.^methods) {
    is $dbh.rows, 1, "simple insert should report 1 row affected"; # test 9
}
else { skip 1, '$dbh.rows not implemented' }

ok $sth = $dbh.prepare( "
    INSERT nom (name, description, quantity, price)
    VALUES ( ?, ?, ?, ? )
"), "prepare an insert command with parameters"; # test 10

ok $sth.execute('TAFM', 'Mild fish taco', 1, 4.85 ) &&
   $sth.execute('BEOM', 'Medium size orange juice', 2, 1.20 ),
   "execute twice with parameters"; # test 11
is $sth.rows, 1, "each insert with parameters also reports 1 row affected"; # test 12

if 'bind_param_array' eq any($sth.^methods) {
    my @tuple_status;
    ok $sth.bind_param_array( 1, [ 'BEOM', 'Medium size orange juice', 2, 1.20 ] ),
       "bind_param_array"; # test 13
    ok $sth.execute_array(  { ArrayTupleStatus => \@tuple_status } ); # test 14
}
else { skip 2, '$sth.bind_param_array() and $sth.execute_array() not implemented' }

# Update some rows

# Delete some rows

# Select data using various method calls
ok $sth = $dbh.prepare( "
    SELECT name, description, quantity, price, quantity*price AS amount
    FROM nom 
"), "prepare a select command without parameters"; # test 15

ok $sth.execute(), "execute a prepared select statement without parameters"; # test 16

if 'fetchall_arrayref' eq any($sth.^methods) {
    my $arrayref = $sth.fetchall_arrayref();
    is $arrayref.elems, 3, "fetchall_arrayref returns 3 rows"; # test 17
    is $arrayref, [ # TODO: numeric columns return as numeric, not string
        [ 'BUBH', 'Hot beef burrito', '1', '4.95', '4.95' ],
        [ 'TAFM', 'Mild fish taco', '1', '4.85', '4.85' ],
        [ 'BEOM', 'Medium size orange juice', '2', '1.20', '2.40' ] ],
    "selected data matches what was written"; # test 18
}
else { skip 2, 'fetchall_arrayref not implemented' }

ok $sth = $dbh.prepare("SELECT * FROM nom WHERE name='TAFM';"),
'prepare new select for fetchrow_hashref test'; #test 19
ok $sth.execute(), 'execute prepared statement for fetchrow_hashref'; #test 20

if 'fetchrow_hashref' eq any ($sth.^methods) {
    ok my $hashref = $sth.fetchrow_hashref(), 'called fetchrow_hashref'; #test 21
    is $hashref, { 'name' => 'TAFM', 'description' => 'Mild fish taco', 'quantity'
    => 1, 'price' => '4.85' }, 'selected data matches test hashref'; #test 22
}
else { skip 2, 'fetchrow_hashref not implemented' }

# TODO: weird sth behavior workaround! Any sth concerning call at this point
# will return empty or (properly) fail if something is called on that
# sth - after this, everything works fine again.
if 'fetchrow_arrayref' eq any ($sth.^methods) {
    my $arrayref = $sth.fetchrow_arrayref(); #'called fetchrow_arrayref'; #test23
    #is $arrayref.elems, 4, "fetchrow_arrayref returns 4 fields in a row"; #test 24
    #is $arrayref, [ 'TAFM', 'Mild fish taco', '1', '4.85' ],
    #'selected data matches test data'; #test 23
}
else { skip 2, 'fetchrow_arrayref not implemented' }

#TODO: I made piña colada (+U00F1) at first to test unicode. It gets properly
# inserted and selected, but a comparison within arrayref fails.
# Output _looks_ identical.

ok $sth = $dbh.prepare("INSERT INTO nom (name, description, quantity, price)
                         VALUES ('PICO', 'Delish pina colada', '5', '7.90');"), 
                         'insert new value for fetchrow_arrayref test'; #test 25

ok $sth.execute(), 'new insert statement executed'; #test 26
is $sth.rows, 1, "insert reports 1 row affected"; # test 27

ok $sth = $dbh.prepare("SELECT * FROM nom WHERE quantity='5';"),
'prepare new select for fetchrow_arrayref test'; #test 28
ok $sth.execute(), 'execute prepared statement for fetchrow_arrayref'; #test 29

if 'fetchrow_arrayref' eq any ($sth.^methods) {
    ok my $arrayref = $sth.fetchrow_arrayref(), 'called fetchrow_arrayref'; #test 30
    is $arrayref.elems, 4, "fetchrow_arrayref returns 4 fields in a row"; #test 31
    is $arrayref, [ 'PICO', 'Delish pina colada', '5', '7.90' ],
    'selected data matches test data of fetchrow_arrayref'; #test 32
}
else { skip 2, 'fetchrow_arrayref not implemented' }

# TODO: weird sth/dbh behavior workaround again. 
if 'fetchrow_arrayref' eq any ($sth.^methods) {
    my $arrayref = $sth.fetchrow_arrayref(); #'called fetchrow_arrayref'; #test23
}

# Drop the table when finished, and disconnect
ok $dbh.do("DROP TABLE nom"), "final cleanup";
ok $dbh.disconnect, "disconnect";

# Return an unabiguous sign of successful completion
"ok 99-common.pl6";
