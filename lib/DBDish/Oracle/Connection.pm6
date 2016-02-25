use v6;

use NativeCall;

need DBDish::Role::Connection;
need DBDish::Oracle::StatementHandle;
use DBDish::Oracle::Native;

unit class DBDish::Oracle::Connection does DBDish::Role::Connection;

has $!envhp;
has $!svchp;
has $!errhp;
has $.AutoCommit is rw;
has $.in_transaction is rw;
submethod BUILD(:$!envhp!, :$!svchp!, :$!errhp!, :$!AutoCommit = 1) { }

method prepare(Str $statement, $attr?) {
    my $oracle_statement = DBDish::Oracle::oracle-replace-placeholder($statement);

    # allocate a statement handle
    my @stmthpp := CArray[OCIStmt].new;
    @stmthpp[0]  = OCIStmt;
    my $errcode = OCIHandleAlloc($!envhp, @stmthpp, OCI_HTYPE_STMT, 0, Pointer );
    if $errcode ne OCI_SUCCESS {
        die "statement handle allocation failed: '$errcode'";
    }

    $errcode = OCIStmtPrepare2(
            $!svchp,
            @stmthpp,
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
    my $stmthp = @stmthpp[0];

    my ub2 $statementtype;
    $errcode = OCIAttrGet_ub2($stmthp, OCI_HTYPE_STMT, $statementtype, Pointer, OCI_ATTR_STMT_TYPE, $!errhp);
    if $errcode ne OCI_SUCCESS {
        my $errortext = get_errortext($!errhp);
        die "statement type get failed ($errcode): '$errortext'";
    }

    my $statement_handle = DBDish::Oracle::StatementHandle.bless(
        # TODO: pass the original or the Oracle statment here?
        statement => $oracle_statement,
        #:$statement,
        :$statementtype,
        :$!svchp,
        :$!errhp,
        :$stmthp,
        #:$.RaiseError,
        :dbh(self),
    );
    return $statement_handle;
}

method do(Str $statement, *@bind is copy) {
    my $sth = self.prepare($statement);
    return $sth.execute(@bind);
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

method disconnect() {
    OCILogoff($!svchp, $!errhp);
    True;
}
