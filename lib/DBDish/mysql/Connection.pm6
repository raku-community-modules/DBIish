
use v6;

class DBDish::mysql::Connection does DBDish::Connection {
    has $!mysql_client;
    submethod BUILD(:$!mysql_client) { }
    method prepare( Str $statement ) {
        my $statement_handle = DBDish::mysql::StatementHandle.new(
            mysql_client => $!mysql_client,
            statement    => $statement,
            RaiseError   => $.RaiseError
        );
        return $statement_handle;
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
}

