use v6;
need DBDish;

unit class DBDish::Pg::StatementHandle does DBDish::StatementHandle;
use DBDish::Pg::Native;
use DBDish::Pg::ErrorHandling;

has PGconn $!pg_conn;
has Str $!statement_name;
has $!statement;
has @!param_type;
has $!result;
has $!row_count;
has $!field_count;
has $!current_row = 0;

method !handle-errors {
    if $!result.is-ok {
        self.reset-err;
    } else {
        self!error-dispatch: X::DBDish::DBError::Pg.new(
            :code($!result.PQresultStatus),
            :native-message($!result.PQresultErrorField(PG_DIAG_MESSAGE_PRIMARY)),
            :driver-name<DBDish::Pg>,

            :result($!result),
        );
    }
}

submethod !get-meta($result) {
    if $!field_count = $result.PQnfields {
        for ^$!field_count {
            @!column-name.push: $result.PQfname($_);
            @!column-type.push: do {
                my $pt = $result.PQftype($_);
                if (my \t = $!parent.dynamic-types{$pt}) === Nil {
                    warn "No type map defined for postgresql type $pt at column $_";
                    Str;
                } else { t }
            }
        }
    }
}

submethod BUILD(:$!parent!, :$!pg_conn!, # Per protocol
    :$!statement, :$!statement_name = ''
) {
    if $!statement_name { # Prepared
        with $!pg_conn.PQdescribePrepared($!statement_name) -> $info {
            @!param_type.push($!parent.dynamic-types{$info.PQparamtype($_)}) for ^$info.PQnparams;
            self!get-meta($info);
            $info.PQclear;
        }
    }
}

method execute(*@params) {
    self!enter-execute(@params.elems, @!param_type.elems);

    my @param_values := ParamArray.new;
    for @params.kv -> $k, $v {
        if $v.defined {
            @param_values[$k] = @!param_type[$k] ~~ Buf
                ?? $!pg_conn.escapeBytea(($v ~~ Buf) ?? $v !! ~$v.encode)
                !! @!param_type[$k] ~~ Array ?? self.pg-array-str($v)
                !! ~$v;
        } else { @param_values[$k] = Str }
    }

    $!result = $!statement_name
        ?? $!pg_conn.PQexecPrepared($!statement_name, @params.elems, @param_values,
                                    Null, Null, 0)
        !! $!pg_conn.PQexec($!statement);

    if $!statement ~~ /:i insert.*returning/ {
      my @returns;

      my $count = 0;
      while $count < $!result.PQntuples {
        @returns.push: $!result.PQgetvalue($count++, 0);
      }

      return @returns;
    }

    self!set-err(PGRES_FATAL_ERROR, $!pg_conn.PQerrorMessage).fail unless $!result;

    $!current_row = 0;
    with self!handle-errors {
        my $rows;
        if $!result.PQresultStatus == PGRES_TUPLES_OK { # WAS SELECT
            self!get-meta($!result) without $!field_count; # Unprepared
            $rows = $!row_count = $!result.PQntuples;
        } else { # Other stmt without data to return
            $rows =  $!result.PQcmdTuples.Int;
        }
        self!done-execute($rows, $!field_count);
    } else {
        .fail;
    }
}

method _row() {
    my $l = ();
    if $!Executed && $!field_count && $!current_row < $!row_count {
        my $col = 0;
        my %Converter := $!parent.Converter;
        $l = do for @!column-type -> \ct {
            my $value = ct;
            unless $!result.PQgetisnull($!current_row, $col) {
                $value = $!result.PQgetvalue($!current_row, $col);
                if ct ~~ Array {
                    $value = _pg-to-array($value, ct.of);
                } elsif (ct.^name ne 'Any') {
                    $value = %Converter.convert($value, ct);
                }
            }
            $col++;
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
    with $value {
        $type($value);
    } else {
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

method pg-array-str(\arr) {
    my @tmp;
    my @data := arr ~~ Array ?? arr !! [ arr ];
    for @data -> $c {
        if $c ~~ Array {
            @tmp.push(self.pg-array-str($c));
        } elsif $c ~~ Numeric {
            @tmp.push($c);
        } else {
            my $t = $c.subst('"', '\\"');
            @tmp.push('"'~$t~'"');
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

# vim: ft=perl6 et
