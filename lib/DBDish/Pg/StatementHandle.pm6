
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

#Try to map pg type to perl type
method fetchrow_typedhash {
    my Str @values = self.fetchrow_array;
    return Any if !@values.defined;
    my @names = self.column_names;
    my @types = self.column_oids;
    my %hash;
    my %p = 'f' => False, 't' => True;
    for 0..(@values.elems-1) -> $i {
        given (%oid-to-type-name{@types[$i]}) {
            %hash{@names[$i]} = @values[$i] when 'Str';
            %hash{@names[$i]} = @values[$i].Num when 'Num';
            %hash{@names[$i]} = @values[$i].Int when 'Int';
            %hash{@names[$i]} = %p{@values[$i]} when 'Bool';
            %hash{@names[$i]} = @values[$i].Real when 'Real';
        }
    }
    return %hash;
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
