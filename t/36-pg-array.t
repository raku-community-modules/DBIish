#!/usr/bin/env perl6

use v6;
use DBIish;
use Test;

plan 7;
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
      ARRAY[10000, 10000, 10000, 1000],
      ARRAY[['meeting', 'lunch'], ['training day', 'presentation']],
      ARRAY[511.123, 622.345, 1]
    );
STATEMENT

$sth = $dbh.prepare(q:to/STATEMENT/);
    SELECT name, pay_by_quarter, schedule, salary_by_month
    FROM sal_emp
STATEMENT

$sth.execute;

my %h = $sth.row(:hash);;

class SalEmp {
  has $.name;
  has Int @.pay_by_quarter;
  has @.schedule;
  has Num @.salary_by_month;
  submethod BUILD(:$!name, :@!pay_by_quarter, :@!schedule, :@!salary_by_month) { }
};

is %h.elems, 4, "Contain 4 elements";

my $obj;
lives-ok {
    $obj = SalEmp.new(|%h);
}, "Can create class";

isa-ok $obj.pay_by_quarter, Array[Int], 'Array[Int]';
isa-ok $obj.salary_by_month,  Array[Num], 'Array[Num]';
isa-ok $obj.schedule, Array, 'schedule is array';
is $obj.schedule.elems, 2,    'schedule with 2';
isa-ok $obj.schedule[0], Array[Str];

# Cleanup
$dbh.dispose;
