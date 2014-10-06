# DBDish::Oracle.pm6

use NativeCall;  # from project 'zavolaj'
use DBDish;     # roles for drivers

my constant lib = 'libclntsh.so';

#module DBDish:auth<mberends>:ver<0.0.1>;

#------------ Oracle library to NativeCall data type mapping ------------

# OCIEnv    OpaquePointer
# OCIError  OpaquePointer
# OCISvcCtx OpaquePointer
# OraText   Str
# sword     int
# ub2       int16
# ub4       int32
# sb4       int32
# size_t    int

#------------ Oracle library functions in alphabetical order ------------

sub OCIEnvCreate (
        CArray[OpaquePointer] $envhpp,
        int32         $mode,
        OpaquePointer $ctxp,
        OpaquePointer $malocfp,
        OpaquePointer $ralocfp,
        OpaquePointer $mfreefp,
        int           $xtramemsz,
        CArray[OpaquePointer] $usrmempp,
    )
    returns int
    is native(lib)
    { ... }

sub OCIEnvNlsCreate (
        CArray[OpaquePointer] $envhpp,
        int32         $mode,
        OpaquePointer $ctxp,
        OpaquePointer $malocfp,
        OpaquePointer $ralocfp,
        OpaquePointer $mfreefp,
        int           $xtramemsz,
        CArray[OpaquePointer] $usrmempp,
        int16         $charset,
        int16         $ncharset,
    )
    returns int
    is native(lib)
    { ... }

sub OCIErrorGet (
        OpaquePointer   $hndlp,
        int32           $recordno,
        OpaquePointer   $sqlstate,
        CArray[int32]   $errcodep,
        CArray[int8]    $bufp,
        int32           $bufsiz,
        int32           $type,
    )
    returns int
    is native(lib)
    { ... }

sub OCIHandleAlloc (
        OpaquePointer           $parenth,
        CArray[OpaquePointer]   $hndlpp,
        int32                   $type,
        int                     $xtramem_sz,
        CArray[OpaquePointer]   $usrmempp,
    )
    returns int
    is native(lib)
    { ... }

sub OCILogon2 (
        OpaquePointer $envhp,
        OpaquePointer $errhp,
        CArray[OpaquePointer] $svchp,
        Str $username is encoded('utf16'),
        int32         $uname_len,
        Str $password is encoded('utf16'),
        int32         $passwd_len,
        Str $dbname is encoded('utf16'),
        int32         $dbname_len,
        int32         $mode,
    )
    returns int
    is native(lib)
    { ... }

sub OCILogoff (
        OpaquePointer $svchp,
        OpaquePointer $errhp,
    )
    returns int
    is native(lib)
    { ... }

#-----

constant OCI_DEFAULT            = 0;
constant OCI_THREADED           = 1;

constant OCI_SUCCESS            = 0;
constant OCI_ERROR              = -1;

constant OCI_HTYPE_ENV          = 1;
constant OCI_HTYPE_ERROR        = 2;

constant OCI_UTF16ID            = 1000;

constant OCI_LOGON2_STMTCACHE   = 4;

#sub status-is-ok($status) { $status ~~ 0..4 }

#-----------------------------------------------------------------------

