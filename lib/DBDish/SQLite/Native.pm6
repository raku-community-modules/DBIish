use v6;

use NativeCall :ALL;

unit module DBDish::SQLite::Native;

enum SQLITE is export (
    SQLITE_OK        =>    0 , #  Successful result
    SQLITE_ERROR     =>    1 , #  SQL error or missing database
    SQLITE_INTERNAL  =>    2 , #  Internal logic error in SQLite
    SQLITE_PERM      =>    3 , #  Access permission denied
    SQLITE_ABORT     =>    4 , #  Callback routine requested an abort
    SQLITE_BUSY      =>    5 , #  The database file is locked
    SQLITE_LOCKED    =>    6 , #  A table in the database is locked
    SQLITE_NOMEM     =>    7 , #  A malloc() failed
    SQLITE_READONLY  =>    8 , #  Attempt to write a readonly database
    SQLITE_INTERRUPT =>    9 , #  Operation terminated by sqlite3_interrupt()
    SQLITE_IOERR     =>   10 , #  Some kind of disk I/O error occurred
    SQLITE_CORRUPT   =>   11 , #  The database disk image is malformed
    SQLITE_NOTFOUND  =>   12 , #  Unknown opcode in sqlite3_file_control()
    SQLITE_FULL      =>   13 , #  Insertion failed because database is full
    SQLITE_CANTOPEN  =>   14 , #  Unable to open the database file
    SQLITE_PROTOCOL  =>   15 , #  Database lock protocol error
    SQLITE_EMPTY     =>   16 , #  Database is empty
    SQLITE_SCHEMA    =>   17 , #  The database schema changed
    SQLITE_TOOBIG    =>   18 , #  String or BLOB exceeds size limit
    SQLITE_CONSTRAINT=>   19 , #  Abort due to constraint violation
    SQLITE_MISMATCH  =>   20 , #  Data type mismatch
    SQLITE_MISUSE    =>   21 , #  Library used incorrectly
    SQLITE_NOLFS     =>   22 , #  Uses OS features not supported on host
    SQLITE_AUTH      =>   23 , #  Authorization denied
    SQLITE_FORMAT    =>   24 , #  Auxiliary database format error
    SQLITE_RANGE     =>   25 , #  2nd parameter to sqlite3_bind out of range
    SQLITE_NOTADB    =>   26 , #  File opened that is not a database file
    SQLITE_ROW       =>   100, #  sqlite3_step() has another row ready
    SQLITE_DONE      =>   101, #  sqlite3_step() has finished executing
);


enum SQLITE_TYPE is export (
    SQLITE_INTEGER => 1,
    SQLITE_FLOAT   => 2,
    SQLITE_TEXT    => 3,
    SQLITE_BLOB    => 4,
    SQLITE_NULL    => 5
);

sub MyLibName {
    %*ENV<DBIISH_SQLITE_LIB> || guess_library_name(('sqlite3', v0));
}
constant LIB = &MyLibName;

constant Null is export = Pointer;
class SQLite is export is repr('CPointer') { };
class STMT is export is repr('CPointer') { };
# Can't use the following 'cus produces
#  "Missing serialize REPR function for REPR CPointer"
# at install time.
#constant SQLITE_TRANSIENT = Pointer.new(-1);

sub sqlite3_errmsg(SQLite $handle)
    returns Str
    is native(LIB)
    is export
    { ... }

sub sqlite3_open(Str $filename, SQLite $handle is rw)
    returns int32
    is native(LIB)
    is export
    { ... }

sub sqlite3_close(SQLite)
    returns int32
    is native(LIB)
    is export
    { ... }


sub sqlite3_prepare_v2 (
        SQLite,
        Str  $statement is encoded('utf8'),
        int32 $statement_length,
        STMT $statement_handle is rw,
        Pointer
    )
    returns int32
    is native(LIB)
    is export
    { ... }

sub sqlite3_prepare (
        SQLite,
        Str $statement is encoded('utf8'),
        int32 $statement_length,
        STMT $statement_handle is rw,
        Pointer
    )
    returns int32
    is native(LIB)
    is export
    { ... }

sub sqlite3_step(STMT $statement_handle)
    returns int32
    is native(LIB)
    is export
    { ... }


sub sqlite3_libversion_number() returns int32 is native(LIB) is export { ... };
sub sqlite3_errstr(int32) returns Str is native(LIB) is export { ... };
sub sqlite3_bind_blob(STMT, int32, Blob, int32, Pointer) returns int32 is native(LIB) is export { ... };
sub sqlite3_bind_double(STMT, int32, num64) returns int32 is native(LIB) is export { ... };
sub sqlite3_bind_int64(STMT, int32, int64) returns int32 is native(LIB) is export { ... };
sub sqlite3_bind_null(STMT, int32) returns int32 is native(LIB) is export { ... };
sub sqlite3_bind_text(STMT, int32, Str is encoded('utf8'), int32, Pointer) returns int32 is native(LIB) is export { ... };

sub sqlite3_changes(SQLite) returns int32 is native(LIB) is export { ... };
sub sqlite3_bind_parameter_count(STMT --> int32) is native(LIB) is export { ... };

proto sub sqlite3_bind(STMT, $, $) {*}
multi sub sqlite3_bind(STMT $stmt, Int $n, Buf:D $b)  is export {
    sqlite3_bind_blob($stmt, $n, $b, $b.bytes, Pointer)
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
