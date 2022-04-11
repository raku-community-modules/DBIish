use v6;
need DBDish;

unit class DBDish::SQLite::StatementHandle does DBDish::StatementHandle;
use DBDish::SQLite::Native;
use NativeHelpers::Blob;
use NativeCall;

has SQLite $!conn;
has $.statement;
has $!statement-handle;
has $!param-count;
has Int $!row-status;
has $!field-count;
has Bool $!rows-is-accurate = False;

method !handle-error(Int $status) {
    unless $status == SQLITE_OK {
        self!set-err($status, sqlite3_errmsg($!conn));
    }
}

submethod BUILD(:$!conn!, :$!parent!, :$!statement-handle!,
    :$!statement
) {
    $!param-count = sqlite3_bind_parameter_count($!statement-handle);
    $!field-count = sqlite3_column_count($!statement-handle);
    for ^$!field-count {
        @!column-name.push: sqlite3_column_name($!statement-handle, $_);
        @!column-type.push: Any;
    }
}

method execute(*@params is raw --> DBDish::StatementHandle) {
    self!enter-execute(@params.elems, $!param-count);

    my int $num-params = @params.elems;
    loop (my int $idx = 0; $idx < $num-params; $idx++) {
        self!handle-error(sqlite3_bind($!statement-handle, $idx + 1, @params[$idx]));
    }
    $!row-status = sqlite3_step($!statement-handle);
    if $!row-status == SQLITE_ROW | SQLITE_DONE {
        my $rows = 0;
        if $!field-count == 0 { # Non-SELECT
            $!rows-is-accurate = True;
            $rows = sqlite3_changes($!conn);
        }

        self.reset-err;
        self!done-execute($rows, $!field-count);
    } else {
        self!set-err($!row-status, sqlite3_errmsg($!conn));
    }
}

# Override DBDish::StatementHandle to throw this error
method rows() {
    # Warn if rows is inaccurate. Message may be suppressed with a CONTROL block.
    if (not $!rows-is-accurate) {
        warn "SQLite rows() result may not be accurate. See SQLite rows section of README for details."
    }

    self._rows();
}

method _row() {
    my $list = ();
    if $!row-status == SQLITE_ROW {
        $list = do for ^$!field-count -> $col {
            my $value = do {
                given sqlite3_column_type($!statement-handle, $col) {
                    when SQLITE_INTEGER { sqlite3_column_int64($!statement-handle, $col) }
                    when SQLITE_FLOAT {
                        sqlite3_column_double($!statement-handle, $col) }
                    when SQLITE_BLOB {
                        my \p = sqlite3_column_blob($!statement-handle, $col);
                        my $elems = sqlite3_column_bytes($!statement-handle, $col);
                        blob-from-pointer(p, :$elems);
                    }
                    when SQLITE_NULL { @!column-type[$col] }
                    default { sqlite3_column_text($!statement-handle, $col) }
                }
            }
            my $ct = @!column-type[$col];
            ($ct === Any || $value ~~ $ct) ?? $value !! $value.$ct;
        }
        $!affected-rows++;
        self.reset-err;
        if ($!row-status = sqlite3_step($!statement-handle)) == SQLITE_DONE {
            # Only after retrieving the final record is the rows value considered accurate.
            $!rows-is-accurate = True;
            self.finish;
        }
    } elsif $!row-status == SQLITE_DONE {
        # An empty result is considered accurate immediately.
        $!rows-is-accurate = True;
    }
    $list;
}

method _free {
    with $!statement-handle {
        sqlite3_finalize($_);
        $_ = Nil;
        $!row-status = Int;
    }
}

method finish {
    with $!statement-handle {
        sqlite3_reset($_);
        sqlite3_clear_bindings($_);
    }
    $!Finished = True;
}
