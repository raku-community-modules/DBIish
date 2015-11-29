
use v6;
use NativeCall;

need DBDish::Role::StatementHandle;
use DBDish::Pg::Native;

unit class DBDish::Pg::StatementHandle does DBDish::Role::StatementHandle;

has $!pg_conn;
has Str $!statement_name;
has $!statement;
has $!param_count;
has $.dbh;
has $!result;
has $!affected_rows;
has @!column_names;
has Int $!row_count;
has $!field_count;
has $!current_row = 0;

method !handle-errors {
    my $status = PQresultStatus($!result);
    if status-is-ok($status) {
        self!reset_errstr;
        return True;
    }
    else {
        self!set_errstr(PQresultErrorMessage($!result));
        die self.errstr if $.RaiseError;
        return Nil;
    }
}

method !munge_statement {
    my $count = 0;
    $!statement.subst(:g, '?', { '$' ~ ++$count});
}

submethod BUILD(:$!statement, :$!pg_conn, :$!statement_name, :$!param_count,
       :$!dbh) {
}
method execute(*@params is copy) {
    $!current_row = 0;
    die "Wrong number of arguments to method execute: got @params.elems(), expected $!param_count" if @params != $!param_count;
    my @param_values := CArray[Str].new;
    for @params.kv -> $k, $v {
        @param_values[$k] = $v.Str;
    }

    $!result = PQexecPrepared($!pg_conn, $!statement_name, @params.elems,
            @param_values,
            OpaquePointer, # ParamLengths, NULL pointer == all text
            OpaquePointer, # ParamFormats, NULL pointer == all text
            0,             # Resultformat, 0 == text
    );

    self!handle-errors;
    $!row_count = PQntuples($!result);

    my $rows = self.rows;
    return ($rows == 0) ?? "0E0" !! $rows;
}

# do() and execute() return the number of affected rows directly or:
# rows() is called on the statement handle $sth.
method rows() {
    unless defined $!affected_rows {
        $!affected_rows = PQcmdTuples($!result);

        self!handle-errors;
    }

    if defined $!affected_rows {
        return +$!affected_rows;
    }
}

method _row(:$hash) {
    my @row_array;
    my %ret_hash;
    return Any if $!current_row >= $!row_count;

    unless defined $!field_count {
        $!field_count = PQnfields($!result);
    }
    my @names = self.column_names if $hash;
    my @types = self.column_p6types;
    if defined $!result {
        self!reset_errstr;
        my $afield = False;
        for ^$!field_count {
            FIRST {
                $afield = True;
            }
            my $res := PQgetvalue($!result, $!current_row, $_);
            if $res eq '' {
                $res := Str if PQgetisnull($!result, $!current_row, $_)
            }
            my $value;
            given (@types[$_]) {
                $value = $res when 'Str';
                $value = $res.Num when 'Num';
                $value = $res.Int when 'Int';
                $value = self.true_false($res) when 'Bool';
                $value = $res.Real when 'Real';
            }
            $hash ?? (%ret_hash{@names[$_]} = $value) !! @row_array.push($value);
        }
        $!current_row++;
        self!handle-errors;

        if ! $afield { self.finish; }
    }
    $hash ?? return %ret_hash !! return @row_array;
}

method allrows(:$hash) {
}

method fetchrow() {
    my @row_array;
    return () if $!current_row >= $!row_count;

    unless defined $!field_count {
        $!field_count = PQnfields($!result);
    }

    if defined $!result {
        self!reset_errstr;

        for ^$!field_count {
            my $res := PQgetvalue($!result, $!current_row, $_);
            if $res eq '' {
                $res := Str if PQgetisnull($!result, $!current_row, $_)
            }
            @row_array.push($res)
        }
        $!current_row++;
        self!handle-errors;

        if ! @row_array { self.finish; }
    }
    return @row_array;
}

method column_names {
    $!field_count = PQnfields($!result);
    unless @!column_names {
        for ^$!field_count {
            my $column_name = PQfname($!result, $_);
            @!column_names.push($column_name);
        }
    }
    @!column_names
}

# for debugging only so far
method column_oids {
    $!field_count = PQnfields($!result);
    my @res;
    for ^$!field_count {
        @res.push: PQftype($!result, $_);
    }
    @res;
}

method fetchall_hashref(Str $key) {
    my %results;

    return () if $!current_row >= $!row_count;

    while my $row = self.fetchrow_hashref {
        %results{$row{$key}} = $row;
    }

    my $results_ref = %results;
    return $results_ref;
}

method column_p6types {
   my @types = self.column_oids;
   return @types.map:{%oid-to-type-name{$_}};
}

method true_false(Str $s) {
    return $s eq 't';
}


method finish() {
    if defined($!result) {
        PQclear($!result);
        $!result       = Any;
        @!column_names = ();
    }
    return Bool::True;
}

method !get_row {
    my @data;
    for ^$!field_count {
        @data.push(PQgetvalue($!result, $!current_row, $_));
    }
    $!current_row++;

    return @data;
}
