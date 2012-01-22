# MiniDBD.pm6
# Provide default methods for all database drivers

=begin pod
=head1 DESCRIPTION
The MiniDBD module contains generic code that should be re-used by every
database driver, and documentation guidelines for DBD implementation.

It is also an experiment in distributing Pod fragments in and around the
code.  Without syntax highlighting, it is very awkward to work with.  It
shows that this style of file layout is unsuitable for general use.

=head1 ROLES
=head2 role MiniDBD::StatementHandle
The Connection C<prepare> method returns a StatementHandle object that
mainly provides the C<execute> and C<finish> methods.
=end pod

role MiniDBD::StatementHandle {

=begin pod
=head3 MiniDBD::StatementHandle members
=head4 instance variables
=head5 $!errstr
The C<$!errstr> variable keeps an internal copy of the last error
message retrieved from the database driver.  It is cleared (when?).
=end pod

    has $!errstr;
    method !errstr() is rw { $!errstr }

=begin pod
=head5 $.PrintError
The C<$.PrintError> variable is a read-write Bool.  True causes the
text of any error messages received from the database driver to be sent
immediately to the standard error output via warn().
=end pod

    has $.PrintError is rw = Bool::False;

=begin pod
=head4 methods
=head5 errstr
This is the accessor method for the last error string returned by the
database driver.
=end pod

    method errstr() {
        return $!errstr;
#       return defined $!errstr ?? $!errstr !! '';
    }
}

=begin pod
=head2 role MiniDBD::Connection
=end pod

role MiniDBD::Connection {

=begin pod
=head3 MiniDBD::Connection members
=head4 instance variables
=head5 $!errstr
The C<$!errstr> variable keeps an internal copy of the last error
message retrieved from the database driver.  It is cleared (when?).
=end pod

    has $!errstr;
    method !errstr() is rw { $!errstr }

=begin pod
=head4 methods
=head5 do
=end pod

    method do( Str $statement, *@params ) {
        # warn "in MiniDBD::Connection.do('$statement')";
        my $sth = self.prepare($statement) or return fail();
        $sth.execute(@params);
#       $sth.execute(@params) or return fail();
    }

=begin pod
=head5 disconnect
The C<disconnect> method 
=end pod

    method disconnect() {
        # warn "in MiniDBI::DatabaseHandle.disconnect()";
        return Bool::True;
    }

=begin pod
=head5 errstr
This is the accessor method for the last error string returned by a
connection method.
=end pod

    method errstr() {
        return $!errstr;
    }
}

=begin pod
=head1 SEE ALSO
The Perl 5 L<DBI::DBD>.
=end pod
