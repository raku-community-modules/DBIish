# DBDish::Oracle.pm6

use NativeCall;
use DBDish;     # roles for drivers

use DBDish::Oracle::Native;
need DBDish::Oracle::Connection;
need DBDish::Oracle::StatementHandle;

unit class DBDish::Oracle:auth<mberends>:ver<0.0.1>;

#-----------------------------------------------------------------------

my grammar OracleTokenizer {
    token TOP {
        ^
        (
            | <normal>
            | <placeholder>
            | <single_quote>
            | <double_quote>
        )*
        $
    }
    token normal { <-[?"']>+ }
    token placeholder { '?' }
    token double_quote_normal { <-[\\"]>+ }
    token double_quote_escape { [\\ . ]+ }
    token double_quote {
        \"
        [
            | <.double_quote_normal>
            | <.double_quote_escape>
        ]*
        \"
    }
    token single_quote_normal { <-['\\]>+ }
    token single_quote_escape { [ \'\' || \\ . ]+ }
    token single_quote {
        \'
        [
            | <.single_quote_normal>
            | <.single_quote_escape>
        ]*
        \'
    }
}

my class OracleTokenizer::Actions {
    has $.counter = 0;
    method TOP($/) {
        make $0.map({.values[0].ast}).join;
    }
    method normal($/)       { make $/.Str }
    # replace each ? placeholder with a named one
    method placeholder($/)  { make ':p' ~ $!counter++ }
    method single_quote($/) { make $/.Str }
    method double_quote($/) { make $/.Str }
}

our sub oracle-replace-placeholder(Str $query) is export {
    OracleTokenizer.parse($query, :actions(OracleTokenizer::Actions.new))
        and $/.ast;
}

has $.Version = 0.01;

#sub quote-and-escape($s) {
#    "'" ~ $s.trans([q{'}, q{\\]}] => [q{\\\'}, q{\\\\}])
#        ~ "'"
#}

#------------------ methods to be called from DBIish ------------------
method connect(*%params) {
    # TODO: the dbname from tnsnames.ora includes the host and port config
    #my $host     = %params<host>     // 'localhost';
    #my $port     = %params<port>     // 1521;
    my $database = %params<database> // die 'Missing <database> config';
    my $username = %params<username> // die 'Missing <username> config';
    my $password = %params<password> // die 'Missing <password> config';

    # create the environment handle
    my @envhpp := CArray[Pointer].new;
    @envhpp[0]  = Pointer;
    my Pointer $ctxp;

    my sword $errcode = OCIEnvNlsCreate(
        @envhpp,
        OCI_DEFAULT,
        $ctxp,
        Pointer,
        Pointer,
        Pointer,
        0,
        Pointer,
        AL32UTF8,
        AL32UTF8,
    );

    # fetch environment handle from pointer
    my $envhp = @envhpp[0];

    if $errcode ne OCI_SUCCESS {
        my $errortext = get_errortext( $envhp, OCI_HTYPE_ENV );
        die "OCIEnvNlsCreate failed: '$errortext'";
    }

    # allocate the error handle
    my @errhpp := CArray[Pointer].new;
    @errhpp[0]  = Pointer;
    $errcode = OCIHandleAlloc($envhp, @errhpp, OCI_HTYPE_ERROR, 0, Pointer );
    if $errcode ne OCI_SUCCESS {
        die "OCIHandleAlloc failed: '$errcode'";
    }
    my $errhp = @errhpp[0];

    my @svchp := CArray[OCISvcCtx].new;
    @svchp[0]  = OCISvcCtx;

    $errcode = OCILogon2(
        $envhp,
        $errhp,
        @svchp,
        $username,
        $username.encode('utf8').bytes,
        $password,
        $password.encode('utf8').bytes,
        $database,
        $database.encode('utf8').bytes,
        OCI_LOGON2_STMTCACHE,
    );
    if $errcode ne OCI_SUCCESS {
        my $errortext = get_errortext($errhp);
        die "OCILogon2 failed: '$errortext'";
    }
    my $svchp = @svchp[0];

    my $connection = DBDish::Oracle::Connection.bless(
            :$envhp,
            :$svchp,
            :$errhp,
            :AutoCommit(%params<AutoCommit>),
            #:RaiseError(%params<RaiseError>),
        );
    return $connection;
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
