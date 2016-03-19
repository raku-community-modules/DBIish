use v6;
need DBDish;

unit class DBDish::TestMock::StatementHandle does DBDish::StatementHandle;

my @data = (|<a b>, 1), (|<d e>, 2);

has Int $!current_idx = 0;

method execute(*@)  {
    self!enter-execute;
    $!current_idx = 0;
    @!column-name = <col1 col2 colN>;
    @!column-type = (Str, Str, Int);
    self!done-execute(@data.elems, True)
}

method _row     { @data[$!current_idx++] // @ }
method _free	{ }
method finish   { True }
