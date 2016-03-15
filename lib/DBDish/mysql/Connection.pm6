use v6;

need DBDish;

unit class DBDish::mysql::Connection does DBDish::Connection;
use DBDish::mysql::Native;
need DBDish::mysql::StatementHandle;

has MYSQL $!mysql_client is required;

submethod BUILD(:$!mysql_client, :$!parent!) { }

method prepare(Str $statement, *%args) {
    self.reset-err;
    DBDish::mysql::StatementHandle.new(
        :$!mysql_client, :parent(self), :$statement, :$!RaiseError, |%args
    );
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
