use v6;
need DBDish;
# DBDish::mysql.pm6

unit class DBDish::mysql:auth<mberends>:ver<0.1.0> does DBDish::Driver;
use DBDish::mysql::Native;
need DBDish::mysql::Connection;

#------------------ methods to be called from DBIish ------------------
method connect(*%params ) {
    my $connection;
    my $mysql_client = MYSQL.mysql_init;
    my $errstr  = $mysql_client.mysql_error;

    unless $errstr {
        %params<host>     //= 'localhost';
        %params<port>     //= 3306;
        %params<database> //= 'mysql';
        %params<socket>   //= Str; # Undef

        # real_connect() returns either the same client pointer or null
        my $result   = $mysql_client.mysql_real_connect(
            |%params<host user password database port socket>, 0
        );

        unless $errstr = $mysql_client.mysql_error {
	    $mysql_client.mysql_set_character_set('utf8'); # A sane default
            $connection = DBDish::mysql::Connection.new(
                :$mysql_client, :parent(self), |%params,
            );
        }
    }
    $errstr ??  self!conn-error(:$errstr) !!  $connection;
}

method version() {
       Version.new(mysql_get_client_info);
}

=begin pod

=head1 DESCRIPTION
# 'DBIish' and 'DBDish::mysql' are Perl 6 modules that use NativeCall
# to use the standard mysqlclient library. There is a long term Rakudo
# based project to develop a new, comprehensive DBI architecture for Parrot
# and Perl 6.  DBIish is not that, it is a naive rewrite of the
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
