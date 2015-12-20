
use v6;
use NativeCall;

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

constant LIB = %*ENV<DBIISH_SQLITE_LIB> || ('libsqlite3' , 0);

sub sqlite3_errmsg(OpaquePointer $handle)
    returns Str
    is native(LIB)
    is export
    { ... }

sub sqlite3_open(Str $filename, CArray[OpaquePointer] $handle)
    returns int32
    is native(LIB)
    is export
    { ... }

sub sqlite3_close(OpaquePointer)
    returns int32
    is native(LIB)
    is export
    { ... }


sub sqlite3_prepare_v2 (
        OpaquePointer $handle,
        Str           $statement,
        int32           $statement_length,
        CArray[OpaquePointer] $statement_handle,
        CArray[OpaquePointer] $pz_tail
    )
    returns int32
    is native(LIB)
    is export
    { ... }

sub sqlite3_prepare (
        OpaquePointer $handle,
        Str           $statement,
        int32           $statement_length,
        CArray[OpaquePointer] $statement_handle,
        CArray[OpaquePointer] $pz_tail
    )
    returns int32
    is native(LIB)
    is export
    { ... }
    
sub sqlite3_step(OpaquePointer $statement_handle)
    returns int32
    is native(LIB)
    is export
    { ... }
  

sub sqlite3_libversion_number() returns int32 is native(LIB) is export { ... };
sub sqlite3_bind_blob(OpaquePointer $stmt, int32, OpaquePointer, int32, OpaquePointer) returns int32 is native(LIB) is export { ... };
sub sqlite3_bind_double(OpaquePointer $stmt, int32, num64) returns int32 is native(LIB) is export { ... };
sub sqlite3_bind_int64(OpaquePointer $stmt, int32, int64) returns int32 is native(LIB) is export { ... };
sub sqlite3_bind_null(OpaquePointer $stmt, int32) returns int32 is native(LIB) is export { ... };
sub sqlite3_bind_text(OpaquePointer $stmt, int32, Str, int32, OpaquePointer) returns int32 is native(LIB) is export { ... };

sub sqlite3_changes(OpaquePointer $handle) returns int32 is native(LIB) is export { ... };

proto sub sqlite3_bind($, $, $) {*}
multi sub sqlite3_bind($stmt, Int $n, Buf:D $b)  is export { sqlite3_bind_blob($stmt, $n, $b, $b.bytes, OpaquePointer) }
multi sub sqlite3_bind($stmt, Int $n, Real:D $d) is export { sqlite3_bind_double($stmt, $n, $d.Num) }
multi sub sqlite3_bind($stmt, Int $n, Int:D $i)  is export { sqlite3_bind_int64($stmt, $n, $i) }
multi sub sqlite3_bind($stmt, Int $n, Any:U)     is export { sqlite3_bind_null($stmt, $n) }
multi sub sqlite3_bind($stmt, Int $n, Str:D $d)  is export { sqlite3_bind_text($stmt, $n, $d, -1,  OpaquePointer) }

sub sqlite3_reset(OpaquePointer) returns int32 is native(LIB) is export  { ... }

sub sqlite3_column_text(OpaquePointer, int32) returns Str is native(LIB) is export  { ... }
sub sqlite3_column_double(OpaquePointer, int32) returns num64 is native(LIB) is export { ... }
sub sqlite3_column_int64(OpaquePointer, int32) returns int64 is native(LIB) is export { ... }

sub sqlite3_finalize(OpaquePointer) returns int32 is native(LIB) is export { ... }
sub sqlite3_column_count(OpaquePointer) returns int32 is native(LIB) is export { ... }
sub sqlite3_column_name(OpaquePointer, int32) returns Str is native(LIB) is export { ... }
sub sqlite3_column_type(OpaquePointer, int32) returns int32 is native(LIB) is export { ... }
