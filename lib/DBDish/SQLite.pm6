use DBDish;

need DBDish::SQLite::Connection;
need DBDish::SQLite::StatementHandle;
use DBDish::SQLite::Native;
use NativeCall;

unit class DBDish::SQLite:auth<mberends>:ver<0.0.1>;

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

# vim: ft=perl6
