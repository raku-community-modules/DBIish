v6;
use Test;
use DBIish::CommonTesting;

plan 3;

my %con-parms;

# If env var set, no parameter needed.
%con-parms<dbname> = 'dbdishtest' unless %*ENV<PGDATABASE>;
%con-parms<user> = 'postgres' unless %*ENV<PGUSER>;
%con-parms<port> = 5432;
# Test for issue #62

my $dbh = DBIish::CommonTesting.connect-or-skip('Pg', |%con-parms);

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
    my $row = $dbh.execute('SELECT 1 AS value').row(:hash);
    is($row<value>, 1, 'Query returned a result');
}, 'DB Connection uncorrupted';

done-testing;
