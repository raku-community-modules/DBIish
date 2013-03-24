# DBIish/t/10-mysql-common.t

use Test;
use DBIish;

# Define the only database specific values used by the common tests.
my $*mdriver = 'mysql';
my %*opts = ().hash;
%*opts<host>       = 'localhost';
%*opts<port>       = 3306;
%*opts<database>   = 'moritz4';
%*opts<user>       = 'moritz';
%*opts<password>   = 'aeNohh4a';

# Detect and report possible errors from eval of the common test script
warn $! if "ok 99-common.pl6" ne eval slurp 't/99-common.pl6';
