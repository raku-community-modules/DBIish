use v6;
use Test;

plan 5;

use-ok 'NativeLibs';
ok (my \Util = ::('NativeLibs::Searcher')) !~~ Failure,	'Class Searcher exists';
my $sub = Util.at-runtime('mysqlclient', 'mysql_init', 16..20);
does-ok $sub, Callable;
my $lib = $sub.();
todo "Can fail if the mysqlclient library isn't installed", 1;
like $lib,  / 'mysql' .* \d+ /,		"Indeed $lib";
todo "Can fail if the pq library isn't installed", 1;
ok $lib = Util.try-versions('pq', 'PQstatus', 4,5,6),	"Postgres is $lib";
