use v6;

# Our exceptions
package X::DBDish {
    class DBError is Exception {
        has $.driver-name;
        has $.native-message is required;
        has $.code;
        has $.why = 'Error';
        method message {
            "$!driver-name: $.why: $!native-message" ~
            ($!code ?? " ($!code)" !! '');
        }

        # Individual drivers are expected to override this to return true for
        # errors which may succeed if retried immediately.
        # Serialization failure, deadlocks, network disconnects, etc.
        method is-temporary {
            False;
        }
    }
    class ConnectionFailed is DBError {
        has $.why = "Can't connect";
    }

    class ConnectionInUse is DBError {
        has $.why = 'Unsupported Concurrency';
    }
}

role DBDish::ErrorHandling is export {
    has $.parent is required;
    has Bool $.PrintError is rw;
    has Bool $.RaiseError is rw;
    has Exception $!last-exception;

    method set-last-exception($e) {
        $!last-exception = $e;
        $!parent.?set-last-exception($e);
    }

    method err(--> Int)  {
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

    method !set-err(Int $code, Str $errstr, Str :$error-class = 'X::DBDish::DBError') is hidden-from-backtrace {
        self!error-dispatch: ::($error-class).new(
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
