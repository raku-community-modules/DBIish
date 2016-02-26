# DBIish/t/40-SQLite-common.t
use v6;
use Test;
use DBIish;
use lib 't/lib';
use Test::DBDish;

my $test-dbdish = Test::DBDish.new(
    dbd => 'SQLite',
    opts => {
        database => 'dbdish-sqlite-test.sqlite3',
    },
    typed-nulls => False # TODO Is the driver who needs to provide the info
);

$test-dbdish.run-tests;
