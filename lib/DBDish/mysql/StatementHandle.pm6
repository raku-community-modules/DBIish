use v6;
need DBDish;

unit class DBDish::mysql::StatementHandle does DBDish::StatementHandle;
use DBDish::mysql::Native;

has MYSQL $!mysql_client is required;
has $!statement;
has MYSQL_RES $!result_set;
has $!affected_rows;
has @!column_names;
has @!column_type;
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
    $!affected_rows = $!field_count = Nil;
    if my $status = $!mysql_client.mysql_query($statement ) { # 0 means OK
        self!set-err($status, $!mysql_client.mysql_error);
    } else {
        $.mysql_warning_count = $!mysql_client.mysql_warning_count;
        $!Executed++;
        self.rows;
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

method !get-meta() {
    without $!field_count {
        @!column_names = ();
        @!column_type = ();
        if $!field_count = $!mysql_client.mysql_field_count {
	    # Was SELECT, so should be a result set.
            with $!result_set = self!get_result {
                loop (my $i = 0; $i < $!field_count; $i++) {
                    with $_.mysql_fetch_field {
                        @!column_names.push: .name;
			if (my \t = %mysql-type-conv{.type}) === Any {
			    warn "No type map defined for mysql type #{.type} at column $i";
			    t = Str;
			}
                        @!column_type.push: t;
                    }
                    else { die "mysql: Opps! mysql_fetch_field"; }
                }
		if ($!affected_rows = $!mysql_client.mysql_affected_rows) == -1 {
		    $!affected_rows = 0;
		}
            }
            else {
                .fail without self!handle-errors;
		$!affected_rows = 0;
            }
        }
        else { # Was DML
            $!affected_rows = $!mysql_client.mysql_affected_rows;
            self.finish;
        }
        self.reset-err;
    }
    $!field_count;
}

# do() and execute() return the number of affected rows directly or:
# rows() is called on the statement handle $sth.
method rows() {
    self!get-meta();
    ($!affected_rows == 0) ?? "0E0" !! $!affected_rows;
}
method _row(:$hash) {
    my @row_array;
    my %hash;
    my @names;
    my @types;

    if self!get-meta -> $fields {
        if my $row = $!result_set.fetch_row {
            loop (my $i = 0; $i < $fields; $i++) {
                my $value = $row.want($i, @!column_type[$i]);
                $hash ?? (%hash{@!column_names[$i]} = $value) !! @row_array.push($value);
            }
            $!affected_rows++ unless $!Prefetch;
        }
        else {
            without self!handle-errors {
                .fail;
            }
            self.finish;
        }
    }
    $hash ?? %hash !! @row_array;
}

method fetchrow() {
    my @row_array;
    if self!get-meta {
        if my $native_row = $!result_set.fetch_row {
            loop ( my $i=0; $i < $!field_count; $i++ ) {
                @row_array.push($native_row[$i]);
            }
            $!affected_rows++ unless $!Prefetch;
        }
        else {
            without self!handle-errors {
                .fail;
            }
            self.finish;
        }
    }
    @row_array;
}

method column_names {
    self!get-meta && @!column_names;
}

method column_types {
    self!get-meta && @!column_type;
}

method mysql_insertid() {
    $!mysql_client.mysql_insert_id;
}

method finish() {
    if $!result_set {
        $!result_set.mysql_free_result;
        $!result_set   = Nil;
        @!column_names = ();
	@!column_type = ();
    }
    $!Finished = True; # Per protocol
}
