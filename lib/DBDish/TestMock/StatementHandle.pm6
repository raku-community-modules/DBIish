use v6;
need DBDish;

unit class DBDish::TestMock::StatementHandle does DBDish::StatementHandle;

has List $!data = ((|<a b>, 1), (|<d e>, 2));
has int $!current_idx;
has $.statement;

submethod BUILD(:$!parent!, :$!statement, :$rows,
    :$col-names = <col1 col2 colN>;
    :$col-types = (Str, Str, Int);
) {
    with $rows {
	$!data = $_;
    }
    @!column-name = @($col-names);
    @!column-type = @($col-types);
}

method execute(*@)  {
    self!enter-execute;
    $!current_idx = 0;
    self!done-execute($!data.elems, True)
}

method _row     {
    if $!current_idx < $!data.elems {
	$!data[$!current_idx++];
    } else {
	self.finish;
	@
    }
}
method _free	{ }
method finish   { $!Finished = True }
