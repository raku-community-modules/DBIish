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
has Bool $!disposed = False;
has Int $!affected-rows;
has @!column-name;
has @!column-type;
has $!which = self.WHICH;

# My defined interface
method execute(*@ --> DBDish::StatementHandle) { ... }
method finish(--> Bool) { ... }
method _row(--> Array) { ... }
method _free() { ... }

method !ftr() {
    $.parent.last-sth-id = $!which;
}

method !enter-execute(int $got = 0, int $expect = 0) {
    self.finish unless $!Finished;
    $!affected-rows = Nil;
    self!ftr;
    self!set-err( -1,
            "Wrong number of arguments to method execute: got $got, expected $expect"
        ).fail unless $got == $expect;
}

method !done-execute(Int $rows, $fields) {
    $!Executed++;
    $!Finished = False;
    $!affected-rows = $rows;
    self.finish unless $fields;
    self;
}

method new(*%args) {
    my \sth = ::?CLASS.bless(|%args);
    %args<parent>.register-statement-handle(sth)
}

method dispose() {
    self.finish unless $!Finished;
    self._free;
    $!disposed = True;
    with $.parent.unregister-statement-handle(self) {
        $.parent.last-rows = self.rows;
        True;
    } else { False };
}
#Avoid leaks if explicit dispose isn't used by the user.
submethod DESTROY() {
    self.dispose;
}

method rows() {self._rows}

method _rows {
    my constant TRUE_ZERO = 0 but IntTrue;
    $!affected-rows.defined
            ?? $!affected-rows || TRUE_ZERO
            !! Int;
}

method row(:$hash) {
    self!ftr;
    self!set-err( -1,
            "row() called after Statement Handle disposed."
            ).fail if ($!disposed);

    self!set-err(-1,
            "row() called before execute()"
            ).fail if ($.Executed == 0);

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
        self!set-err( -1,
                "Lazy data used after Statement Handle disposed. Retain statement handle or use allrows(:array-of-hash).eager"
                ).fail if ($!disposed);

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
        self!set-err( -1,
                "Lazy data used after Statement Handle disposed. Retain statement handle or use allrows().eager"
                ).fail if ($!disposed);

        while self.row -> \r {
            take r;
        }
    }
}

