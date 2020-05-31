use v6;
use Test;
use DBIish;

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

# Purposfully hold off connecting until mutiple threads are running. This trips up the driver
# loading mechanism in a way that 43-sqlite-threads.t misses.

my $skip-tests = False;
my @promises = do for ^5 -> $thread {
    start {
        my $dbh;
        try {
            $dbh = DBIish.connect('Pg', |%con-parms);
            CATCH {
                when X::DBIish::LibraryMissing | X::DBDish::ConnectionFailed {
                    diag "$_\nCan't continue.";
                }
                default { .rethrow; }
            }
        }
        # Skip work if there is no connection
        if $dbh {
            # Keep queries active by having them in sleep
            my $sth = $dbh.prepare('SELECT pg_sleep(0.3)');
            for ^4 {
                $sth.execute();
            }
            $sth.finish;
            $dbh.dispose;
        } else {
            $skip-tests = True;
        }
    }
}
await @promises;

if ($skip-tests) {
    skip-rest 'prerequisites failed';
} else {
    pass 'Pass multithread multiconnection survival test';
}


