use v6;
need DBDish;

unit class DBDish::Oracle::Connection does DBDish::Connection;
use DBDish::Oracle::Native;
need DBDish::Oracle::StatementHandle;

has OCIEnv    $!envh;
has OCISvcCtx $!svch;
has OCIError  $!errh;
has $.AutoCommit is rw;
has $.in_transaction is rw;
has $.lc-field-names is rw;
has $.no-alter-session is rw;
has $.no-datetime-container is rw;

submethod BUILD(:$!parent!, :$!envh!, :$!svch!, :$!errh!
    , :$!AutoCommit = 1
    , :$!lc-field-names = False
    , :$!no-alter-session = False
    , :$!no-datetime-container = False
  ) { }

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

method set-defaults {
    ## Some are not compatible with DateTime if the field is a timestamp(0) ...
    ## Most will also produce bad dates using DateTime if the clients can/will be using a
    ##  a TZ not in the set [GMT,UCT,[+-]00:00]
    ## Perhaps it's safer to stay out of the consumers way.
    ## But if we must get in their business lets go all the way!
    if ! $!no-alter-session
    {
      for
        q|ALTER SESSION SET time_zone               = '-00:00'|,
        q|ALTER SESSION SET nls_date_format         = 'YYYY-MM-DD"T"HH24:MI:SS"Z"'|,
        q|ALTER SESSION SET nls_timestamp_format    = 'YYYY-MM-DD"T"HH24:MI:SS.FF"Z"'|,
        q|ALTER SESSION SET nls_timestamp_tz_format = 'YYYY-MM-DD"T"HH24:MI:SS.FF"Z"'|
        -> $alter-session-stmt
      {
      # $*ERR.say: '# ', $alter-session-stmt;
        self.execute($alter-session-stmt);
      }
      $!last-sth-id = Nil; # Lie a little.
    }
}

method commit {
    if $!AutoCommit {
        warn "Commit ineffective while AutoCommit is on";
        return;
    };
    self.execute("COMMIT");
    $.in_transaction = 0;
}

method rollback {
    if $!AutoCommit {
        warn "Rollback ineffective while AutoCommit is on";
        return;
    };
    self.execute("ROLLBACK");
    $.in_transaction = 0;
}

method ping {
    $!svch.Ping($!errh, OCI_DEFAULT) == OCI_SUCCESS;
}

method _disconnect() {
    $!svch.Logoff($!errh);
}
