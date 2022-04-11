use v6;
# DBIish.pm6

unit class DBIish:ver($?DISTRIBUTION.meta<ver>):api($?DISTRIBUTION.meta<api>):auth($?DISTRIBUTION.meta<auth>);
use DBDish;

package GLOBAL::X::DBIish {
    class DriverNotFound is Exception {
        has $.bogus;
        method message { "DBIish: No DBDish driver found: $.bogus" };
    }
    class LibraryMissing is Exception {
        has $.driver;
        has $.library;
        method message { "DBIish: DBDish::$.driver needs $.library, not found" }
    }
    class NotADBDishDriver is Exception {
        has $.who;
        method message { "$.who is not a DBDish::Driver" };
    }
}

my %installed;
my Lock $installed-lock = Lock.new;

my $err-handler = DBDish::ErrorHandling.new(:parent(Nil));
method err { $err-handler.err };
method errstr { $err-handler.errstr };

method connect( $driver ) {
    my $d = self.install-driver( $driver );
    return $d.connect(|%_);

    CATCH {default {self!handle-library-exception($_, $driver)}}
}

method install-driver( $drivername ) {
    $installed-lock.protect: {
        my $d = %installed{$drivername} //= do {
            CATCH {
                when X::CompUnit::UnsatisfiedDependency {
                    X::DBIish::DriverNotFound.new(:bogus($drivername)).fail;
                }
                default {
                    .rethrow;
                }
            }
            my $module = "DBDish::$drivername";
            my \M = (require ::($module));
            # The DBDish namespace isn't formally reserved for DBDish's drivers,
            # and is a good place for related common code.
            # An assurance at driver load time is in place,
            unless M ~~ DBDish::Driver {
                # This warn will be converted in a die after the Role is settled,
                # it's an advice for authors for externally developed drivers
                warn "$module doesn't do DBDish::Driver role!";
            }
            M.new(:parent($err-handler), |%($*DBI-DEFS<ConnDefaults>), |%_);
        }
        without $d { .throw; };
        $d;
    }
}
method install_driver($drivername)
        is hidden-from-backtrace
        is DEPRECATED("install-driver")
{

    self.install-driver($drivername)
}
method installed-drivers {
    $installed-lock.protect: {
        %installed.pairs.cache;
    }
}

method !handle-library-exception($ex, $drivername) {
    # The first native call done by the driver can trigger an X::AdHoc
    # to report missing libraries.
    # I catch here to avoid the drivers the need of this logic.
    given $ex {
        when $_.message ~~ m/
        ^ "Cannot locate symbol '" <-[ ' ]>* "' in native library "
        ( "'" <-[ ' ]> * "'" )
        / {
            X::DBIish::LibraryMissing.new(:library($/[0]), :driver($drivername)).fail;
        }
        when $_.message ~~ m/
        ^ "Cannot locate native library "
        ( "'" <-[ ' ]> * "'" )
        / {
            X::DBIish::LibraryMissing.new(:library($/[0]), :driver($drivername)).fail;
        }
        default {
            .rethrow;
        };
    }
}


=begin pod
=head1 SYNOPSIS

    use v6;
    use DBIish;

    my $dbh = DBIish.connect("SQLite", :database<example-db.sqlite3>);

    my $sth = $dbh.execute(q:to/STATEMENT/);
        DROP TABLE nom
        STATEMENT

    $sth = $dbh.execute(q:to/STATEMENT/);
        CREATE TABLE nom (
            name        varchar(4),
            description varchar(30),
            quantity    int,
            price       numeric(5,2)
        )
        STATEMENT

    $sth = $dbh.execute(q:to/STATEMENT/);
        INSERT INTO nom (name, description, quantity, price)
        VALUES ( 'BUBH', 'Hot beef burrito', 1, 4.95 )
        STATEMENT

    $sth = $dbh.prepare(q:to/STATEMENT/);
        INSERT INTO nom (name, description, quantity, price)
        VALUES ( ?, ?, ?, ? )
        STATEMENT

    $sth.execute('TAFM', 'Mild fish taco', 1, 4.85);
    $sth.execute('BEOM', 'Medium size orange juice', 2, 1.20);

    $sth = $dbh.prepare(q:to/STATEMENT/);
        SELECT name, description, quantity, price, quantity*price AS amount
        FROM nom
        STATEMENT

    $sth.execute();

    my $arrayref = $sth.allrows();
    say $arrayref.elems; # 3

    $sth.finish;

    $dbh.dispose;

See also F<README.md> for more documentation.

=head1 DESCRIPTION
The name C<DBIish> has two meanings.  In lowercase it indicates the
github project being used for development.  In mixed case it is the
module name and class name that database client applications should use.

=head1 DBIish CLASSES and ROLES

=head2 DBIish
The C<DBIish> class exists mainly to provide the F<connect> method,
which acts as a constructor for database connections.

=head2 DBDish
The C<DBDish> role should only be used with 'does' to provide standard
members for DBDish classes.

=head1 SEE ALSO
L<http://dbi.perl.org>
=end pod
