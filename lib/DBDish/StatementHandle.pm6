use v6;

=begin pod
=head2 role DBDish::StatementHandle
The Connection C<prepare> method returns a StatementHandle object that
should provides the C<execute> and C<finish> methods.

A Statetement handle should provide also the low-level C<_row> and C<_free>
methods.

It also has all the methods from C<DBDish::Role::ErrorHandling>.
=end pod

need DBDish::ErrorHandling;

unit role DBDish::StatementHandle does DBDish::ErrorHandling;

my role IntTrue { method Bool { self.defined } };

has Int $.Executed = 0;
has Bool $.Finished = True;
has Int $!affected_rows;
has @!column-name;
has @!column-type;

# My defined interface
method execute(*@ --> IntTrue) { ... }
method finish(--> Bool) { ... }
method _row(--> Array) { ... }
method _free() { ... }

method !ftr() {
    $.parent.last-sth-id = self.WHICH;
}

method !enter-execute() {
    self.finish unless $!Finished;
    $!affected_rows = Nil;
    self!ftr;
}

method !done-execute(Int $rows, Bool $was-select) {
    $!Executed++;
    $!Finished = False;
    $!affected_rows = $rows;
    self.finish unless $was-select;
    self.rows;
}

method new(*%args) {
    my \sth = ::?CLASS.bless(|%args);
    %args<parent>.Statements{sth.WHICH} = sth;
}

method dispose() {
    self.finish unless $!Finished;
    self._free;
    with $.parent.Statements{self.WHICH}:delete {
	$.parent.last-rows = self.rows;
	True;
    } else { False };
}
#Avoid leaks if explicit dispose isn't used by the user.
submethod DESTROY() {
    self.dispose;
}

method rows {
    $!affected_rows but IntTrue;
}

method row(:$hash) {
    self!ftr;
    if my \r = self._row {
	$hash ?? (@!column-name Z=> @(r)).hash !! r.Array;
    } else {
	$hash ?? % !! @;
    }
}

method column-names {
    @!column-name;
}

method column-types {
    @!column-type;
}

multi method allrows(:$array-of-hash!) {
    gather {
	while self.row(:hash) -> %r {
	    take %r;
	}
    }
}

multi method allrows(:$hash-of-array!) {
    my %rows = @!column-name Z=> [] xx *;
    while self.row -> @a {
	for @a Z @!column-name -> ($v, $n) {
	    %rows{$n}.push: $v;
	}
    }
    %rows;
}

multi method allrows() {
    gather {
	while self.row -> @r {
	    take @r;
	}
    }
}

# Legacy
method fetchrow {
    if my \r = self._row {
	my @ = (r.map: { .defined ?? ~$_ !! Str });
    } else { @ };
}

method fetchrow-hash {
    hash @!column-name Z=> self.fetchrow;
}
method fetchrow_hashref { self.fetchrow-hash }

method fetchall_hashref(Str $key) {
    my %results;
    while self.fetch-hash -> \h {
	%results{h{$key}} = h;
    }
    %results;
}

method fetchall-hash {
    my @names := @!column-name;
    my %res = @names Z=> [] xx *;
    for self.fetchall-array -> @a {
        for @a Z @names -> ($v, $n) {
            %res{$n}.push: $v;
        }
    }
    %res;
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
method fetchrow_arrayref { self.fetchrow; }
method fetch { self.fetchrow; }

method fetchall_arrayref  { [ self.fetchall-array.eager ] }
