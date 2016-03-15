use v6;
need DBDish;

unit class DBDish::mysql::StatementHandle does DBDish::StatementHandle;
use DBDish::mysql::Native;

has MYSQL $!mysql_client is required;
has $!statement;
has MYSQL_RES $!result_set;
has $!field_count;
has $.mysql_warning_count is rw = 0;
has Bool $.Prefetch;

method !handle-errors {
    if $!mysql_client.mysql_errno -> $code {
        self!set-err($code, $!mysql_client.mysql_error);
    } else {
        self.reset-err;
    }
}

submethod BUILD(:$!mysql_client!, :$!parent!, :$!statement, Bool :$!Prefetch = True) { }

method execute(*@params is copy) {
    my $statement = '';
    my @chunks = $!statement.split('?', @params + 1);
    my $last-chunk = @chunks.pop;
    for @chunks {
        $statement ~= $_;
        my $param = @params.shift;
        if $param.defined {
            if $param ~~ Real {
                $statement ~= $param
            }
            else {
                $statement ~= self.quote($param);
            }
        }
        else {
            $statement ~= 'NULL';
        }
    }
    $statement ~= $last-chunk;
    self!enter-execute;
    if my $status = $!mysql_client.mysql_query($statement) { # 0 means OK
        self!set-err($status, $!mysql_client.mysql_error);
    } else {
        $.mysql_warning_count = $!mysql_client.mysql_warning_count;
        my $rows = 0; my $was-select = True;
        without $!field_count { # First execution
            if $!field_count = $!mysql_client.mysql_field_count {
                # Was SELECT, so should be a result set.
                with $!result_set = self!get_result {
                    loop (my $i = 0; $i < $!field_count; $i++) {
                        with $_.mysql_fetch_field {
                            @!column-name.push: .name;
                            if (my \t = %mysql-type-conv{.type}) === Any {
                                warn "No type map defined for mysql type #{.type} at column $i";
                                t = Str;
                            }
                            @!column-type.push: t;
                        }
                        else { die 'mysql: Opps! mysql_fetch_field'; }
                    }
                    $rows = $!mysql_client.mysql_affected_rows;
                }
                else {
                    .fail without self!handle-errors;
                }
            }
        }
        if $!field_count == 0 { # Not a SELECT
            $rows = $!mysql_client.mysql_affected_rows;
            $was-select = False;
        }
        elsif $!Executed {
            # Get the new one
            $!result_set = self!get_result;
            .fail without self!handle-errors;
            $rows = $!mysql_client.mysql_affected_rows;
        }
        $rows++ if $rows == -1;
        self!done-execute($rows, $was-select);
    }
}

method escape(|a) {
    $!mysql_client.escape(a);
}

multi method quote(Str $x) {
    q['] ~ $!mysql_client.escape($x) ~ q['];
}

multi method quote(Blob $b) {
    "X'" ~ $!mysql_client.escape($b,:bin) ~ "'";
}

method !get_result {
    $!Prefetch ?? $!mysql_client.mysql_store_result !! $!mysql_client.mysql_use_result;
}

method _row(:$hash) {
    my @row_array;
    my %hash;
    my @names;
    my @types;

    if $!field_count -> $fields {
        if my $row = $!result_set.fetch_row {
            loop (my int $i = 0; $i < $fields; $i++) {
                my $value = $row.want($i, @!column-type[$i]);
                $hash ?? (%hash{@!column-name[$i]} = $value) !! @row_array.push($value);
            }
            $!affected_rows++ unless $!Prefetch;
        }
        else {
            .fail without self!handle-errors;
            self.finish;
        }
    }
    $hash ?? %hash !! @row_array;
}

method fetchrow() {
    my @row_array;
    if $!field_count {
        if my $native_row = $!result_set.fetch_row {
            loop (my int $i=0; $i < $!field_count; $i++ ) {
                @row_array.push($native_row[$i]);
            }
            $!affected_rows++ unless $!Prefetch;
        }
        else {
            .fail without self!handle-errors;
            self.finish;
        }
    }
    @row_array;
}

method mysql_insertid() {
    $!mysql_client.mysql_insert_id;
}

method _free() {
}

method finish() {
    with $!result_set {
        .mysql_free_result;
        $_ = Nil;
    }
    $!Finished = True; # Per protocol
}
