use v6;
need DBDish;

unit class DBDish::mysql::StatementHandle does DBDish::StatementHandle;
use DBDish::mysql::Native;
use NativeHelpers::Blob;
use NativeHelpers::CStruct;

has MYSQL $!mysql-client;
has MYSQL_STMT $!stmt;
has int $!param-count;
has $.statement;
has MYSQL_RES $!result-set;
has $!field-count;
has Bool $.Prefetch;
# For prepared stmts
has $!par-binds;
has $!in-lengths;
has $!binds;
has @!out-bufs;
has $!out-lengths;
has $!isnull;

method !handle-errors {
    if $!mysql-client.mysql_errno -> $code {
        self!set-err($code, $!mysql-client.mysql_error);
    } else {
        self.reset-err;
    }
}

method !get-meta(MYSQL_RES $res) {
    my $lengths = blob-allocate(Buf[intptr], $!field-count);
    loop (my $i = 0; $i < $!field-count; $i++) {
        with $res.mysql_fetch_field {
            @!column-name.push: .name;
            @!column-type.push: do {
                my $pt = .type;
                if (my \t = $!parent.dynamic-types{$pt}) === Nil {
                    warn "No type map defined for mysql type #$pt at column $i";
                    Str;
                } else { t }
            }
            $lengths[$i] = .length;
        }
        else { die 'mysql: Opps! mysql_fetch_field'; }
    }
    $lengths;
}

submethod BUILD(:$!mysql-client!, :$!parent!, :$!stmt = MYSQL_STMT,
    :$!statement, Bool :$!Prefetch = True
) {
    with $!stmt { #Prepared
        if $!param-count = .mysql_stmt_param_count -> $pc {
            $!par-binds = LinearArray[MYSQL_BIND].new($pc);
            my $lb = BPointer(
                $!in-lengths = blob-allocate(Buf[intptr], $pc)
            ).Int;
            $!par-binds[$_].length = $lb + $_ * ptrsize for ^$pc;
        }
        if ($!field-count = .mysql_stmt_field_count) && .mysql_stmt_result_metadata -> $res {
            $!binds = LinearArray[MYSQL_BIND].new($!field-count);
            my $lb = BPointer($!out-lengths = self!get-meta($res)).Int;
            $!isnull = blob-allocate(Buf[intptr], $!field-count);
            my $nb = BPointer($!isnull).Int;
            for ^$!field-count -> $col {
                given $!binds[$col] {
                    if .buffer_length = $!out-lengths[$col] {
                        # The buffer requested is the maximum size for the datatype which may be several
                        # GBs in size. Start with a low size and increase the buffer size as needed during
                        # retrieval.
                        if $!out-lengths[$col] > 8192 {
                            $!out-lengths[$col] = 8192;
                            .buffer_length = $!out-lengths[$col];
                        }
                        @!out-bufs[$col] = blob-allocate(Buf, $!out-lengths[$col]);
                        .buffer = BPointer(@!out-bufs[$col]).Int;
                        .length = $lb + $col * ptrsize;
                        .is_null = $nb + $col * ptrsize;
                        .buffer_type = @!column-type[$col] ~~ Blob
                                ?? MYSQL_TYPE_BLOB !! MYSQL_TYPE_STRING;
                    } else {
                        $!isnull[$col] = 1;
                        .buffer_type = MYSQL_TYPE_NULL;
                    }
                }
            }
            $!result-set = $res; # To be free at finish time;
            $!stmt.mysql_stmt_bind_result($!binds.typed-pointer);
        }
        without self!handle-errors { .fail }
    }
    else {
        $!param-count = 0;
    }
}

