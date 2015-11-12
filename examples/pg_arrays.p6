#!/usr/bin/env perl6

use v6;
use lib 'lib';
use DBIish;
use NativeCall;

# Windows support
if $*DISTRO.is-win {
	# libpq.dll on windows depends on libeay32.dll which in this path
	my constant PG-HOME   = 'C:\Program Files\PostgreSQL\9.3';
	my $path              = sprintf( 'Path=%s;%s\bin', %*ENV<Path>, PG-HOME );
	%*ENV<DBIISH_PG_LIB>  = (PG-HOME).fmt( '%s\lib\libpq.dll' );

	# Since %*ENV<Path> = ... does not actually own process environment
	# Weird magic but needed atm :)
	sub _putenv(Str) is native('msvcrt') { ... }
	_putenv( $path);
}

my $dbh = DBIish.connect(
	"Pg",
	:database<postgres>,
	:user<postgres>,
	:password<sa>, :RaiseError
);

my $sth = $dbh.do(q:to/STATEMENT/);
	DROP TABLE IF EXISTS sal_emp;
STATEMENT

$sth = $dbh.do(q:to/STATEMENT/);
  CREATE TABLE sal_emp (
    name            text,
    pay_by_quarter  integer[],
    schedule        text[][]
  );
STATEMENT

$sth = $dbh.do(q:to/STATEMENT/);
	INSERT INTO sal_emp
    VALUES (
      'Bill',
      '{10000, 10000, 10000, 10000}',
      '{{"meeting", "lunch"}, {"training day", "presentation"}}'
    );
STATEMENT

# $sth = $dbh.prepare(q:to/STATEMENT/);
#	INSERT INTO sal_emp (name, pay_by_quarter, schedule)
#	VALUES ( ?, ?, ? )
#STATEMENT

# $sth.execute('TAFM', 'Mild fish taco', 1, 4.85);

# $sth.execute('BEOM', 'Medium size orange juice', 2, 1.20);

$sth = $dbh.prepare(q:to/STATEMENT/);
	SELECT name, pay_by_quarter, schedule
	FROM sal_emp
STATEMENT

$sth.execute;

my %h = $sth.fetchrow_typedhash;
say %h;

#my $arrayref = $sth.fetchall_arrayref();
#say $arrayref.elems;
#say $arrayref.perl;



# Cleanup
$sth.finish;
$dbh.disconnect;
