use NativeCall;
use DBDish;

enum SQLITE (
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

sub sqlite3_errmsg(OpaquePointer $handle)
    returns Str
    is native('libsqlite3')
    { ... }

sub sqlite3_open(Str $filename, CArray[OpaquePointer] $handle)
    returns Int
    is native('libsqlite3')
    { ... }

sub sqlite3_close(OpaquePointer)
    returns Int
    is native('libsqlite3')
    { ... }


sub sqlite3_prepare_v2 (
        OpaquePointer $handle,
        Str           $statement,
        Int           $statement_length,
        CArray[OpaquePointer] $statement_handle,
        CArray[OpaquePointer] $pz_tail
    )
    returns Int
    is native('libsqlite3')
    { ... }

sub sqlite3_step(OpaquePointer $statement_handle)
    returns Int
    is native('libsqlite3')
    { ... }

sub sqlite3_bind_blob(OpaquePointer $stmt, int, OpaquePointer, Int, OpaquePointer) returns Int is native('libsqlite3') { ... };
sub sqlite3_bind_double(OpaquePointer $stmt, Int, Num) returns Int is native('libsqlite3') { ... };
sub sqlite3_bind_int(OpaquePointer $stmt, Int, Int) returns Int is native('libsqlite3') { ... };
sub sqlite3_bind_null(OpaquePointer $stmt, Int) returns Int is native('libsqlite3') { ... };
sub sqlite3_bind_text(OpaquePointer $stmt, Int, Str, Int, OpaquePointer) returns Int is native('libsqlite3') { ... };

sub sqlite3_changes(OpaquePointer $handle) returns Int is native('libsqlite3') { ... };

proto sub sqlite3_bind($, $, $) {*}
multi sub sqlite3_bind($stmt, Int $n, Buf:D $b)  { sqlite3_bind_blob($stmt, $n, $b, $b.bytes, OpaquePointer) }
multi sub sqlite3_bind($stmt, Int $n, Real:D $d) { sqlite3_bind_double($stmt, $n, $d.Num) }
multi sub sqlite3_bind($stmt, Int $n, Int:D $i)  { sqlite3_bind_int($stmt, $n, $i) }
multi sub sqlite3_bind($stmt, Int $n, Any:U)     { sqlite3_bind_null($stmt, $n) }
multi sub sqlite3_bind($stmt, Int $n, Str:D $d)  { sqlite3_bind_text($stmt, $n, $d, -1,  OpaquePointer) }

sub sqlite3_reset(OpaquePointer) returns Int is native('libsqlite3') { ... }
sub sqlite3_column_text(OpaquePointer, Int) returns Str is native('libsqlite3') { ... }
sub sqlite3_finalize(OpaquePointer) returns Int is native('libsqlite3') { ... }
sub sqlite3_column_count(OpaquePointer) returns Int is native('libsqlite3') { ... }
sub sqlite3_column_name(OpaquePointer, Int) returns Str is native('libsqlite3') { ... }


class DBDish::SQLite::StatementHandle does DBDish::StatementHandle {
    has $!conn;
    has $.statement;
    has $!statement_handle;
    has $.dbh;
    has Int $!row_status;
    has @!mem_rows;
    has @!column_names;

    method !handle-error($status) {
        return if $status == SQLITE_OK;
        self!set_errstr(join ' ', SQLITE($status), sqlite3_errmsg($!conn));
    }

    submethod BUILD(:$!conn, :$!statement, :$!statement_handle, :$!dbh) { }

    method execute(*@params) {
        sqlite3_reset($!statement_handle) if $!statement_handle.defined;
        @!mem_rows = ();
        my @strings;
        for @params.kv -> $idx, $v {
            if $v ~~ Str {
                explicitly-manage($v);
                @!mem_rows.push: $v;
            }
            self!handle-error(sqlite3_bind($!statement_handle, $idx + 1, $v));
            push @strings, $v;
        }
        $!row_status = sqlite3_step($!statement_handle);
        if $!row_status != SQLITE_ROW and $!row_status != SQLITE_DONE {
            self!handle-error($!row_status);
        }
        self.rows;
    }

    method rows() {
        die 'Cannot determine rows of closed connection' unless $!conn.DEFINITE;
        my $rows = sqlite3_changes($!conn);
        $rows == 0 ?? '0E0' !! $rows;
    }

    method column_names {
        unless @!column_names {
                my Int $count = sqlite3_column_count($!statement_handle);
                @!column_names.push: sqlite3_column_name($!statement_handle, $_)
                    for ^$count;
        }
        @!column_names;
    }

    method fetchrow {
        my @row;
        die 'fetchrow_array without prior execute' unless $!row_status.defined;
        return @row if $!row_status == SQLITE_DONE;
        my Int $count = sqlite3_column_count($!statement_handle);
        for ^$count {
            @row.push: sqlite3_column_text($!statement_handle, $_);
        }
        $!row_status = sqlite3_step($!statement_handle);

        @row || Nil;
    }

    method finish() {
        sqlite3_finalize($!statement_handle) if $!statement_handle.defined;
        $!row_status = Int;;
        $!dbh._remove_sth(self);
        True;
    }
}

class DBDish::SQLite::Connection does DBDish::Connection {
    has $!conn;
    has @!sths;
    method BUILD(:$!conn) { }
    method !handle-error($status) {
        return if $status == SQLITE_OK;
        self!set_errstr(join ' ', SQLITE($status), sqlite3_errmsg($!conn));
    }
    method prepare(Str $statement, $attr?) {
        my @stmt := CArray[OpaquePointer].new;
        @stmt[0]  = OpaquePointer;
        my $status = sqlite3_prepare_v2(
                $!conn,
                $statement,
                -1,
                @stmt,
                CArray[OpaquePointer]
        );
        my $statement_handle = @stmt[0];
        self!handle-error($status);
        return Nil unless $status == SQLITE_OK;
        my $sth = DBDish::SQLite::StatementHandle.bless(
            :$!conn,
            :$statement,
            :$statement_handle,
            :$.RaiseError,
            :dbh(self),
        );
        @!sths.push: $sth;
        $sth;
    }

    method _remove_sth($sth) {
        @!sths.=grep(* !=== $sth);
    }

    method rows() {
        die 'Cannot determine rows of closed connection' unless $!conn.DEFINITE;
        my $rows = sqlite3_changes($!conn);
        $rows == 0 ?? '0E0' !! $rows;
    }

    method do(Str $sql, *@args) {
        my $sth = self.prepare($sql);
        $sth.execute(@args);
        my $res = $sth.rows || '0e0';
        $sth.finish;
        return $sth;
    }
    method disconnect() {
        .finish for @!sths;
        self!handle-error(sqlite3_close($!conn));
        return not self.errstr;
    }
}

class DBDish::SQLite:auth<mberends>:ver<0.0.1> {
    has $.Version = 0.01;
    has $.errstr;
    method !errstr() is rw { $!errstr }
    method connect(:$RaiseError, *%params) {
        my $dbname = %params<dbname> // %params<database>;
        die 'No "dbname" or "database" given' unless defined $dbname;

        my @conn := CArray[OpaquePointer].new;
        @conn[0]  = OpaquePointer;
        my $status = sqlite3_open($dbname, @conn);
        if $status == SQLITE_OK {
            return DBDish::SQLite::Connection.bless(
                    :conn(@conn[0]),
                    :$RaiseError,
            );
        }
        else {
            $!errstr = SQLITE($status);
            die $!errstr if $RaiseError;
        }
    }
}



# vim: ft=perl6
