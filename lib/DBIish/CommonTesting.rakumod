use v6;

use Test;
use DBIish;

unit class DBIish::CommonTesting;

has $.dbd is required;
has %.opts is required;
has $.post-connect-cb;
has $.create-table-sql = q|
    CREATE TABLE nom (
        name        varchar(4),
        description varchar(30),
        quantity    bigint,
        price       numeric(5,2)
    )
|;

# Common queries
has $.drop-table-sql    = 'DROP TABLE IF EXISTS nom';
has $.select-null-query = 'SELECT NULL';

method !hash-str(%h) {
    %h.sort.flatmap({ join '', .key, '=«', .value, '»' }).join('; ');
}

method connect-or-skip($driver-name) {
    my $dbh;
    try {
        $dbh = DBIish.connect($driver-name, |%_);
        CATCH {
            when X::DBIish::LibraryMissing | X::DBDish::ConnectionFailed {
                diag "Skipping $driver-name tests in $*PROGRAM due to:\n" ~ $_.message.indent(4);
            }
            when X::DBDish::ConnectionFailed {
                diag "Skipping $driver-name tests in $*PROGRAM due to:\n" ~ $_.message.indent(4);
            }
            default { .rethrow; }
        }
    }
    without $dbh {
        skip-rest 'prerequisites failed';
        exit;
    }

    return $dbh;
}

