use v6;
use Test;
use DBIish;

plan 1;

my %con-parms = :database<dbdishtest>, :user<testuser>, :password<testpass>;
%con-parms<host> = %*ENV<MYSQL_HOST> if %*ENV<MYSQL_HOST>;
my $dbh;

# Thread tests may fail periodically under 2020.01
unless $*PERL.compiler.version >= v2020.01 {
    skip-rest 'Rakudo v2020.01 required for threading tests';
    exit;
}

try {
    $dbh = DBIish.connect('mysql', |%con-parms);
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

# Connection tested. Each thread is expected to get it's own connection
$dbh.dispose;

my $skip-tests = False;
my @promises = do for ^5 -> $thread {
    start {
        my $dbh = DBIish.connect('mysql', |%con-parms);

            # Keep queries active by having them in sleep
            my $sth = $dbh.prepare('SELECT sleep(1)');
            for ^4 {
                $sth.execute();
            }
            $sth.finish;
            $dbh.dispose;
    }
}
await @promises;

pass 'Pass multithread multiconnection survival test';


