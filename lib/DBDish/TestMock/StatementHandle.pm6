
use v6;

need DBDish::Role::StatementHandle;

unit class DBDish::TestMock::StatementHandle does DBDish::Role::StatementHandle;

my @data = (
       [<a b c>],
       [<d e f>],
);

my @column_names = <col1 col2 col3>;

has Int $!current_idx = 0;

method execute(*@)  { $!current_idx = 0; @data.elems }
method rows         { @data.elems }

method fetchrow     { (@data[$!current_idx++] // ()).list }
method column_names { @column_names }

method finish       { True }
