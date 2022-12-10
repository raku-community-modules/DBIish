use v6;
use Test;
use DBIish;
plan 16;

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
# Testing the internals
my \a = $sth.allrows;
isa-ok a, Seq, 'allrows returns Seq';
ok my $iter = a.iterator, 'Got iterator';
is $iter.pull-one, ['a', 'b', 1], 'A row';

$sth.execute;
is-deeply [$sth.allrows], [ ['a', 'b', 1], ['d','e', 2]], 'allrows';

$sth.execute;
is-deeply $sth.row :hash, hash(col1 => 'a', col2 => 'b', colN => 1),
    'row :hash (1)';
is-deeply $sth.row :hash, hash(col1 => 'd', col2 => 'e', colN => 2),
    'row :hash (2)';
is-deeply $sth.row :hash, hash(), 'row :hash (empty)';

