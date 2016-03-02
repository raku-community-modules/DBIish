role DBDish::ErrorHandling {

# Our exceptions
    package GLOBAL::X::DBDish {
	our class DBError is Exception {
	    has $.driver-name;
	    has $.native-message is required;
	    has $.code;
	    method message {
		"$!driver-name: Error: $!native-message" ~
		($!code ?? " ($!code)" !! '');
	    }
	}
	our class LibraryNotFound is Exception {
	    method message { "Can't load my native library" }
	}
	our class ConnectionFailed is Exception {
	    has $.driver-name;
	    has $.native-message is required;
	    has $.code;
	    method message {
		"$!driver-name: Can't connect: $!native-message" ~
		($!code ?? " ($!code)" !! '');
	    }
	}
    }

    has $.parent is required;
    has Bool $.PrintError is rw = False;
    has Bool $.RaiseError is rw = True;
    has $.err is default(0);
    has $.errstr is default('');

    method driver-name {
	state $dn = do {
	    if self.DEFINITE {
		($!parent ~~ DBDish::Driver) ?? $!parent.^name !! self.parent.^name;
	    } else {
		::?CLASS.^name.split('::').[^(*-1)].join('::');
	    }
	}
	$dn;
    }

    method !reset-err( --> True) { $!err = Nil; $!errstr = Nil; }

    method !set-err($code, $errstr) is hidden-from-backtrace {
	given X::DBDish::DBError.new(
	    :$code, :native-message($errstr), :$.driver-name
	) {
	    $!RaiseError and .throw or .fail;
	}
    }

    # For report errors at connection time before a Connection can be made
    method conn-error(::?CLASS:U: :$errstr!, :$code, :$RaiseError) {
	given X::DBDish::ConnectionFailed.new(
	    :$code, :native-message($errstr), :$.driver-name
	) {
	    $RaiseError and .throw or .fail;
	}
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
=head4 !set_errstr
Private method that sets the error string, and prints and/or raises an
exception, depending on the C<$.PrintError> and C<$.RaiseError> flags.
=head4 !reset_errstr
Resets the error string to the empty string.

=end pod
