# DBIish/t/40-SQLite-common.t
use v6;
need DBIish::CommonTesting;

DBIish::CommonTesting.new(
    dbd => 'SQLite',
    opts => {
        :database(':memory:')
    },
    typed-nulls => False # TODO Is the driver who needs to provide the info
).run-tests;
