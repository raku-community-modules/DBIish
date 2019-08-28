use v6;
need DBDish;

unit class DBDish::SQLite::StatementHandle does DBDish::StatementHandle;
use DBDish::SQLite::Native;
use NativeHelpers::Blob;
use NativeCall;

has SQLite $!conn;
has $.statement;
has $!statement_handle;
has $!param-count;
has Int $!row_status;
has $!field_count;

method !handle-error(Int $status) {
    unless $status == SQLITE_OK {
        self!set-err($status, sqlite3_errmsg($!conn));
    }
}

submethod BUILD(:$!conn!, :$!parent!, :$!statement_handle!,
    :$!statement
) {
    $!param-count = sqlite3_bind_parameter_count($!statement_handle);
    $!field_count = sqlite3_column_count($!statement_handle);
    for ^$!field_count {
	@!column-name.push: sqlite3_column_name($!statement_handle, $_);
	@!column-type.push: Any;
    }
}

method execute(*@params is raw) {
    self!enter-execute(@params.elems, $!param-count);

    my int $num-params = @params.elems;
    loop (my int $idx = 0; $idx < $num-params; $idx++) {
        self!handle-error(sqlite3_bind($!statement_handle, $idx + 1, @params[$idx]));
    }
    $!row_status = sqlite3_step($!statement_handle);
    if $!row_status == SQLITE_ROW | SQLITE_DONE {
        my $rows = $!field_count ?? 0 !! sqlite3_changes($!conn); # Non SELECT
        self.reset-err;
        self!done-execute($rows, $!field_count);
    } else {
        self!set-err($!row_status, sqlite3_errmsg($!conn));
    }
}

method _row() {
    my $list = ();
    if $!row_status == SQLITE_ROW {
       $list = do for ^$!field_count -> $col {
            my $value = do {
		given sqlite3_column_type($!statement_handle, $col) {
		    when SQLITE_INTEGER { sqlite3_column_int64($!statement_handle, $col) }
		    when SQLITE_FLOAT {
			 sqlite3_column_double($!statement_handle, $col) }
		    when SQLITE_BLOB {
			 my \p = sqlite3_column_blob($!statement_handle, $col);
			 my $elems = sqlite3_column_bytes($!statement_handle, $col);
			 blob-from-pointer(p, :$elems);
		    }
		    when SQLITE_NULL { @!column-type[$col] }
		    default { sqlite3_column_text($!statement_handle, $col) }
		}
	    }
	    my $ct = @!column-type[$col];
	    ($ct === Any || $value ~~ $ct) ?? $value !! $value.$ct;
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
