v6;
use Test;
use DBIish;

plan 19;

my %con-parms;

# If env var set, no parameter needed.
%con-parms<dbname> = 'dbdishtest' unless %*ENV<PGDATABASE>;
%con-parms<user> = 'postgres' unless %*ENV<PGUSER>;
%con-parms<port> = 5432; # Test for issue #62

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

ok $dbh,    'Connected';

ok (my $sv = $dbh.server-version), "server-version ($sv)";

ok $dbh.pg-socket, "There's a socket";

is $dbh.quote('foo'),	    "'foo'",    'Quote literal';
is $dbh.quote('foo'):as-id, '"foo"',    'Quote Id';

# Dollar Quoting. Test our tokenizer
my $sth = $dbh.prepare(q:to/STATEMENT/);
    SELECT $$some string value$$ AS col1, $more$another string$$ "value 'here$more$ AS col2, $1::text AS col3;
STATEMENT
$sth.execute('value');
my $row = $sth.row(:hash);
is $row<col1>, 'some string value', 'Basic dollar quoting';
is $row<col2>, q{another string$$ "value 'here}, 'Named dollar quoting';

# Listen/Notify
lives-ok { $dbh.execute('LISTEN test') }, 'Listen to test';
my $note = $dbh.pg-notifies;
isa-ok $note, Any, 'No notification';
lives-ok { $dbh.execute('NOTIFY test') }, 'Notify test';
lives-ok { $dbh.execute("NOTIFY test, 'Payload'") }, 'Notify test w/payload';
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

#dd $dbh.drv.data-sources(:user<postgres>);
#dd $dbh.table-info(:table<sal_emp>).allrows(:array-of-hash).list;
#dd $dbh.column-info(:schema<public>, :table<sal_emp>).allrows.list;
