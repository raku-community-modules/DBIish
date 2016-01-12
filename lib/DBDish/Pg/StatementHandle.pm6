
use v6;
use NativeCall;

need DBDish::Role::StatementHandle;
use DBDish::Pg::Native;

unit class DBDish::Pg::StatementHandle does DBDish::Role::StatementHandle;

has $!pg_conn;
has Str $!statement_name;
has $!statement;
has $!param_count;
has $.dbh;
has $!result;
has $!affected_rows;
has @!column_names;
has Int $!row_count;
has $!field_count;
has $!current_row = 0;

method !handle-errors {
    my $status = PQresultStatus($!result);
    if status-is-ok($status) {
        self!reset_errstr;
        return True;
    }
    else {
        self!set_errstr(PQresultErrorMessage($!result));
        die self.errstr if $.RaiseError;
        return Nil;
    }
}

method !munge_statement {
    my $count = 0;
    $!statement.subst(:g, '?', { '$' ~ ++$count});
}

submethod BUILD(:$!statement, :$!pg_conn, :$!statement_name, :$!param_count,
       :$!dbh) {
}
method execute(*@params is copy) {
    $!current_row = 0;
    die "Wrong number of arguments to method execute: got @params.elems(), expected $!param_count" if @params != $!param_count;
    my @param_values := CArray[Str].new;
    for @params.kv -> $k, $v {
        @param_values[$k] = $v.Str;
    }

    $!result = PQexecPrepared($!pg_conn, $!statement_name, @params.elems,
            @param_values,
            OpaquePointer, # ParamLengths, NULL pointer == all text
            OpaquePointer, # ParamFormats, NULL pointer == all text
            0,             # Resultformat, 0 == text
    );

    self!handle-errors;
    $!row_count = PQntuples($!result);

    my $rows = self.rows;
    return ($rows == 0) ?? "0E0" !! $rows;
}

# do() and execute() return the number of affected rows directly or:
# rows() is called on the statement handle $sth.
method rows() {
    unless defined $!affected_rows {
        $!affected_rows = PQcmdTuples($!result);

        self!handle-errors;
    }

    if defined $!affected_rows {
        return +$!affected_rows;
    }
}

method _row(:$hash) {
    my @row_array;
    my %ret_hash;
    return Any if $!current_row >= $!row_count;

    unless defined $!field_count {
        $!field_count = PQnfields($!result);
    }
    my @names = self.column_names if $hash;
    my @types = self.column_p6types;
    if defined $!result {
        self!reset_errstr;
        my $afield = False;
        for ^$!field_count {
            FIRST {
                $afield = True;
            }
            my $res := PQgetvalue($!result, $!current_row, $_);
            if $res eq '' {
                $res := Str if PQgetisnull($!result, $!current_row, $_)
            }
            my $value;
            given (@types[$_]) {
                when 'Str' {
                  $value = $res
                }
                when 'Num' {
                  $value = $res.Num
                }
                when 'Int' {
                  $value = $res.Int
                }
                when 'Bool' {
                  $value = self.true_false($res)
                }
                when 'Real' {
                  $value = $res.Real
                }
                when 'Array<Int>' {
                  $value := _pg-to-array( $res, 'Int' );
                }
                when 'Array<Str>' {
                  $value := _pg-to-array( $res, 'Str' );
                }
                when 'Array<Num>' {
                  $value := _pg-to-array( $res, 'Num' );
                }
                default {
                  $value = $res;
                }
            }
            $hash ?? (%ret_hash{@names[$_]} = $value) !! @row_array.push($value);
        }
        $!current_row++;
        self!handle-errors;

        if ! $afield { self.finish; }
    }
    $hash ?? return %ret_hash !! return @row_array;
}


method fetchrow() {
    my @row_array;
    return () if $!current_row >= $!row_count;

    unless defined $!field_count {
        $!field_count = PQnfields($!result);
    }

    if defined $!result {
        self!reset_errstr;

        for ^$!field_count {
            my $res := PQgetvalue($!result, $!current_row, $_);
            if $res eq '' {
                $res := Str if PQgetisnull($!result, $!current_row, $_)
            }
            @row_array.push($res)
        }
        $!current_row++;
        self!handle-errors;

        if ! @row_array { self.finish; }
    }
    return @row_array;
}

method column_names {
    $!field_count = PQnfields($!result);
    unless @!column_names {
        for ^$!field_count {
            my $column_name = PQfname($!result, $_);
            @!column_names.push($column_name);
        }
    }
    @!column_names
}

# for debugging only so far
method column_oids {
    $!field_count = PQnfields($!result);
    my @res;
    for ^$!field_count {
        @res.push: PQftype($!result, $_);
    }
    @res;
}

method fetchall_hashref(Str $key) {
    my %results;

    return () if $!current_row >= $!row_count;

    while my $row = self.fetchrow_hashref {
        %results{$row{$key}} = $row;
    }

    my $results_ref = %results;
    return $results_ref;
}

method column_p6types {
   my @types = self.column_oids;
   return @types.map:{%oid-to-type-name{$_}};
}

my grammar PgArrayGrammar {
    rule array        { '{' (<element> ','?)* '}' }
    rule TOP         { ^ <array> $ }
    rule element      { <array> | <float> | <integer> | <string> }
    token float        { (\d+ '.' \d+) }
    token integer      { (\d+) }
    rule string       { '"' $<value>=( [\w|\s]+ ) '"' | $<value>=( \w+ ) }
};

sub _to-type($value, Str $type where $_ eq any([ 'Str', 'Num', 'Int' ])) {
  return $value unless $value.defined;
  if $type eq 'Str' {
      # String
      return ~$value;
  } elsif $type eq 'Num' {
      # Floating point number
      return Num($value);
  } else {
      # Must be Int
      return Int($value);
  }
}

sub _to-array(Match $match, Str $type where $_ eq any([ 'Str', 'Num', 'Int' ])) {
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

    return @array;
}

sub _pg-to-array(Str $text, Str $type where $_ eq any([ 'Str', 'Num', 'Int' ])) {
    my $match = PgArrayGrammar.parse( $text );
    die "Failed to parse" unless $match.defined;
    return _to-array($match, $type);
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
  return '{' ~ @tmp.join(',') ~ '}';
}

method true_false(Str $s) {
    return $s eq 't';
}


method finish() {
    if defined($!result) {
        PQclear($!result);
        $!result       = Any;
        @!column_names = ();
    }
    return Bool::True;
}

method !get_row {
    my @data;
    for ^$!field_count {
        @data.push(PQgetvalue($!result, $!current_row, $_));
    }
    $!current_row++;

    return @data;
}
