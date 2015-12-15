# DBIish/t/10-mysql-common.t

use Test;
use DBIish;
#use DBDish::mysql;

# Define the only database specific values used by the common tests.
my $*mdriver = 'mysql';
my %*opts = ().hash;
%*opts<host>       = 'localhost';
%*opts<port>       = 3306;
%*opts<database>   = 'zavolaj';
%*opts<user>       = 'testuser';
%*opts<password>   = 'testpass';

# Detect and report possible errors from EVAL of the common test script
warn $! if "ok 99-common.pl6" ne EVAL slurp 't/99-common.pl6';
