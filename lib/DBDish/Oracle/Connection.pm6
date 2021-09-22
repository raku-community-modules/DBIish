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
has $.no-alter-session is rw;
has $.no-lc-field-name is rw;
has $.no-datetime-container is rw;
has $.alter-session-iso8601 is rw;

## Cached common handles reused
has $.statement-cached-commit;
has $.statement-cached-rollback;

submethod BUILD(:$!parent!, :$!envh!, :$!svch!, :$!errh!
    , :$!AutoCommit = 1
    , :$!no-alter-session = False
    , :$!no-lc-field-name = False
    , :$!no-datetime-container = False
    , :$!alter-session-iso8601 = False
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
    ## ALTER SESSION
    if ! $!no-alter-session
    {
      ## GOAL; configure session to format all DATE & TIMESTAMPS for ISO-8601
      ## Perhaps it's safer to stay out of the consumers way.
      ## But if we must get in their business lets go all the way!
      if $!alter-session-iso8601
      {
        for
          q|ALTER SESSION SET time_zone               = '-00:00'|,
          q|ALTER SESSION SET nls_date_format         = 'YYYY-MM-DD"T"HH24:MI:SS"Z"'|,
          q|ALTER SESSION SET nls_timestamp_format    = 'YYYY-MM-DD"T"HH24:MI:SS"Z"'|,
          q|ALTER SESSION SET nls_timestamp_tz_format = 'YYYY-MM-DD"T"HH24:MI:SS"Z"'|
           -> $alter-session-stmt
        {
          # $*ERR.say: '# ', $alter-session-stmt;
          self.execute($alter-session-stmt).dispose;
        }
      }
      else
      {
        ## Default format; but only works for "TIMESTAMP WITH TIME ZONE" fields
	##  See: README.pod for details
        self.execute(
           q|ALTER SESSION SET nls_timestamp_tz_format = 'YYYY-MM-DD"T"HH24:MI:SS.FFTZR'|
        ).dispose;
      }
      $!last-sth-id = Nil; # Lie a little.
    }
}

method commit {
    if $!AutoCommit {
        warn "Commit ineffective while AutoCommit is on";
        return;
    };
    $!statement-cached-commit
      ?? $!statement-cached-commit.execute
      !! do { $!statement-cached-commit = self.execute("COMMIT"); };
    $.in_transaction = 0;
}

method rollback {
    if $!AutoCommit {
        warn "Rollback ineffective while AutoCommit is on";
        return;
    };
    $!statement-cached-rollback
      ?? $!statement-cached-rollback.execute
      !! do { $!statement-cached-rollback = self.execute("ROLLBACK"); };
    $.in_transaction = 0;
}

method ping {
    $!svch.Ping($!errh, OCI_DEFAULT) == OCI_SUCCESS;
}

method _disconnect() {
    $!svch.Logoff($!errh);
}
