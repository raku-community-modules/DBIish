use v6;
use Test;
use DBIish;

plan 2;

given DBIish.install-driver('SQLite') -> $driver {
    unless $driver.version {
        skip-rest 'No SQLite3 library installed';
        exit;
    }
    unless $driver.threadsafe {
        skip-rest 'SQLite3 library was not compiled threadsafe';
        exit;
    }
}

my $database = IO::Path.new('dbdish-sqlite-test-threaded.sqlite3');
$database.unlink if $database.e;
END try $database.unlink;

# Create a test table.
my $dbh = DBIish.connect("SQLite", :$database);
END try $dbh.dispose;
$dbh.do('CREATE TABLE nom ( name varchar(50) )');

# Check that it is possible to work with the database from multiple threads
# at once with a single connection option. This works in SQLite's serialized
# mode, which is the default.
subtest 'Statements across threads on one connection' => {
    my @inserters = do for ^5 -> $thread {
        start {
            for ^100 {
                my $sth = $dbh.prepare(q:to/STATEMENT/);
                    INSERT INTO nom (name)
                    VALUES (?)
                    STATEMENT
                $sth.execute((('a'..'z').pick xx 40).join);
                $sth.finish;
            }
        }
    }

    for @inserters.kv -> $idx, $i {
        lives-ok { await $i }, "Inserting thread $idx completed";
    }

    given $dbh.prepare('SELECT COUNT(*) FROM nom') -> $sth {
        $sth.execute;
        is $sth.row()[0], 500, 'Correct number of rows were inserted';
        $sth.finish;
    }

    $dbh.do('DELETE FROM nom');
}

# Check that it is possible to work with the database from multiple threads
# at once with a connection object per thread
subtest 'Multiple connections, one per thread' => {
    my @inserters = do for ^5 -> $thread {
        start {
            my $dbht = DBIish.connect("SQLite", :$database);
            for ^100 {
                my $sth = $dbht.prepare(q:to/STATEMENT/);
                    INSERT INTO nom (name)
                    VALUES (?)
                    STATEMENT
                $sth.execute((('a'..'z').pick xx 40).join);
                $sth.finish;
            }
            $dbht.dispose;
        }
    }

    for @inserters.kv -> $idx, $i {
        lives-ok { await $i }, "Inserting thread $idx completed";
    }

    given $dbh.prepare('SELECT COUNT(*) FROM nom') -> $sth {
        $sth.execute;
        is $sth.row()[0], 500, 'Correct number of rows were inserted';
        $sth.finish;
    }

    $dbh.do('DELETE FROM nom');
}
