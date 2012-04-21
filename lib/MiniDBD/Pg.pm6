# MiniDBD::Pg.pm6

use NativeCall;  # from project 'zavolaj'
use MiniDBD;     # roles for drivers

#module MiniDBD:auth<mberends>:ver<0.0.1>;

#------------ Pg library functions in alphabetical order ------------

sub PQexec (OpaquePointer $conn, Str $statement)
    returns OpaquePointer
    is native('libpq')
    { ... }

sub PQprepare (OpaquePointer $conn, Str $statement_name, Str $query, Int $n_params, OpaquePointer $paramTypes)
    returns OpaquePointer
    is native('libpq')
    { ... }

# PGresult *PQexecPrepared(PGconn *conn,
#                          const char *stmtName,
#                          int nParams,
#                          const char * const *paramValues,
#                          const int *paramLengths,
#                          const int *paramFormats,
#                          int resultFormat);
# 
sub PQexecPrepared(
        OpaquePointer $conn,
        Str $statement_name,
        Int $n_params,
        CArray[Str] $param_values,
        CArray[int] $param_length,
        CArray[int] $param_formats,
        Int $resultFormat
    )
    returns OpaquePointer
    is native('libpq')
    { ... }

sub PQresultStatus (OpaquePointer $result)
    returns Int
    is native('libpq')
    { ... }

sub PQerrorMessage (OpaquePointer $conn)
    returns Str
    is native('libpq')
    { ... }

sub PQresultErrorMessage (OpaquePointer $result)
    returns Str
    is native('libpq')
    { ... }

sub PQconnectdb (Str $conninfo)
    returns OpaquePointer
    is native('libpq')
    { ... }

sub PQstatus (OpaquePointer $conn)
    returns Int
    is native('libpq')
    { ... }

sub PQnfields (OpaquePointer $result)
    returns Int
    is native('libpq')
    { ... }

sub PQntuples (OpaquePointer $result)
    returns Int
    is native('libpq')
    { ... }

sub PQcmdTuples (OpaquePointer $result)
    returns Str
    is native('libpq')
    { ... }

sub PQgetvalue (OpaquePointer $result, Int $row, Int $col)
    returns Str
    is native('libpq')
    { ... }

sub PQfname (OpaquePointer $result, Int $col)
    returns Str
    is native('libpq')
    { ... }

sub PQclear (OpaquePointer $result)
    is native('libpq')
    { ... }


constant CONNECTION_OK     = 0;
constant CONNECTION_BAD    = 1;

constant PGRES_EMPTY_QUERY = 0;
constant PGRES_COMMAND_OK  = 1;
constant PGRES_TUPLES_OK   = 2;
constant PGRES_COPY_OUT    = 3;
constant PGRES_COPY_IN     = 4;

#-----------------------------------------------------------------------

class MiniDBD::Pg::StatementHandle does MiniDBD::StatementHandle {
    has $!pg_conn;
    has $.RaiseError;
    has Str $!statement_name;
    has $!statement;
    has $.dbh;
    has $!result;
    has $!affected_rows;
    has @!column_names;
    has Int $!row_count;
    has $!field_count;
    has $!current_row;

    method !munge_statement {
        my $count = 0;
        my $munged = $!statement.subst(:g, '?', { '$' ~ ++$count});
        return ($munged, $count);
    }

    submethod BUILD(:$!statement, :$!pg_conn) {
        state $statement_postfix = 0;
        $!statement_name = join '_', 'pg', $*PID, $statement_postfix++;
        my ($munged, $nparams) = self!munge_statement;

        $!result = PQprepare(
                $!pg_conn,
                $!statement_name,
                $munged,
                $nparams,
                OpaquePointer
        );
        my $status = PQresultStatus($!result);
        if $status != PGRES_EMPTY_QUERY | PGRES_COMMAND_OK | PGRES_TUPLES_OK | PGRES_COPY_OUT | PGRES_COPY_IN {
            die 'OH NOEZ, died with ' ~ PQresultErrorMessage($!result);
        }

    }
    method execute(*@params is copy) {
        $!current_row = 0;
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

        my $status = PQresultStatus($!result);
        if $status != PGRES_EMPTY_QUERY | PGRES_COMMAND_OK | PGRES_TUPLES_OK | PGRES_COPY_OUT | PGRES_COPY_IN {
            self!set_errstr(PQresultErrorMessage($!result));
            if $!RaiseError { die self!errstr; }
        }
        self!set_errstr(Any);
        $!row_count = PQntuples($!result);

        my $rows = self.rows;
        return ($rows == 0) ?? "0E0" !! $rows;
    }

