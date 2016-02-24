use v6;
# DBDish::Pg.pm6

unit class DBDish::Pg:auth<mberends>:ver<0.0.1>;
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
    token placeholder { '?' }
    token normal { <-[?"']>+ }

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
}

my class PgTokenizer::Actions {
    has $.counter = 0;
    method single_quote($/) { make $/.Str }
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

has $.Version = 0.01;
has $!errstr;
method !errstr() is rw { $!errstr }
method errstr() { $!errstr }

sub quote-and-escape($s) {
    "'" ~ $s.trans([q{'}, q{\\]}] => [q{\\\'}, q{\\\\}])
        ~ "'"
}

#------------------ methods to be called from DBIish ------------------
method connect(*%params) {
    my %keymap =
        database => 'dbname',
        ;
    my @connection_parameters = gather for %params.kv -> $key, $value {
        # Internal parameter, not for PostgreSQL usage.
        next if $key ~~ / <-lower> /;
        my $translated = %keymap{ $key } // $key;
        take "$translated={quote-and-escape $value}"
    }
    my $conninfo = ~@connection_parameters;
    my $pg_conn = PQconnectdb($conninfo);
    my $status = PQstatus($pg_conn);
    my $connection;
    if $status eq CONNECTION_OK {
        $connection = DBDish::Pg::Connection.new(
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

