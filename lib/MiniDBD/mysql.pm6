# MiniDBD::mysql.pm6

use NativeCall;  # from project 'zavolaj'
use MiniDBD;     # roles for drivers

#module MiniDBD:auth<mberends>:ver<0.0.1>;

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
    returns Positional of Str
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

#-----------------------------------------------------------------------

class MiniDBD::mysql::StatementHandle does MiniDBD::StatementHandle {
    has $!mysql_client;
    has $!RaiseError;
    has $!statement;
    has $!result_set;
    has $!affected_rows;
    has @!column_names;
    has $!field_count;
    has $.mysql_warning_count is rw = 0;
    method execute(*@params is copy) {
        # warn "in MiniDBD::mysql::StatementHandle.execute()";
        my $statement = $!statement;
        while @params.elems>0 and $statement.index('?')>=0 {
            my $param = @params.shift;
            if $param ~~ /<-[0..9]>/ {
                $statement .= subst("?","'$param'"); # quote non numerics
            }
            else {
                $statement .= subst("?",$param); # do not quote numbers
            }
        }
        # warn "in MiniDBD::mysql::StatementHandle.execute statement=$statement";
        $!result_set = Mu;
        my $status = mysql_query( $!mysql_client, $statement ); # 0 means OK
        $.mysql_warning_count = mysql_warning_count( $!mysql_client );
        $!errstr = Mu;
        if $status != 0 {
            $!errstr = mysql_error( $!mysql_client );
            if $!RaiseError { die $!errstr; }
        }
        return !defined $!errstr;
    }
    
    # do() and execute() return the number of affected rows directly or:
    # rows() is called on the statement handle $sth.
    method rows() {
        unless defined $!affected_rows {
            $!errstr = Mu;
            $!affected_rows = mysql_affected_rows($!mysql_client);
            my $errstr      = mysql_error( $!mysql_client );

            if $errstr ne '' { $!errstr = $errstr; }
        }
        
        if defined $!affected_rows {
            return $!affected_rows;
        } 
    }

    method fetchrow_array() {
        my @row_array;

        unless defined $!result_set {
            $!result_set  = mysql_use_result( $!mysql_client);
            $!field_count = mysql_field_count($!mysql_client);
        }

        if defined $!result_set {
            # warn "fetching a row";
            $!errstr = Mu;

            my $native_row = mysql_fetch_row($!result_set); # can return NULL
            my $errstr     = mysql_error( $!mysql_client );
            
            if $errstr ne '' { $!errstr = $errstr; }
            
            if $native_row {
                loop ( my $i=0; $i < $!field_count; $i++ ) {
                    @row_array.push($native_row[$i]);
                }
            }
            else { self.finish; }
        }
        return @row_array;
    }

    method fetchrow_arrayref() {
        my $row_arrayref;
        unless defined $!result_set {
            $!result_set  = mysql_use_result( $!mysql_client);
            $!field_count = mysql_field_count($!mysql_client);
        }
        if defined $!result_set {
            # warn "fetching a row";
            $!errstr = Mu;
            my $native_row = mysql_fetch_row($!result_set); # can return NULL
            my $errstr = mysql_error( $!mysql_client );
            if $errstr ne '' { $!errstr = $errstr; }
            if $native_row {
                my @row_array;
                loop ( my $i=0; $i < $!field_count; $i++ ) {
                    @row_array[$i] = $native_row[$i];
                }
                $row_arrayref = @row_array;
            }
            else { self.finish; }
        }
        return $row_arrayref;
    }
    method fetch() { self.fetchrow_arrayref(); } # alias according to perldoc DBI
    method fetchall_arrayref() {
        my $all_arrayref;
        unless defined $!result_set {
            $!result_set  = mysql_use_result( $!mysql_client);
            $!field_count = mysql_field_count($!mysql_client);
        }
        if defined $!result_set {
            $!errstr = Mu;
            my @all_array;
            while ! $!errstr && my $native_row = mysql_fetch_row($!result_set) { # can return NULL
                my $row_arrayref;
                my $errstr = mysql_error( $!mysql_client );
                if $errstr ne '' { $!errstr = $errstr; }
                if $native_row {
                    my @row_array;
                    loop ( my $i=0; $i < $!field_count; $i++ ) {
                        @row_array[$i] = $native_row[$i];
                    }
                    $row_arrayref = @row_array;
                    push @all_array, $row_arrayref;
                }
                else { self.finish; }
            }
            $all_arrayref = @all_array;
        }
        return $all_arrayref;
    }

