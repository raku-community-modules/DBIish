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

has %!statements;
has Lock $!statements-lock .= new;
has $.last-sth-id is rw;
has $.last-rows is rw;

# Treated as a boolean
has atomicint $!connection-lock = 0;

method dispose() {
    $!statements-lock.protect: {
        $_.dispose for %!statements.values;
        %!statements = ();
    }
    self._disconnect;
    ?($.parent.unregister-connection(self))
}
submethod DESTROY() {
    self.dispose;
}

method disconnect is hidden-from-backtrace is DEPRECATED("dispose") {
    self.dispose;
}

method drv { $.parent }

method new(*%args) {
    my \con = ::?CLASS.bless(|%args);
    con.reset-err;
    con.?set-defaults;
    %args<parent>.register-connection(con)
}

method prepare(Str $statement, *%args) { ... }

# Many DBs can only use the connection by a single thread at a time.
# Lock this with a fast CAS operation for minimal overhead. Don't try to
# wait for it to be free, just notify the user about the problem.
#
# DB level transactions make sharing a connection without some additional
# coordination risky.
method lock-connection(--> Bool) {
    if cas($!connection-lock, 0, 1) != 0 {
        self!set-err( -1, 'Connection used by multiple threads simultaneously', error-class => 'X::DBDish::ConnectionInUse').fail;
        return False;
    }
    return True;
}

method unlock-connection() {
    if cas($!connection-lock, 1, 0) != 1 {
        warn "Driver error: Unlock requested on an already unlocked connection";
    }
}

method protect-connection(Callable $code) {
    my $locked = self.lock-connection();
    LEAVE {
        self.unlock-connection() if ($locked);
    }
    $code();
}

method do(Str $statement, *@params, *%args) {
    LEAVE {
        with $!statements-lock.protect({ %!statements{$!last-sth-id} }) {
            warn "'do' should not be used for statements that return rows"
            unless .Finished;
            .dispose;
        }
    }
    if !@params && self.can('execute') {
        self.execute($statement, |%args);
    } orwith self.prepare($statement, |%args) {
        .execute(@params, |%args);
    }
    else {
        .fail;
    }
}

method rows {
    if $!last-sth-id {
        with $!statements-lock.protect({ %!statements{$!last-sth-id} }) {
            .rows;
        } else {
            $!last-rows
        }
    }
}

method register-statement-handle($handle) {
    $!statements-lock.protect: {
        %!statements{$handle.WHICH} = $handle;
    }
}

method unregister-statement-handle($handle) {
    $!statements-lock.protect: {
        %!statements{$handle.WHICH}:delete;
    }
}

method Statements() {
    # Defensive copy, since %!statements access must be done under lock
    $!statements-lock.protect: { %!statements.clone }
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