    # do() and execute() return the number of affected rows directly or:
    # rows() is called on the statement handle $sth.
    method rows() {
        unless defined $!affected_rows {
            $!affected_rows = PQcmdTuples($!result);

            my $errstr = PQresultErrorMessage ($!result);
            if $errstr.chars {
                self!set_errstr($errstr);
                if $!RaiseError { die self!errstr; }
                return -1;
            }
            else {
                self!set_errstr(Any);
            }
        }

        if defined $!affected_rows {
            return +$!affected_rows;
        }
    }

    method fetchrow_array() {
        my @row_array;
        return if $!current_row >= $!row_count;

        unless defined $!field_count {
            $!field_count = PQnfields($!result);
        }

        if defined $!result {
            self!errstr = Any;

            for ^$!field_count {
                @row_array.push(PQgetvalue($!result, $!current_row, $_));
            }
            $!current_row++;

            my $errstr = PQresultErrorMessage ($!result);
            if $errstr ne '' {
                self!errstr = $errstr;
                if $!RaiseError { die self!errstr; }
                return;
            }

            if ! @row_array { self.finish; }
        }
        return @row_array;
    }

    method fetchrow_arrayref() {
        my $row_arrayref;

        return if $!current_row >= $!row_count;

        unless defined $!field_count {
            $!field_count = PQnfields($!result);
        }
        if defined $!result {
            self!set_errstr(Any);

            my @row = self!get_row();

            my $errstr = PQresultErrorMessage ($!result);
            if $errstr ne '' {
                self!errstr = $errstr;
                if $!RaiseError { die $errstr; }
                return;
            }

            if @row {
                $row_arrayref = @row;
            }
            else { self.finish; }
        }
        return $row_arrayref;
    }
    method fetch() { self.fetchrow_arrayref(); } # alias according to perldoc DBI
    method fetchall_arrayref() {
        my $all_arrayref;
        return if $!current_row >= $!row_count;

        unless defined $!field_count {
            $!field_count = PQnfields($!result);
        }
        if defined $!result {
            self!set_errstr(Any);
            my @all_array;
            for ^$!row_count {
                my @row = self!get_row();

                my $errstr = PQresultErrorMessage ($!result);
                if $errstr ne '' {
                    self!errstr = $errstr;
                    if $!RaiseError { die $errstr; }
                    return;
                }

                if @row {
                    my $row_arrayref = @row;
                    push @all_array, $row_arrayref;
                }
                else { self.finish; }
            }
            $all_arrayref = @all_array;
        }
        return $all_arrayref;
    }

    method fetchrow_hashref () {
        my $row_hashref;
        my %row_hash;

        return if $!current_row >= $!row_count;

        unless defined $!field_count {
            $!field_count = PQnfields($!result);
        }

        if defined $!result {
            self!set_errstr(Any);
            my $errstr = PQresultErrorMessage ($!result);
            if $errstr ne '' {
                self!errstr = $errstr;
                if $!RaiseError { die $errstr; }
                return;
            }

            my @row = self!get_row();

            unless @!column_names {
                for ^$!field_count {
                    my $column_name = PQfname($!result, $_);
                    @!column_names.push($column_name);
                }
            }

            if @row && @!column_names {
                for @row Z @!column_names -> $column_value, $column_name {
                    %row_hash{$column_name} = $column_value;
                }
            } else {
                self.finish;
            }

            $row_hashref = %row_hash;
        }
        return $row_hashref;
    }

    method fetchall_hashref(Str $key) {
        my %results;

        return if $!current_row >= $!row_count;

        while my $row = self.fetchrow_hashref {
            %results{$row{$key}} = $row;
        }

        my $results_ref = %results;
        return $results_ref;
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
}

class MiniDBD::Pg::Connection does MiniDBD::Connection {
    has $!pg_conn;
    has $.RaiseError;
    has $.AutoCommit is rw = 1;
    has $.in_transaction is rw;
    method BUILD(:$!pg_conn) { }

