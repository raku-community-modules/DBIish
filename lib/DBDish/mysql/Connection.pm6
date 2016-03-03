use v6;

need DBDish;

unit class DBDish::mysql::Connection does DBDish::Connection;
use DBDish::mysql::Native;
need DBDish::mysql::StatementHandle;

has MYSQL $!mysql_client is required;

submethod BUILD(:$!mysql_client, :$!parent!) { }

method prepare( Str $statement ) {
    self.reset-err;
    DBDish::mysql::StatementHandle.new(
        :$!mysql_client, :parent(self), :$statement, :$!RaiseError
    );
}

method mysql_insertid() {
    mysql_insert_id($!mysql_client);
    # but Parrot NCI cannot return an unsigned  long long :-(
}

method ping() {
    0 == mysql_ping($!mysql_client);
}

method disconnect() {
    mysql_close($!mysql_client);
    True
}

method quote-identifer(Str:D $name) {
    qq[`$name`];
}
