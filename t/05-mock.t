use v6;
use Test;
use DBIish;
plan 25;

my $dbh = DBIish.connect('TestMock');
my $sth = $dbh.prepare('mockdata');

nok $sth.Executed, 'Not executed yet';
is $sth.statement, 'mockdata',		'Statement';
is $sth.column-names, <col1 col2 colN>, 'Columns';
is $sth.column-types.perl, [Str, Str, Int].perl,  'Types';

$sth.execute;
is $sth.rows, 2, 'Results';

is $sth.row.join(','), 'a,b,1', 'first row';
is $sth.row.join(','), 'd,e,2', 'second row';
nok $sth.row, 'third row is empty';
ok $sth.Finished, 'Finished';

$sth.execute;
is $sth.fetchrow.join(','), 'a,b,1', 'first row (legacy)';
is $sth.fetchrow.join(','), 'd,e,2', 'second row (legacy)';
nok $sth.fetchrow, 'third row is empty (legacy)';

$sth.execute;
# Testing the internals
my \a = $sth.allrows;
isa-ok a, Seq, 'allrows returns Seq';
ok my $iter = a.iterator, 'Got iterator';
is $iter.pull-one, ['a', 'b', 1], 'A row';

$sth.execute;
is-deeply [$sth.allrows], [ ['a', 'b', 1], ['d','e', 2]], 'allrows';
$sth.execute;
is-deeply [$sth.fetchall-array], [ ['a', 'b', '1'], ['d', 'e', '2']], 'fetchall-array';

$sth.execute;
is-deeply $sth.row :hash, hash(col1 => 'a', col2 => 'b', colN => 1),
    'row :hash (1)';
is-deeply $sth.row :hash, hash(col1 => 'd', col2 => 'e', colN => 2),
    'row :hash (2)';
is-deeply $sth.row :hash, hash(), 'row :hash (empty)';

$sth.execute;
is-deeply $sth.fetchrow-hash, hash(col1 => 'a', col2 => 'b', colN => '1'),
    'fetchrow-hash (1)';
is-deeply $sth.fetchrow-hash, hash(col1 => 'd', col2 => 'e', colN => '2'),
    'fetchrow-hash (2)';
is-deeply $sth.fetchrow-hash, hash(), 'fetchrow-hash (empty)';

$sth.execute;
is-deeply $sth.fetchall-hash, hash(
    col1 => [<a d>], col2 => [<b e>], colN => ['1', '2']
), 'fetchall-HoA';

$sth.execute;
is-deeply $sth.fetchall-AoH, (
    {col1 => 'a', col2 => 'b', colN => '1'},
    {col1 => 'd', col2 => 'e', colN => '2'},
).list, 'fetchall-AoH';
