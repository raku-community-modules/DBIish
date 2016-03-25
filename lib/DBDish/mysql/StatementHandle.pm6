use v6;
need DBDish;

unit class DBDish::mysql::StatementHandle does DBDish::StatementHandle;
use DBDish::mysql::Native;
use NativeHelpers::Blob;
use NativeHelpers::CStruct;

has MYSQL $!mysql_client is required;
has MYSQL_STMT $!stmt;
has $!param-count;
has $!statement;
has MYSQL_RES $!result_set;
has $!field_count;
has $.mysql_warning_count is rw = 0;
has Bool $.Prefetch;
# For prepared stmts
has $!binds;
has @!out-bufs;
has $!retlen;
has $!isnull;

method !handle-errors {
    if $!mysql_client.mysql_errno -> $code {
        self!set-err($code, $!mysql_client.mysql_error);
    } else {
        self.reset-err;
    }
}

submethod BUILD(:$!mysql_client!, :$!parent!, :$!stmt = MYSQL_STMT, :$!param-count = 0,
    :$!statement, Bool :$!Prefetch = True
) { }

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


method execute(*@params) {
    self!enter-execute(@params.elems, $!param-count);
    my $rows = 0; my $was-select = True;
    if $!param-count {
	my @Bufs;
	my $par = LinearArray[MYSQL_BIND].new($!param-count);
	my $lengths = blob-allocate(Buf[int64], $!param-count);
	my $lb = BPointer($lengths).Int;
	LEAVE { $par.dispose if $par }
	for @params.kv -> $k, $v { # The binding dance
	    with $v {
		my $buf = do {
		    when Blob { $_ }
		    when Str  { .encode }
		    default   { .Str.encode }
		};
		given $par[$k] {
		    .buffer_length = $lengths[$k] = $buf.bytes;
		    .buffer = BPointer(@Bufs[$k] = $buf).Int;
		    .length = $lb + $k * 8;
		    .buffer_type = $v ~~ Blob ?? MYSQL_TYPE_BLOB !! MYSQL_TYPE_STRING;
		}
	    } else { # Null;
		$par[$k].buffer_type = MYSQL_TYPE_NULL;
	    }
	}
	$!stmt.mysql_stmt_bind_param($par.typed-pointer)
	or $!stmt.mysql_stmt_execute
	or do without $!field_count {
	    if ($!field_count = $!stmt.mysql_stmt_field_count)
		&& $!stmt.mysql_stmt_result_metadata -> $res
	    { # Need to bind outputs, reuse params structs.
		$lengths = self!get-meta($res);
		$!isnull = blob-allocate(Buf[int64], $!field_count);
		my $nb = BPointer($!isnull).Int;
		my $stmt_buf = LinearArray[MYSQL_BIND].new($!field_count);
		$lb = BPointer($lengths).Int;
		@Bufs = ();
		for ^$!field_count -> $col {
		    given $stmt_buf[$col] {
			.buffer = BPointer(
			    @Bufs[$col] = blob-allocate(
				Buf, .buffer_length = $lengths[$col]
			    )
			).Int;
			.length = $lb + $col * 8;
			.is_null = $nb + $col * 8;
			.buffer_type = @!column-type[$col] ~~ Blob
			    ?? MYSQL_TYPE_BLOB !! MYSQL_TYPE_STRING;
		    }
		}
		@!out-bufs := @Bufs;
		$!binds = $stmt_buf;
		$!retlen = $lengths;
		$!result_set = $res; # To be free at finish time;
		$!stmt.mysql_stmt_bind_result($!binds.typed-pointer)
		    or $!Prefetch
		    and $!stmt.mysql_stmt_store_result;
	    }
	}
	without self!handle-errors { .fail }
	$rows = $!stmt.mysql_stmt_affected_rows;
	return self!done-execute($rows, $!field_count > 0);
    # Try the fast unprepared path
    } elsif my $status = $!mysql_client.mysql_query($!statement) { # 0 means OK
	    self!set-err($status, $!mysql_client.mysql_error).fail;
    }
    $!stmt = Nil; # Mark unused, was closed at prepare time
    $.mysql_warning_count = $!mysql_client.mysql_warning_count;
    without $!field_count { # First execution
	if $!field_count = $!mysql_client.mysql_field_count {
	    # Was SELECT, so should be a result set.
	    with self!get_result {
		self!get-meta($!result_set = $_);
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

method _row {
    my $list = ();
    if $!field_count -> $fields {
	my $row;
	with $!stmt {
	    my $res = .mysql_stmt_fetch;
	    if $res == 0 { # Has data
		$list = do for ^$fields {
		    my $t = @!column-type[$_];
		    my $val = $t;
		    unless $!isnull[$_] {
			my $len = $!retlen[$_];
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

method _free() {
    with $!stmt {
	with $!binds {
	    .dispose;
	    @!out-bufs = ();
	}
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
