use v6;
need DBDish;     # roles for drivers

unit class DBDish::Oracle:auth<mberends>:ver<0.1.0> does DBDish::Driver;
use DBDish::Oracle::Native;
need DBDish::Oracle::Connection;
need DBDish::Oracle::StatementHandle;

=begin pod

=head1 NAME

DBDish::Oracle - Database driver for Oracle

=head1 DESCRIPTION

This module uses L<NativeCall> and the Oracle InstantClient version 12.1
to connect to Oracle databases, execute queries etc.
UTF-8 encoding is used for all strings, called AL32UTF8 by Oracle.
Currently only connecting using a tnsnames.ora entry is supported.

=head1 SEE ALSO

The Oracle OCI Documentation, C Library:
L<http://docs.oracle.com/cd/E11882_01/appdev.112/e10646/oci02bas.htm#LNOCI16208>

=end pod

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
    # replace each ? placeholder with a oracle's counted ones
    method placeholder($/)  { make ':' ~ $!counter++ }
    method single_quote($/) { make $/.Str }
    method double_quote($/) { make $/.Str }
}

our sub oracle-replace-placeholder(Str $query) is export {
    OracleTokenizer.parse($query, :actions(OracleTokenizer::Actions.new))
        and $/.ast;
}

#------------------ methods to be called from DBIish ------------------
method connect(:database(:$dbname), :$username, :$password, *%params) {

    # create the environment handle
    my $envh = OCIEnv.NlsCreate();
    if $envh ~~ OCIErr {
        self!conn-error(:code(+$envh), :errstr(~$envh));
    }

    # allocate the error handle
    my $errh = $envh.HandleAlloc(OCIError);
    if $errh ~~ OCIErr {
        self!conn-error(:code(+$errh), :errstr(~$errh));
    }

    my $svch = $envh.Logon(
        :$errh,
        :$username,
        :$password,
        :$dbname,
        :mode(OCI_LOGON2_STMTCACHE),
    );
    if $svch ~~ OCIErr {
        self!conn-error(:code(+$svch), :errstr("Logon failed: '$svch'"));
    }

    DBDish::Oracle::Connection.new(:$envh, :$errh, :$svch, :parent(self), |%params)
}

method version {
    libver;
}

# vim: expandtab ft=perl6
