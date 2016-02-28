use v6;

=begin pod
=head2 role DBDish::StatementHandle
The Connection C<prepare> method returns a StatementHandle object that
mainly provides the C<execute> and C<finish> methods. It also has all the methods from C<DBDish::Role::ErrorHandling>.
=end pod

need DBDish::ErrorHandling;

unit role DBDish::StatementHandle does DBDish::ErrorHandling;

method finish() { ... }
method fetchrow() { ... }
method execute(*@) { ... }

method	_row(:$hash) { ... }


method fetchrow-hash() {
    hash self.column_names Z=> self.fetchrow;
}

method row(:$hash) {
     self._row(:$hash);
}

method allrows(:$array-of-hash, :$hash-of-array) {
    my @rows;
    die "You can't use array-of-hash with hash-of-array" if $array-of-hash and $hash-of-array;
    if $array-of-hash {
        while self.row(:hash) -> %row {
            @rows.push(%row);
        }
        return @rows;
    }
    if $hash-of-array {
        my @names := self.column_names;
        my %rows = @names Z=> [] xx *;
        while self.row -> @a {
            for @a Z @names -> ($v, $n) {
                %rows{$n}.push: $v;
            }
        }
        return %rows;
    }
    while self.row -> @r {
         @rows.push(@r);
    }
    @rows;
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

method fetchall_arrayref  { [ self.fetchall-array.eager ] }
