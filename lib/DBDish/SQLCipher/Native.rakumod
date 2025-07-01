use v6;

use NativeLibs;
use NativeCall;

unit module DBDish::SQLCipher::Native;

enum SQLCIPHER is export (
    SQLCIPHER_OK        =>    0 , #  Successful result
    SQLCIPHER_ERROR     =>    1 , #  SQL error or missing database
    SQLCIPHER_INTERNAL  =>    2 , #  Internal logic error in SQLCipher
    SQLCIPHER_PERM      =>    3 , #  Access permission denied
    SQLCIPHER_ABORT     =>    4 , #  Callback routine requested an abort
    SQLCIPHER_BUSY      =>    5 , #  The database file is locked
    SQLCIPHER_LOCKED    =>    6 , #  A table in the database is locked
    SQLCIPHER_NOMEM     =>    7 , #  A malloc() failed
    SQLCIPHER_READONLY  =>    8 , #  Attempt to write a readonly database
    SQLCIPHER_INTERRUPT =>    9 , #  Operation terminated by sqlite3_interrupt()
    SQLCIPHER_IOERR     =>   10 , #  Some kind of disk I/O error occurred
    SQLCIPHER_CORRUPT   =>   11 , #  The database disk image is malformed
    SQLCIPHER_NOTFOUND  =>   12 , #  Unknown opcode in sqlite3_file_control()
    SQLCIPHER_FULL      =>   13 , #  Insertion failed because database is full
    SQLCIPHER_CANTOPEN  =>   14 , #  Unable to open the database file
    SQLCIPHER_PROTOCOL  =>   15 , #  Database lock protocol error
    SQLCIPHER_EMPTY     =>   16 , #  Database is empty
    SQLCIPHER_SCHEMA    =>   17 , #  The database schema changed
    SQLCIPHER_TOOBIG    =>   18 , #  String or BLOB exceeds size limit
    SQLCIPHER_CONSTRAINT=>   19 , #  Abort due to constraint violation
    SQLCIPHER_MISMATCH  =>   20 , #  Data type mismatch
    SQLCIPHER_MISUSE    =>   21 , #  Library used incorrectly
    SQLCIPHER_NOLFS     =>   22 , #  Uses OS features not supported on host
    SQLCIPHER_AUTH      =>   23 , #  Authorization denied
    SQLCIPHER_FORMAT    =>   24 , #  Auxiliary database format error
    SQLCIPHER_RANGE     =>   25 , #  2nd parameter to sqlite3_bind out of range
    SQLCIPHER_NOTADB    =>   26 , #  File opened that is not a database file
    SQLCIPHER_ROW       =>   100, #  sqlite3_step() has another row ready
    SQLCIPHER_DONE      =>   101, #  sqlite3_step() has finished executing
);


enum SQLCIPHER_TYPE is export (
    SQLCIPHER_INTEGER => 1,
    SQLCIPHER_FLOAT   => 2,
    SQLCIPHER_TEXT    => 3,
    SQLCIPHER_BLOB    => 4,
    SQLCIPHER_NULL    => 5
);

constant LIB = 'sqlcipher';

constant Null is export = Pointer;
class SQLCipher is export is repr('CPointer') { };
class STMT is export is repr('CPointer') { };
# Can't use the following 'cus produces
#  "Missing serialize REPR function for REPR CPointer"
# at install time.
#constant SQLCIPHER_TRANSIENT = Pointer.new(-1);

sub sqlite3_threadsafe()
    returns int32
    is native(LIB)
    is export
    { ... }

sub sqlite3_errmsg(SQLCipher $handle)
    returns Str
    is native(LIB)
    is export
    { ... }

sub sqlite3_extended_result_codes(SQLCipher $handle, int32)
    returns int32
    is native(LIB)
    is export
    { ... }

sub sqlite3_extended_errcode(SQLCipher $handle)
    returns int32
    is native(LIB)
    is export
    { ... }

sub sqlite3_open(Str $filename, SQLCipher $handle is rw)
    returns int32
    is native(LIB)
    is export
    { ... }

sub sqlite3_close(SQLCipher)
    returns int32
    is native(LIB)
    is export
    { ... }

sub sqlite3_busy_timeout(SQLCipher, int32)
    returns int32
    is native(LIB)
    is export
    { ... }

