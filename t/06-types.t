use v6;
use Test;
use DBDish;
plan 9;

class type-test does DBDish::Type {
	method test-str(Str $value) {
		$value.flip;
	}

	submethod BUILD {
		%!Conversions{'Int'} = sub (Str $value) { Int($value) };
		self.set('Str', self.^find_method('test-str'));
	}
}

ok my $test = type-test.new;
ok my $sub = $test.get('Int');
is $sub('123'), 123;
my $int =  sub ($) {1};
ok $test.set('Int', $int);
ok $sub = $test.get('Int');
is $sub.WHAT, Sub;
is $sub('123'), 1;
ok $sub = $test.get('Str');
$sub.gist.say;
is $test.$sub('test'), 'tset';
