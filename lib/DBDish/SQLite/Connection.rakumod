use v6;

need DBDish;

unit class DBDish::SQLite::Connection does DBDish::Connection;
need DBDish::SQLite::StatementHandle;
use DBDish::SQLite::Native;

has SQLite $!conn;

submethod BUILD(:$!conn!, :$!parent!) { }

method !handle-error(Int $status) {
    if $status == SQLITE_OK {
        self.reset-err;
    } else {
        self!set-err($status, sqlite3_errmsg($!conn));
    }
}

method prepare(Str $statement, *%args) {
    my STMT $statement-handle .= new;
    my $status = (sqlite3_libversion_number() >= 3003009)
            ?? sqlite3_prepare_v2($!conn, $statement, -1, $statement-handle, Null)
            !! sqlite3_prepare($!conn, $statement, -1, $statement-handle, Null);
    with self!handle-error($status) {
        DBDish::SQLite::StatementHandle.new(
            :$!conn,
            :parent(self),
            :$statement-handle,
            :$statement,
            :$.RaiseError,
            |%args
        );
    }
    else {
        .fail;
    }
}

method ping() {
    $!conn.defined;
}

method _disconnect() {
    LEAVE { $!conn = Nil }
    if $!conn and (my $status = sqlite3_close($!conn)) != SQLITE_OK {
        self!set-err($status, sqlite3_errstr($status)).fail;
    }
}
