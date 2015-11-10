# DBDish::mysql.pm6

use NativeCall;
use DBDish;     # roles for drivers

#------------ mysql library functions in alphabetical order ------------

sub mysql_affected_rows( OpaquePointer $mysql_client )
    returns int32
    is native('libmysqlclient')
    { ... }

sub mysql_close( OpaquePointer $mysql_client )
    is native('libmysqlclient')
    { ... }

sub mysql_error( OpaquePointer $mysql_client)
    returns str
    is native('libmysqlclient')
    { ... }

sub mysql_fetch_field( OpaquePointer $result_set )
    returns CArray[Str]
    is native('libmysqlclient')
    { ... }

sub mysql_fetch_row( OpaquePointer $result_set )
    returns CArray[Str]
    is native('libmysqlclient')
    { ... }

sub mysql_field_count( OpaquePointer $mysql_client )
    returns uint32
    is native('libmysqlclient')
    { ... }

sub mysql_free_result( OpaquePointer $result_set )
    is native('libmysqlclient')
    { ... }

sub mysql_init( OpaquePointer $mysql_client )
    returns OpaquePointer
    is native('libmysqlclient')
    { ... }

sub mysql_insert_id( OpaquePointer $mysql_client )
    returns uint64
    is native('libmysqlclient')
    { ... }

sub mysql_num_rows( OpaquePointer $result_set )
    returns Int
    is native('libmysqlclient')
    { ... }

sub mysql_query( OpaquePointer $mysql_client, str $sql_command )
    returns int32
    is native('libmysqlclient')
    { ... }

sub mysql_real_connect( OpaquePointer $mysql_client, Str $host, Str $user,
    Str $password, Str $database, int32 $port, Str $socket, Int $flag )
    returns OpaquePointer
    is native('libmysqlclient')
    { ... }

sub mysql_use_result( OpaquePointer $mysql_client )
    returns OpaquePointer
    is native('libmysqlclient')
    { ... }

sub mysql_warning_count( OpaquePointer $mysql_client )
    returns uint32
    is native('libmysqlclient')
    { ... }

sub mysql_stmt_init( OpaquePointer $mysql_client )
    returns OpaquePointer
    is native('libmysqlclient')
    { ... }

sub mysql_stmt_prepare( OpaquePointer $mysql_stmt, Str, Int $length )
    returns OpaquePointer
    is native('libmysqlclient')
    { ... }

sub mysql_ping(OpaquePointer $mysql_client)
    returns int32
    is native('libmysqlclient')
    { ... }

#-----------------------------------------------------------------------

class DBDish::mysql:auth<mberends>:ver<0.0.1> {

    has $.Version = 0.01;

#------------------ methods to be called from DBIish ------------------
    method connect(Str :$user, Str :$password, :$RaiseError, *%params ) {
        my ( $mysql_client, $mysql_error );
        unless defined $mysql_client {
            $mysql_client = mysql_init( OpaquePointer );
            $mysql_error  = mysql_error( $mysql_client );
        }
        my $host     = %params<host>     // 'localhost';
        my $port     = (%params<port>     // 0).Int;
        my $database = %params<database> // 'mysql';
        my $socket   = %params<socket> // OpaquePointer;
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

