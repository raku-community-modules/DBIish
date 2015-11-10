
use v6;

=begin pod
=head2 role DBDish::Role::StatementHandle
The Connection C<prepare> method returns a StatementHandle object that
mainly provides the C<execute> and C<finish> methods. It also has all the methods from C<DBDish::Role::ErrorHandling>.
=end pod

need DBDish::Role::ErrorHandling;

unit role DBDish::Role::StatementHandle does DBDish::Role::ErrorHandling;

method finish() { ... }
method fetchrow() { ... }
method execute(*@) { ... }

method fetchrow-hash() {
    hash self.column_names Z=> self.fetchrow;
}

method fetchrow_hashref { $.fetchrow-hash }

method fetchall-hash {
    my @names := self.column_names;
    my %res = @names Z=> [] xx *;
    for self.fetchall-array -> @a {
        for @a Z @names -> ($v, $n) {
            %res{$n}.push: $v;
        }
    }
    return %res;
}

method fetchall-AoH {
    (0 xx *).flatmap: {
        my $h = self.fetchrow-hash;
        last unless $h;
        $h;
    };
}

method fetchall-array {
    (0 xx *).flatmap: {
        my $r = self.fetchrow;
        last unless $r;
        $r;
    };
}

method fetchrow_array { self.fetchrow }

method fetchrow_arrayref {
    $.fetchrow;
}

method fetch() {
    $.fetchrow;
}

method fetchall_arrayref { [ self.fetchall-array.eager ] }
