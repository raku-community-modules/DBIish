
use v6;
use DBIish;
use Test;

plan 4;

my %con-parms;
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

my $sth = $dbh.do(q:to/SQL/);
  DROP TABLE IF EXISTS rakuists;
SQL

$sth = $dbh.do(q:to/SQL/);
  CREATE TABLE rakuists (
    id SERIAL,
    name VARCHAR NOT NULL
  );
SQL

$sth = $dbh.do(q:to/SQL/);
  INSERT INTO rakuists (name)
  VALUES ('Jonathan Worthington')
  RETURNING id;
SQL

ok $sth[0] == 1, '"do" returns an insert id';

$sth = $dbh.do(q:to/SQL/);
  INSERT INTO rakuists (name)
  VALUES ('Moritz Lenz'), ('Patrick R. Michaud')
  RETURNING id;
SQL

ok $sth[0] == 2, '"do" with multiple values returns the first insert id';
ok $sth[1] == 3, '"do" with multiple values returns the second insert id';

$sth = $dbh.prepare(q:to/SQL/);
  INSERT INTO rakuists (name)
  VALUES (?)
  RETURNING id;
SQL

ok $sth.execute('Elizabeth Mattijsen')[0] == 4, '"prepare" returns an insert id';

$sth.dispose;
$dbh.dispose;
