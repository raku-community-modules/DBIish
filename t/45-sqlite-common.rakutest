# DBIish/t/40-SQLite-common.t
use v6;
need DBIish::CommonTesting;

my $TDB = IO::Path.new('dbdish-sqlite-test.sqlite3');
DBIish::CommonTesting.new(
    dbd => 'SQLite',
    opts => {
        :database($TDB)
    },
    typed-nulls => False # TODO Is the driver who needs to provide the info
).run-tests;
$TDB.unlink;
