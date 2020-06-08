use v6;
need DBDish;

unit class DBDish::Pg::StatementHandle does DBDish::StatementHandle;
use DBDish::Pg::Native;
use DBDish::Pg::ErrorHandling;

has PGconn $!pg_conn;
has Str $.statement-name;
has $.statement;
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
            :$!pg_conn,
            statement-handle => self,

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
    :$!statement, :$!statement-name = ''
) {
    if $!statement-name { # Prepared
        $!parent.protect-connection: {
            with $!pg_conn.PQdescribePrepared($!statement-name) -> $info {
                @!param_type.push($!parent.dynamic-types{$info.PQparamtype($_)}) for ^$info.PQnparams;
                self!get-meta($info);
                $info.PQclear;
            }
        };
    }
}

method execute(**@params --> DBDish::StatementHandle) {
    self!enter-execute(@params.elems, @!param_type.elems);

    $!parent.protect-connection: {
        my @param_values := ParamArray.new;
        for @params.kv -> $k, $v {
            if $v.defined {
                @param_values[$k] = @!param_type[$k] ~~ Buf
                        ?? $!pg_conn.escapeBytea(($v ~~ Buf) ?? $v !! ~$v.encode)
                        !! @!param_type[$k] ~~ Array ?? self.pg-array-str($v)
                        !! ~$v;
            } else { @param_values[$k] = Str }
        }

        $!result = $!statement-name
                ?? $!pg_conn.PQexecPrepared($!statement-name, @params.elems, @param_values,
                        Null, Null, 0)
                !! $!pg_conn.PQexec($!statement);

        self!set-err(PGRES_FATAL_ERROR, $!pg_conn.PQerrorMessage).fail unless $!result;

        $!current_row = 0;
        with self!handle-errors {
            my $rows;
            if $!result.PQresultStatus == PGRES_TUPLES_OK { # WAS SELECT
                self!get-meta($!result) without $!field_count;
                # Unprepared
                $rows = $!row_count = $!result.PQntuples;
            } else { # Other stmt without data to return
                $rows =  $!result.PQcmdTuples.Int;
            }
            self!done-execute($rows, $!field_count);
        } else {
            .fail;
        }
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
                    $value = _pg-to-array($value, ct.of, %Converter);
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
    rule TOP         { ^ <array> $ }
    rule array       { '{' ( <element> ','?)* '}' }
    rule element     { <array> | <quoted-string> | <null> | <unquoted-string>}

    # Quoted strings may contain any byte sequence except a null. Characters like " and \
    # are escaped by a \ and must be unescaped (\" => ", \\ => \)
    rule quoted-string   { '"' $<value>=( [<-[\\"]>||'\"'||'\\\\']* ) '"' }
    rule null            { "NULL" }
    rule unquoted-string { <-["{},]>+ }

};

sub _to-type($value, Mu:U $type) {
    with $value {
        $type($value);
    } else {
        $value;
    }
}

sub _to-array(Match $match, Mu:U $type, %Converter) {
    my $arr = Array[$type].new;
    my $clean = True;
    for $match.<array>.values -> $element {
        if $element.values[0]<array>.defined { # An array
            if $clean && $arr.of === $type { # Need to downgrade
                $arr = Array.new;
                $clean = False;
            }
            $arr.push: @(_to-array($element.values[0], $type, %Converter));
        } elsif $element.values[0]<quoted-string>.defined {
            my $val = ~$element.values[0]<quoted-string><value>;

            # Remove escape sequences
            $val ~~ s|'\\"'|"|;
            $val ~~ s|'\\\\'|\\|;

            $arr.push: %Converter.convert($val, $type);
        } elsif $element.values[0]<null>.defined {
            $arr.push: Nil;
        } else {
            # Every element will be of the expected datatype.
            my $val = ~$element.values[0]<unquoted-string>;
            $arr.push: %Converter.convert($val, $type);
        }
    }
    $arr;
}

sub _pg-to-array(Str $text, Mu:U $type, %Converter) {
    my $match = PgArrayGrammar.parse( $text );
    die "Failed to parse" unless $match.defined;
    _to-array($match, $type, %Converter);
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

method _free() { }

method finish() {
    with $!result {
        .PQclear;
        $_ = Nil;
    }
    $!Finished = True;
}

# vim: ft=perl6 et
