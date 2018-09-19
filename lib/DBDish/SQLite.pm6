use v6;

need DBDish;

unit class DBDish::SQLite:auth<mberends>:ver<0.1.1> does DBDish::Driver;
use NativeLibs;
use DBDish::SQLite::Native;
need DBDish::SQLite::Connection;

has $.library;
has $.library-resolved = False;

method connect(Str() :database(:$dbname)! is copy, *%params) {
    die "Cannot locate native library '" ~
    $*VM.platform-library-name('sqlite3'.IO, :version(v0)) ~ "'"
    unless $!library-resolved;

    my SQLite $p .= new;
    # Add the standard extension unless has one
    $dbname ~= '.sqlite3' unless $dbname ~~ / '.'|':memory:' /;

    my $status = sqlite3_open($dbname, $p);
    if $status == SQLITE_OK {
        given %params<busy-timeout> // 10000 {
            sqlite3_busy_timeout($p, .Int);
        }
        DBDish::SQLite::Connection.new(:conn($p), :parent(self), |%params);
    }
    else {
        self!conn-error: :code($status) :errstr(SQLITE($status));
    }
}

my $wks = 'sqlite3_libversion'; # A well known symbol
method new() {
    with (%*ENV<DBIISH_SQLITE_LIB> andthen NativeLibs::Searcher.try-versions($_, $wks))
     // NativeLibs::Searcher.try-versions( 'sqlite3', $wks, 0) {
    # Try to keep the library loaded.
    %_<library> = NativeLibs::Loader.load($_);
    %_<library-resolved> = True;
    }
    self.bless(|%_);
}

method version() {
    $!library-resolved ?? Version.new(sqlite3_libversion) !! Nil;
}

method threadsafe(--> Bool) {
    so sqlite3_threadsafe()
}

# vim: ft=perl6
