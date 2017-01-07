use v6;
use Test;
need DBDish;

plan 11;

class type-test {
	has %.Converter is DBDish::TypeConverter;

	method test-str(Str $value) {
		$value.flip;
	}

	submethod BUILD {
		%!Converter{Int} = sub (Str $value, $typ) { Int($value) };
		%!Converter{Str} = self.^find_method('test-str');
	}
}

ok my $test = type-test.new;
ok my $res = $test.Converter.convert('123', Int), 'Get the result (Int)';
is $res, 123, 'Check it';

ok my $sub = $test.Converter{Int}, 'Get the converter sub (Int)';
is $sub('123', Int), 123, 'and then convert';
my $int =  sub ($) {1};
ok ($test.Converter{Int} = $int), 'Change the Int converter';
ok $sub = $test.Converter{Int}, 'Get it back';
is $sub.WHAT, Sub, 'Is it a sub?';
is $sub('123'), 1, 'Does it do its job?';

ok $sub = $test.Converter{Str}, 'get the Str method';
is $test.$sub('test'), 'tset', 'and try it';
