# DBIish/t/10-mysql-common.t
use v6;
need DBIish::CommonTesting;

DBIish::CommonTesting.new(
    :dbd<mysql>,
    opts => {
	:database<dbdishtest>,
	:user<testuser>,
	:password<testpass>,
    },
).run-tests;

=begin pod

=head1 PREREQUISITES

Your system should already have MySQL server installed and running.

The tests by default use the database 'dbdishtest', user 'testuser' and
password 'testpass', all this can be create with:

    mysql -e "CREATE DATABASE dbdistest;" -uroot
    mysql -e "CREATE USER 'testuser'@'localhost' IDENTIFIED BY 'testpass';" -uroot
    mysql -e "GRANT ALL PRIVILEGES ON dbdishtest.* TO 'testuser'@'localhost';"

=end pod
