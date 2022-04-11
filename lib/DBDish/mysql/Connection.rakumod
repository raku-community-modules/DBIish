use v6;

need DBDish;

unit class DBDish::mysql::Connection does DBDish::Connection;
use DBDish::mysql::Native;
need DBDish::mysql::StatementHandle;

has MYSQL $!mysql-client;
has %.Converter is DBDish::TypeConverter;
has %.dynamic-types = %mysql-type-conv;

submethod BUILD(:$!mysql-client!, :$!parent!) {
    %!Converter =
            method (--> DateTime) {
                # Mysql don't report offset, and perl assume Z, so…
                DateTime.new(self.split(' ').join('T')):timezone($*TZ);
            };
}

method !handle-errors($code) {
    if $code {
        self!error-dispatch: X::DBDish::DBError::mysql.new(
                :code($!mysql-client.mysql_errno),
                :native-message($!mysql-client.mysql_error),
                :driver-name<DBDish::mysql>,
                statement-handle => self,

                :sqlstate($!mysql-client.mysql_sqlstate),
                );
    } else {
        self.reset-err;
    }
}
method prepare(Str $statement, *%args) {
    self.protect-connection: {
        with $!mysql-client.mysql_stmt_init -> $stmt {
            with self!handle-errors(
                    $stmt.mysql_stmt_prepare($statement, $statement.encode.bytes)
                    ) {
                DBDish::mysql::StatementHandle.new(
                        :$!mysql-client, :parent(self), :$stmt
                        :$statement, :$!RaiseError, |%args
                        );
            } else { .fail }
        } else {
            self!set-err(-1, "Can't allocate memory");
        }
    }
}

# Override DBIish::Connection.execute as statements such as LOCK TABLE cannot
# be prepared in MySQL.
method execute(Str $statement, **@params, *%args) {
    try {
        # Copied from the DBIish::Connection.execute
        return self.prepare($statement, |%args).execute(|@params);

        # A small number of statements cannot be executed using prepare/execute. Handle these
        # by calling the older protocol. We try very hard to use the newer protocol first as
        # it has several bug and minor behaviour fixes such as the handling of NULLs.
        #
        # Code 1295 means ER_UNSUPPORTED_PS:
        #   This command is not supported in the prepared statement protocol yet
        CATCH {
            when X::DBDish::DBError::mysql {
                when $_.code == 1295 and $_.sqlstate eq 'HY000' {
                    return DBDish::mysql::StatementHandle.new(
                            :$!mysql-client, :parent(self), :$statement, :$!RaiseError, |%args).execute;
                }
                default {
                    .rethrow;
                }
            }
        }
    }
}

method insert-id() {
    with $!last-sth-id andthen $!statements-lock.protect({ %!statements{$_} }) {
        .insert-id;
    }
}

method mysql_insertid is DEPRECATED('insert-id') {
    self.insert-id;
}

method server-version() {
    Version.new($!mysql-client.mysql_get_server_info);
}

method ping() {
    with $!mysql-client {
        # Protection appears to be required due to a reconnect race.
        self.protect-connection: {
            0 == $!mysql-client.mysql_ping;
        }
    } else {
        False;
    }
}

method _disconnect() {
    .mysql_close with $!mysql-client;
    $!mysql-client = Nil;
}

method quote(Str $x, :$as-id) {
    if $as-id {
        q[`] ~ $!mysql-client.escape($x) ~ q[`]
    } else {
        q['] ~ $!mysql-client.escape($x) ~ q[']
    }
}

