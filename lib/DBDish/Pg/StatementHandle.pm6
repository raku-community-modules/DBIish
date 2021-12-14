use v6;
need DBDish;

unit class DBDish::Pg::StatementHandle does DBDish::StatementHandle;
use DBDish::Pg::Native;
use DBDish::Pg::ErrorHandling;

has PGconn $!pg-conn;
has Str $.statement-name;
has $.statement;
has @!param-type;
has $!result;
has $!row-count;
has $!field-count;
has $!current-row = 0;

has @!import-func;

method !handle-errors {
    if $!result.is-ok {
        self.reset-err;
    } else {
        self!error-dispatch: X::DBDish::DBError::Pg.new(
            :code($!result.PQresultStatus),
            :native-message($!result.PQresultErrorField(PG_DIAG_MESSAGE_PRIMARY)),
            :driver-name<DBDish::Pg>,
            :$!pg-conn,
            statement-handle => self,

            :result($!result),
        );
    }
}

submethod !get-meta($result) {
    if $!field-count = $result.PQnfields {
        for ^$!field-count -> $col {
            @!column-name.push: $result.PQfname($col);

            my $pt = $result.PQftype($col);
            my $type;
            if ($type = $!parent.dynamic-types{$pt}) === Nil {
                warn "No type map defined for postgresql type $pt at column $col";
                $type = Str;
            }

            @!column-type.push($type);
        }
    }
}

submethod BUILD(:$!parent!, :$!pg-conn!, # Per protocol
    :$!statement, :$!statement-name = ''
) {
    if $!statement-name { # Prepared
        $!parent.protect-connection: {
            with $!pg-conn.PQdescribePrepared($!statement-name) -> $info {
                @!param-type.push($!parent.dynamic-types{$info.PQparamtype($_)}) for ^$info.PQnparams;
                self!get-meta($info);
                $info.PQclear;
            }
        };
    }
}

method execute(**@params --> DBDish::StatementHandle) {
    self!enter-execute(@params.elems, @!param-type.elems);

    my %Converter := $!parent.Converter-To-DB;

    $!parent.protect-connection: {
        my @param-values := ParamArray.new;
        for @params.kv -> $k, $val {
            if $val.defined {
                my $have-type = $val.WHAT;
                if $have-type ~~ Array {
                    @param-values[$k] = self.pg-array-str($val);
                } else {
                    @param-values[$k] = %Converter.convert($val);
                }
            } else {
                @param-values[$k] = Str;
            }
        }

        $!result = $!statement-name
                ?? $!pg-conn.PQexecPrepared($!statement-name, @params.elems, @param-values,
                        Null, Null, 0)
                !! $!pg-conn.PQexec($!statement);

        self!set-err(PGRES_FATAL_ERROR, $!pg-conn.PQerrorMessage).fail unless $!result;

        $!current-row = 0;
        with self!handle-errors {
            my $rows;
            if $!result.PQresultStatus == PGRES_TUPLES_OK { # WAS SELECT
                self!get-meta($!result) without $!field-count;
                # Unprepared
                $rows = $!row-count = $!result.PQntuples;
            } else { # Other stmt without data to return
                $rows =  $!result.PQcmdTuples.Int;
            }
            self!done-execute($rows, $!field-count);
        } else {
            .fail;
        }
    }
}

method _row() {
    # Cache type conversion functions. Allow column-type to be configured by the client
    # after prepare/execute
    if @!import-func.elems != $!field-count {
        my %Converter := $!parent.Converter-From-DB;

        for @!column-type -> $type {
            @!import-func.push: do {
                if $type ~~ Array {
                    sub ($value) {
                        _pg-to-array($value, $type.of, %Converter)
                    }
                } elsif ($type.^name ne 'Any') {
                    %Converter.convert-function($type);
                } else {
                    sub ($value) {
                        $value
                    };
                }
            }
        }
    }

    my @l;
    if $!Executed && $!field-count && $!current-row < $!row-count {
        my $col = 0;
        for @!import-func -> $func {
            my $value = @!column-type[$col];
            unless $!result.PQgetisnull($!current-row, $col) {
                $value = $func($!result.PQgetvalue($!current-row, $col));
            }

            $col++;
            @l.push($value);
        }
        self.finish if ++$!current-row == $!row-count;
    }
    @l;
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
            $val = $val.subst('\\"', '"', :g).subst('\\\\', '\\', :g);

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
    my %Converter := $!parent.Converter-To-DB;

    my @tmp;
    my @data := arr ~~ Array ?? arr !! [ arr ];
    for @data -> $c {
        if $c ~~ Array {
            @tmp.push(self.pg-array-str($c));
        } else {
            # Convert $c from Raku object value to DB string value if necessary.
            my $t = %Converter.convert($c);

            # Escape the converted value and push it into the array string.
            $t = $t.subst('\\', '\\\\', :g).subst('"', '\\"', :g);
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
