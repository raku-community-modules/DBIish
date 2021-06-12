# DBIish/t/10-mysql-common.t
use v6;
need DBIish::CommonTesting;

my %con-parms = :database<dbdishtest>, :user<testuser>, :password<testpass>;
%con-parms<host> = %*ENV<MYSQL_HOST> if %*ENV<MYSQL_HOST>;

DBIish::CommonTesting.new(
    :dbd<mysql>,
    opts => %con-parms,
).run-tests;

=begin pod

=head1 PREREQUISITES

Your system should already have MySQL server installed and running.

The tests by default use the database 'dbdishtest', user 'testuser' and
password 'testpass', all this can be create with:

    mysql -e "CREATE DATABASE dbdishtest;" -uroot
    mysql -e "CREATE USER 'testuser'@'localhost' IDENTIFIED BY 'testpass';" -uroot
    mysql -e "GRANT ALL PRIVILEGES ON dbdishtest.* TO 'testuser'@'localhost';"

=end pod
