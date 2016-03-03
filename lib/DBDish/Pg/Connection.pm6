use v6;
need DBDish;

unit class DBDish::Pg::Connection does DBDish::Connection;
use DBDish::Pg::Native;
need DBDish::Pg::StatementHandle;

has PGconn $!pg_conn is required;
has $.AutoCommit is rw = True;
has $.in_transaction is rw = False;

submethod BUILD(:$!pg_conn, :$!parent!, :$!AutoCommit) { }

method prepare(Str $statement, $attr?) {
    state $statement_postfix = 0;
    my $statement_name = join '_', 'pg', $*PID, $statement_postfix++;
    my $munged = DBDish::Pg::pg-replace-placeholder($statement);
    my $result = $!pg_conn.PQprepare($statement_name, $munged, 0, OidArray);
    if $result.is-ok {
	self.reset-err;
	my $info = $!pg_conn.PQdescribePrepared($statement_name);
	my $param_count = $info.PQnparams;

	my $statement_handle = DBDish::Pg::StatementHandle.new(
	    :$!pg_conn,
	    :parent(self),
	    :$statement,
	    :$.RaiseError,
	    :$statement_name,
	    :$result,
	    :$param_count,
	);
	$statement_handle;
    } else {
        self!set-err($result, $result.PQresultErrorMessage);
    };
}

method selectrow_arrayref(Str $statement, $attr?, *@bind is copy) {
    with self.prepare($statement, $attr) {
	.execute(@bind) and .fetchrow_arrayref;
    } else {
	.fail;
    }
}

method selectrow_hashref(Str $statement, $attr?, *@bind is copy) {
    with self.prepare($statement, $attr) {
	.execute(@bind) and .fetchrow_hashref;
    } else {
	.fail;
    }
}

method selectall_arrayref(Str $statement, $attr?, *@bind is copy) {
    with self.prepare($statement, $attr) {
	.execute(@bind) and .fetchall_arrayref;
    } else {
	.fail;
    }
}

method selectall_hashref(Str $statement, Str $key, $attr?, *@bind is copy) {
    with self.prepare($statement, $attr) {
	.execute(@bind) and .fetchall_hashref($key);
    } else {
	.fail;
    }
}

method selectcol_arrayref(Str $statement, $attr?, *@bind is copy) {
    with self.prepare($statement, $attr) {
	.execute(@bind) and do {
	    my @results;
	    while (my $row = .fetchrow_arrayref) {
		@results.push($row[0]);
	    }
	    item @results;
	}
    } else {
	.fail;
    }
}

method commit {
    if $!AutoCommit {
        warn "Commit ineffective while AutoCommit is on";
        return;
    };
    $!pg_conn.PQexec("COMMIT");
    $.in_transaction = False;
}

method rollback {
    if $!AutoCommit {
        warn "Rollback ineffective while AutoCommit is on";
        return;
    };
    $!pg_conn.PQexec("ROLLBACK");
    $.in_transaction = False;
}

method ping {
    $!pg_conn.PQstatus == CONNECTION_OK
}

method disconnect {
    $!pg_conn.PQfinish;
    True;
}
