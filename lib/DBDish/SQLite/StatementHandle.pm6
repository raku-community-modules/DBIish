use v6;
need DBDish;

unit class DBDish::SQLite::StatementHandle does DBDish::StatementHandle;
use DBDish::SQLite::Native;
use NativeCall;

has SQLite $!conn;
has $.statement;
has $!statement_handle;
has $!param-count;
has Int $!row_status;
has $!field_count;

method !handle-error($status) {
    if $status == SQLITE_OK {
        self.reset-err;
    } else {
        self!set-err($status, sqlite3_errmsg($!conn));
    }
}

submethod BUILD(:$!conn!, :$!parent!,
    :$!statement_handle!, :$!statement, :$!param-count
) { }

method execute(*@params) {
    self!set-err( -1,
        "Wrong number of arguments to method execute: got @params.elems(), expected $!param-count"
    ) if @params != $!param-count;

    self!enter-execute;

    for @params.kv -> $idx, $v {
        self!handle-error(sqlite3_bind($!statement_handle, $idx + 1, $v));
    }
    $!row_status = sqlite3_step($!statement_handle);
    if $!row_status != SQLITE_ROW and $!row_status != SQLITE_DONE {
        self!set-err($!row_status, sqlite3_errmsg($!conn));
    } else {
        my $rows = 0; my $was-select = True;
        without $!field_count  {
            $!field_count = sqlite3_column_count($!statement_handle);
            for ^$!field_count {
                @!column-name.push: sqlite3_column_name($!statement_handle, $_);
                @!column-type.push: Any; #TODO
            }
        }
        unless $!field_count { # Assume non SELECT
            $rows = sqlite3_changes($!conn);
            $was-select = False;
        }
        self!done-execute($rows, $was-select);
    }
}

method _row() {
    my $list = ();
    if $!row_status == SQLITE_ROW {
       $list = do for ^$!field_count  -> $col {
            my $value;
            given sqlite3_column_type($!statement_handle, $col) {
                when SQLITE_INTEGER {
                     $value = sqlite3_column_int64($!statement_handle, $col);
                }
                when SQLITE_FLOAT {
                     $value = sqlite3_column_double($!statement_handle, $col);
                     $value = $value.Rat; # FIXME
                }
                when SQLITE_BLOB {
                     ...  # TODO WIP
                     $value = sqlite3_column_blob($!statement_handle, $col);
                }
                when SQLITE_NULL {
                     # SQLite can't determine the type of NULL column, so instead
                     # of lying, prefer an explicit Nil.
                     $value = Nil;
                }
                default {
                    $value = sqlite3_column_text($!statement_handle, $col);
                }
            }
            $value;
        }
        $!affected_rows++;
        self.reset-err;
        if ($!row_status = sqlite3_step($!statement_handle)) == SQLITE_DONE {
            self.finish;
        }
    }
    $list;
}

method _free {
    with $!statement_handle {
        sqlite3_finalize($_);
        $_ = Nil;
        $!row_status = Int;
    }
}

method finish {
    with $!statement_handle {
        sqlite3_reset($_);
        sqlite3_clear_bindings($_);
    }
    $!Finished = True;
}
