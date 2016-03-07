#!/usr/bin/env perl6

use v6;
use lib 'lib';
use DBIish;
use Test;

plan 2;
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

my $sth = $dbh.do(q:to/STATEMENT/);
  DROP TABLE IF EXISTS sal_emp;
STATEMENT

$sth = $dbh.do(q:to/STATEMENT/);
  CREATE TABLE sal_emp (
    name               text,
    pay_by_quarter     integer[],
    schedule           text[][],
    salary_by_month    float[]
  );
STATEMENT

$sth = $dbh.do(q:to/STATEMENT/);
	INSERT INTO sal_emp
    VALUES (
      'Bill',
      '{10000, 10000, 10000, 10000}',
      '{{"meeting", "lunch"}, {"training day", "presentation"}}',
      '{511.123, 622.345,1}'
    );
STATEMENT

# $sth = $dbh.prepare(q:to/STATEMENT/);
#	INSERT INTO sal_emp (name, pay_by_quarter, schedule)
#	VALUES ( ?, ?, ? )
#STATEMENT

# $sth.execute('TAFM', 'Mild fish taco', 1, 4.85);

# $sth.execute('BEOM', 'Medium size orange juice', 2, 1.20);

$sth = $dbh.prepare(q:to/STATEMENT/);
	SELECT name, pay_by_quarter, schedule, salary_by_month
	FROM sal_emp
STATEMENT

$sth.execute;

my %h = $sth.row(:hash);;


my %ref = (
name => 'Bill',
pay_by_quarter => [10000, 10000, 10000, 10000],
schedule => [["meeting", "lunch"], ["training day", "presentation"]],
salary_by_month => [Num(511.123), Num(622.345), Num(1)]
).Hash;

is %h.elems, 4, "Contain 4 elements";
is-deeply %h, %ref, "Right data";

# Cleanup
$sth.finish;
$dbh.disconnect;
