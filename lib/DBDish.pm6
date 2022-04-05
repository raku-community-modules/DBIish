use v6;

unit module DBDish;
need DBIish::Common;
need DBDish::Connection;
need DBDish::StatementHandle;

role Driver does DBDish::ErrorHandling {
    has $.Version = ::?CLASS.^ver;
    has Lock $!connections-lock .= new;
    has %!connections;

    method connect(*%params --> DBDish::Connection) { ... };

    method !conn-error(:$errstr!, :$code) is hidden-from-backtrace {
        self!error-dispatch: X::DBDish::ConnectionFailed.new(
            :$code, :native-message($errstr), :$.driver-name
        );
    }

    method register-connection($con) {
        $!connections-lock.protect: {
            %!connections{$con.WHICH} = $con
        }
    }

    method unregister-connection($con) {
        $!connections-lock.protect: {
            %!connections{$con.WHICH}:delete
        }
    }

    method Connections() {
        # Return a defensive copy, since %!connections access must be done
        # while holding the lock
        $!connections-lock.protect: { %!connections.clone }
    }
}

role TypeConverter does Associative {
    has Callable %!Conversions{Mu:U} handles <AT-KEY EXISTS-KEY>;

    # The role implements the conversion
    method convert (::?CLASS:D: Str $datum, Mu:U $type) {
        my $func = self.convert-function($type);
        $func($datum);
    }
    # Return a function which will perform conversion based on the type provided
    # Since databases return the same types for each record, this information may be gathered
    # ahead of time and cached by the driver.
    method convert-function (::?CLASS:D: Mu:U $type) {
        with %!Conversions{$type} -> &converter {
            if (&converter.signature.params.any ~~ .named) {
                sub ($datum) { converter($datum, :$type) };
            } else {
                sub ($datum) { converter($datum) };
            }
        } else { # Common case
            if (Str.can($type.^name)) {
                sub ($datum) { try $type($datum) };
            } else {
                sub ($datum) { $type.new($datum) };
            }
        }
    }
    method STORE(::?CLASS:D: \to_store) {
        for @(to_store) {
            when Callable { %!Conversions{$_.signature.returns} = $_ }
            when Pair { %!Conversions{::($_.key)} = $_.value }
        }
    }
}

=begin pod
=head1 DESCRIPTION
The DBDish module loads the generic code needed by every DBDish driver of the
Perl6 DBIish Database API

It is the base namespace of all drivers related packages, future drivers extensions
and documentation guidelines for DBDish driver implementors.

It is also an experiment in distributing Pod fragments in and around the
code.

=head1 Roles needed by a DBDish's driver

A proper DBDish driver Foo needs to implement at least three classes:

- class DBDish::Foo does DBDish::Driver
- class DBDish::Foo::Connection does DBDish::Connection
- DBDish::Foo::StatementHandle does DBDish::StatementHandle

Those roles are documented below.

=head2 DBDish::Driver

This role define the minimum interface that a driver should provide to be properly
loaded by DBIish.

The minimal declaration of a driver Foo typically start like:

   use v6;
   need DBDish; # Load all roles

   unit class DBDish::Foo does DBDish::Driver;
   ...

- See L<DBDish::ErrorHandling>

- See L<DBDish::Connection>

- See L<DBDish::StatementHandle>

=head2 DBDish::TypeConverter

This role defines the API for dynamic handling of the types of a DB system

=head1 SEE ALSO

The Perl 5 L<DBI::DBD>.

=end pod
