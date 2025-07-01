use v6;

need DBDish;

unit class DBDish::SQLCipher::Connection does DBDish::Connection;
need DBDish::SQLCipher::StatementHandle;
use DBDish::SQLCipher::Native;

use NativeCall;

has SQLCipher $!conn;

submethod BUILD(:$!conn!, :$!parent!) { }

method !handle-error(Int $status) {
    if $status == SQLCIPHER_OK {
        self.reset-err;
    } else {
        self!set-err($status, sqlite3_errmsg($!conn));
    }
}

## Provide the key for the connection.
method key(Str $key) {
    my $key_enc = $key.encode('utf8');
    my $key_buf = CArray[uint8].new($key_enc);
    my $key_ptr = nativecast(Pointer, $key_buf);

    sqlite3_key($!conn, $key_ptr, $key_enc.bytes);
};

## Change the key for the connection.
method rekey(Str $key) {
    my $key_enc = $key.encode('utf8');
    my $key_buf = CArray[uint8].new($key_enc);
    my $key_ptr = nativecast(Pointer, $key_buf);

    sqlite3_rekey($!conn, $key_ptr, $key_enc.bytes);
};

method prepare(Str $statement, *%args) {
    my STMT $statement-handle .= new;
    my $status = (sqlite3_libversion_number() >= 3003009)
            ?? sqlite3_prepare_v2($!conn, $statement, -1, $statement-handle, Null)
            !! sqlite3_prepare($!conn, $statement, -1, $statement-handle, Null);
    with self!handle-error($status) {
        DBDish::SQLCipher::StatementHandle.new(
            :$!conn,
            :parent(self),
            :$statement-handle,
            :$statement,
            :$.RaiseError,
            |%args
        );
    }
    else {
        .fail;
    }
}

method ping() {
    $!conn.defined;
}

method _disconnect() {
    LEAVE { $!conn = Nil }
    if $!conn and (my $status = sqlite3_close($!conn)) != SQLCIPHER_OK {
        self!set-err($status, sqlite3_errstr($status)).fail;
    }
}
