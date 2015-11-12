#!/usr/bin/env perl6

#use Grammar::Tracer;
#use Grammar::Debugger;

my grammar ArrayListGrammar {
  token TOP  { ^ <array> $ }
  rule array { '{' ($<value>=<element> ','?)+ '}' }
  rule element { $<value>=[<array> | <number> | <string>] }
  rule number { $<value>=(\d+) }
  rule string { '"' $<value>=(\w+) '"' | $<value>=(\w+) }
};

my class ArrayListActions {

  method TOP($/) {
    #make $/;
    make $/<value>;
  }

  #method element($/) {
    #push @array, $<value>;
  #}

  method array($/) {
    state @a;
    say "Adding " ~ $<value>;
    push @a, $<value>;
    make @a;
  }

  method number($/) {
    say "number: " ~ $<value>;
    make +$<value>;
  }

  method string($/) {
    say "string: " ~ $<value>;
    make ~$<value>;
  }

}

my $t = ArrayListGrammar.parse( '{1,2,3}', :actions(ArrayListActions.new) );
die "Failed to parse" unless $t.defined;
say $t.ast.perl;

