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

my $dbh = DBIish.connect("Pg", :database<postgres>, :user<postgres>, :password<sa>, :RaiseError);

my $sth = $dbh.do(q:to/STATEMENT/);
	DROP TABLE IF EXISTS nom
STATEMENT

$sth = $dbh.do(q:to/STATEMENT/);
	CREATE TABLE nom (
		name        varchar(4),
		description varchar(30),
		quantity    int,
		price       numeric(5,2)
	)
STATEMENT

$sth = $dbh.do(q:to/STATEMENT/);
	INSERT INTO nom (name, description, quantity, price)
	VALUES ( 'BUBH', 'Hot beef burrito', 1, 4.95 )
STATEMENT

$sth = $dbh.prepare(q:to/STATEMENT/);
	INSERT INTO nom (name, description, quantity, price)
	VALUES ( ?, ?, ?, ? )
STATEMENT

$sth.execute('TAFM', 'Mild fish taco', 1, 4.85);

$sth.execute('BEOM', 'Medium size orange juice', 2, 1.20);

$sth = $dbh.prepare(q:to/STATEMENT/);
	SELECT name, description, quantity, price, quantity*price AS amount
	FROM nom
STATEMENT

$sth.execute;

my $arrayref = $sth.fetchall_arrayref();
say $arrayref.elems; # 3

# Cleanup
$sth.dispose;
$dbh.dispose;
