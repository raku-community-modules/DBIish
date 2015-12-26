
=begin pod

=head1 role DBDish::Role::ErrorHandling

A role that handles the errors from connection handles and statement handles

=head3 Attributes
=head4 C<PrintError is rw>
Errors are printed to the standard error handle if this is True
=head4 C<RaiseErrors is rw = True>
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

role DBDish::Role::ErrorHandling {
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
