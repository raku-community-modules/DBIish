use v6;
use Test;
use DBIish;
use DBIish::DataSet;

plan 48;

my %con-parms = :database<dbdishtest>, :user<testuser>, :password<testpass>;
my ($dbhP, $dbhM);

try {
  $dbhM = DBIish.connect('mysql', |%con-parms),
  $dbhP = DBIish.connect('Pg', |%con-parms, :user<postgres>) :Set-Default;
  CATCH {
            when X::DBIish::LibraryMissing | X::DBDish::ConnectionFailed {
                diag "$_\nCan't continue.";
            }
            default { .throw; }
  }
}
unless $dbhP && $dbhM {
    skip-rest 'prerequisites failed';
    exit;
}

for ($dbhP, $dbhM) {
    .do('DROP TABLE IF EXISTS test');
    .do('CREATE TABLE test (id int, name varchar(35))');
}

my $insert = "INSERT INTO test(id, name) VALUES (?, ?)";

# Ready
{
    with $insert.SQL {
	ok .(0, 'First'),	'Insert one';
	ok .(100, 'Last'),	'Insert one';
	.dispose;
    }
}

with "SELECT * FROM test".SQL -> $S1 {
    ok $S1,				"SELECT defined";

    my $ds;
    lives-ok {
	$ds = $S1();
    },					'Statement can be called';

    ok $ds,				'DataSet created';
    isa-ok $ds,				DataSet;

    # An important thing!
    does-ok $ds,			Iterable;

    # I'm testing the internals, so need to go slowly.
    is $ds.current, -1,			'At start';
    nok $ds.is-empty,			'Not empty';

    ok (my $L = $ds.list),		'Can get list';
    isa-ok $L,				List;

    with $L[0] -> $/ {
	pass				"Defined";

	# This List is constructed from the iterator, so DS and List are entangled
	# until reified
	is $ds.current, 0,		'one taken';

	isa-ok $/,			Row;
	# Testing its properties
	does-ok $/,			Positional;
	does-ok $/,			Associative;
	# Numeric forms
	is +$/, 2,			"A row with 2 elems";
	is $/.Int, 2;
	is $/.elems, 2;
	# hash semantic
	is %(), { id => 0, name => 'First' },   'as Hash';
	is $/.keys, <id name>,		'ordered keys';
	# list semantic
	is $/.list, (0, 'First'),	'as List';
	is $/.values, (0, 'First'),	'also';
	# array semantic
	is @(), [ 0, 'First' ],		'as Array';
	# Positionals
	is $0, 0,			"By pos(\$0): $0";
	is $1, 'First',			"By pos(\$1); $1";
	# Named
	is $<id>, 0,			"By name 'id': $<id>";
	is $<name>, 'First',		"By name 'name' $<name>";
	# As Capture
	is \(|$/), \(0, 'First'),	'Positional Capture';
	# TODO This is broken somehow
	#is \(|%$/), \(:id(0), :name('First')), 'Named Capture';
	is $/.idx, 0,			'My idx is zero';
    }

    nok $ds.is-empty,			'Has more';

    with $L[1] {
	pass				'another';
	is $ds.current, 1,		'taken';
	is $_.idx, $ds.current,		'The same';
	is @$_, (100, 'Last'),		'expected';
	is $_.gist, "DBIish::Row[1](100 Last)",  'Some util';
    }

    nok $L[2],				'No more';
    ok $ds.is-empty,			'Empty';

    is $L.elems, 2,			'Two rows';
    $L=();

    my $count = 0;
    my $data = '';
    for $S1.() { # Call again
	isa-ok $_,			Row;
	$count += $_<id>;
	$data ~= $_<name>;
    }
    is $count, 100,			'Expected sum';
    is $data, 'FirstLast',		'Expected data';
    $S1.dispose;
}

my %test-data;
my $all-ok = True;
# We need more data
with $insert.SQL -> $insertor {
    my @chars =  (0..9, 'A'..'Z', 'a'..'z').flat;
    for 1..^20 -> $i {
      my $random_chars = @chars.pick(16).join('');
      %test-data{$i} = $random_chars; # save these values for later testing

      unless $insertor($i, $random_chars) { $all-ok = False; }
    }
    $insertor.dispose;
    ok $all-ok, "insert 19 rows of random chars";
}


# Move them to other DB
with $insert.SQL($dbhM) -> $insertor {
    isa-ok $insertor.parent.drv, 'DBDish::mysql';
    with "SELECT * FROM test where id > ? and id <= ?".SQL {
	isa-ok .parent.drv, 'DBDish::Pg';
	for .(1, 10) -> $/ {
	    # Check data
	    $all-ok &&= %test-data{$<id>} eq $<name>;
	    # Copy
	    $all-ok &&= $insertor(|$/);
	}
    }
}
ok $all-ok, "Data match and copied";

with "SELECT * FROM test WHERE id > ? and id <= ?".SQL($dbhM) {
    for .(1, 10) -> $/ {
	# Check data
	$all-ok &&= %test-data{$<id>} eq $<name>;
    }
}
ok $all-ok, "Copied data match";

diag "Continuará...";
