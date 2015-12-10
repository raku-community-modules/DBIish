
use v6;

use NativeCall;

unit module DBDish::mysql::Native;

constant LIB = %*ENV<DBIISH_MYSQL_LIB> || 'libmysqlclient';

#------------ mysql library functions in alphabetical order ------------

sub mysql_affected_rows( OpaquePointer $mysql_client )
    returns int32
    is native(LIB)
    is export
    { ... }

sub mysql_close( OpaquePointer $mysql_client )
    is native(LIB)
    is export
    { ... }

sub mysql_error( OpaquePointer $mysql_client)
    returns str
    is native(LIB)
    is export
    { ... }

sub mysql_fetch_field( OpaquePointer $result_set )
    returns CArray[Str]
    is native(LIB)
    is export
    { ... }

sub mysql_fetch_row( OpaquePointer $result_set )
    returns CArray[Str]
    is native(LIB)
    is export
    { ... }

sub mysql_field_count( OpaquePointer $mysql_client )
    returns uint32
    is native(LIB)
    is export
    { ... }

sub mysql_free_result( OpaquePointer $result_set )
    is native(LIB)
    is export
    { ... }

sub mysql_init( OpaquePointer $mysql_client )
    returns OpaquePointer
    is native(LIB)
    is export
    { ... }

sub mysql_insert_id( OpaquePointer $mysql_client )
    returns uint64
    is native(LIB)
    is export
    { ... }

sub mysql_num_rows( OpaquePointer $result_set )
    returns ulonglong
    is native(LIB)
    is export
    { ... }

sub mysql_query( OpaquePointer $mysql_client, str $sql_command )
    returns int32
    is native(LIB)
    is export
    { ... }

sub mysql_real_connect( OpaquePointer $mysql_client, Str $host, Str $user,
    Str $password, Str $database, int32 $port, Str $socket, ulong $flag )
    returns OpaquePointer
    is native(LIB)
    is export
    { ... }

sub mysql_use_result( OpaquePointer $mysql_client )
    returns OpaquePointer
    is native(LIB)
    is export
    { ... }

sub mysql_warning_count( OpaquePointer $mysql_client )
    returns uint32
    is native(LIB)
    is export
    { ... }

sub mysql_stmt_init( OpaquePointer $mysql_client )
    returns OpaquePointer
    is native(LIB)
    is export
    { ... }

sub mysql_stmt_prepare( OpaquePointer $mysql_stmt, Str, ulong $length )
    returns OpaquePointer
    is native(LIB)
    is export
    { ... }

sub mysql_ping(OpaquePointer $mysql_client)
    returns int32
    is native(LIB)
    is export
    { ... }
