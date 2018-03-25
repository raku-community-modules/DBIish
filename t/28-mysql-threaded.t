use DBIish;
use Test;

plan 100;

# This is meant to ensure that we load libmysqlclient.{so|dll} early enough.
DBIish.install-driver('mysql', :RaiseError);

await do for 1..100 {
    start {
        diag "Connecting to database for test $_ in thread $*THREAD.id()";
        my $mysql = DBIish.connect('mysql',
            :database<dbdishtest>,
            :user<testuser>,
            :password<testpass>,
            :RaiseError,
        );
        my $time = rand * 10;
        my $sth  = $mysql.prepare("SELECT $time, SLEEP($time)");
        $sth.execute();

        # sleepsorted output
        pass "Slept about $time seconds for test $_ in thread $*THREAD.id()";
        $mysql.dispose();
    }
}