sub sqlite3_prepare_v2 (
        SQLCipher,
        Str  $statement is encoded('utf8'),
        int32 $statement-length,
        STMT $statement-handle is rw,
        Pointer
    )
    returns int32
    is native(LIB)
    is export
    { ... }

sub sqlite3_prepare (
        SQLCipher,
        Str $statement is encoded('utf8'),
        int32 $statement-length,
        STMT $statement-handle is rw,
        Pointer
    )
    returns int32
    is native(LIB)
    is export
    { ... }

sub sqlite3_step(STMT $statement-handle)
    returns int32
    is native(LIB)
    is export
    { ... }

sub sqlite3_key(SQLCipher, Pointer $key is encoded('utf8'), int32 $keylen)
    returns int32 is native(LIB) is export { ... };
sub sqlite3_key_v2(SQLCipher, Str $zDbName is encoded('utf8'), Pointer $key, int32 $keylen)
    returns int32 is native(LIB) is export { ... };
sub sqlite3_rekey(SQLCipher, Pointer $key is encoded('utf8'), int32 $keylen)
    returns int32 is native(LIB) is export { ... };
sub sqlite3_rekey_v2(SQLCipher, Str $zDbName is encoded('utf8'), Pointer $key, int32 $keylen)
    returns int32 is native(LIB) is export { ... };

sub sqlite3_libversion_number() returns int32 is native(LIB) is export { ... };
sub sqlite3_libversion(--> Str) is export is native(LIB) { * }
sub sqlite3_errstr(int32) returns Str is native(LIB) is export { ... };
sub sqlite3_bind_blob(STMT, int32, Blob, int32, Pointer) returns int32 is native(LIB) is export { ... };
sub sqlite3_bind_double(STMT, int32, num64) returns int32 is native(LIB) is export { ... };
sub sqlite3_bind_int64(STMT, int32, int64) returns int32 is native(LIB) is export { ... };
sub sqlite3_bind_null(STMT, int32) returns int32 is native(LIB) is export { ... };
sub sqlite3_bind_text(STMT, int32, Str is encoded('utf8'), int32, Pointer) returns int32 is native(LIB) is export { ... };

sub sqlite3_changes(SQLCipher) returns int32 is native(LIB) is export { ... };
sub sqlite3_bind_parameter_count(STMT --> int32) is native(LIB) is export { ... };

proto sub sqlite3_bind(STMT, $, $) {*}
multi sub sqlite3_bind(STMT $stmt, Int $n, Blob:D $b)  is export {
    sqlite3_bind_blob($stmt, $n, $b, $b.bytes, Pointer.new(-1))
}
multi sub sqlite3_bind(STMT $stmt, Int $n, Real:D $d) is export {
    sqlite3_bind_double($stmt, $n, $d.Num)
}
multi sub sqlite3_bind(STMT $stmt, Int $n, Int:D $i)  is export {
    sqlite3_bind_int64($stmt, $n, $i)
}
multi sub sqlite3_bind(STMT $stmt, Int $n, Any:U)     is export {
    sqlite3_bind_null($stmt, $n)
}
multi sub sqlite3_bind(STMT $stmt, Int $n, Str:D $d)  is export {
    sqlite3_bind_text($stmt, $n, $d, -1, Pointer.new(-1))
}

sub sqlite3_reset(STMT) returns int32 is native(LIB) is export  { ... }
sub sqlite3_clear_bindings(STMT) returns int32 is native(LIB) is export { ... }

sub sqlite3_column_text(STMT, int32) returns Str is native(LIB) is export  { ... }
sub sqlite3_column_double(STMT, int32) returns num64 is native(LIB) is export { ... }
sub sqlite3_column_int64(STMT, int32) returns int64 is native(LIB) is export { ... }
sub sqlite3_column_blob(STMT, int32) returns Pointer is native(LIB) is export { ... }
sub sqlite3_column_bytes(STMT, int32) returns int32 is native(LIB) is export { ... }

sub sqlite3_finalize(STMT) returns int32 is native(LIB) is export { ... }
sub sqlite3_column_count(STMT) returns int32 is native(LIB) is export { ... }
sub sqlite3_column_name(STMT, int32) returns Str is native(LIB) is export { ... }
sub sqlite3_column_type(STMT, int32) returns int32 is native(LIB) is export { ... }

