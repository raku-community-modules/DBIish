use v6;
need DBDish;

unit class DBDish::mysql::StatementHandle does DBDish::StatementHandle;
use DBDish::mysql::Native;
use NativeHelpers::Blob;
use NativeHelpers::CStruct;

has MYSQL $!mysql_client is required;
has MYSQL_STMT $!stmt;
has int $!param-count;
has $!statement;
has MYSQL_RES $!result_set;
has $!field_count;
has Bool $.Prefetch;
# For prepared stmts
has $!par-binds;
has $!in-lengths;
has $!binds;
has @!out-bufs;
has $!out-lengths;
has $!isnull;

method !handle-errors {
    if $!mysql_client.mysql_errno -> $code {
        self!set-err($code, $!mysql_client.mysql_error);
    } else {
        self.reset-err;
    }
}

method !get-meta(MYSQL_RES $res) {
    my $lengths = blob-allocate(Buf[int64], $!field_count);
    loop (my $i = 0; $i < $!field_count; $i++) {
        with $res.mysql_fetch_field {
            @!column-name.push: .name;
            if (my \t = %mysql-type-conv{.type}) === Any {
                warn "No type map defined for mysql type #{.type} at column $i";
                t = Str;
            }
            @!column-type.push: t;
            $lengths[$i] = .length;
        }
        else { die 'mysql: Opps! mysql_fetch_field'; }
    }
    $lengths;
}

submethod BUILD(:$!mysql_client!, :$!parent!, :$!stmt = MYSQL_STMT,
    :$!statement, Bool :$!Prefetch = True
) {
    with $!stmt { #Prepared
        if $!param-count = .mysql_stmt_param_count -> $pc {
            $!par-binds = LinearArray[MYSQL_BIND].new($pc);
            my $lb = BPointer(
                $!in-lengths = blob-allocate(Buf[int64], $pc)
            ).Int;
            $!par-binds[$_].length = $lb + $_ * 8 for ^$pc;
        }
        if ($!field_count = .mysql_stmt_field_count) && .mysql_stmt_result_metadata -> $res {
            $!binds = LinearArray[MYSQL_BIND].new($!field_count);
            my $lb = BPointer($!out-lengths = self!get-meta($res)).Int;
            $!isnull = blob-allocate(Buf[int64], $!field_count);
            my $nb = BPointer($!isnull).Int;
            for ^$!field_count -> $col {
                given $!binds[$col] {
                    if .buffer_length = $!out-lengths[$col] {
                        @!out-bufs[$col] = blob-allocate(Buf, $!out-lengths[$col]);
                        .buffer = BPointer(@!out-bufs[$col]).Int;
                        .length = $lb + $col * 8;
                        .is_null = $nb + $col * 8;
                        .buffer_type = @!column-type[$col] ~~ Blob
                            ?? MYSQL_TYPE_BLOB !! MYSQL_TYPE_STRING;
                    } else {
                        $!isnull[$col] = 1;
                        .buffer_type = MYSQL_TYPE_NULL
                    }
                }
            }
            $!result_set = $res; # To be free at finish time;
            $!stmt.mysql_stmt_bind_result($!binds.typed-pointer);
        }
        without self!handle-errors { .fail }
    }
    else {
        $!param-count = 0;
    }
}

method execute(*@params) {
    self!enter-execute(@params.elems, $!param-count);
    if $!stmt { # Prepared
        if $!param-count {
            my @Bufs;
            for @params.kv -> $k, $v { # The binding dance
                with $v {
                    my $st = MYSQL_TYPE_STRING;
                    @Bufs[$k] = do {
                        when Blob { $st = MYSQL_TYPE_BLOB; $_ }
                        when Str  { .encode }
                        when Int  { $st = MYSQL_TYPE_LONGLONG; Blob[int64].new($_) }
                        default   { .Str.encode }
                    };
                    given $!par-binds[$k] {
                        .buffer_length = $!in-lengths[$k] = $@Bufs[$k].bytes;
                        .buffer = BPointer(@Bufs[$k]).Int;
                        .buffer_type = $st;
                    }
                } else { # Null;
                    $!par-binds[$k].buffer_type = MYSQL_TYPE_NULL;
                }
            }
            $!stmt.mysql_stmt_bind_param($!par-binds.typed-pointer)
        }
        $!stmt.mysql_stmt_execute
        or $!Prefetch
        and $!stmt.mysql_stmt_store_result;
        without self!handle-errors { .fail }
    }
    else { # Unprepared path
        my $status = $!mysql_client.mysql_query($!statement)
            and self!set-err($status, $!mysql_client.mysql_error).fail;

        $_ = $!mysql_client.mysql_field_count without $!field_count;

        if $!field_count {
            $!result_set = $!Prefetch ?? $!mysql_client.mysql_store_result
                                      !! $!mysql_client.mysql_use_result;
            .fail without self!handle-errors;
            self!get-meta($!result_set) unless $!Executed; # First execution
        }
    }
    my $rows = $!mysql_client.mysql_affected_rows;
    $rows++ if $rows == -1;
    self!done-execute($rows, $!field_count);
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

method _row {
    my $list = ();
    if $!field_count -> $fields {
        my $row;
        with $!stmt {
            if .mysql_stmt_fetch == 0 { # Has data
                $list = do for ^$fields {
                    my $val = my $t = @!column-type[$_];
                    unless $!isnull[$_] {
                        my $len = $!out-lengths[$_];
                        if $t ~~ Blob {
                            $val = @!out-bufs[$_].subbuf(0,$len);
                        } else {
                            $val = @!out-bufs[$_].subbuf(0,$len).decode;
                            $val = $t($val) if $t !~~ Str;
                        }
                    }
                    $val;
                }
                $row = True;
            }
        } elsif $row = $!result_set.fetch_row {
            $list = do for ^$fields { $row.want($_, @!column-type[$_]) }
            $!affected_rows++ unless $!Prefetch;
        }
        unless $row {
            .fail without self!handle-errors;
            self.finish;
        }
    }
    $list;
}

method mysql_insertid() {
    $!mysql_client.mysql_insert_id;
}

method mysql_warning_count {
    $!mysql_client.mysql_warning_count;
}

method _free() {
    with $!stmt {
        with $!binds {
            .dispose;
            @!out-bufs = ();
        }
        .dispose with $!par-binds;
        .mysql_stmt_close;
        $_ = Nil;
    }
}

method finish() {
    with $!stmt {
        .mysql_stmt_free_result;
        .mysql_stmt_reset;
    }
    with $!result_set {
        .mysql_free_result;
        $_ = Nil;
    }
    $!Finished = True; # Per protocol
}