#my grammar PgTokenizer {
#    token double_quote_normal { <-[\\"]>+ }
#    token double_quote_escape { [\\ . ]+ }
#    token double_quote {
#        \"
#        [
#            | <.double_quote_normal>
#            | <.double_quote_escape>
#        ]*
#        \"
#    }
#    token single_quote_normal { <-['\\]>+ }
#    token single_quote_escape { [ \'\' || \\ . ]+ }
#    token single_quote {
#        \'
#        [
#            | <.single_quote_normal>
#            | <.single_quote_escape>
#        ]*
#        \'
#    }
#    token placeholder { '?' }
#    token normal { <-[?"']>+ }
#
#    token TOP {
#        ^
#        (
#            | <normal>
#            | <placeholder>
#            | <single_quote>
#            | <double_quote>
#        )*
#        $
#    }
#}
#
#my class PgTokenizer::Actions {
#    has $.counter = 0;
#    method single_quote($/) { make $/.Str }
#    method double_quote($/) { make $/.Str }
#    method placeholder($/)  { make '$' ~ ++$!counter }
#    method normal($/)       { make $/.Str }
#    method TOP($/) {
#        make $0.map({.values[0].ast}).join;
#    }
#}
#
#
#class DBDish::Pg::StatementHandle does DBDish::StatementHandle {
#    has $!pg_conn;
#    has Str $!statement_name;
#    has $!statement;
#    has $!param_count;
#    has $.dbh;
#    has $!result;
#    has $!affected_rows;
#    has @!column_names;
#    has Int $!row_count;
#    has $!field_count;
#    has $!current_row = 0;
#
#    method !handle-errors {
#        my $status = PQresultStatus($!result);
#        if status-is-ok($status) {
#            self!reset_errstr;
#            return True;
#        }
#        else {
#            self!set_errstr(PQresultErrorMessage($!result));
#            die self.errstr if $.RaiseError;
#            return Nil;
#        }
#    }
#
#    method !munge_statement {
#        my $count = 0;
#        $!statement.subst(:g, '?', { '$' ~ ++$count});
#    }
#
#    submethod BUILD(:$!statement, :$!pg_conn, :$!statement_name, :$!param_count,
#           :$!dbh) {
#    }
#    method execute(*@params is copy) {
#        $!current_row = 0;
#        die "Wrong number of arguments to method execute: got @params.elems(), expected $!param_count" if @params != $!param_count;
#        my @param_values := CArray[Str].new;
#        for @params.kv -> $k, $v {
#            @param_values[$k] = $v.Str;
#        }
#
#        $!result = PQexecPrepared($!pg_conn, $!statement_name, @params.elems,
#                @param_values,
#                OpaquePointer, # ParamLengths, NULL pointer == all text
#                OpaquePointer, # ParamFormats, NULL pointer == all text
#                0,             # Resultformat, 0 == text
#        );
#
#        self!handle-errors;
#        $!row_count = PQntuples($!result);
#
#        my $rows = self.rows;
#        return ($rows == 0) ?? "0E0" !! $rows;
#    }
#
#    # do() and execute() return the number of affected rows directly or:
#    # rows() is called on the statement handle $sth.
#    method rows() {
#        unless defined $!affected_rows {
#            $!affected_rows = PQcmdTuples($!result);
#
#            self!handle-errors;
#        }
#
#        if defined $!affected_rows {
#            return +$!affected_rows;
#        }
#    }
#
#    method fetchrow() {
#        my @row_array;
#        return if $!current_row >= $!row_count;
#
#        unless defined $!field_count {
#            $!field_count = PQnfields($!result);
#        }
#
#        if defined $!result {
#            self!reset_errstr;
#
#            for ^$!field_count {
#                @row_array.push(PQgetvalue($!result, $!current_row, $_));
#            }
#            $!current_row++;
#            self!handle-errors;
#
#            if ! @row_array { self.finish; }
#        }
#        return @row_array;
#    }
#
#    method column_names {
#        $!field_count = PQnfields($!result);
#        unless @!column_names {
#            for ^$!field_count {
#                my $column_name = PQfname($!result, $_);
#                @!column_names.push($column_name);
#            }
#        }
#        @!column_names
#    }
#
#    # for debugging only so far
#    method column_oids {
#        $!field_count = PQnfields($!result);
#        my @res;
#        for ^$!field_count {
#            @res.push: PQftype($!result, $_);
#        }
#        @res;
#    }
#
#    method fetchall_hashref(Str $key) {
#        my %results;
#
#        return if $!current_row >= $!row_count;
#
#        while my $row = self.fetchrow_hashref {
#            %results{$row{$key}} = $row;
#        }
#
#        my $results_ref = %results;
#        return $results_ref;
#    }
#
#    method finish() {
#        if defined($!result) {
#            PQclear($!result);
#            $!result       = Any;
#            @!column_names = ();
#        }
#        return Bool::True;
#    }
#
#    method !get_row {
#        my @data;
#        for ^$!field_count {
#            @data.push(PQgetvalue($!result, $!current_row, $_));
#        }
#        $!current_row++;
#
#        return @data;
#    }
#}
#
#class DBDish::Pg::Connection does DBDish::Connection {
#    has $!pg_conn;
#    has $.AutoCommit is rw = 1;
#    has $.in_transaction is rw;
#    method BUILD(:$!pg_conn) { }
#
#    method prepare(Str $statement, $attr?) {
#        state $statement_postfix = 0;
#        my $statement_name = join '_', 'pg', $*PID, $statement_postfix++;
#        my $munged = DBDish::Pg::pg-replace-placeholder($statement);
#        my $result = PQprepare(
#                $!pg_conn,
#                $statement_name,
#                $munged,
#                0,
#                OpaquePointer
#        );
#        my $status = PQresultStatus($result);
#        unless status-is-ok($status) {
#            self!set_errstr(PQresultErrorMessage($result));
#            die self.errstr if $.RaiseError;
#            return Nil;
#        }
#        my $info = PQdescribePrepared($!pg_conn, $statement_name);
#        my $param_count = PQnparams($info);
#
#        my $statement_handle = DBDish::Pg::StatementHandle.bless(
#            :$!pg_conn,
#            :$statement,
#            :$.RaiseError,
#            :dbh(self),
#            :$statement_name,
#            :$result,
#            :$param_count,
#        );
#        return $statement_handle;
#    }
#
#    method do(Str $statement, *@bind is copy) {
#        my $sth = self.prepare($statement);
#        $sth.execute(@bind);
#        my $rows = $sth.rows;
#        return ($rows == 0) ?? "0E0" !! $rows;
#    }
#
#    method selectrow_arrayref(Str $statement, $attr?, *@bind is copy) {
#        my $sth = self.prepare($statement, $attr);
#        $sth.execute(@bind);
#        return $sth.fetchrow_arrayref;
#    }
#
#    method selectrow_hashref(Str $statement, $attr?, *@bind is copy) {
#        my $sth = self.prepare($statement, $attr);
#        $sth.execute(@bind);
#        return $sth.fetchrow_hashref;
#    }
#
#    method selectall_arrayref(Str $statement, $attr?, *@bind is copy) {
#        my $sth = self.prepare($statement, $attr);
#        $sth.execute(@bind);
#        return $sth.fetchall_arrayref;
#    }
#
#    method selectall_hashref(Str $statement, Str $key, $attr?, *@bind is copy) {
#        my $sth = self.prepare($statement, $attr);
#        $sth.execute(@bind);
#        return $sth.fetchall_hashref($key);
#    }
#
#    method selectcol_arrayref(Str $statement, $attr?, *@bind is copy) {
#        my @results;
#
#        my $sth = self.prepare($statement, $attr);
#        $sth.execute(@bind);
#        while (my $row = $sth.fetchrow_arrayref) {
#            @results.push($row[0]);
#        }
#
#        my $aref = @results;
#        return $aref;
#    }
#
#    method commit {
#        if $!AutoCommit {
#            warn "Commit ineffective while AutoCommit is on";
#            return;
#        };
#        PQexec($!pg_conn, "COMMIT");
#        $.in_transaction = 0;
#    }
#
#    method rollback {
#        if $!AutoCommit {
#            warn "Rollback ineffective while AutoCommit is on";
#            return;
#        };
#        PQexec($!pg_conn, "ROLLBACK");
#        $.in_transaction = 0;
#    }
#
#    method ping {
#        PQstatus($!pg_conn) == CONNECTION_OK
#    }
#
#    method disconnect() {
#        PQfinish($!pg_conn);
#        True;
#    }
#}

