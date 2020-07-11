use v6;
need DBDish;

unit class DBDish::Pg:auth<mberends>:ver<0.1.7> does DBDish::Driver;
use DBDish::Pg::Native;
need DBDish::Pg::Connection;

my grammar PgTokenizer {
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
    token single_quote_escape { [ \'\' | \\ . ]+ }
    token single_quote {
        \'
        [
        | <.single_quote_normal>
        | <.single_quote_escape>
        ]*
        \'
    }
    token dollar_placeholder {\$<digit>+}
    token dollar_quote {
        ( \$\$ | \$<alpha><alnum>*\$ ) .*? $0
    }
    token placeholder { '?' }
    token normal { <-[?"'$]>+ }

    token TOP {
        ^
        (
        | <normal>
        | <placeholder>
        | <dollar_placeholder>
        | <dollar_quote>
        | <single_quote>
        | <double_quote>
        )*
        $
    }
}

my class PgTokenizer::Actions {
    has $.counter = 0;
    method single_quote($/) { make $/.Str }
    method dollar_placeholder($/) { make $/.Str }
    method dollar_quote($/) { make $/.Str }
    method double_quote($/) { make $/.Str }
    method placeholder($/)  { make '$' ~ ++$!counter }
    method normal($/)       { make $/.Str }
    method TOP($/) {
        make $0.flatmap({.values[0].ast}).join;
    }
}

our sub pg-replace-placeholder(Str $query) is export {
    PgTokenizer.parse($query, :actions(PgTokenizer::Actions.new))
            and $/.ast;
}


#------------------ methods to be called from DBIish ------------------

method connect(:database(:$dbname), *%params) {

    %params.push((:$dbname)) with $dbname;
    my $pg-conn = PGconn.new(%(%params<
    host hostaddr port dbname user password connect-timeout
    client-encoding options application-name keepalives keepalives-idle
    keepalives-interval sslmode requiressl sslcert sslkey sslrootcert
    sslcrl requirepeer krbsrvname gsslib service>:p:delete));
    my $status = $pg-conn.PQstatus;
    if $status == CONNECTION_OK {
        DBDish::Pg::Connection.new(:$pg-conn, :parent(self), |%params);
    }
    else {
        self!conn-error: :code($status) :errstr($pg-conn.PQerrorMessage);
    }
}

method version {
    my $ver = PQlibVersion;
    $ver = Version.new((gather for ^3 { take $ver mod 100; $ver div= 100 }).reverse);
    CATCH { when X::AdHoc { } }
    $ver;
}

method data-sources(*%params) {
    with self.connect(:dbname<template1>, |%params) {
        LEAVE { .dispose }
        with .prepare('SELECT pg_catalog.quote_ident(datname) FROM pg_catalog.pg_database ORDER BY 1') {
            .execute;
            .allrows.map({ dbname => .[0] }) . eager; # 'cus this conn will be disposed
        } else { .fail }
    } else { .fail }
}

=begin pod

=head1 DESCRIPTION
# 'DBIish' and # 'DBDish::Pg' are Perl 6 modules that use Rakudo's
# NativeCall to use the standard libpq library.
# There is a long term Rakudo based project to develop a new,
# comprehensive DBI architecture for Rakudo and Perl 6.
# DBIish is not that, it is a naive rewrite of the similarly named Perl 5 modules.

=head1 CLASSES
The DBDish::Pg module contains the same classes and methods as every
database driver.  Therefore read the main documentation of usage in
L<doc:DBIish> and internal architecture in L<doc:DBDish>.  Below are
only notes about code unique to the DBDish::Pg implementation.

=head1 SEE ALSO
The PostgreSQL Documentation, C Library.
L<https://www.postgresql.org/docs/current/static/libpq.html>

=end pod