    method fetchrow_hashref () {
        my $row_hashref;
        my %row_hash;

        unless defined $!result_set {
            $!result_set  = mysql_use_result($!mysql_client);
            $!field_count = mysql_field_count($!mysql_client);
        }

        if defined $!result_set {
            $!errstr = Mu;
            my $errstr = mysql_error( $!mysql_client );
            if $errstr ne '' { $!errstr = $errstr; }

            my $native_row = mysql_fetch_row($!result_set); # can return NULL

            unless @!column_names {    
                loop ( my $i=0; $i < $!field_count; $i++ ) {
                    my $field_info  = mysql_fetch_field($!result_set);
                    my $column_name = $field_info[0];
                    @!column_names.push($column_name);    
                }
            }

            if $native_row && @!column_names {
                loop ( my $i=0; $i < $!field_count; $i++ ) {
                    my $column_value = $native_row[$i];
                    my $column_name  = @!column_names[$i];

                    %row_hash{$column_name} = $column_value;
                }
            } else {
                self.finish;
            }

            $row_hashref = %row_hash;
        }
        return $row_hashref;
    }

    method mysql_insertid() {
        mysql_insert_id($!mysql_client);
        # but Parrot NCI cannot return an unsigned long long :-(
    }

    method finish() {
        if defined( $!result_set ) {
            mysql_free_result($!result_set);
            $!result_set   = Mu;
            @!column_names = Mu;
        }
        return Bool::True;
    }
}

class MiniDBD::mysql::Connection does MiniDBD::Connection {
    has $!mysql_client;
    has $!RaiseError;
    method prepare( Str $statement ) {
        # warn "in MiniDBD::mysql::Connection.prepare()";
        my $statement_handle = MiniDBD::mysql::StatementHandle.bless(
            MiniDBD::mysql::StatementHandle.CREATE(),
            mysql_client => $!mysql_client,
            statement    => $statement,
            RaiseError   => $!RaiseError
        );
        return $statement_handle;
    }
    method mysql_insertid() {
        mysql_insert_id($!mysql_client);
        # but Parrot NCI cannot return an unsigned  long long :-(
    }
}

class MiniDBD::mysql:auth<mberends>:ver<0.0.1> {

    has $.Version = 0.01;

#------------------ methods to be called from MiniDBI ------------------
    method connect( Str $user, Str $password, Str $params, $RaiseError ) {
        # warn "in MiniDBD::mysql.connect('$user',*,'$params')";
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
            $connection = MiniDBD::mysql::Connection.bless(
                MiniDBD::mysql::Connection.CREATE(),
                mysql_client => $mysql_client,
                RaiseError => $RaiseError
            );
        }
        return $connection;
    }
}

# warn "module MiniDBD::mysql.pm has loaded";

=begin pod

=head1 DESCRIPTION
# 'zavolaj' is a Native Call Interface for Rakudo/Parrot. 'MiniDBI' and
# 'MiniDBD::mysql' are Perl 6 modules that use 'zavolaj' to use the
# standard mysqlclient library.  There is a long term Parrot based
# project to develop a new, comprehensive DBI architecture for Parrot
# and Perl 6.  MiniDBI is not that, it is a naive rewrite of the
# similarly named Perl 5 modules.  Hence the 'Mini' part of the name.

=head1 CLASSES
The MiniDBD::mysql module contains the same classes and methods as every
database driver.  Therefore read the main documentation of usage in
L<doc:MiniDBI> and internal architecture in L<doc:MiniDBD>.  Below are
only notes about code unique to the MiniDBD::mysql implementation.

=head1 SEE ALSO
The MySQL 5.1 Reference Manual, C API.
L<http://dev.mysql.com/doc/refman/5.1/en/c-api-function-overview.html>

=end pod

