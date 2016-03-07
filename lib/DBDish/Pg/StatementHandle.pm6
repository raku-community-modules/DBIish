use v6;
need DBDish;

unit class DBDish::Pg::StatementHandle does DBDish::StatementHandle;
use DBDish::Pg::Native;

has PGconn $!pg_conn;
has Str $!statement_name;
has $!statement;
has @!param_type;
has $!result;
has $!affected_rows;
has @!column_names;
has @!column_type;
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

method execute(*@params is copy) {
    self!set-err( -1,
	"Wrong number of arguments to method execute: got @params.elems(), expected @!param_type.elems()"
    ) if @params != @!param_type;
    my @param_values := ParamArray.new;
    for @params.kv -> $k, $v {
	if $v.defined {
	    @param_values[$k] = (@!param_type[$k] ~~ Buf)
		?? $!pg_conn.escapeBytea(($v ~~ Buf) ?? $v !! ~$v.encode)
		!! ~$v;
	} else { Str }
    }

    $!result = $!pg_conn.PQexecPrepared($!statement_name, @params.elems, @param_values,
        Null, # ParamLengths, NULL pointer == all text
        Null, # ParamFormats, NULL pointer == all text
        0,    # Resultformat, 0 == text
    );
    self!set-err(PGRES_FATAL_ERROR, $!pg_conn.PQerrorMessage).fail unless $!result;

    $!current_row = 0;
    $!affected_rows = Nil;
    with self!handle-errors {
        $!Executed++;
        if $!result.PQresultStatus == PGRES_TUPLES_OK { # WAS SELECT
	    without $!field_count {
		$!field_count = $!result.PQnfields;
		for ^$!field_count {
		    @!column_names.push($!result.PQfname($_));
		    @!column_type.push(%oid-to-type{$!result.PQftype($_)});
		}
	    }
            with $!row_count = $!result.PQntuples {
		$!affected_rows = $_ == 0 ?? '0E0' !! $_;
	    }
        } else { # Other stmt without data to return
	    with $!result.PQcmdTuples.Int {
		$!affected_rows = $_ == 0 ?? '0E0' !! $_;
	    }
	    self.finish;
        }
        self.rows;
    } else {
        .fail;
    }
}

# do() and execute() return the number of affected rows directly or:
# rows() is called on the statement handle $sth.
method rows() {
    $!affected_rows;
}

method _row(:$hash) {
    my @row_array;
    my %ret_hash;
    if $!field_count && $!current_row < $!row_count {
        for ^$!field_count {
            my $value = @!column_type[$_];
            if ! $!result.PQgetisnull($!current_row, $_) {
		$value = $!result.get-value($!current_row, $_, $value);
		if @!column_type[$_] ~~ Array {
		    $value := _pg-to-array( $value, $_.of.^name );
		}
            }
            $hash ?? (%ret_hash{@!column_names[$_]} = $value)
	          !! @row_array.push($value);
        }
	self.finish if ++$!current_row == $!row_count;
    }
    $hash ?? %ret_hash !! @row_array;
}

method fetchrow() {
    my @row_array;
    if $!field_count && $!current_row < $!row_count {
	@row_array.push($!result.PQgetisnull($!current_row, $_) ?? Str
		        !! $!result.PQgetvalue($!current_row, $_)
	) for ^$!field_count;
	self.finish if ++$!current_row == $!row_count;
    }
    @row_array;
}

method column_names {
    @!column_names;
}

method column_type {
    @!column_type;
}

method fetchall_hashref(Str $key) {
    my %results;

    return () if $!current_row >= $!row_count;

    while my $row = self.fetchrow_hashref {
        %results{$row{$key}} = $row;
    }

    my $results_ref = %results;
    $results_ref;
}

my grammar PgArrayGrammar {
    rule array       { '{' (<element> ','?)* '}' }
    rule TOP         { ^ <array> $ }
    rule element     { <array> | <float> | <integer> | <string> }
    token float      { (\d+ '.' \d+) }
    token integer    { (\d+) }
    rule string      { '"' $<value>=( [\w|\s]+ ) '"' | $<value>=( \w+ ) }
};

sub _to-type($value, Str $type where $_ eq any([ 'Str', 'Num', 'Rat', 'Int' ])) {
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

sub _to-array(Match $match, Str $type where $_ eq any([ 'Str', 'Num', 'Rat', 'Int' ])) {
    my @array;
    for $match.<array>.values -> $element {
      if $element.values[0]<array>.defined {
          # An array
          push @array, _to-array( $element.values[0], $type );
      } elsif $element.values[0]<float>.defined {
          # Floating point number
          push @array, _to-type( $element.values[0]<float>, $type );
      } elsif $element.values[0]<integer>.defined {
          # Integer
          push @array, _to-type( $element.values[0]<integer>, $type );
      } else {
          # Must be a String
          push @array, _to-type( $element.values[0]<string><value>, $type );
      }
    }

    @array;
}

sub _pg-to-array(Str $text, Str $type where $_ eq any([ 'Str', 'Rat', 'Int' ])) {
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

method finish() {
    if $!result {
        $!result.PQclear;
        $!result        = Nil;
    }
    $!Finished = True;
}
