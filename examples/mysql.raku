#!/usr/bin/env perl6

use v6;

use lib 'lib';
use DBIish;


# Windows support
%*ENV<DBIISH_MYSQL_LIB> = "C:/Program Files/MySQL/MySQL Server 5.6/lib/libmysql.dll"
	if $*DISTRO.is-win;

my $dbh = DBIish.connect("mysql", :database<test>, :user<root>, :password<sa>, :RaiseError);

my $sth = $dbh.execute(q:to/STATEMENT/);
	DROP TABLE IF EXISTS nom
STATEMENT

$sth = $dbh.execute(q:to/STATEMENT/);
	CREATE TABLE nom (
		name        varchar(4),
		description varchar(30),
		quantity    int,
		price       numeric(5,2)
	)
STATEMENT

$sth = $dbh.execute(q:to/STATEMENT/);
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

my @array = $sth.allrows();
say @array.elems; # 3

# Cleanup
$sth.dispose;
$dbh.dispose;
