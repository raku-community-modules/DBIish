# DBIish/t/40-SQLite-common.t
use v6;
use Test;
use DBIish;

# Define the only database specific values used by the common tests.
my ( $*mdriver, %*opts) = 'SQLite';
%*opts<database> = 'minidbi-test.sqlite3';
my $dbh;

# Detect and report possible errors from EVAL of the common test script
warn $! if "ok 99-common.pl6" ne EVAL slurp 't/99-common.pl6';
