use v6;
need DBDish;

unit class DBDish::TestMock::StatementHandle does DBDish::StatementHandle;

my @data = (
       [<a b c>],
       [<d e f>],
);

has Int $!current_idx = 0;

method execute(*@)  {
    self!enter-execute;
    $!current_idx = 0;
    @!column-name = <col1 col2 col3>;
    self!done-execute(@data.elems, True)
}

method _row	    {self.fetchrow}

method fetchrow     { (@data[$!current_idx++] // ()).list }

method _free	    { }
method finish       { True }
