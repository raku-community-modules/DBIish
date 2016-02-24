
use v6;

use NativeCall;
need DBDish::Role::StatementHandle;
use DBDish::SQLite::Native;


unit class DBDish::SQLite::StatementHandle does DBDish::Role::StatementHandle;

has $!conn;
has $.statement;
has $!statement_handle;
has $.dbh;
has Int $!row_status;
has @!mem_rows;
has @!column_names;
has $!finished = False;

method !handle-error(Int $status) {
    return if $status == SQLITE_OK;
    self!set_errstr(join ' ', SQLITE($status), sqlite3_errmsg($!conn));
}

submethod BUILD(:$!conn, :$!statement, :$!statement_handle, :$!dbh) { }

method execute(*@params) {
    die "Finish was previously called on the StatementHandle" if $!finished;
    sqlite3_reset($!statement_handle) if $!statement_handle.defined;
    @!mem_rows = ();
    my @strings;
    for @params.kv -> $idx, $v {
        if $v ~~ Str {
            explicitly-manage($v);
            @!mem_rows.push: $v;
        }
        self!handle-error(sqlite3_bind($!statement_handle, $idx + 1, $v));
        push @strings, $v;
    }
    $!row_status = sqlite3_step($!statement_handle);
    if $!row_status != SQLITE_ROW and $!row_status != SQLITE_DONE {
        self!handle-error($!row_status);
    }
    self.rows;
}

method rows {
    die 'Cannot determine rows of closed connection' unless $!conn.DEFINITE;
    my $rows = sqlite3_changes($!conn);
    $rows == 0 ?? '0E0' !! $rows;
}

method column_names {
    unless @!column_names {
            my Int $count = sqlite3_column_count($!statement_handle);
            @!column_names.push: sqlite3_column_name($!statement_handle, $_)
                for ^$count;
    }
    @!column_names;
}


method _row (:$hash) {
    my @row;
    my %hash;
    die 'row without prior execute' unless $!row_status.defined;
    return $hash ?? Hash !! Array if $!row_status == SQLITE_DONE;
    my Int $count = sqlite3_column_count($!statement_handle);
    for ^$count  -> $col {
        my $value;
        given sqlite3_column_type($!statement_handle, $col) {
            when SQLITE_INTEGER {
                 $value = sqlite3_column_int64($!statement_handle, $col);
            }
            when SQLITE_FLOAT {
                 $value = sqlite3_column_double($!statement_handle, $col);
                 $value = $value.Rat;
            }
            default { 
                $value = sqlite3_column_text($!statement_handle, $col);
            }
        }
        $hash ?? (%hash{sqlite3_column_name($!statement_handle, $col)} = $value) !! @row.push: $value;
    }
    $!row_status = sqlite3_step($!statement_handle);

    $hash ?? %hash !! @row;
}


method fetchrow {
    my @row;
    die 'fetchrow_array without prior execute' unless $!row_status.defined;
    return @row if $!row_status == SQLITE_DONE;
    my Int $count = sqlite3_column_count($!statement_handle);
    for ^$count {
        @row.push: sqlite3_column_text($!statement_handle, $_);
    }
    $!row_status = sqlite3_step($!statement_handle);

    @row || Nil;
}

method finish {
    sqlite3_finalize($!statement_handle) if $!statement_handle.defined;
    $!row_status = Int;;
    $!dbh._remove_sth(self);
    $!finished = True;
    True;
}
