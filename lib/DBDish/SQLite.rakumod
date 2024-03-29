use v6;

need DBDish;

unit class DBDish::SQLite:ver($?DISTRIBUTION.meta<ver>):api($?DISTRIBUTION.meta<api>):auth($?DISTRIBUTION.meta<auth>) does DBDish::Driver;
use NativeLibs;
use DBDish::SQLite::Native;
need DBDish::SQLite::Connection;

has $.library;
has $.library-resolved = False;

method connect(:database(:$dbname)! is copy, *%params) {
    die "Cannot locate native library '" ~
            $*VM.platform-library-name('sqlite3'.IO, :version(v0)) ~ "'"
    unless $!library-resolved;

    my SQLite $p .= new;
    if ($dbname ne ':memory:') {
        $dbname = (
        # Don't touch if already an IO::Path
        $dbname ~~ IO::Path ?? $dbname !!
                # Add the standard extension unless has one
                ($dbname.IO.extension ?? $dbname !! $dbname ~ '.sqlite3').IO
        ).absolute;
    }

    my $status = sqlite3_open($dbname, $p);

    # Enable extended result codes if available
    sqlite3_extended_result_codes($p, 1);

    if $status == SQLITE_OK {
        given %params<busy-timeout> // 10000 {
            sqlite3_busy_timeout($p, .Int);
        }
        DBDish::SQLite::Connection.new(:conn($p), :parent(self), |%params);
    }
    else {
        # Show the extended status code for the connection error
        # if one is available
        my $detailed-status = sqlite3_extended_errcode($p) // $status;
        self!conn-error: :code($$detailed-status) :errstr(sqlite3_errmsg($p));
    }
}

my $wks = 'sqlite3_libversion'; # A well known symbol
method new() {
    with (%*ENV<DBIISH_SQLITE_LIB> andthen NativeLibs::Searcher.try-versions($_, $wks))
    //   NativeLibs::Searcher.try-versions('sqlite3', $wks, 0)
    {
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
