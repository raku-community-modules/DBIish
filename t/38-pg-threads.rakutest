use v6;
use Test;
use DBIish::CommonTesting;

plan 1;

# Thread tests may fail periodically under 2020.01
unless $*PERL.compiler.version >= v2020.01 {
    skip-rest 'Rakudo v2020.01 required for threading tests';
    exit;
}

my %con-parms;
# If env var set, no parameter needed.
%con-parms<database> = 'dbdishtest' unless %*ENV<PGDATABASE>;
%con-parms<user> = 'postgres' unless %*ENV<PGUSER>;
my $dbh = DBIish::CommonTesting.connect-or-skip('Pg', |%con-parms);

# Connection is functional. Each thread is expected to get it's own connection
$dbh.dispose;

# Purposfully hold off connecting until mutiple threads are running. This trips up the driver
# loading mechanism in a way that 43-sqlite-threads.t misses.

my $skip-tests = False;
my @promises = do for ^5 -> $thread {
    start {
        my $dbh = DBIish.connect('Pg', |%con-parms);

        # Keep queries active by having them in sleep
        my $sth = $dbh.prepare('SELECT pg_sleep(0.3)');
        for ^4 {
            $sth.execute();
        }
        $sth.finish;
        $dbh.dispose;
    }
}
await @promises;

pass 'Pass multithread multiconnection survival test';
