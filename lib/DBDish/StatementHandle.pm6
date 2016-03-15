use v6;

=begin pod
=head2 role DBDish::StatementHandle
The Connection C<prepare> method returns a StatementHandle object that
mainly provides the C<execute> and C<finish> methods. It also has all the methods from C<DBDish::Role::ErrorHandling>.
=end pod

need DBDish::ErrorHandling;

unit role DBDish::StatementHandle does DBDish::ErrorHandling;


has Int $.Executed = 0;
has Bool $.Finished = True;
has Int $!affected_rows;
has @!column-name;
has @!column-type;

method dispose() {
    self.finish unless $!Finished;
    self._free;
    my \id := self.WHICH.Str;
    ?($.parent.Statements{id}:delete);
}
#Avoid leaks if explicit dispose isn't used by the user.
submethod DESTROY() {
    self.dispose;
}
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

my role IntTrue { method Bool { self.defined } };
method rows {
    $!affected_rows but IntTrue;
}

method _free() { ... }
method finish(--> Bool) { ... }
method fetchrow() { ... }
method execute(*@ --> IntTrue) { ... }
method	_row(:$hash) { ... }

method row(:$hash) {
    self!ftr;
    self._row(:$hash);
}

method column-names {
    @!column-name;
}

method column-types {
    @!column-type;
}

multi method allrows(:$array-of-hash!) {
    my @rows;
    while self.row(:hash) -> %row {
	@rows.push(%row);
    }
    @rows;
}

multi method allrows(:$hash-of-array!) {
    my @names := @!column-name;
    my %rows = @names Z=> [] xx *;
    while self.row -> @a {
	for @a Z @names -> ($v, $n) {
	    %rows{$n}.push: $v;
	}
    }
    %rows;
}

multi method allrows() {
    my @rows;
    while self.row -> @r {
         @rows.push(@r);
    }
    @rows;
}

method fetchrow-hash() {
    hash @!column-name Z=> self.fetchrow;
}

method fetchrow_hashref { $.fetchrow-hash }

method fetchall-hash {
    my @names := @!column-name;
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
