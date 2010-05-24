# FakeDBD::mysql.pm6

use NativeCall;  # from project 'zavolaj'
use FakeDBD;     # roles for drivers

#------------ mysql library functions in alphabetical order ------------

sub mysql_affected_rows( OpaquePointer $mysql_client )
    returns Int
    is native('libmysqlclient')
    { ... }

sub mysql_close( OpaquePointer $mysql_client )
    returns OpaquePointer
    is native('libmysqlclient')
    { ... }

sub mysql_data_seek( OpaquePointer $result_set, Int $row_number )
    returns OpaquePointer
    is native('libmysqlclient')
    { ... }

sub mysql_error( OpaquePointer $mysql_client)
    returns Str
    is native('libmysqlclient')
    { ... }

sub mysql_fetch_field( OpaquePointer $result_set )
    returns OpaquePointer
    is native('libmysqlclient')
    { ... }

sub mysql_fetch_lengths( OpaquePointer $result_set )
    returns Positional of Int
    is native('libmysqlclient')
    { ... }

sub mysql_fetch_row( OpaquePointer $result_set )
    returns Positional of Str
    is native('libmysqlclient')
    { ... }

sub mysql_field_count( OpaquePointer $mysql_client )
    returns Int
    is native('libmysqlclient')
    { ... }

sub mysql_free_result( OpaquePointer $result_set )
    returns OpaquePointer
    is native('libmysqlclient')
    { ... }

sub mysql_get_client_info( OpaquePointer $mysql_client)
    returns Str
    is native('libmysqlclient')
    { ... }

sub mysql_init( OpaquePointer $mysql_client )
    returns OpaquePointer
    is native('libmysqlclient')
    { ... }

sub mysql_insert_id( OpaquePointer $mysql_client )
    returns Int # WRONG: actually returns an unsigned long long
    is native('libmysqlclient')
    { ... }

sub mysql_library_init( Int $argc, OpaquePointer $argv,
    OpaquePointer $group )
    returns Int
    is native('libmysqlclient')
    { ... }

sub mysql_library_end()
    returns OpaquePointer # currently not working, should be void
    is native('libmysqlclient')
    { ... }

sub mysql_num_rows( OpaquePointer $result_set )
    returns Int
    is native('libmysqlclient')
    { ... }

sub mysql_query( OpaquePointer $mysql_client, Str $sql_command )
    returns Int
    is native('libmysqlclient')
    { ... }

sub mysql_real_connect( OpaquePointer $mysql_client, Str $host, Str $user,
    Str $password, Str $database, Int $port, Str $socket, Int $flag )
    returns OpaquePointer
    is native('libmysqlclient')
    { ... }

sub mysql_stat( OpaquePointer $mysql_client)
    returns Str
    is native('libmysqlclient')
    { ... }

sub mysql_store_result( OpaquePointer $mysql_client )
    returns OpaquePointer
    is native('libmysqlclient')
    { ... }

sub mysql_use_result( OpaquePointer $mysql_client )
    returns OpaquePointer
    is native('libmysqlclient')
    { ... }

sub mysql_warning_count( OpaquePointer $mysql_client )
    returns Int
    is native('libmysqlclient')
    { ... }

#--------------------------- 

