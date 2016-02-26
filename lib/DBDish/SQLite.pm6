unit class DBDish::SQLite:auth<mberends>:ver<0.0.1>;
use DBDish::SQLite::Native;
need DBDish::SQLite::Connection;

has $.Version = 0.01;
has $.errstr;
method !errstr() is rw { $!errstr }
method connect(:$RaiseError, *%params) {
    my $dbname = %params<dbname> // %params<database>;
    die 'No "dbname" or "database" given' unless defined $dbname;

    my SQLite $p .= new;
    my $status = sqlite3_open($dbname, $p);
    if $status == SQLITE_OK {
        return DBDish::SQLite::Connection.new(
                :conn($p),
                :$RaiseError,
        );
    }
    else {
        $!errstr = SQLITE($status);
        die $!errstr if $RaiseError;
    }
}

# vim: ft=perl6
