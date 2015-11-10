
use v6;

=begin pod
=head2 role DBDish::Role::Connection

Does the C<DBDish::Role::ErrorHandling> role.

=end pod

need DBDish::Role::ErrorHandling;

unit role DBDish::Role::Connection does DBDish::Role::ErrorHandling;

=begin pod
=head4 instance variables
=head4 methods
=head5 do
=end pod

method do( Str $statement, *@params ) {
    my $sth = self.prepare($statement) or return fail();
    $sth.execute(@params);
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
=head5 disconnect
The C<disconnect> method 
=end pod

method disconnect() {
    ...
}