class FakeDBD::mysql::StatementHandle does FakeDBD::StatementHandle {
    has $!mysql_client;
    has $!statement;
    has $!result_set;
    has $!field_count;
    has $.mysql_warning_count is rw = 0;
    method execute(*@params is copy) {
        # warn "in FakeDBD::mysql::StatementHandle.execute()";
        my $statement = $!statement;
        while @params.elems>0 and $statement.index('?')>=0 {
            my $param = @params.pop;
            $statement .= subst("?","'$param'");
        }
        # warn "in FakeDBD::mysql::StatementHandle.execute statement=$statement";
        $!result_set = Mu;
        my $status = mysql_query( $!mysql_client, $statement ); # 0 means OK
        $.mysql_warning_count = mysql_warning_count( $!mysql_client );
        $!errstr = Mu;
        if $status != 0 {
            my $errstr = mysql_error( $!mysql_client );
            $!errstr = $errstr;
        }
        return !defined $!errstr;
    }
    method fetchrow_arrayref() {
        my $row_arrayref;
        unless defined $!result_set {
            $!result_set  = mysql_use_result( $!mysql_client);
            $!field_count = mysql_field_count($!mysql_client);
        }
        if defined $!result_set {
            # warn "fetching a row";
            my $native_row = mysql_fetch_row($!result_set); # can return NULL
            if $native_row {
                my @row_array;
                loop ( my $i=0; $i < $!field_count; $i++ ) {
                    @row_array[$i] = $native_row[$i];
                }
                $row_arrayref = @row_array;
            }
        }
        return $row_arrayref;
    }
    method fetch() { self.fetchrow_arrayref(); } # alias according to perldoc DBI
    method mysql_insertid() {
        mysql_insert_id($!mysql_client);
        # but Parrot NCI cannot return an unsigned  long long :-(
    }
    method finish() {
        mysql_free_result($!result_set);
        $!result_set = Mu;
    }
}

class FakeDBD::mysql::Connection does FakeDBD::Connection {
    has $!mysql_client;
    method prepare( Str $statement ) {
        # warn "in FakeDBD::mysql::Connection.prepare()";
        my $statement_handle = FakeDBD::mysql::StatementHandle.bless(
            FakeDBD::mysql::StatementHandle.CREATE(),
            mysql_client => $!mysql_client,
            statement    => $statement
        );
        return $statement_handle;
    }
    method mysql_insertid() {
        mysql_insert_id($!mysql_client);
        # but Parrot NCI cannot return an unsigned  long long :-(
    }
}

class FakeDBD::mysql:auth<mberends>:ver<0.0.1> {

    has $.Version = 0.01;

#------------------ methods to be called from FakeDBI ------------------
    method connect( Str $user, Str $password, Str $params ) {
        # warn "in FakeDBD::mysql.connect('$user',*,'$params')";
        my ( $mysql_client, $mysql_error );
        unless defined $mysql_client {
            $mysql_client = mysql_init( pir::null__P() );
            $mysql_error  = mysql_error( $mysql_client );
        }
        my @params = $params.split(';');
        my %params;
        for @params -> $p {
            my ( $key, $value ) = $p.split('=');
            %params{$key} = $value;
        }
        my $host     = %params<host>     // 'localhost';
        my $port     = %params<port>     // 0;
        my $database = %params<database> // 'mysql';
        # real_connect() returns either the same client pointer or null
        my $result   = mysql_real_connect( $mysql_client, $host,
            $user, $password, $database, $port, pir::null__P(), 0 );
        my $error = mysql_error( $mysql_client );
        my $connection;
        if $error eq '' {
            $connection = FakeDBD::mysql::Connection.bless(
                FakeDBD::mysql::Connection.CREATE(),
                mysql_client => $mysql_client
            );
        }
        return $connection;
    }
}

# warn "module FakeDBD::mysql.pm has loaded";

=begin pod

# 'zavolaj' is a Native Call Interface for Rakudo/Parrot. 'FakeDBI' and
# 'FakeDBD::mysql' are Perl 6 modules that use 'zavolaj' to use the
# standard mysqlclient library.  There is a long term Parrot based
# project to develop a new, comprehensive DBI architecture for Parrot
# and Perl 6.  FakeDBI is not that, it is a naive rewrite of the
# similarly named Perl 5 modules.  Hence the 'Fake' part of the name.

=head1 SEE ALSO
The MySQL 5.1 Reference Manual, C API.
L<http://dev.mysql.com/doc/refman/5.1/en/c-api-function-overview.html>

=end pod

