use v6;
use Test;
use DBIish;
plan 9;

my $dbh = DBIish.connect('TestMock');
my $sth = $dbh.prepare('everything');

$sth.execute;
is $sth.fetchrow.join(','), 'a,b,c', 'first row';
is $sth.fetchrow.join(','), 'd,e,f', 'second row';
nok $sth.fetchrow, 'third row is empty';

$sth.execute;
is_deeply [$sth.fetchall-array], [ [<a b c>], [<d e f>]], 'fetchall-array';

$sth.execute;
is_deeply $sth.fetchrow-hash, hash(col1 => 'a', col2 => 'b', col3 => 'c'),
    'fetchrow-hash (1)';
is_deeply $sth.fetchrow-hash, hash(col1 => 'd', col2 => 'e', col3 => 'f'),
    'fetchrow-hash (2)';
is_deeply $sth.fetchrow-hash, hash(), 'fetchrow-hash (empty)';

$sth.execute;
is_deeply $sth.fetchall-hash, hash(col1 => [<a d>], col2 => [<b e>], col3 => [<c f>]), 'fetchall-HoA';

$sth.execute;
is_deeply $sth.fetchall-AoH, (
    {col1 => 'a', col2 => 'b', col3 => 'c'},
    {col1 => 'd', col2 => 'e', col3 => 'f'},
).list, 'fetchall-AoH';
