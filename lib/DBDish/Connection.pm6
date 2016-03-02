
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

# If need a hook in creation
#method new(*%args) {
#    my \new = ::?CLASS.bless(|%args);
#    new;
#}

method drv { $.parent }

method do( Str $statement, *@params ) {
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
=head5 disconnect
The C<disconnect> method 
=end pod

method disconnect() {
    ...
}
