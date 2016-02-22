
use v6;

use NativeCall;
need DBDish::Role::StatementHandle;
use DBDish::mysql::Native;

unit class DBDish::mysql::StatementHandle does DBDish::Role::StatementHandle;

has $!mysql_client;
has $!statement;
has $!result_set;
has $!affected_rows;
has @!column_names;
has @!column_mysqltype;
has $!field_count;
has $.mysql_warning_count is rw = 0;

submethod BUILD(:$!mysql_client, :$!statement) { }

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
                $statement ~= self.quote($param.Str);
            }
        }
        else {
            $statement ~= 'NULL';
        }
    }
    $statement ~= $last-chunk;
    if defined( $!result_set ) {
        mysql_free_result($!result_set);
    }
    $!result_set = Mu;
    my $status = mysql_query( $!mysql_client, $statement ); # 0 means OK
    $.mysql_warning_count = mysql_warning_count( $!mysql_client );
    self!reset_errstr();
    if $status != 0 {
        self!set_errstr(mysql_error( $!mysql_client ));
    }

    my $rows = self.rows;
    return ($rows == 0) ?? "0E0" !! $rows;
}

method escape(Str $x) {
    # XXX should really call mysql_real_scape_string
    $x.trans(
            [q['],  q["],  q[\\],   chr(0), "\r", "\n"]
        =>  [q[\'], q[\"], q[\\\\], '\0',   '\r', '\n']
    );
}

method quote(Str $x) {
    q['] ~ self.escape($x) ~ q['];
}

# do() and execute() return the number of affected rows directly or:
# rows() is called on the statement handle $sth.
method rows() {
    unless defined $!affected_rows {
        self!reset_errstr();
        $!affected_rows = mysql_affected_rows($!mysql_client);
        my $errstr      = mysql_error( $!mysql_client );

        if $errstr ne '' { self!set_errstr($errstr); }
    }

    if defined $!affected_rows {
        return $!affected_rows;
    }
}

method _row(:$hash) {
    my @row_array;
    my %hash;
    my @names;
    my @types;

    unless defined $!result_set {
        $!result_set  = mysql_use_result( $!mysql_client);
        $!field_count = mysql_field_count($!mysql_client);
        @!column_names = ();
        @!column_mysqltype = ();
        loop ( my $i=0; $i < $!field_count; $i++ ) {
            my MYSQL_FIELD $field_info = mysql_fetch_field($!result_set).deref;
            my $column_name = $field_info.name;
            @!column_names.push($column_name);
            @!column_mysqltype.push($field_info.type);
        }
    }

    if defined $!result_set {
        self!reset_errstr();

        my $native_row = mysql_fetch_row($!result_set); # can return NULL
        my $errstr     = mysql_error( $!mysql_client );

        if $errstr ne '' { self!set_errstr($errstr);}

        if $native_row {
            loop ( my $i=0; $i < $!field_count; $i++ ) {
                die "unhandled data type @!column_mysqltype[$i]"
                    unless %mysql-type-conv{@!column_mysqltype[$i]}:exists;
                my $type = %mysql-type-conv{@!column_mysqltype[$i]};
                my Bool $is-null = $native_row[$i] ~~ Any;
                my $value = do given $type {
                    when 'Int' {
                        $is-null ?? Int !! $native_row[$i].Int;
                    }
                    when 'Rat' {
                        $is-null ?? Rat !! $native_row[$i].Rat;
                    }
                    when 'Str' {
                        $is-null ?? Str !! $native_row[$i].Str;
                    }
                    when 'Num' {
                        $is-null ?? Num !! $native_row[$i].Num;
                    }
                    default {
                        warn "unhandled type $type";
                        $native_row[$i];
                    }
                };
                $hash ?? (%hash{@!column_names[$i]} = $value) !! @row_array.push($value);
            }
        }
        else { self.finish; }
    }
    return $hash ?? %hash !! @row_array;
}

method fetchrow() {
    my @row_array;

    unless defined $!result_set {
        $!result_set  = mysql_use_result( $!mysql_client);
        $!field_count = mysql_field_count($!mysql_client);
    }

    if defined $!result_set {
        self!reset_errstr();

        my $native_row = mysql_fetch_row($!result_set); # can return NULL
        my $errstr     = mysql_error( $!mysql_client );

        if $errstr ne '' { self!set_errstr($errstr); }

        if $native_row {
            loop ( my $i=0; $i < $!field_count; $i++ ) {
                @row_array.push($native_row[$i]);
            }
        }
        else { self.finish; }
    }
    return @row_array;
}

method column_names {
    unless @!column_names {
        unless defined $!result_set {
            $!result_set  = mysql_use_result( $!mysql_client);
            $!field_count = mysql_field_count($!mysql_client);
            @!column_mysqltype = ();
        }
        loop ( my $i=0; $i < $!field_count; $i++ ) {
            my MYSQL_FIELD $field_info = mysql_fetch_field($!result_set).deref;
            my $column_name = $field_info.name;
            @!column_names.push($column_name);
            @!column_mysqltype.push($field_info.type);
        }
    }
    @!column_names;
}

method mysql_insertid() {
    mysql_insert_id($!mysql_client);
    # but Parrot NCI cannot return an unsigned long long :-(
}

method finish() {
    self.fetchrow if !defined $!result_set;
    if defined( $!result_set ) {
        mysql_free_result($!result_set);
        $!result_set   = Mu;
        @!column_names = ();
    }
    return Bool::True;
}
