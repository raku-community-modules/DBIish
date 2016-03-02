use v6;

need DBDish;

unit class DBDish::SQLite::Connection does DBDish::Connection;
need DBDish::SQLite::StatementHandle;
use DBDish::SQLite::Native;

has SQLite $!conn is required;
has @!sths;

submethod BUILD(:$!conn, :$!parent!) { }

method !handle-error(Int $status) {
    if $status == SQLITE_OK {
	self!reset-err;
    } else {
	self!set-err(SQLITE($status), sqlite3_errmsg($!conn));
    }
}

method prepare(Str $statement, $attr?) {
    my STMT $stmt .= new;
    my $status = (sqlite3_libversion_number() >= 3003009)
        ?? sqlite3_prepare_v2($!conn, $statement, -1, $stmt, Null)
        !! sqlite3_prepare($!conn, $statement, -1, $stmt, Null);
    self!handle-error($status);
    my $sth = DBDish::SQLite::StatementHandle.new(
        :$!conn,
        :parent(self),
        :$statement,
        :statement_handle($stmt),
        :$.RaiseError,
    );
    @!sths.push: $sth;
    $sth;
}

method _remove_sth($sth) {
    @!sths .= grep(* !=== $sth);
}

method rows() {
    die 'Cannot determine rows of closed connection' unless $!conn.DEFINITE;
    my $rows = sqlite3_changes($!conn);
    $rows == 0 ?? '0E0' !! $rows;
}

method disconnect() {
    .free for @!sths;
    self!handle-error(sqlite3_close($!conn));
}
