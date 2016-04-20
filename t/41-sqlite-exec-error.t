use v6;
use Test;
plan 16;
use DBIish;

ok not DBIish.err,  "At start DBIish.err is 0";
throws-like {
    DBIish.connect('SQLite');
}, X::AdHoc, 'Need database';

throws-like {
    DBIish.connect('SQLite', :database</no-such/database>);
}, X::DBDish::ConnectionFailed, "Die on invalid database";
ok so DBIish.err,     "Error registered";

my $dbfile = 'exec-error';
ok (my $dbh =  DBIish.connect('SQLite', dbname => $dbfile)), 'Created';
without $dbh {
    skip-rest 'SQLite3 not available';
    exit;
}
ok not $dbh.err,    'Without errors en $dbh';
ok not DBIish.err,  'Error cleared in DBIish';

lives-ok {
    $dbh.do('DROP TABLE IF EXISTS with_unique');
    $dbh.do('CREATE TABLE with_unique(a integer not null, b integer not null, UNIQUE(a, b))');
}, 'Can create table';

my $insert = $dbh.prepare('INSERT INTO with_unique(a, b) VALUES(?, ?)');

lives-ok { $insert.execute(1, 1) }, 'Can insert tuple the first time';
throws-like {
    $insert.execute(1, 1);
}, X::DBDish::DBError,  'Cannot insert tuple the second time';

ok so $insert.err,	'Has error at $sth level';
ok (my $e = $insert.errstr),	'Error preserved';
diag $e;
ok so $dbh.err,		'Has error at $dbh level';
ok so $dbh.drv.err,	'Has error at $drv level';
ok so DBIish.err,	'Has error at $sth leval';
is DBIish.errstr, $e, 'Propagated to DBIish';
$dbh.dispose; # Close the connection


END { try unlink "$dbfile.sqlite3" };
