use v6;

need DBDish;

unit class DBDish::mysql::Connection does DBDish::Role::Connection;
use DBDish::mysql::Native;
need DBDish::mysql::StatementHandle;

has $!mysql_client;

submethod BUILD(:$!mysql_client) { }

method prepare( Str $statement ) {
    DBDish::mysql::StatementHandle.new(
        mysql_client => $!mysql_client,
        statement    => $statement,
        RaiseError   => $.RaiseError
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
