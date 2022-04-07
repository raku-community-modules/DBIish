use v6;
need DBDish;
# DBDish::mysql.pm6

unit class DBDish::mysql:auth<mberends>:ver<0.6.4> does DBDish::Driver;
use DBDish::mysql::Native;
need DBDish::mysql::Connection;
use NativeLibs;

has $.library;
has $.library-resolved = False;

method connect(Str :$host = 'localhost', Int :$port = 3306, Str :$database = 'mysql', Str :$user, Str :$password, Str :$socket, Int :$connection-timeout, Int :$read-timeout, Int :$write-timeout ) {
    my $connection;
    my $mysql-client = MYSQL.mysql_init;
    my $errstr  = $mysql-client.mysql_error;

    unless $errstr {

        with $connection-timeout {
            my uint32 $value = $_;
            $mysql-client.mysql_options: MYSQL_OPT_CONNECT_TIMEOUT, $value
        }

        with $read-timeout {
            my uint32 $value = $_;
            $mysql-client.mysql_options: MYSQL_OPT_READ_TIMEOUT, $value
        }

        with $write-timeout {
            my uint32 $value = $_;
            $mysql-client.mysql_options: MYSQL_OPT_WRITE_TIMEOUT, $value
        }

        # real_connect() returns either the same client pointer or null
        my $result   = $mysql-client.mysql_real_connect(
            $host, $user, $password, $database, $port, $socket, 0
        );

        unless $errstr = $mysql-client.mysql_error {
            $mysql-client.mysql_set_character_set('utf8'); # A sane default
            $connection = DBDish::mysql::Connection.new(
                :$mysql-client, :parent(self), :$host, :$user, :$password, :$database, :$port, :$socket
            );
        }
    }
    $errstr ?? self!conn-error(:$errstr) !! $connection;
}

my $wks = 'mysql_init'; # A well known symbol
method new() {
    with (%*ENV<DBIISH_MYSQL_LIB> andthen NativeLibs::Searcher.try-versions($_, $wks,0..99))
    //   NativeLibs::Searcher.try-versions('mariadb', $wks, 0..4)
    //   NativeLibs::Searcher.try-versions('mysqlclient', $wks, 16..21)
    {
        %_<library> = NativeLibs::Loader.load($_);
        %_<library-resolved> = True;
        try mysql_server_init(0, Pointer, Pointer);
    }
    self.bless(|%_);
}

method version() {
    try Version.new(mysql_get_client_info);
}

=begin pod

=head1 DESCRIPTION
# 'DBIish' and 'DBDish::mysql' are Perl 6 modules that use NativeCall
# to use the standard mysqlclient library. There is a long term Rakudo
# based project to develop a new, comprehensive DBI architecture for
# Perl 6.  DBIish is not that, it is a naive rewrite of the
# similarly named Perl 5 modules.

=head1 CLASSES
The DBDish::mysql module contains the same classes and methods as every
database driver.  Therefore read the main documentation of usage in
L<doc:DBIish> and internal architecture in L<doc:DBDish>.  Below are
only notes about code unique to the DBDish::mysql implementation.

=head1 SEE ALSO
The MySQL 5.1 Reference Manual, C API.
L<http://dev.mysql.com/doc/refman/5.1/en/c-api-function-overview.html>

=end pod
