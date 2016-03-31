use v6;
need DBDish;

use NativeCall;

need DBDish::Oracle::StatementHandle;
use DBDish::Oracle::Native;

unit class DBDish::Oracle::Connection does DBDish::Connection;

has $!envhp;
has $!svchp;
has $!errhp;
has $.AutoCommit is rw;
has $.in_transaction is rw;
submethod BUILD(:$!envhp!, :$!svchp!, :$!errhp!, :$!AutoCommit = 1, :$!parent!) { }

method prepare(Str $statement, $attr?) {
    my $oracle_statement = DBDish::Oracle::oracle-replace-placeholder($statement);

    my $errcode = OCIHandleAlloc($!envhp, my $stmthp = OCIStmt.new, OCI_HTYPE_STMT, 0, Pointer );
    if $errcode ne OCI_SUCCESS {
        die "statement handle allocation failed: '$errcode'";
    }

    $errcode = OCIStmtPrepare2(
            $!svchp,
            $stmthp,
            $!errhp,
            $oracle_statement,
            $oracle_statement.encode('utf8').bytes,
            OraText,
            0,
            OCI_NTV_SYNTAX,
            OCI_DEFAULT,
        );
    if $errcode ne OCI_SUCCESS {
        my $errortext = get_errortext($!errhp);
        die "prepare failed ($errcode): '$errortext'";
#            die self.errstr if $.RaiseError;
#            return Nil;
    }
    #my $stmthp = @stmthpp[0];

    my ub2 $statementtype;
    $errcode = OCIAttrGet_ub2($stmthp, OCI_HTYPE_STMT, $statementtype, Pointer, OCI_ATTR_STMT_TYPE, $!errhp);
    if $errcode ne OCI_SUCCESS {
        my $errortext = get_errortext($!errhp);
        die "statement type get failed ($errcode): '$errortext'";
    }

    DBDish::Oracle::StatementHandle.new(
        # TODO: pass the original or the Oracle statment here?
        statement => $oracle_statement,
        #:$statement,
        :$statementtype,
        :$!svchp,
        :$!errhp,
        :$stmthp,
        #:$.RaiseError,
        :parent(self),
    );
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

#    method ping {
#        PQstatus($!pg_conn) == CONNECTION_OK
#    }

method _disconnect() {
    OCILogoff($!svchp, $!errhp);
}
