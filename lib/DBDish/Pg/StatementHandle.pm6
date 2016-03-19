use v6;
need DBDish;

unit class DBDish::Pg::StatementHandle does DBDish::StatementHandle;
use DBDish::Pg::Native;

has PGconn $!pg_conn;
has Str $!statement_name;
has $!statement;
has @!param_type;
has $!result;
has Int $!row_count;
has $!field_count;
has $!current_row = 0;

method !handle-errors {
    if $!result.is-ok {
        self.reset-err;
    } else {
        self!set-err($!result.PQresultStatus, $!pg_conn.PQerrorMessage);
    }
}

submethod BUILD(:$!parent!, :$!pg_conn, # Per protocol
    :$!statement, :$!statement_name, :@!param_type
) { }

method execute(*@params) {
    self!set-err( -1,
	"Wrong number of arguments to method execute: got @params.elems(), expected @!param_type.elems()"
    ) if @params != @!param_type;

    self!enter-execute;

    my @param_values := ParamArray.new;
    for @params.kv -> $k, $v {
	if $v.defined {
	    @param_values[$k] = (@!param_type[$k] ~~ Buf)
		?? $!pg_conn.escapeBytea(($v ~~ Buf) ?? $v !! ~$v.encode)
		!! ~$v;
	} else { @param_values[$k] = Str }
    }

    $!result = $!pg_conn.PQexecPrepared($!statement_name, @params.elems, @param_values,
        Null, # ParamLengths, NULL pointer == all text
        Null, # ParamFormats, NULL pointer == all text
        0,    # Resultformat, 0 == text
    );
    self!set-err(PGRES_FATAL_ERROR, $!pg_conn.PQerrorMessage).fail unless $!result;

    $!current_row = 0;
    with self!handle-errors {
	my $rows; my $was-select = True;
        if $!result.PQresultStatus == PGRES_TUPLES_OK { # WAS SELECT
	    without $!field_count {
		$!field_count = $!result.PQnfields;
		for ^$!field_count {
		    @!column-name.push($!result.PQfname($_));
		    @!column-type.push(%oid-to-type{$!result.PQftype($_)});
		}
	    }
            $rows = $!row_count = $!result.PQntuples;
        } else { # Other stmt without data to return
	    $rows =  $!result.PQcmdTuples.Int;
	    $was-select = False;
        }
	self!done-execute($rows, $was-select);
    } else {
        .fail;
    }
}

method _row() {
    my $l = ();
    if $!field_count && $!current_row < $!row_count {
        $l = do for ^$!field_count {
            my $value = @!column-type[$_];
            unless $!result.PQgetisnull($!current_row, $_) {
		$value = $!result.get-value($!current_row, $_, $value);
		if @!column-type[$_] ~~ Array {
		    $value = _pg-to-array($value, @!column-type[$_].of);
		}
            }
            $value;
    }
	self.finish if ++$!current_row == $!row_count;
    }
    $l;
}

my grammar PgArrayGrammar {
    rule array       { '{' (<element> ','?)* '}' }
    rule TOP         { ^ <array> $ }
    rule element     { <array> | <float> | <integer> | <string> }
    token float      { (\d+ '.' \d+) }
    token integer    { (\d+) }
    rule string      { '"' $<value>=( [\w|\s]+ ) '"' | $<value>=( \w+ ) }
};

sub _to-type($value, Mu:U $type) {
    if $value.defined {
        given $type {
            when 'Str' { ~$value }     # String;
            when 'Num' { Num($value) } # SQL Floating point
            when 'Rat' { Rat($value) } # SQL Numeric
            default    { Int($value) } # Must be
        }
    }
    else {
        $value;
    }
}

sub _to-array(Match $match, Mu:U $type) {
    my $arr = Array[$type].new;
    my $clean = True;
    for $match.<array>.values -> $element {
      if $element.values[0]<array>.defined { # An array
	  if $clean && $arr.of === $type { # Need to downgrade
	      $arr = Array.new; $clean = False;
	  }
          $arr.push: @(_to-array($element.values[0], $type));
      } elsif $element.values[0]<float>.defined { # Floating point number
          $arr.push: $type($element.values[0]<float>);
      } elsif $element.values[0]<integer>.defined { # Integer
          $arr.push: $type($element.values[0]<integer>);
      } else { # Must be a String
          $arr.push: ~$element.values[0]<string><value>;
      }
    }
    $arr;
}

sub _pg-to-array(Str $text, Mu:U $type) {
    my $match = PgArrayGrammar.parse( $text );
    die "Failed to parse" unless $match.defined;
    _to-array($match, $type);
}

method pg-array-str(@data) {
  my @tmp;
  for @data -> $c {
    if  $c ~~ Array {
      @tmp.push(self.pg-array-str($c));
    } else {
      if $c ~~ Numeric {
        @tmp.push($c);
      } else {
         my $t = $c.subst('"', '\\"');
         @tmp.push('"'~$t~'"');
      }
    }
  }
  '{' ~ @tmp.join(',') ~ '}';
}

method true_false(Str $s) {
    $s eq 't';
}

method _free() { }

method finish() {
    with $!result {
        .PQclear;
        $_ = Nil;
    }
    $!Finished = True;
}
