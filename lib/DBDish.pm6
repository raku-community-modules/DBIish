# DBDish.pm6
# Provide default methods for all database drivers

=begin pod
=head1 DESCRIPTION
The DBDish module contains generic code that should be re-used by every
database driver, and documentation guidelines for DBD implementation.

It is also an experiment in distributing Pod fragments in and around the
code.  Without syntax highlighting, it is very awkward to work with.  It
shows that this style of file layout is unsuitable for general use.

=head1 ROLES

=head2 role DBDish::ErrorHandling

A role that handles the errors from connection handles and statement handles

=head3 Attributes
=head4 C<PrintError is rw>
Errors are printed to the standard error handle if this is True
=head4 C<RaisErrors is rw = True>
Errors raise exceptions if this is True
=head3 Methods
=head4 errstr
Returns the string representation of the last error
=head4 !set_errstr
Private method that sets the error string, and prints and/or raises an
exception, depending on the C<$.PrintError> and C<$.RaiseError> flags.
=head4 !reset_errstr
Resets the error string to the empty string.
=end pod

role DBDish::ErrorHandling {
    has Bool $.PrintError is rw = False;
    has Bool $.RaiseError is rw = True;
    has $.errstr;
    method !set_errstr($err) is hidden-from-backtrace {
        $!errstr = $err;
        note $!errstr if self.PrintError;
        die  $!errstr if self.RaiseError;
    }
    method !reset_errstr() { $!errstr = '' };
}

=begin pod
=head2 role DBDish::StatementHandle
The Connection C<prepare> method returns a StatementHandle object that
mainly provides the C<execute> and C<finish> methods. It also has all the methods from C<DBDish::ErrorHandling>.
=end pod

role DBDish::StatementHandle does DBDish::ErrorHandling {
    method finish() { ... }
    method fetchrow() { ... }
    method execute(*@) { ... }

    method fetchrow-hash() {
        hash self.column_names Z=> self.fetchrow;
    }

    method fetchrow_hashref { $.fetchrow-hash }
    method fetchrow_typedhash { die "Your selected backend does not support/implement typed values" }

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
}

=begin pod
=head2 role DBDish::Connection

Does the C<DBDish::ErrorHandling> role.

=end pod

role DBDish::Connection does DBDish::ErrorHandling {

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
}

=begin pod
=head1 SEE ALSO
The Perl 5 L<DBI::DBD>.
=end pod
