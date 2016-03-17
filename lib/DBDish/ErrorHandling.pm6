role DBDish::ErrorHandling {

    # Our exceptions
    package GLOBAL::X::DBDish {
        our class DBError is Exception {
            has $.driver-name;
            has $.native-message is required;
            has $.code;
            has $.why = 'Error';
            method message {
                "$!driver-name: $.why: $!native-message" ~
                ($!code ?? " ($!code)" !! '');
            }
        }
    }

    has $.parent is required;
    has Bool $.PrintError is rw = False;
    has Bool $.RaiseError is rw = True;
    has Exception $!last-exception;

    method set-last-exception($e) {
        $!last-exception = $e;
        if $!parent.^can('set-last-exception') {
            $!parent.set-last-exception($e);
        }
    }

    method err( --> Int)  {
        with $!last-exception {
            .?code || -1;
        }
        else { 0 }
    }

    method errstr(--> Str) {
        with $!last-exception {
            .message;
        }
        else { '' }
    }

    method driver-name(--> Str) {
        $ = do {
            self.^can('connect') ?? self.^name !! $!parent.driver-name;
        }
    }

    method reset-err(--> True) { self.set-last-exception(Nil); }

    method !error-dispatch(X::DBDish::DBError $_) is hidden-from-backtrace {
        self.set-last-exception($_);
        $!RaiseError and .throw or .fail;
    }

    method !set-err($code, $errstr) is hidden-from-backtrace {
        self!error-dispatch: X::DBDish::DBError.new(
            :$code, :native-message($errstr), :$.driver-name
        );
    }
}

=begin pod

=head1 role DBDish::Role::ErrorHandling

A role that handles the errors from connection handles and statement handles

=head3 Attributes
=head4 C<PrintError is rw>
Errors are printed to the standard error handle if this is True
=head4 C<RaiseError is rw = True>
Errors raise exceptions if this is True
=head3 Methods
=head4 errstr
Returns the string representation of the last error
=head4 !set_err
Private method that sets the error string, and prints and/or raises an
exception, depending on the C<$.PrintError> and C<$.RaiseError> flags.
=head4 !reset_err
Resets the error string to the empty string.

=end pod
