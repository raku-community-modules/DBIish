v6;
use Test;
use DBIish;

plan 10;

my %con-parms;

# If env var set, no parameter needed.
%con-parms<dbname> = 'dbdishtest' unless %*ENV<PGDATABASE>;
%con-parms<user> = 'postgres' unless %*ENV<PGUSER>;

my $dbh;

try {
  $dbh = DBIish.connect('Pg', |%con-parms);
  CATCH {
	    when X::DBIish::LibraryMissing | X::DBDish::ConnectionFailed {
		diag "$_\nCan't continue.";
	    }
            default { .throw; }
  }
}
without $dbh {
    skip-rest 'prerequisites failed';
    exit;
}

ok $dbh,    'Connected';
lives-ok { $dbh.do('LISTEN test') }, 'Listen to test';
my $note = $dbh.pg_notifies;
isa-ok $note, Any, 'No notification';
lives-ok { $dbh.do('NOTIFY test') }, 'Notify test';
ok my $sth = $dbh.prepare('SELECT 1'), 'SELECT prepared';
ok $sth.execute, 'Executed for 1';
$note = $dbh.pg_notifies;
isa-ok $note, 'DBDish::Pg::Native::PGnotify', 'A notification received';
is $note.relname, 'test', 'Test channel';
isa-ok $note.be_pid, Int, 'Pid';
is $note.extra, '', 'No extras';
