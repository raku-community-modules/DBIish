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
);

$test-dbdish.run-tests;
