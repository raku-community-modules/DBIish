use v6;
use Test;
need DBDish;

plan 12;

class type-test {
	has %.Converter is DBDish::TypeConverter;

	method test-str(Str $value) {
		$value.flip;
	}

	submethod BUILD {
		%!Converter{Str} = self.^find_method('test-str');
	}
}

ok my $test = type-test.new,	    'Converter created';
nok $test.Converter{Int}:exists,    'Int is builtin';
ok not $test.Converter{Int}.defined, 'So not defined';
ok my $res = $test.Converter.convert('123', Int), 'But can be used';
ok $res ~~ Int,	    'Correct type';
is $res, 123,	    'Check it';

my $int =  sub ($) {1};
ok ($test.Converter{Int} = $int),   'Change the Int converter';
ok my $sub = $test.Converter{Int},  'Get it back';
ok $sub === $int,		    'The same sub';
is $test.Converter.convert('123', Int), 1, 'Does it do its job?';

ok $sub = $test.Converter{Str}, 'get the Str method';
is $test.$sub('test'), 'tset', 'and try it';