    method prepare(Str $statement, $attr?) {
        my $statement_handle = MiniDBD::Pg::StatementHandle.bless(
            MiniDBD::Pg::StatementHandle.CREATE(),
            :$!pg_conn,
            :$statement,
            :$!RaiseError,
            :dbh(self),
        );
        return $statement_handle;
    }

    method do(Str $statement, $attr?, *@bind is copy) {
        my $sth = self.prepare($statement);
        $sth.execute(@bind);
        my $rows = $sth.rows;
        return ($rows == 0) ?? "0E0" !! $rows;
    }

    method selectrow_arrayref(Str $statement, $attr?, *@bind is copy) {
        my $sth = self.prepare($statement, $attr);
        $sth.execute(@bind);
        return $sth.fetchrow_arrayref;
    }

    method selectrow_hashref(Str $statement, $attr?, *@bind is copy) {
        my $sth = self.prepare($statement, $attr);
        $sth.execute(@bind);
        return $sth.fetchrow_hashref;
    }

    method selectall_arrayref(Str $statement, $attr?, *@bind is copy) {
        my $sth = self.prepare($statement, $attr);
        $sth.execute(@bind);
        return $sth.fetchall_arrayref;
    }

    method selectall_hashref(Str $statement, Str $key, $attr?, *@bind is copy) {
        my $sth = self.prepare($statement, $attr);
        $sth.execute(@bind);
        return $sth.fetchall_hashref($key);
    }

    method selectcol_arrayref(Str $statement, $attr?, *@bind is copy) {
        my @results;

        my $sth = self.prepare($statement, $attr);
        $sth.execute(@bind);
        while (my $row = $sth.fetchrow_arrayref) {
            @results.push($row[0]);
        }

        my $aref = @results;
        return $aref;
    }

    method commit {
        if $!AutoCommit {
            warn "Commit ineffective while AutoCommit is on";
            return;
        };
        PQexec($!pg_conn, "COMMIT");
        $.in_transaction = 0;
    }

    method rollback {
        if $!AutoCommit {
            warn "Rollback ineffective while AutoCommit is on";
            return;
        };
        PQexec($!pg_conn, "ROLLBACK");
        $.in_transaction = 0;
    }
}

class MiniDBD::Pg:auth<mberends>:ver<0.0.1> {

    has $.Version = 0.01;
    has $!errstr;
    method !errstr() is rw { $!errstr }

#------------------ methods to be called from MiniDBI ------------------
    method connect( Str $user, Str $password, Str $params, $RaiseError ) {
        my @params = $params.split(';');
        my %params;
        for @params -> $p {
            my ( $key, $value ) = $p.split('=');
            %params{$key} = $value;
        }
        my $host     = %params<host>     // 'localhost';
        my $port     = %params<port>     // 5432;
        my $database = %params<dbname>   // 'postgres';
        my $conninfo = "host=$host port=$port dbname=$database user=$user password=$password";
        my $pg_conn = PQconnectdb($conninfo);
        my $status = PQstatus($pg_conn);
        my $connection;
        if $status eq CONNECTION_OK {
            $connection = MiniDBD::Pg::Connection.bless(*,
                :$pg_conn,
                :$RaiseError,
            );
        }
        else {
            $!errstr = PQerrorMessage($pg_conn);
            if $RaiseError { die $!errstr; }
        }
        return $connection;
    }
}

=begin pod

=head1 DESCRIPTION
# 'zavolaj' is a Native Call Interface for Rakudo/Parrot. 'MiniDBI' and
# 'MiniDBD::Pg' are Perl 6 modules that use 'zavolaj' to use the
# standard libpq library.  There is a long term Parrot based
# project to develop a new, comprehensive DBI architecture for Parrot
# and Perl 6.  MiniDBI is not that, it is a naive rewrite of the
# similarly named Perl 5 modules.  Hence the 'Mini' part of the name.

=head1 CLASSES
The MiniDBD::Pg module contains the same classes and methods as every
database driver.  Therefore read the main documentation of usage in
L<doc:MiniDBI> and internal architecture in L<doc:MiniDBD>.  Below are
only notes about code unique to the MiniDBD::Pg implementation.

=head1 SEE ALSO
The Postgres 8.4 Documentation, C Library.
L<http://www.postgresql.org/docs/8.4/static/libpq.html>

=end pod