method run-tests {
    diag "Testing DBDish::$.dbd";
    plan 109;

    # Convert to TEMPORARY table instead?
    without %*ENV<DBIISH_WRITE_TEST> {
        skip-rest 'Set environment variable DBIISH_WRITE_TEST=YES to run this test';
        exit;
    }

    # Verify that the driver loads before attempting a connect
    my $drh = DBIish.install-driver($.dbd);
    ok $drh, 'Install driver';
    my $aversion = $drh.Version;
    ok $aversion ~~ Version:D, "DBDish::{$.dbd} version $aversion";
    # Connect to the data source
    my $dbh = $.connect-or-skip($.dbd, |%.opts, :RaiseError);

    ok $aversion = $drh.version, "{$.dbd} library version $aversion";
    ok $dbh, "connect to '{%.opts<database> || "default"}'";
    is $dbh.drv.Connections.elems, 1, 'Driver has one connection';

    if $dbh.can('server-version') {
        ok $aversion = $dbh.server-version, "Server version $aversion";
    } else {
       skip "No server version", 1;
    }

    # Test preconditions
    nok $dbh.last-sth-id,         'No statement executed yet';
    is  $dbh.Statements.elems, 0,     'No statement registered';

    try EVAL '$.post-connect-cb.($dbh)';

    # Drop a table of the same name so that the following create can work.
    ok $dbh.execute($!drop-table-sql), "drop table if exists works";

    ok (my $stid = $dbh.last-sth-id), 'Statement registered';
    with $dbh.Statements{$stid} {
        ok .Finished,             'After do sth is Finished';
    }
    else  {
        pass                  'was GC-ected, so Finished';
    }

    # Create a table
    my $sth = $dbh.execute($.create-table-sql);
    ok $sth, 'execute: create table returns True';
    is $sth.rows, 0, "do: create table nom returns 0";

    is $dbh.err, 0, 'err after successful create should be 0';
    is $dbh.errstr, '', 'errstr after successful create should be empty';

    isnt $dbh.last-sth-id, $stid,   'A different statement id';

    # Insert rows using the various method calls
    ok $dbh.execute( "
        INSERT INTO nom (name, description, quantity, price)
        VALUES ( 'BUBH', 'Hot beef burrito', 1, 4.95 )
    "), "insert without parameters called from do";

    is $dbh.rows, 1, "simple insert should report 1 row affected";

    # Test .prepare() and .execute() a few times while setting things up.
    ok $sth = $dbh.prepare( "
        INSERT INTO nom (name)
        VALUES ( ? )
    "), "prepare an insert command with one string parameter";

    ok not $sth.Executed,   'Not executed yet';
    ok $sth.Finished,       'So Finished';
    ok !$sth.rows.defined,  'Rows undefined';

    ok my $rc = $sth.execute('ONE').rows, "execute one with one string parameter";

    ok $sth.Executed,       'Was executed';
    ok $sth.Finished,       'execute on DML statement should leave finished';

    is $dbh.Statements{$dbh.last-sth-id}, $sth, 'The expected Statement';

    is $rc, 1, "execute one with one string parameter should return 1 row affected";
    if $sth.^can('rows') {
        is $sth.rows, 1, '$sth.rows for execute one with one string parameter should report 1 row affected';
    }
    else { skip '$sth.rows not implemented', 1 }

    ok $sth.dispose,        'Can dispose a StatementHandle';
    nok $sth.dispose,       'Already disposed';

    ok $sth = $dbh.prepare( "
        INSERT INTO nom (quantity)
        VALUES ( ? )
    "), "prepare an insert command with one integer parameter";

    ok not $sth.Executed,   'New statement sould not be marked executed yet';
    ok $rc = $sth.execute(1).rows, "execute one with one integer parameter";
    ok $sth.Finished,       'execute on DML statement should leave finished';

    is $rc, 1, "execute one with one integer parameter should return 1 row affected";
    is $sth.rows, 1, '$sth.rows for execute one with one integer parameter should report 1 row affected';
    $sth.dispose;

    ok $sth = $dbh.prepare( "
        INSERT INTO nom (price)
        VALUES ( ? )
    " ), "prepare an insert command with one float parameter";
    ok $rc = $sth.execute(4.85).rows, "execute one with one float parameter";
    is $rc, 1, "execute one with one float parameter should return 1 row affected";
    is $sth.rows, 1, '$sth.rows for execute one with one float parameter should report 1 row affected';
    $sth.dispose;

    ok $sth = $dbh.prepare( "
        INSERT INTO nom (name, description, quantity, price)
        VALUES ( ?, ?, ?, ? )
    " ), "prepare an insert command with parameters";


    ok $sth.execute('TAFM', 'Mild fish taco', 1, 4.85 ) &&
       $sth.execute('BEOM', 'Medium size orange juice', 2, 1.20 ),
       "execute twice with parameters";

    is $sth.Executed, 2,    'Was executed twice';
    ok $sth.Finished,       'Multiple execute finished';

    is $dbh.rows, $sth.rows, "each level reports the same rows affected";

    if $sth.^can('bind-param-array') {
        my @tuple_status;
        ok $sth.bind-param-array( 1, [ 'BEOM', 'Medium size orange juice', 2, 1.20 ] ),
           "bind_param_array";
        ok $sth.execute-array(  { ArrayTupleStatus => @tuple_status } );
    }
    else { skip '$sth.bind_param_array() and $sth.execute_array() not implemented', 2 }

    # Update some rows

    # Delete some rows

    # Select data using various method calls
    ok $sth = $dbh.prepare("
        SELECT name, description, quantity, price, quantity*price AS amount
        FROM nom
        ORDER BY COALESCE(name,'A')
    "), "prepare a select command without parameters";

    ok not $sth.Executed,    'SELECT statement sould not be marked executed yet';
    $rc = $sth.execute.rows,
    ok $rc.defined,      'execute a prepared select statement without parameters';
    ok $sth.Executed,        'SELECT statement sould now be marked executed';

    # TODO Different drivers returns different values, should implement the
    # capabilities announce.
    todo 'Will probably fails for the lack of proper capabilities announce'
    if $.dbd eq 'SQLite' | 'Oracle';
    is $rc, 6,          'In an ideal world should returns rows available';

    #row and allrows return typed value, when possible
    my @typed-ref = (
        [ Str, Str, 1 , Rat, Rat],
        [ Str, Str, Int, 4.85, Rat ],
        [ 'BEOM', 'Medium size orange juice', 2, 1.2, 2.4 ],
        [ 'BUBH', 'Hot beef burrito', 1, 4.95, 4.95 ],
        [ 'ONE', Str, Int, Rat, Rat ],
        [ 'TAFM', 'Mild fish taco', 1, 4.85, 4.85 ]
    );

    if $.dbd eq 'SQLite' { # Munge types
        $sth.column-types[$_] = [Str, Str, Int, Rat, Rat][$_] for ^5;
    }

    my @array = $sth.allrows;
    is $sth.rows, 6,    '$sth.rows after fetch-array should report all';
    ok $sth.Finished,   'And marked Finished';
    is @array.elems, 6, 'fetchall-array returns 6 rows';

    my $ok = True;
    for ^6 -> $i {
        $ok &&= @array[$i] eqv @typed-ref[$i];
    }
    ok $ok, 'selected data be allrows matches';

    # Re-execute the same statement
    ok $sth.execute,    'statement can be re-executed';

    ok (my @columns = $sth.column-names), 'called column-name';
    is @columns.elems, 5, 'column-name returns 5';
    is @columns, [ <name description quantity price amount> ],
    'column-name matched test data';

    ok (@columns = $sth.column-types), 'called column-type';
    is @columns.elems, 5, "column-type returns 5 fields in a row";
    ok @columns eqv [ Str, Str, Int, Rat, Rat ], 'column-types matches test data';

    if $.dbd eq 'SQLite' { # Munge types
        $sth.column-types[$_] = [Str, Str, Int, Rat, Rat][$_] for ^5;
    }

    # we skip some uninterested rows
    $sth.row(); $sth.row();
    my @results = $sth.row();
    ok @results[1] ~~ Str, "Test the type of a Str field";
    ok @results[2] ~~ Int, "Test the type of an Int field";
    ok @results[3] ~~ Rat, "Test the type of a NUMERIC like field";

    my %results = $sth.row(:hash);

    ok %results<name>     ~~ Str, "HASH: Test the type of a Str field";
    ok %results<quantity> ~~ Int, "HASH: Test the type of a Int field";
    ok %results<price>    ~~ Rat, "HASH: Test the type of a NUMERIC like field";

    ok $sth.finish, 'No more rows needed';
    ok $sth.Finished,   'Finished indeed';
    ok $sth.execute,    'Can re-execute after explicit finish';

    ok (@results = $sth.allrows),   'call allrows works';
    ok @results.elems == 6,     'Test allrows, get 6 rows';

    $ok = True;
    for ^6 -> $i {
      $ok &&= @results[$i] eqv @typed-ref[$i];
    }
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
    is-deeply %results, %ref, "Test allrows(:hash-of-array)";

    $sth.execute();
    @results = $sth.allrows(:array-of-hash);
    $sth.finish;
    my @ref-aoh =  (
        { name => Str, description => Str, quantity => 1, price => Rat, amount => Rat },
        { name => Str, description => Str, quantity => Int, price => 4.85, amount => Rat },
        { name => 'BEOM', description => 'Medium size orange juice', quantity => 2, price => 1.2, amount => 2.4 },
        { name => 'BUBH', description => 'Hot beef burrito', quantity => 1, price => 4.95, amount => 4.95 },
        { name => 'ONE', description => Str, quantity => Int, price => Rat, amount => Rat },
        { name => 'TAFM', description => 'Mild fish taco', quantity => 1, price => 4.85, amount => 4.85 },
    );

    is-deeply @results, @ref-aoh, 'types and values match';

    ok $sth = $dbh.prepare($.select-null-query), "can prepare '$.select-null-query'";
    $sth.execute;
    @results = $sth.allrows;
    is @results.elems, 1,   'SELECT return one row';
    isa-ok @results[0], Array,  'An array';
    is @results[0].elems, 1,    'with a column';

    nok @results[0][0].defined, 'NULL returns an undefined value';
    ok $sth.Finished,       'After one row is finished';

    ok $sth = $dbh.prepare("
    INSERT INTO nom (name, description, quantity, price)
        VALUES ('PICO', 'Delish piña colada', '5', '7.9')
    " ), 'insert new value for fetchrow_arrayref test'; #test 38

    ok $sth.execute, 'new insert statement executed'; #test 39
    is $sth.rows, 1, "insert reports 1 row affected"; #test 40

    ok $sth = $dbh.prepare("SELECT * FROM nom WHERE quantity= 5"),
        'prepare new select for fetchrow_arrayref test'; #test 41

    $sth.execute;

    ok my $arrayref = $sth.row(), 'called row'; #test 43
    is $arrayref.elems, 4, "row returns 4 fields in a row"; #test 44
    is $arrayref, [ 'PICO', 'Delish piña colada', '5', 7.9 ],
    'selected data matches test data of row'; #test 45

    $sth.dispose;

    # test quotes and so on
    {
        $sth = $dbh.prepare(q[INSERT INTO nom (name, description) VALUES (?, ?)]);
        my Bool $lived = False;
        lives-ok { $sth.execute("quot", q["';]); $lived = True }, 'can insert single and double quotes';
        $sth.dispose;
        if $lived {
            $sth = $dbh.prepare(q[SELECT description FROM nom WHERE name = ?]);
            lives-ok { $sth.execute('quot'); }, 'lived while retrieving result';
            is $sth.row.join, q["';], 'got the right string back';
            $sth.dispose;
        }
        else {
            skip('dependent tests', 2);
        }

        $lived = False;
        lives-ok {
            $dbh.execute(q[INSERT INTO nom (name, description) VALUES(?, '?"')], 'mark');
            $lived = True
            }, 'can use question mark in quoted strings';
        if $lived {
            my $sth = $dbh.prepare(q[SELECT description FROM nom WHERE name = 'mark']);
            $sth.execute;
            is $sth.row.join, '?"', 'correctly retrieved question mark';
            $sth.dispose;
        }
        else {
            skip('dependent test', 1);
        }
    }

    # test that a query with no results has a falsy value
    {
        $sth = $dbh.prepare('SELECT * FROM nom WHERE 1 = 0');
        $sth.execute;

        my $row = $sth.row(:hash);

        ok !?$row, 'a query with no results should have a falsy value';
        $sth.dispose;
    }

    # test that a query that's exhausted its result set has a falsy value
    {
        $sth = $dbh.prepare('SELECT COUNT(*) FROM nom');
        $sth.execute;

        my $row = $sth.row(:hash);
           $row = $sth.row(:hash);

        ok !?$row, 'a query with no more results should have a falsy value';
        $sth.dispose;
    }

    # test that an integer >= 2**31 still works as an argument to execute
    {
        my $large-int = 2 ** 31;
        $dbh.execute(qq[INSERT INTO nom (name, description, quantity) VALUES ('too', 'many', $large-int)]);
        $sth = $dbh.prepare('SELECT name, description, quantity FROM nom WHERE quantity = ?');
        $sth.execute($large-int);

        my $row = $sth.row();

        ok $row, 'A row was successfully retrieved when using a large integer in a prepared statement';
        is $row[0], 'too', 'The contents of the row fetched via a large integer are correct';
        is $row[1], 'many', 'The contents of the row fetched via a large integer are correct';
        is $row[2], $large-int, 'The contents of the row fetched via a large integer are correct';

        $sth.dispose;
    }


    # Tests for semi-deprecated do()
    my $ret;
    ok $ret = $dbh.do("INSERT INTO nom (name, description, quantity) VALUES ('too', 'many', ?)", 5), "do with parameter";
    is $ret, 1, 'Record count for insert';

    # Drop the table when finished, and disconnect
    ok $dbh.execute("DROP TABLE nom"), "final cleanup";
    if $dbh.can('ping') {
        ok $dbh.ping, '.ping is true on a working DB handle';
    }
    else {
        skip('ping not implemented', 1);
    }
    ok $dbh.dispose, "disconnect";
    is $dbh.drv.Connections.elems, 0, 'Driver has no connections';
    lives-ok {
        nok $dbh.dispose, 'Already disconnected';
    }, 'Safe to call dispose on a disconnected handle';
}
