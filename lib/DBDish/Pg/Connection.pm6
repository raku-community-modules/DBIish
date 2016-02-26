use v6;

need DBDish;

unit class DBDish::Pg::Connection does DBDish::Role::Connection;
use DBDish::Pg::Native;
need DBDish::Pg::StatementHandle;

has PGconn $!pg_conn;
has $.AutoCommit is rw = 1;
has $.in_transaction is rw;

submethod BUILD(:$!pg_conn, :$!AutoCommit, :$!in_transaction) { }

method prepare(Str $statement, $attr?) {
    state $statement_postfix = 0;
    my $statement_name = join '_', 'pg', $*PID, $statement_postfix++;
    my $munged = DBDish::Pg::pg-replace-placeholder($statement);
    my $result = $!pg_conn.PQprepare($statement_name, $munged, 0, OidArray);
    unless $result.is-ok {
        self!set_errstr($result.PQresultErrorMessage);
        die self.errstr if $.RaiseError;
        return Nil;
    }
    my $info = $!pg_conn.PQdescribePrepared($statement_name);
    my $param_count = $info.PQnparams;

    my $statement_handle = DBDish::Pg::StatementHandle.new(
        :dbh(self),
        :$!pg_conn,
        :$statement,
        :$.RaiseError,
        :$statement_name,
        :$result,
        :$param_count,
    );
    $statement_handle;
}

method do(Str $statement, *@bind is copy) {
    my $sth = self.prepare($statement);
    $sth.execute(@bind);
    my $rows = $sth.rows;
    ($rows == 0) ?? "0E0" !! $rows;
}

method selectrow_arrayref(Str $statement, $attr?, *@bind is copy) {
    my $sth = self.prepare($statement, $attr);
    $sth.execute(@bind);
    $sth.fetchrow_arrayref;
}

method selectrow_hashref(Str $statement, $attr?, *@bind is copy) {
    my $sth = self.prepare($statement, $attr);
    $sth.execute(@bind);
    $sth.fetchrow_hashref;
}

method selectall_arrayref(Str $statement, $attr?, *@bind is copy) {
    my $sth = self.prepare($statement, $attr);
    $sth.execute(@bind);
    $sth.fetchall_arrayref;
}

method selectall_hashref(Str $statement, Str $key, $attr?, *@bind is copy) {
    my $sth = self.prepare($statement, $attr);
    $sth.execute(@bind);
    $sth.fetchall_hashref($key);
}

method selectcol_arrayref(Str $statement, $attr?, *@bind is copy) {
    my @results;

    my $sth = self.prepare($statement, $attr);
    $sth.execute(@bind);
    while (my $row = $sth.fetchrow_arrayref) {
        @results.push($row[0]);
    }

    item @results;
}

method commit {
    if $!AutoCommit {
        warn "Commit ineffective while AutoCommit is on";
        return;
    };
    $!pg_conn.PQexec("COMMIT");
    $.in_transaction = 0;
}

method rollback {
    if $!AutoCommit {
        warn "Rollback ineffective while AutoCommit is on";
        return;
    };
    $!pg_conn.PQexec("ROLLBACK");
    $.in_transaction = 0;
}

method ping {
    $!pg_conn.PQstatus == CONNECTION_OK
}

method disconnect {
    $!pg_conn.PQfinish;
    True;
}