method execute(*@params --> DBDish::StatementHandle) {
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
                        when DateTime {
                            # mysql knows nothing of timezones, all assumed local-time
                            # but in Windows the parser chokes with the offset,
                            # and the version in TravisCI chokes with 'T', so
                            # we should remove it. See _row for the reverse
                            my $l = .local.Str;
                            $l .= subst(/ 'T' /,' ');
                            $l .= subst(/ <[\-\+]>\d\d ':' \d\d /,'');
                            $l .= subst(/ 'Z' /,''); # .local with Z !?
                            $l.encode;
                        }
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
            $!stmt.mysql_stmt_bind_param($!par-binds.typed-pointer);
            without self!handle-errors { .fail }
        }
        $!parent.protect-connection: {
            $!stmt.mysql_stmt_execute
              or $!Prefetch
              and $!stmt.mysql_stmt_store_result;
        }
        without self!handle-errors { .fail }
    }
    else { # Unprepared path
        $!parent.protect-connection: {
            my $status = $!mysql-client.mysql_query($!statement)
                    and self!set-err($status, $!mysql-client.mysql_error).fail;

            $_ = $!mysql-client.mysql_field_count without $!field-count;

            if $!field-count {
                $!result-set = $!Prefetch ?? $!mysql-client.mysql_store_result
                        !! $!mysql-client.mysql_use_result;
                .fail without self!handle-errors;
                self!get-meta($!result-set) unless $!Executed; # First execution
            }
        }
    }
    my $rows = $!mysql-client.mysql_affected_rows;
    $rows++ if $rows == -1;
    self!done-execute($rows, $!field-count);
}

method escape(|a) {
    $!mysql-client.escape(a);
}

multi method quote(Str $x) {
    q['] ~ $!mysql-client.escape($x) ~ q['];
}

multi method quote(Blob $b) {
    "X'" ~ $!mysql-client.escape($b,:bin) ~ "'";
}

method _row {
    my $list = ();
    if $!field-count -> $fields {
        my %Converter := $!parent.Converter;
        my $row;
        with $!stmt {
            my $ret = .mysql_stmt_fetch;
            if $ret == 0 or $ret == 101 { # Has data, possibly truncated
                $list = do for ^$fields {
                    my $val = my $t = @!column-type[$_];
                    if $!isnull[$_] {
                        $val;
                    } else {
                        # Re-allocate buffer if the value is larger than the buffer previously allocated
                        # Overallocate by 10% reduce number of reallocations if all tuples are close to but not exactly
                        # the same size.
                        if $!out-lengths[$_] > $!binds[$_].buffer_length {
                            @!out-bufs[$_] = blob-allocate(Buf, $!out-lengths[$_] * 1.1);
                            $!binds[$_].buffer = BPointer(@!out-bufs[$_]).Int;
                            $!binds[$_].buffer_length = $!out-lengths[$_];

                            # Fetch the specific column of interest.
                            if $!stmt.mysql_stmt_fetch_column($!binds.typed-pointer, $_, 0) != 0 {
                                .fail without self!handle-errors;
                            }
                        }

                        my $len = $!out-lengths[$_];
                        $val = @!out-bufs[$_].subbuf(0,$len);
                        if $t ~~ Blob {
                            # Don't touch
                        } elsif ($t.^name ne 'Any') {
                            $val = %Converter.convert($val.decode, $t);
                        }
                        $val;
                    }
                }
                $row = True;
            }
        } elsif $row = $!result-set.fetch_row {
            # Differs from .mysql_stmt_fetch case in handling of NULLS and pulling the value out of the buffer.
            $list = do for ^$fields {
                my $t = @!column-type[$_];
                my $val = $row.want($_, $t);

                if $t ~~ Blob {
                    # Don't touch
                } elsif ($t.^name ne 'Any') {
                    $val = %Converter.convert($val, $t);
                }
                $val;
            }
            $!affected_rows++ unless $!Prefetch;
        }
        unless $row {
            .fail without self!handle-errors;
            self.finish;
        }
    }
    $list;
}

method insert-id() {
    self!ftr;
    with $!stmt {
        $!stmt.mysql_stmt_insert_id;
    } else {
        $!mysql-client.mysql_insert_id;
    }
}

method mysql_insertid is DEPRECATED('insert-id'){
    self.insert-id;
}

method mysql_warning_count {
    $!mysql-client.mysql_warning_count;
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
    with $!result-set {
        .mysql_free_result;
        $_ = Nil;
    }
    $!Finished = True; # Per protocol
}
