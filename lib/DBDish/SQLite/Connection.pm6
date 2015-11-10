
use v6;

unit class DBDish::SQLite::Connection does DBDish::Role::Connection;

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
