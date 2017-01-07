use v6;

unit module DBDish;
need DBIish::Common;
need DBDish::Connection;
need DBDish::StatementHandle;

role Driver does DBDish::ErrorHandling {
    has $.Version = ::?CLASS.^ver;
    has %.Connections;

    method connect(*%params --> DBDish::Connection) { ... };

    method !conn-error(:$errstr!, :$code) is hidden-from-backtrace {
	self!error-dispatch: X::DBDish::ConnectionFailed.new(
	    :$code, :native-message($errstr), :$.driver-name
	);
    }
    #method new() { nextsame; }
}

role TypeConverter does Associative {
    has Callable %!Conversions{Mu:U} handles <AT-KEY EXISTS-KEY>;

    # The role implements the conversion
    method convert (::?CLASS:D: Str $datum, Mu:U $typ) {
        with %!Conversions{$typ} -> &converter {
            converter($datum, $typ);
        } else { # Common case
            $typ($datum);
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

=head2 DBDish::Type

This role defines the API for dynamic handling of the types of a DB system

=head1 SEE ALSO

The Perl 5 L<DBI::DBD>.

=end pod
