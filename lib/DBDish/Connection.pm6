use v6;

=begin pod
=head2 role DBDish::Connection

Does the C<DBDish::ErrorHandling> role.

=end pod

need DBDish::ErrorHandling;

unit role DBDish::Connection does DBDish::ErrorHandling;

=begin pod
=head4 instance variables
=head4 methods
=head5 do
=end pod

has %.Statements;

method dispose() {
    $_.dispose for %!Statements.values;
    self._disconnect;
    ?($.parent.Connections{self.WHICH}:delete);
}
submethod DESTROY() {
    self.dispose;
}

method disconnect is hidden-from-backtrace {
    warn "{::?CLASS.^name}.disconnect is DEPRECATED, please use .dispose";
    self.dispose;
}

method drv { $.parent }

method new(*%args) {
    my \con = ::?CLASS.bless(|%args);
    con.reset-err;
    %args<parent>.Connections{con.WHICH} = con;
}

method prepare(Str $statement, *%args) { ... }

method do(Str $statement, *@params) {
    with self.prepare($statement) {
	LEAVE { .finish }
	.execute(@params);
    }
    else {
	.fail;
    }
}

=begin pod
=head5 quote-identifier

Returns the string parameter as a quoted identifier

=end pod

method quote-identifier(Str:D $name) {
    # a first approximation
    qq["$name"];
}

=begin pod
=head5 _disconnect
The C<_disconnect> method 
=end pod

method _disconnect() {
    ...
}
