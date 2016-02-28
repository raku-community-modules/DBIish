use v6;
need DBDish;
# DBDish::mysql.pm6

unit class DBDish::mysql:auth<mberends>:ver<0.0.2> does DBDish::Driver;
use DBDish::mysql::Native;
need DBDish::mysql::Connection;

#------------------ methods to be called from DBIish ------------------
method connect(Str :$user, Str :$password, :$RaiseError, *%params ) {
    my ( $mysql_client, $mysql_error );
    unless defined $mysql_client {
        $mysql_client = mysql_init( MYSQL );
        $mysql_error  = mysql_error( $mysql_client );
    }
    my $host     = %params<host>     // 'localhost';
    my $port     = (%params<port>     // 0).Int;
    my $database = %params<database> // 'mysql';
    my $socket   = %params<socket> // Str;
    # real_connect() returns either the same client pointer or null
    my $result   = mysql_real_connect( $mysql_client, $host,
        $user, $password, $database, $port, $socket, 0 );
    my $error = mysql_error( $mysql_client );
    my $connection;
    if $error eq '' {
        $connection = DBDish::mysql::Connection.new(
            mysql_client => $mysql_client,
            RaiseError => $RaiseError
        );
    }
    else {
        die "DBD::mysql connection failed: $error";
    }
    return $connection;
}

=begin pod

=head1 DESCRIPTION
# 'zavolaj' is a Native Call Interface for Rakudo/Parrot. 'DBIish' and
# 'DBDish::mysql' are Perl 6 modules that use 'zavolaj' to use the
# standard mysqlclient library.  There is a long term Parrot based
# project to develop a new, comprehensive DBI architecture for Parrot
# and Perl 6.  DBIish is not that, it is a naive rewrite of the
# similarly named Perl 5 modules.  Hence the 'Mini' part of the name.

=head1 CLASSES
The DBDish::mysql module contains the same classes and methods as every
database driver.  Therefore read the main documentation of usage in
L<doc:DBIish> and internal architecture in L<doc:DBDish>.  Below are
only notes about code unique to the DBDish::mysql implementation.

=head1 SEE ALSO
The MySQL 5.1 Reference Manual, C API.
L<http://dev.mysql.com/doc/refman/5.1/en/c-api-function-overview.html>

=end pod
