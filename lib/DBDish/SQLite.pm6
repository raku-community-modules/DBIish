use v6;

need DBDish;

unit class DBDish::SQLite:auth<mberends>:ver<0.0.3> does DBDish::Driver;
use DBDish::SQLite::Native;
need DBDish::SQLite::Connection;

has $.errstr;

method !errstr() is rw { $!errstr }
method connect(:database(:$dbname)! is copy, :$RaiseError, *%params) {

    my SQLite $p .= new;
    # Add the standard extension unless has one
    $dbname ~= '.sqlite3' unless $dbname ~~ / '.' /;

    my $status = sqlite3_open($dbname, $p);
    if $status == SQLITE_OK {
        $!errstr = Nil;
        my $con = DBDish::SQLite::Connection.new(
            :conn($p), :$RaiseError, :parent(self)
        );
        @!Connections.unshift($con);
        $con;
    }
    else {
        $!errstr = SQLITE($status);
        DBDish::SQLite::Connection.conn-error(
            :code($status), :$!errstr, :$RaiseError
        );
    }
}

# vim: ft=perl6
