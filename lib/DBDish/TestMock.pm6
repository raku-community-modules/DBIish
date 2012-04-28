use v6;

use DBDish;

my @data = (
       [<a b c>],
       [<d e f>],
);

my @column_names = <col1 col2 col3>;

class DBDish::TestMock::StatementHandle does DBDish::StatementHandle {
    has Int $!current_idx = 0;

    method execute(*@)  { $!current_idx = 0; @data.elems }
    method rows         { @data.elems }

    method fetchrow     { (@data[$!current_idx++] // ()).list }
    method column_names { @column_names }

    method finish       { True }
}

class DBDish::TestMock::Connection does DBDish::Connection {
    method prepare($) { DBDish::TestMock::StatementHandle.new }
    method disconnect { True }
}

class DBDish::TestMock {
    method connect() { DBDish::TestMock::Connection.new }
}
