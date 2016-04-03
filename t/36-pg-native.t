v6;
use Test;
use DBIish;

plan 14;

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
ok($dbh.pg-socket, "There's a socket");
lives-ok { $dbh.do('LISTEN test') }, 'Listen to test';
my $note = $dbh.pg-notifies;
isa-ok $note, Any, 'No notification';
lives-ok { $dbh.do('NOTIFY test') }, 'Notify test';
lives-ok { $dbh.do("NOTIFY test, 'Payload'") }, 'Notify test w/payload';
$note = $dbh.pg-notifies;
isa-ok $note, 'DBDish::Pg::Native::pg-notify', 'A notification received';
is $note.relname, 'test', 'Test channel';
isa-ok $note.be_pid, Int, 'Pid';
is $note.extra, '', 'No extras';
$note = $dbh.pg-notifies;
isa-ok $note, 'DBDish::Pg::Native::pg-notify', 'A notification received';
is $note.relname, 'test', 'Test channel';
isa-ok $note.be_pid, Int, 'Pid';
is $note.extra, 'Payload', 'w/ extras';
