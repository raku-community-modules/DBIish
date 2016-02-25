# DBIish/t/10-mysql-common.t
use v6;
use Test;
use DBIish;
use lib 't/lib';
if %*ENV<DBDTESTNEWFW> {
    my \FW = (require ::('Test::DBDish'));
    my $test-dbdish = FW.new(
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
} else {
    # Define the only database specific values used by the common tests.
    my $*mdriver = 'mysql';
    my %*opts = ().hash;
    %*opts<host>       = 'localhost';
    %*opts<port>       = 3306;
    %*opts<database>   = 'dbdishmysqltest';
    %*opts<user>       = 'testuser';
    %*opts<password>   = 'testpass';
    # Detect and report possible errors from EVAL of the common test script
    warn $! if "ok 99-common.pl6" ne EVAL slurp 't/99-common.pl6';
}
