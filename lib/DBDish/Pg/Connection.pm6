use v6;

need DBDish::Role::Connection;

unit class DBDish::Pg::Connection does DBDish::Role::Connection;
use DBDish::Pg::Native;
import NativeCall;
need DBDish::Pg::StatementHandle;

has $!pg_conn;
has $.AutoCommit is rw = 1;
has $.in_transaction is rw;

submethod BUILD(:$!pg_conn, :$!AutoCommit, :$!in_transaction) { }

method prepare(Str $statement, $attr?) {
    state $statement_postfix = 0;
    my $statement_name = join '_', 'pg', $*PID, $statement_postfix++;
    my $munged = DBDish::Pg::pg-replace-placeholder($statement);
    my $result = PQprepare(
            $!pg_conn,
            $statement_name,
            $munged,
            0,
            OpaquePointer
    );
    my $status = PQresultStatus($result);
    unless status-is-ok($status) {
        self!set_errstr(PQresultErrorMessage($result));
        die self.errstr if $.RaiseError;
        return Nil;
    }
    my $info = PQdescribePrepared($!pg_conn, $statement_name);
    my $param_count = PQnparams($info);

    my $statement_handle = DBDish::Pg::StatementHandle.bless(
        :$!pg_conn,
        :$statement,
        :$.RaiseError,
        :dbh(self),
        :$statement_name,
        :$result,
        :$param_count,
    );
    return $statement_handle;
}

method do(Str $statement, *@bind is copy) {
    my $sth = self.prepare($statement);
    $sth.execute(@bind);
    my $rows = $sth.rows;
    return ($rows == 0) ?? "0E0" !! $rows;
}

method selectrow_arrayref(Str $statement, $attr?, *@bind is copy) {
    my $sth = self.prepare($statement, $attr);
    $sth.execute(@bind);
    return $sth.fetchrow_arrayref;
}

method selectrow_hashref(Str $statement, $attr?, *@bind is copy) {
    my $sth = self.prepare($statement, $attr);
    $sth.execute(@bind);
    return $sth.fetchrow_hashref;
}

method selectall_arrayref(Str $statement, $attr?, *@bind is copy) {
    my $sth = self.prepare($statement, $attr);
    $sth.execute(@bind);
    return $sth.fetchall_arrayref;
}

method selectall_hashref(Str $statement, Str $key, $attr?, *@bind is copy) {
    my $sth = self.prepare($statement, $attr);
    $sth.execute(@bind);
    return $sth.fetchall_hashref($key);
}

method selectcol_arrayref(Str $statement, $attr?, *@bind is copy) {
    my @results;

    my $sth = self.prepare($statement, $attr);
    $sth.execute(@bind);
    while (my $row = $sth.fetchrow_arrayref) {
        @results.push($row[0]);
    }

    my $aref = @results;
    return $aref;
}

method commit {
    if $!AutoCommit {
        warn "Commit ineffective while AutoCommit is on";
        return;
    };
    PQexec($!pg_conn, "COMMIT");
    $.in_transaction = 0;
}

method rollback {
    if $!AutoCommit {
        warn "Rollback ineffective while AutoCommit is on";
        return;
    };
    PQexec($!pg_conn, "ROLLBACK");
    $.in_transaction = 0;
}

method ping {
    PQstatus($!pg_conn) == CONNECTION_OK
}

method disconnect() {
    PQfinish($!pg_conn);
    True;
}
