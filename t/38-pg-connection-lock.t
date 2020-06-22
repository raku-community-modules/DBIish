v6;
use Test;
use DBIish;

plan 3;

my %con-parms;

# If env var set, no parameter needed.
%con-parms<dbname> = 'dbdishtest' unless %*ENV<PGDATABASE>;
%con-parms<user> = 'postgres' unless %*ENV<PGUSER>;
%con-parms<port> = 5432;
# Test for issue #62

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
without $dbh {
    skip-rest 'prerequisites failed';
    exit;
}

# Use the connection for some activity
my $sth = $dbh.prepare('SELECT pg_sleep(0.4)');
my $p1 = start {
    $sth.execute();
}

# Ensure the query is running
sleep 0.2;

throws-like {
    $sth.execute();
}, X::DBDish::ConnectionInUse, 'Connection used by multiple threads', message => /"multiple threads"/;

await $p1;

# Test for query success
lives-ok {
    my $sth-select = $dbh.prepare('SELECT 1 AS value');
    $sth-select.execute();
    my $row = $sth-select.row(:hash);
    is($row<value>, 1, 'Query returned a result');
}, 'DB Connection uncorrupted';

done-testing;
