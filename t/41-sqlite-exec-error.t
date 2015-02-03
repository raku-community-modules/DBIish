use v6;
use Test;
plan 3;
use DBIish;

my $dbfile = 't/exec-error.sqlite3';
try unlink $dbfile;
my $dbh = try { DBIish.connect('SQLite', database => $dbfile) };
unless $dbh {
    skip_rest 'SQLite3 not available';
    exit;
}


lives_ok {
    $dbh.do('DROP TABLE IF EXISTS with_unique');
    $dbh.do('CREATE TABLE with_unique(a integer not null, b integer not null, UNIQUE(a, b))');
}, 'Can create table';

my $insert = $dbh.prepare('INSERT INTO with_unique(a, b) VALUES(?, ?)');

lives_ok { $insert.execute(1, 1) }, 'Can insert tuple the first time';
dies_ok { $insert.execute(1, 1) }, 'Cannot insert tuple the second time';

try unlink $dbfile;
