use v6;

=begin pod
=head2 role DBDish::Connection

Does the C<DBDish::ErrorHandling> role.

=end pod

need DBDish::ErrorHandling;
need DBDish::StatementHandle;

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

## Introspection methods added to facilitate better testing of statement handle management!
## While the Oracle specific driver does have this issue I suspect others do as well for
## the same reasons. Connection methods such as .execute, .do, .commit, .rollback perhaps
## others have been know to leak handles until Oracle runs out of cursors.
method inspect-statement-count { return $!statements-lock.protect: { %!statements.keys.elems }}
method inspect-statement-keys  { return $!statements-lock.protect: { %!statements.keys }}
method inspect-statement-sql
{
  return $!statements-lock.protect: {
    my @sql-statements;
    for %!statements.values -> $sth {
      @sql-statements.push: $sth.statement;
    }
    @sql-statements;
  }
}

# Treated as a boolean
has atomicint $!connection-lock = 0;

method dispose() {
    self.teardown-connection-state();

    self._disconnect;
    ?($.parent.unregister-connection(self));
}

# Remove client-side information about the connection state. This is separate from dispose to
# to enable connection reuse.
method teardown-connection-state() {
    $!statements-lock.protect: {
        $_.dispose for %!statements.values;
        %!statements = ();
    }
}

# A scrub-connection-for-reuse() function is implemented to allow cleaning the connection for reuse
method supports-connection-reuse(--> Bool) {
    return so self.^can('scrub-connection-for-reuse');
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

# Lock and Unlock around a block of driver code.
#
# Since CATCH in the caller fires before LEAVE in this method, we need to do
# a bit of fiddly tracking to make unlock fire in both the success and error
# case prior to passing control back upstream as the caller may wish to
# $dbh.execute('ROLLBACK') in a CATCH block.
method protect-connection(Callable $code) {
    my $locked = self.lock-connection();

    my $ret = $code();

    # Unlock if successful
    if ($locked) {
        self.unlock-connection();
        $locked = False;
    }

    # Unlock in the error case too
    CATCH {
        default {
            self.unlock-connection() if $locked;
            $_.rethrow;
        }
    }

    return $ret;
}

method execute(Str $statement, **@params, *%args --> DBDish::StatementHandle) {
    return self.prepare($statement, |%args).execute(|@params);
}

# Kinda deprecated
method do(Str $statement, **@params, *%args) {
    LEAVE {
        with $!statements-lock.protect({ %!statements{$!last-sth-id} }) {
            warn "'do' should not be used for statements that return rows"
            unless .Finished;
            .dispose;
        }
    }
    if !@params && self.can('execute') {
        self.execute($statement, |%args).rows;
    } orwith self.prepare($statement, |%args) {
        .execute(|@params, |%args).rows;
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
=head5 quote

Returns the string parameter quoted as a literal by default.

quote($str, :as-id) will return it as a quoted identifier.

=end pod

# Implement basic SQL spec escaping. Individual drivers should override this function with their
# own implementation if the database driver provides quoting/escaping routines. Even if this is
# sufficient today, it may not be for future releases of that database.
# Many database products also require backslash escaping.
method quote(Str $x, :$as-id) {
    if $as-id {
        q["] ~ $x.subst(q{"}, q{""}, :global) ~ q["]
    } else {
        q['] ~ $x.subst(q{'}, q{''}, :global) ~ q[']
    }
}

method quote-identifier(Str:D $name) is DEPRECATED('quote($name, :as-id)') {
    return self.quote($name, :as-id);
}

=begin pod
=head5 _disconnect
The C<_disconnect> method
=end pod

method _disconnect() {
    ...
}
