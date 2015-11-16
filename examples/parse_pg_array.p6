#!/usr/bin/env perl6

#use Grammar::Tracer;
#use Grammar::Debugger;

my grammar ArrayListGrammar {
  token TOP         { ^ <array> $ }
  rule array        { '{' (<element> ','?)+ '}' }
  rule element      { <array> | <number> | <string> }
  rule number       { (\d+) }
  rule string       { '"' $<value>=(\w+) '"' | $<value>=(\w+) }
};

my $t = ArrayListGrammar.parse( '{1,"2",{1,2}}' );
die "Failed to parse" unless $t.defined;


sub _to-list($t) {
  my @array;
  for $t.<array>.values -> $element {
    if $element.values[0]<array>.defined {
      # An array
      push @array, _to-list( $element.values[0] );
    } elsif $element.values[0]<number>.defined {
      # Number
      push @array, +$element.values[0]<number>;
    } else {
      # Must be a String
      push @array, ~$element.values[0]<string><value>;
    }
  }

  return @array;
}

say _to-list($t).perl;
