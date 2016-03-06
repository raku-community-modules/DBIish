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
    LEAVE { self.reset-err }
    0 == $!mysql_client.mysql_ping;
}

method disconnect() {
    $!mysql_client.mysql_close;
    $!mysql_client = Nil;
    True
}

method quote-identifer(Str:D $name) {
    qq[`$name`];
}