class DBDish::Oracle:auth<mberends>:ver<0.0.1> {

    #our sub pg-replace-placeholder(Str $query) is export {
    #    PgTokenizer.parse($query, :actions(PgTokenizer::Actions.new))
    #        and $/.ast;
    #}

    has $.Version = 0.01;
    #has $!errstr;
    #method !errstr() is rw { $!errstr }
    #method errstr() { $!errstr }

    #sub quote-and-escape($s) {
    #    "'" ~ $s.trans([q{'}, q{\\]}] => [q{\\\'}, q{\\\\}])
    #        ~ "'"
    #}

    method get_errortext(OpaquePointer $handle, $handle_type = OCI_HTYPE_ERROR) {
        my @errorcodep := CArray[int32].new;
        @errorcodep[0] = 0;
        my @errortextp := CArray[int8].new;
        @errortextp[$_] = 0 for ^512;

        OCIErrorGet( $handle, 1, OpaquePointer, @errorcodep, @errortextp, 512, $handle_type );
        my @errortextary;
        for ^512 {
            last if @errortextp[$_] eq \0;
            @errortextary[$_] = @errortextp[$_];
        }
        return Buf.new(@errortextary).decode();
    }

#------------------ methods to be called from DBIish ------------------
    method connect(*%params) {
        my $host     = %params<host>     // 'localhost';
        my $port     = %params<port>     // 1521;
        my $dbname   = %params<dbname>   // die 'Missing <dbname> config';
        my $username = %params<username> // die 'Missing <username> config';
        my $password = %params<password> // die 'Missing <password> config';

        # create the environment handle
        my @envhpp := CArray[OpaquePointer].new;
        @envhpp[0]  = OpaquePointer;
        my OpaquePointer $ctxp,

        my int $errcode = OCIEnvNlsCreate(
            @envhpp,
            OCI_DEFAULT,
            $ctxp,
            OpaquePointer,
            OpaquePointer,
            OpaquePointer,
            0,
            OpaquePointer,
            OCI_UTF16ID,
            OCI_UTF16ID,
        );

        # fetch environment handle from pointer
        my $envhp = @envhpp[0];

        if $errcode ne OCI_SUCCESS {
            my $errortext = self.get_errortext( $envhp, OCI_HTYPE_ENV );
            die "OCIEnvNlsCreate failed: '$errortext'\n";
        }

        # allocate the error handle
        my @errhpp := CArray[OpaquePointer].new;
        @errhpp[0]  = OpaquePointer;
        OCIHandleAlloc($envhp, @errhpp, OCI_HTYPE_ERROR, 0, OpaquePointer );
        my $errhp = @errhpp[0];

        my @svchp := CArray[OpaquePointer].new;
        @svchp[0]  = OpaquePointer;

        $errcode = OCILogon2(
            $envhp,
            $errhp,
            @svchp,
            $username,
            $username.encode('UTF-16').elems,
            $password,
            $password.encode('UTF-16').elems,
            $dbname,
            $dbname.encode('UTF-16').elems,
            OCI_LOGON2_STMTCACHE,
        );
        if $errcode ne OCI_SUCCESS {
            die "OCILogon2 failed with errcode = $errcode.\n";
        }

        my $connection = DBDish::Oracle::Connection.bless(
                :@svchp[0],
                :RaiseError(%params<RaiseError>),
            );
        return $connection;
    }
}

=begin pod

=head1 DESCRIPTION
# 'zavolaj' is a Native Call Interface for Rakudo/Parrot. 'DBIish' and
# 'DBDish::Oracle' are Perl 6 modules that use 'zavolaj' to use the
# standard libclntsh library.  There is a long term Parrot based
# project to develop a new, comprehensive DBI architecture for Parrot
# and Perl 6.  DBIish is not that, it is a naive rewrite of the
# similarly named Perl 5 modules.  Hence the 'Mini' part of the name.

=head1 CLASSES
The DBDish::Oracle module contains the same classes and methods as every
database driver.  Therefore read the main documentation of usage in
L<doc:DBIish> and internal architecture in L<doc:DBDish>.  Below are
only notes about code unique to the DBDish::Oracle implementation.

=head1 SEE ALSO
The Oracle OCI Documentation, C Library.
L<http://docs.oracle.com/cd/E11882_01/appdev.112/e10646/oci02bas.htm#LNOCI16208>

=end pod

