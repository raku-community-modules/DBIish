use v6;

need DBDish;

unit class DBDish::SQLite:auth<mberends>:ver<0.1.0> does DBDish::Driver;
use DBDish::SQLite::Native;
need DBDish::SQLite::Connection;

method connect(:database(:$dbname)! is copy, *%params) {

    my SQLite $p .= new;
    # Add the standard extension unless has one
    $dbname ~= '.sqlite3' unless $dbname ~~ / '.'|':memory:' /;

    my $status = sqlite3_open($dbname, $p);
    if $status == SQLITE_OK {
        DBDish::SQLite::Connection.new(:conn($p), :parent(self), |%params);
    }
    else {
        self!conn-error: :code($status) :errstr(SQLITE($status));
    }
}

method version() {
    Version.new(sqlite3_libversion);
}

# vim: ft=perl6
