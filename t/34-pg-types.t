use v6;
use Test;
use DBIish;

plan 9;

my %con-parms;
# If env var set, no parameter needed.
%con-parms<database> = 'dbdishtest' unless %*ENV<PGDATABASE>;
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

# Be less verbose;
$dbh.do('SET client_min_messages TO WARNING');
lives-ok {
    $dbh.do(q|
    CREATE TEMPORARY TABLE test_types (
	col1 text
    )|)
}, 'Table created';

my $sth = $dbh.prepare('INSERT INTO test_types (col1) VALUES(?)');
lives-ok {
    $sth.execute('test');
}, 'Insert Perl6 values';
$sth.dispose;
$sth = $dbh.prepare('SELECT col1 FROM test_types');
my @coltype = $sth.column-types;
ok @coltype eqv [Str],	    'Column-types';

is $sth.execute, 1,			    '1 row';
my ($col1) = $sth.row;
isa-ok $col1, Str;
is $col1, 'test',			    'Test';
$dbh.Converter{Str} = sub ($) { 'changed' };
is $sth.execute, 1,			    '1 row';
($col1) = $sth.row;
is $col1, 'changed',		    'Changed';
