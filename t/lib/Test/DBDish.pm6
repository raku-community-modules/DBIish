use v6;

use Test;
use Data::Dump;
use DBIish;

unit class Test::DBDish;

has $.dbd is required;
has %.opts is required;
has $.post-connect-cb;
has $.drop-table-sql = 'DROP TABLE IF EXISTS nom';
has $.create-table-sql = '
    CREATE TABLE nom (
        name        varchar(4),
        description varchar(30),
        quantity    bigint,
        price       numeric(5,2)
    )
';

has $.select-null-query = 'SELECT NULL';

# compare rows of the nom table
method !magic-cmp(@a, @b) {
    my $res =  @a ~~ @b;
    unless $res {
        diag "     Got: {Dump(@a)}";
        diag "Expected: {Dump(@b)}";
    }
    $res;
}

method !hash-str(%h) {
    %h.sort.flatmap({ join '', .key, '=«', .value, '»' }).join('; ');
}

method run-tests {
    diag "Testing DBDish::$.dbd";
    plan 70;

    # Verify that the driver loads before attempting a connect
    my $drh = DBIish.install_driver($.dbd);
    ok $drh, 'Install driver'; # test 1
    my $drh_version;
    $drh_version = $drh.Version;
    ok $drh_version > 0, "DBDish::{$.dbd} version $drh_version"; # test 2

    # Connect to the data sourcequantity*price AS amount FROM nom
    my $dbh;
    try {
        $dbh = DBIish.connect( $.dbd, |%.opts, :RaiseError<1> );
        CATCH {
            default {
                diag "Connect failed with error $_";
                skip-rest 'connect failed -- maybe the prerequisites are not installed?';
                exit;
            }
        }
    }
    ok $dbh, "connect to %.opts<database>"; # test 3

    try EVAL '$.post-connect-cb.($dbh)';

    # Test .prepare() and .execute() a few times while setting things up.
    # Drop a table of the same name so that the following create can work.
    my $sth = $dbh.prepare($.drop-table-sql);
    my $rc = $sth.execute();
    isnt $rc, Bool::True, "drop table gave an expected error " ~
        "(did a previous test not clean up?)"; # test 4
    $sth.finish;

    # Create a table
    $sth = $dbh.prepare($.create-table-sql);
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
        INSERT INTO nom (name)
        VALUES ( ? )
    "), "prepare an insert command with one string parameter"; # test 10
    ok $rc = $sth.execute('ONE'), "execute one with one string parameter"; # test 11
    is $rc, 1, "execute one with one string parameter should return 1 row affected"; # test 12
    if $sth.^can('rows') {
        is $sth.rows, 1, '$sth.rows for execute one with one string parameter should report 1 row affected'; # test 13
    }
    else { skip '$sth.rows not implemented', 1 }

    ok $sth = $dbh.prepare( "
        INSERT INTO nom (quantity)
        VALUES ( ? )
    "), "prepare an insert command with one integer parameter"; # test 14
    ok $rc = $sth.execute(1), "execute one with one integer parameter"; # test 15
    is $rc, 1, "execute one with one integer parameter should return 1 row affected"; # test 16
    if $sth.^can('rows') {
        is $sth.rows, 1, '$sth.rows for execute one with one integer parameter should report 1 row affected'; # test 17
    }
    else { skip '$sth.rows not implemented', 1 }

    ok $sth = $dbh.prepare( "
        INSERT INTO nom (price)
        VALUES ( ? )
    " ), "prepare an insert command with one float parameter"; # test 18
    ok $rc = $sth.execute(4.85), "execute one with one float parameter"; # test 19
    is $rc, 1, "execute one with one float parameter should return 1 row affected"; # test 20
    if $sth.^can('rows') {
        is $sth.rows, 1, '$sth.rows for execute one with one float parameter should report 1 row affected'; # test 21
    }
    else { skip '$sth.rows not implemented', 1 }

    ok $sth = $dbh.prepare( "
        INSERT INTO nom (name, description, quantity, price)
        VALUES ( ?, ?, ?, ? )
    " ), "prepare an insert command with parameters"; # test 22

    ok $sth.execute('TAFM', 'Mild fish taco', 1, 4.85 ) &&
       $sth.execute('BEOM', 'Medium size orange juice', 2, 1.20 ),
       "execute twice with parameters"; # test 23
    if $dbh.^can('rows') {
        is $sth.rows, 1, "each insert with parameters also reports 1 row affected"; # test 24
    }
    else { skip '$dbh.rows not implemented', 1 }

    if $sth.^can('bind_param_array') {
        my @tuple_status;
        ok $sth.bind_param_array( 1, [ 'BEOM', 'Medium size orange juice', 2, 1.20 ] ),
           "bind_param_array"; # test 25
        ok $sth.execute_array(  { ArrayTupleStatus => @tuple_status } ); # test 26
    }
    else { skip '$sth.bind_param_array() and $sth.execute_array() not implemented', 2 }

    # Update some rows

    # Delete some rows

    # Select data using various method calls
    ok $sth = $dbh.prepare( "
        SELECT name, description, quantity, price, quantity*price AS amount
        FROM nom
        ORDER BY COALESCE(name,'A')
    " ), "prepare a select command without parameters"; # test 27

    ok $sth.execute(), "execute a prepared select statement without parameters"; # test 28
    #fetch stuff return Str
    my @ref =
        [ Str, Str, "1" , Str, Str],
        [ Str, Str, Str, 4.85, Str ],
        [ 'BEOM', 'Medium size orange juice', "2", "1.20", "2.40" ],
        [ 'BUBH', 'Hot beef burrito', "1", "4.95", "4.95" ],
        [ 'ONE', Str, Str, Str, Str ],
        [ 'TAFM', 'Mild fish taco', "1", "4.85", "4.85" ];
    #row and allrows return typed value
    my @typed-ref =
        [ Str, Str, 1 , Rat, Rat],
        [ Str, Str, Int, 4.85, Rat ],
        [ 'BEOM', 'Medium size orange juice', 2, 1.2, 2.4 ],
        [ 'BUBH', 'Hot beef burrito', 1, 4.95, 4.95 ],
        [ 'ONE', Str, Int, Rat, Rat ],
        [ 'TAFM', 'Mild fish taco', 1, 4.85, 4.85 ];

    my $arrayref = $sth.fetchall_arrayref();
    is $arrayref.elems, 6, "fetchall_arrayref returns 6 rows"; # test 29
    my $ok = True;
    for ^6 -> $i {
        $ok &&= self!magic-cmp($arrayref[$i], @ref[$i]);
    }
    todo "Will fail in sqlite (ExplicitlyManaged)";
    ok $ok, "selected data matches what was written"; # test 30

    $sth.execute();

    #FIXME, sqlite (for example) return NULL field as NULL type, we can't really use
    # the empty line for this. so we skip them.
    $sth.row();$sth.row();
    my @results = $sth.row();
    ok @results[1] ~~ Str, "Test the type of a Str field";
    ok @results[2] ~~ Int, "Test the type of an Int field";
    ok @results[3] ~~ Rat, "Test the type of a Float like field";

    my %results = $sth.row(:hash);

    ok %results<name> ~~ Str, "HASH: Test the type of a Str field";
    ok %results<quantity> ~~ Int, "HASH: Test the type of a Int field";
    ok %results<price> ~~ Rat, "HASH: Test the type of a Float like field";

    $sth.execute();

    @results = $sth.allrows();
    ok @results.elems == 6, "Test allrows, get 6 rows";

    $ok = True;
    #FIXME, same that the previous concern with NULL
    for ^6 -> $i {
      #$ok &&= self!magic-cmp(@results[$i], @typed-ref[$i]);
      $ok &&= @results[$i] eqv @typed-ref[$i];
    }
    todo "WIll fail depending on how the drivers handle null result";
    ok $ok, "Selected data still matches";

    $sth.execute();
    %results = $sth.allrows(:hash-of-array);

    my %ref = (
        name        => @typed-ref.map({ .[0] }).Array,
        description => @typed-ref.map({ .[1] }).Array,
        quantity    => @typed-ref.map({ .[2] }).Array,
        price       => @typed-ref.map({ .[3] }).Array,
        amount      => @typed-ref.map({ .[4] }).Array
    );
    todo "Figure why the ref data get the NC-explicit role sometime";
    is-deeply %results, %ref, "Test allrows(:hash-of-array)";

    # use Data::Dump;
    # say "============EXPECTED==========";
    # say Dump(%ref);
    # say "============GOT===============";
    # say Dump(%results);

    $sth.execute();
    @results = $sth.allrows(:array-of-hash);
    my @ref-aoh = (
        { name => Str, description => Str, quantity => 1, price => Rat, amount => Rat },
        { name => Str, description => Str, quantity => Int, price => 4.85, amount => Rat },
        { name => 'BEOM', description => 'Medium size orange juice', quantity => 2, price => 1.2, amount => 2.4 },
        { name => 'BUBH', description => 'Hot beef burrito', quantity => 1, price => 4.95, amount => 4.95 },
        { name => 'ONE', description => Str, quantity => Int, price => Rat, amount => Rat },
        { name => 'TAFM', description => 'Mild fish taco', quantity => 1, price => 4.85, amount => 4.85 },
    );

    #diag "ref-aoh: {Dump(@ref-aoh)}";

    todo "Figure why the ref data get the NC-explicit role sometime";
    #ok self!magic-cmp(@results, @ref-aoh), 'types and values match';
    is-deeply @results, @ref-aoh, 'types and values match';

    ok $sth = $dbh.prepare("SELECT * FROM nom WHERE name = 'TAFM'"),
	'prepare new select for fetchrow_hashref test'; #test 31
    ok $sth.execute(), 'execute prepared statement for fetchrow_hashref'; #test 32

    if $sth.can('column_names') {
        ok my $hashref = $sth.fetchrow_hashref(), 'called fetchrow_hashref'; #test 33
        is self!hash-str($hashref), self!hash-str({ 'name' => 'TAFM', 'description' => 'Mild fish taco', 'quantity'
        => 1, 'price' => '4.85' }), 'selected data matches test hashref'; #test 34
    }
    else { skip 'fetchrow_hashref not implemented', 2 }

    if $sth.can('colum_names') {
        $sth.execute;
        my $arrayref = $sth.fetchrow_arrayref(); #'called fetchrow_arrayref'; #test 35
        is $arrayref.elems, 4, "fetchrow_arrayref returns 4 fields in a row"; #test 36
        ok self!magic-cmp([ 'TAFM', 'Mild fish taco', 1, 4.85 ], $arrayref), 'selected data matches test data'; #test 37
    }
    else { skip 'fetchrow_arrayref not implemented', 2 }
    $sth.finish;

    {
        ok $sth = $dbh.prepare($.select-null-query), "can prepare statement '$.select-null-query'";
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
                             VALUES ('PICO', 'Delish pina colada', '5', '7.9')"),
                             'insert new value for fetchrow_arrayref test'; #test 38

    ok $sth.execute(), 'new insert statement executed'; #test 39
    is $sth.?rows, 1, "insert reports 1 row affected"; #test 40
    $sth.finish;

    ok $sth = $dbh.prepare("SELECT * FROM nom WHERE quantity='5'"),
    'prepare new select for fetchrow_arrayref test'; #test 41
    ok $sth.execute(), 'execute prepared statement for fetchrow_arrayref'; #test 42

    if $sth.^can('fetchrow_arrayref') {
        ok my $arrayref = $sth.fetchrow_arrayref(), 'called fetchrow_arrayref'; #test 43
        is $arrayref.elems, 4, "fetchrow_arrayref returns 4 fields in a row"; #test 44
        ok self!magic-cmp($arrayref, [ 'PICO', 'Delish pina colada', '5', 7.90 ]),
        'selected data matches test data of fetchrow_arrayref'; #test 45
    }
    else { skip 'fetchrow_arrayref not implemented', 2 }

    # TODO: weird sth/dbh behavior workaround again.
    if $sth.^can('fetchrow_arrayref') {
        my $arrayref = $sth.fetchrow_arrayref(); #'called fetchrow_arrayref'; #test 46
    }
    $sth.finish;

    # test quotes and so on
    {
        $sth = $dbh.prepare(q[INSERT INTO nom (name, description) VALUES (?, ?)]);
        my $lived;
        lives-ok { $sth.execute("quot", q["';]); $lived = 1 }, 'can insert single and double quotes';
        $sth.finish;
        if $lived {
            $sth = $dbh.prepare(q[SELECT description FROM nom where name = ?]);
            lives-ok { $sth.execute('quot') }, 'lived while retrieving result';
            is $sth.fetchrow.join, q["';], 'got the right string back';
            $sth.finish;
        }
        else {
            skip('dependent tests', 2);
        }

        $lived = 0;
        lives-ok { $dbh.do(q[INSERT INTO nom (name, description) VALUES(?, '?"')], 'mark'); $lived = 1}, 'can use question mark in quoted strings';
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

    # test that a query with no results has a falsy value
    {
        $sth = $dbh.prepare('SELECT * FROM nom WHERE 1 = 0');
        $sth.execute;

        my $row = $sth.fetchrow-hash;

        ok !?$row, 'a query with no results should have a falsy value';
    }

    # test that a query that's exhausted its result set has a falsy value
    {
        $sth = $dbh.prepare('SELECT COUNT(*) FROM nom');
        $sth.execute;

        my $row = $sth.fetchrow-hash;
           $row = $sth.fetchrow-hash;

        ok !?$row, 'a query with no more results should have a falsy value';
    }

    # test that an integer >= 2**31 still works as an argument to execute
    {
        my $large-int = 2 ** 31;
        $dbh.do(qq[INSERT INTO nom (name, description, quantity) VALUES ('too', 'many', $large-int)]);
        $sth = $dbh.prepare('SELECT name, description, quantity FROM nom WHERE quantity = ?');
        $sth.execute($large-int);

        my $row = $sth.fetchrow_arrayref;

        ok $row, 'A row was successfully retrieved when using a large integer in a prepared statement';
        is $row[0], 'too', 'The contents of the row fetched via a large integer are correct';
        is $row[1], 'many', 'The contents of the row fetched via a large integer are correct';
        is $row[2], $large-int, 'The contents of the row fetched via a large integer are correct';

        $sth.finish;
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
}
