# DBDish::Pg.pm6

use NativeCall;  # from project 'zavolaj'
use DBDish;     # roles for drivers

#module DBDish:auth<mberends>:ver<0.0.1>;

#------------ Pg library functions in alphabetical order ------------

sub PQexec (OpaquePointer $conn, Str $statement)
    returns OpaquePointer
    is native('libpq')
    { ... }

sub PQprepare (OpaquePointer $conn, Str $statement_name, Str $query, Int $n_params, OpaquePointer $paramTypes)
    returns OpaquePointer
    is native('libpq')
    { ... }

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

sub PQnparams (OpaquePointer)
    returns Int
    is native('libpq')
    { * }

sub PQdescribePrepared (OpaquePointer, Str)
    returns OpaquePointer
    is native('libpq')
    { * }


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

sub PQfinish(OpaquePointer) 
    is native('libpq')
    { ... }

sub PQftype(OpaquePointer, Int)
    is native('libpq')
    returns Int
    { * }

# from pg_type.h
constant %oid-to-type-name = (
        16  => 'Bool',  # bool
        17  => 'Buf',   # bytea
        20  => 'Int',   # int8
        21  => 'Int',   # int2
        23  => 'Int',   # int4
        25  => 'Str',   # text
       700  => 'Num',   # float4
       701  => 'Num',   # float8
      1000  => 'Bool',  # _bool
      1001  => 'Buf',   # _bytea
      1005  => 'Int',   # _int2
      1009  => 'Str',   # _text
      1015  => 'Str',   # _varchar
      1021  => 'Num',   # _float4
      1022  => 'Num',   # _float8
      1043  => 'Str',   # varchar
      1700  => 'Real',  # numeric
      2950  => 'Str',   # uuid
      2951  => 'Str',   # _uuid


).hash;

constant CONNECTION_OK     = 0;
constant CONNECTION_BAD    = 1;

constant PGRES_EMPTY_QUERY = 0;
constant PGRES_COMMAND_OK  = 1;
constant PGRES_TUPLES_OK   = 2;
constant PGRES_COPY_OUT    = 3;
constant PGRES_COPY_IN     = 4;

#-----------------------------------------------------------------------

class DBDish::Pg::StatementHandle does DBDish::StatementHandle {
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
    has $!current_row;

    method !handle-errors {
        my $status = PQresultStatus($!result);
        if $status != PGRES_EMPTY_QUERY | PGRES_COMMAND_OK | PGRES_TUPLES_OK | PGRES_COPY_OUT | PGRES_COPY_IN {
            self!set_errstr(PQresultErrorMessage($!result));
        }
        self!set_errstr(Any);
    }

    method !munge_statement {
        my $count = 0;
        $!statement.subst(:g, '?', { '$' ~ ++$count});
    }

    submethod BUILD(:$!statement, :$!pg_conn) {
        state $statement_postfix = 0;
        $!statement_name = join '_', 'pg', $*PID, $statement_postfix++;
        my $munged = self!munge_statement;

        $!result = PQprepare(
                $!pg_conn,
                $!statement_name,
                $munged,
                0,
                OpaquePointer
        );
        self!handle-errors;
        my $info = PQdescribePrepared($!pg_conn, $!statement_name);
        $!param_count = PQnparams($info);
        True;
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
        return if $!current_row >= $!row_count;

        unless defined $!field_count {
            $!field_count = PQnfields($!result);
        }

        if defined $!result {
            self!reset_errstr;

            for ^$!field_count {
                @row_array.push(PQgetvalue($!result, $!current_row, $_));
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

class DBDish::Pg::Connection does DBDish::Connection {
    has $!pg_conn;
    has $.AutoCommit is rw = 1;
    has $.in_transaction is rw;
    method BUILD(:$!pg_conn) { }

    method prepare(Str $statement, $attr?) {
        my $statement_handle = DBDish::Pg::StatementHandle.bless(
            DBDish::Pg::StatementHandle.CREATE(),
            :$!pg_conn,
            :$statement,
            :$.RaiseError,
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

    method ping {
        PQstatus($!pg_conn) == CONNECTION_OK
    }

    method disconnect() {
        PQfinish($!pg_conn);
        True;
    }
}

class DBDish::Pg:auth<mberends>:ver<0.0.1> {

    has $.Version = 0.01;
    has $!errstr;
    method !errstr() is rw { $!errstr }

#------------------ methods to be called from DBIish ------------------
    method connect(*%params) {
        my $host     = %params<host>     // 'localhost';
        my $port     = %params<port>     // 5432;
        my $database = %params<dbname>   // %params<database> // 'postgres';
        my $user     = %params<user>     // die 'Missing <user> config';
        my $password = %params<password> // die 'Missing <password> config';
        my $conninfo = "host=$host port=$port dbname=$database user=$user password=$password";
        my $pg_conn = PQconnectdb($conninfo);
        my $status = PQstatus($pg_conn);
        my $connection;
        if $status eq CONNECTION_OK {
            $connection = DBDish::Pg::Connection.bless(*,
                :$pg_conn,
                :RaiseError(%params<RaiseError>),
            );
        }
        else {
            $!errstr = PQerrorMessage($pg_conn);
            if %params<RaiseError> { die $!errstr; }
        }
        return $connection;
    }
}

=begin pod

=head1 DESCRIPTION
# 'zavolaj' is a Native Call Interface for Rakudo/Parrot. 'DBIish' and
# 'DBDish::Pg' are Perl 6 modules that use 'zavolaj' to use the
# standard libpq library.  There is a long term Parrot based
# project to develop a new, comprehensive DBI architecture for Parrot
# and Perl 6.  DBIish is not that, it is a naive rewrite of the
# similarly named Perl 5 modules.  Hence the 'Mini' part of the name.

=head1 CLASSES
The DBDish::Pg module contains the same classes and methods as every
database driver.  Therefore read the main documentation of usage in
L<doc:DBIish> and internal architecture in L<doc:DBDish>.  Below are
only notes about code unique to the DBDish::Pg implementation.

=head1 SEE ALSO
The Postgres 8.4 Documentation, C Library.
L<http://www.postgresql.org/docs/8.4/static/libpq.html>

=end pod

