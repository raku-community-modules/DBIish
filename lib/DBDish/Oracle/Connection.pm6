use v6;
need DBDish;

unit class DBDish::Oracle::Connection does DBDish::Connection;
use DBDish::Oracle::Native;
need DBDish::Oracle::StatementHandle;

has OCIEnv    $!envh is required;
has OCISvcCtx $!svch is required;
has OCIError  $!errh is required;
has $.AutoCommit is rw;
has $.in_transaction is rw;
submethod BUILD(:$!parent!, :$!envh, :$!svch, :$!errh, :$!AutoCommit = 1) { }

method !handle-err($res) {
    $res ~~ OCIErr ?? self!set-err(+$res, ~$res) !! $res;
}

method prepare(Str $statement, :$RaiseError = $!RaiseError, *%attr) {
    my $oracle_statement = DBDish::Oracle::oracle-replace-placeholder($statement);

    with self!handle-err: $!svch.StmtPrepare($oracle_statement, :$!errh) -> $stmth {
	DBDish::Oracle::StatementHandle.new(
	    :$!svch,
	    :$!errh,
	    :$stmth,
	    :statement($oracle_statement), # Use the oracle ready statement
	    :$RaiseError,
	    :parent(self),
	    |%attr
	);
    } else { .fail }
}

method commit {
    if $!AutoCommit {
        warn "Commit ineffective while AutoCommit is on";
        return;
    };
    self.do("COMMIT");
    $.in_transaction = 0;
}

method rollback {
    if $!AutoCommit {
        warn "Rollback ineffective while AutoCommit is on";
        return;
    };
    self.do("ROLLBACK");
    $.in_transaction = 0;
}

method ping {
    $!svch.Ping($!errh, OCI_DEFAULT) == OCI_SUCCESS;
}

method _disconnect() {
    $!svch.Logoff($!errh);
}
