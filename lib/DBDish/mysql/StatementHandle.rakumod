use v6;
need DBDish;

unit class DBDish::mysql::StatementHandle does DBDish::StatementHandle;
use DBDish::mysql::Native;
use DBDish::mysql::ErrorHandling;
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
has @!import-func;

method !handle-errors {
    if $!mysql-client.mysql_errno -> $code {
        self!error-dispatch: X::DBDish::DBError::mysql.new(
                :code($!mysql-client.mysql_errno),
                :native-message($!mysql-client.mysql_error),
                :driver-name<DBDish::mysql>,
                statement-handle => self,

                :sqlstate($!mysql-client.mysql_sqlstate),
                );
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
                        when Int  {
                            # Handle anything larger than int64 as a string.
                            if -2**63 <= $_ <= 2**63 -1 {
                                $st = MYSQL_TYPE_LONGLONG;
                                Blob[int64].new($_);
                            } else {
                                $st = MYSQL_TYPE_NEWDECIMAL;
                                .Str.encode;
                            }
                        }
                        when Num {
                            $st = MYSQL_TYPE_DOUBLE;
                            my $buf = buf8.new();
                            $buf.write-num64(0, $_);
                            $buf;
                        }
                        when Rat {
                            # Similar to Num above but the conversion to Num can be lossy. Fallback to Decimal
                            # if precision would be lost. Most smaller numbers, like decimalized currency,
                            # will work as a Double.
                            #
                            # TODO: It might be possible to look at Rats denominator length instead.
                            my Num $cast-num = $_.Num;
                            my Str $cast-string = $cast-num.Str;
                            if $_.Str eq $cast-string {
                                $st = MYSQL_TYPE_DOUBLE;
                                my $buf = buf8.new();
                                $buf.write-num64(0, $cast-num);
                                $buf;
                            } else {
                                $st = MYSQL_TYPE_NEWDECIMAL;
                                .Str.encode;
                            }
                        }
                        when FatRat {
                            $st = MYSQL_TYPE_NEWDECIMAL;
                            .Str.encode;
                        }
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
    else { # Unprepared path, seldome used.
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
    # Setup import functions on the first row retrieval
    if @!import-func.elems != $!field-count {
        my %Converter := $!parent.Converter;
        for @!column-type -> $type {
            @!import-func.push: do {
                if $type ~~ Blob {
                    # Don't touch blob values
                    sub ($value) {
                        $value
                    };
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

    my @list;
    if $!field-count {
        my %Converter := $!parent.Converter;
        my $row;
        with $!stmt {
            my $ret = .mysql_stmt_fetch;
            if $ret == 0 or $ret == 101 { # Has data, possibly truncated
                my $col = 0;
                for @!import-func -> $import-func {
                    my $val = my $t = @!column-type[$col];
                    if not $!isnull[$col] {
                        # Re-allocate buffer if the value is larger than the buffer previously allocated
                        # Overallocate by 10% reduce number of reallocations if all tuples are close to but not exactly
                        # the same size.
                        if $!out-lengths[$col] > $!binds[$col].buffer_length {
                            @!out-bufs[$col] = blob-allocate(Buf, $!out-lengths[$col] * 1.1);
                            $!binds[$col].buffer = BPointer(@!out-bufs[$col]).Int;
                            $!binds[$col].buffer_length = $!out-lengths[$col];

                            # Fetch the specific column of interest.
                            if $!stmt.mysql_stmt_fetch_column($!binds[$col], $col, 0) != 0 {
                                .fail without self!handle-errors;
                            }
                        }

                        my $len = $!out-lengths[$col];
                        $val = @!out-bufs[$col].subbuf(0,$len);

                        # Most values need to be decoded prior to being passed to import-func. This is not easy
                        # to push into import-func as fetch_row type result sets do not require this step.
                        if ($t !~~ Blob and $t.^name ne 'Any') {
                           $val = $val.decode;
                        }
                        $val = $import-func($val);
                    }

                    $col++;
                    @list.push($val);
                }
                $row = True;
            }
        } elsif $row = $!result-set.fetch_row {
            # Differs from .mysql_stmt_fetch case in handling of NULLS and pulling the value out of the buffer.
            my $col = 0;
            for @!import-func -> $import-func {
                my $t = @!column-type[$col];
                my $val = $row.want($col, $t);
                $val = $import-func($val);

                $col++;
                @list.push($val);
            }

            $!affected-rows++ unless $!Prefetch;
        }
        unless $row {
            .fail without self!handle-errors;
            self.finish;
        }
    }
    @list;
}

method insert-id() {
    self!ftr;
    with $!stmt {
        $!stmt.mysql_stmt_insert_id;
    } else {
        $!mysql-client.mysql_insert_id;
    }
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
