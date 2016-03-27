use v6;

need DBDish;

unit class DBDish::mysql::Connection does DBDish::Connection;
use DBDish::mysql::Native;
need DBDish::mysql::StatementHandle;

has MYSQL $!mysql_client is required;

submethod BUILD(:$!mysql_client, :$!parent!) { }

method !handle-errors($code) {
    if $code {
	self!set-err($code, $!mysql_client.mysql_error);
    } else {
	self.reset-err;
    }
}
method prepare(Str $statement, *%args) {
    with $!mysql_client.mysql_stmt_init -> $stmt {
	with self!handle-errors(
	    $stmt.mysql_stmt_prepare($statement, $statement.encode.bytes)
	) {
	    DBDish::mysql::StatementHandle.new(
		:$!mysql_client, :parent(self), :$stmt
		:$statement, :$!RaiseError, |%args
	    );
	} else { .fail }
    } else {
	self!set-err(-1, "Can't allocate memory");
    }
}

method execute(Str $statement, *%args) {
    DBDish::mysql::StatementHandle.new(
	:$!mysql_client, :parent(self), :$statement, :$!RaiseError, |%args
    ).execute;
}

method mysql_insertid() {
    $!mysql_client.mysql_insert_id;
}

method ping() {
    with $!mysql_client {
	0 == $!mysql_client.mysql_ping;
    } else {
	False;
    }
}

method _disconnect() {
    .mysql_close with $!mysql_client;
    $!mysql_client = Nil;
}

method quote-identifer(Str:D $name) {
    qq[`$name`];
}
