# DBIish/t/10-mysql-common.t
use v6;
use Test;
use lib 't/lib';
need Test::DBDish;
my $test-dbdish = Test::DBDish.new(
    dbd => 'mysql',
    opts => {
	host => 'localhost',
	port => 3306,
	database => 'dbdishmysqltest',
	user => 'testuser',
	password => 'testpass',
    },
);
$test-dbdish.run-tests;
