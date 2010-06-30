# FakeDBD::Pg.pm6

use NativeCall;  # from project 'zavolaj'
use FakeDBD;     # roles for drivers

#module FakeDBD:auth<mberends>:ver<0.0.1>;

#------------ Pg library functions in alphabetical order ------------

sub PQexec (OpaquePointer $conn, Str $statement)
    returns OpaquePointer
    is native('libpq')
    { ... }

sub PQresultStatus (OpaquePointer $result)
    returns Int
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
    returns Int
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


sub CONNECTION_OK     { 0 }
sub CONNECTION_BAD    { 1 }

sub PGRES_EMPTY_QUERY { 0 }
sub PGRES_COMMAND_OK  { 1 }
sub PGRES_TUPLES_OK   { 2 }
sub PGRES_COPY_OUT    { 3 }
sub PGRES_COPY_IN     { 4 }

#-----------------------------------------------------------------------

class FakeDBD::Pg::StatementHandle does FakeDBD::StatementHandle {
    has $!pg_conn;
    has $!RaiseError;
    has $!statement;
    has $!dbh;
    has $!result;
    has $!affected_rows;
    has @!column_names;
    has $!row_count;
    has $!field_count;
    has $!current_row;
    method execute(*@params is copy) {
        my $statement = $!statement;

        if (!$!dbh.AutoCommit and !$!dbh.in_transaction) {
            PQexec($!pg_conn, "BEGIN");
            $!dbh.in_transaction = 1;
        }

        $!current_row = 0;
        while @params.elems and $statement.index('?') >= 0 {
            my $param = @params.shift;
            if $param ~~ /<-[0..9]>/ {
                $statement .= subst("?","'$param'"); # quote non numerics
            }
            else {
                $statement .= subst("?",$param); # do not quote numbers
            }
        }
        $!result = PQexec($!pg_conn, $statement); # 0 means OK
        $!row_count = PQntuples($!result);
        my $status = PQresultStatus($!result);
        $!errstr = Mu;
        if $status != PGRES_EMPTY_QUERY() | PGRES_COMMAND_OK() | PGRES_TUPLES_OK() | PGRES_COPY_OUT() | PGRES_COPY_IN() {
            $!errstr = PQresultErrorMessage ($!result);
            if $!RaiseError { die $!errstr; }
        }

        my $rows = self.rows;
        return ($rows == 0) ?? "0E0" !! $rows;
    }

    # do() and execute() return the number of affected rows directly or:
    # rows() is called on the statement handle $sth.
    method rows() {
        unless defined $!affected_rows {
            $!errstr = Mu;
            $!affected_rows = PQcmdTuples($!result);

            my $errstr = PQresultErrorMessage ($!result);
            if $errstr ne '' {
                $!errstr = $errstr;
                if $!RaiseError { die $!errstr; }
                return -1;
            }
        }

        if defined $!affected_rows {
            return $!affected_rows;
        }
    }

    method fetchrow_array() {
        my @row_array;

        return if $!current_row >= $!row_count;

        unless defined $!field_count {
            $!field_count = PQnfields($!result);
        }

        if defined $!result {
            $!errstr = Mu;

            for ^$!field_count {
                @row_array.push(PQgetvalue($!result, $!current_row, $_));
            }
            $!current_row++;

            my $errstr = PQresultErrorMessage ($!result);
            if $errstr ne '' {
                $!errstr = $errstr;
                if $!RaiseError { die $!errstr; }
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
            $!errstr = Mu;

            my @row = self!get_row();

            my $errstr = PQresultErrorMessage ($!result);
            if $errstr ne '' {
                $!errstr = $errstr;
                if $!RaiseError { die $!errstr; }
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
            $!errstr = Mu;
            my @all_array;
            for ^$!row_count {
                my @row = self!get_row();

                my $errstr = PQresultErrorMessage ($!result);
                if $errstr ne '' {
                    $!errstr = $errstr;
                    if $!RaiseError { die $!errstr; }
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
            $!errstr = Mu;
            my $errstr = PQresultErrorMessage ($!result);
            if $errstr ne '' {
                $!errstr = $errstr;
                if $!RaiseError { die $!errstr; }
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
            $!result       = Mu;
            @!column_names = Mu;
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

class FakeDBD::Pg::Connection does FakeDBD::Connection {
    has $!pg_conn;
    has $!RaiseError;
    has $.AutoCommit is rw = 1;
    has $.in_transaction is rw;

    method prepare(Str $statement, $attr?) {
        my $statement_handle = FakeDBD::Pg::StatementHandle.bless(
            FakeDBD::Pg::StatementHandle.CREATE(),
            pg_conn    => $!pg_conn,
            statement  => $statement,
            RaiseError => $!RaiseError,
            dbh        => self,
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

class FakeDBD::Pg:auth<mberends>:ver<0.0.1> {

    has $.Version = 0.01;

#------------------ methods to be called from FakeDBI ------------------
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
        if $status eq CONNECTION_OK() {
            $connection = FakeDBD::Pg::Connection.bless(
                FakeDBD::Pg::Connection.CREATE(),
                pg_conn     => $pg_conn,
                RaiseError  => $RaiseError
            );
        }
        return $connection;
    }
}

=begin pod

=head1 DESCRIPTION
# 'zavolaj' is a Native Call Interface for Rakudo/Parrot. 'FakeDBI' and
# 'FakeDBD::Pg' are Perl 6 modules that use 'zavolaj' to use the
# standard libpq library.  There is a long term Parrot based
# project to develop a new, comprehensive DBI architecture for Parrot
# and Perl 6.  FakeDBI is not that, it is a naive rewrite of the
# similarly named Perl 5 modules.  Hence the 'Fake' part of the name.

=head1 CLASSES
The FakeDBD::Pg module contains the same classes and methods as every
database driver.  Therefore read the main documentation of usage in
L<doc:FakeDBI> and internal architecture in L<doc:FakeDBD>.  Below are
only notes about code unique to the FakeDBD::Pg implementation.

=head1 SEE ALSO
The Postgres 8.4 Documentation, C Library.
L<http://www.postgresql.org/docs/8.4/static/libpq.html>

=end pod

