
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

method	_row(:$hash) { ... }
method	allrows(:$hash) { ... }

method column_p6types { die "The selected backend does not support/implement typed value" }
# Used by fetch* typedhash
method true_false { return True }

method fetchrow-hash() is DEPRECATED("row(:hash)") {
    hash self.column_names Z=> self.fetchrow;
}

method row(:$hash) {
  gather { while my $row = self._row(:hash($hash)) { take $row }};
}

method fetchall_typedhash {
    my @names = self.column_names;
    my @types = self.column_p6types;
    my %res = @names Z=> [] xx *;
    for self.fetchall-array -> @a {
        my $i = 0;
        for @a Z @names -> ($v, $n) {
            %res{$n}.push: self.typed_value(@types[$i++], $v);
        }
    }
    return %res;
}

method fetchrow_typedhash {
    my Str @values = self.fetchrow_array;
    return Any if !@values.defined;
    my @names = self.column_names;
    my @types = self.column_p6types;
    my %hash;
    for 0..(@values.elems-1) -> $i {
        %hash{@names[$i]} = self.typed_value(@types[$i], @values[$i]);
    }
    return %hash;
}

method typed_value(Str $typename, Str $value) {
    given ($typename) {
            return $value when 'Str';
            return $value.Num when 'Num';
            return $value.Int when 'Int';
            return self.true_false($value) when 'Bool';
            return $value.Real when 'Real';
        }
}

method fetchrow_hashref is DEPRECATED("row(:hash)") { $.fetchrow-hash }

method fetchall-hash is DEPRECATED("row(:hash)") {
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

method fetchall-array is DEPRECATED("allrows(:hash)"){
    (0 xx *).flatmap: {
        my $r = self.fetchrow;
        last unless $r;
        $r;
    };
}

method fetchrow_array is DEPRECATED("row()") { self.fetchrow }

method fetchrow_arrayref is DEPRECATED("row()") {
    $.fetchrow;
}

method fetch() is DEPRECATED("row()") {
    $.fetchrow;
}

method fetchall_arrayref is DEPRECATED("allrows()") { [ self.fetchall-array.eager ] }
