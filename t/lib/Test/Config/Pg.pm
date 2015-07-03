########################################################################
# housekeeping
# configure options for testing Postgres via DBIish::Pg
########################################################################

use v6;

unit module Test::Config::Pg;

sub config_pg_connect is export
{
    state %defaultz =
    <
        host    localhost
        port    5432
    >;

    my %optz    = ();

    %optz<database> = %*ENV< PGDATABASE >
    or die 'Environment lacks PGDATABASE';

    for < user password host port > -> $key
    {
        my $var         = %*ENV{ "PG{$key.uc}" } // %defaultz{ $key }
        // next;

        %optz{ $key }   = $var;
    }

    %optz
}

=begin pod

=head1 NAME

Test::Config::Pg - configuration for testing DBIish::Pg.

=head1 SYNOPSIS

    use Test::Config::Pg;

    # checks for PGDATABASE in environment, returning false if
    # it is not.
    # 
    # returns hash with kes of database, user password host port
    # from defaults of PGDATABASE, PGUSER, PGPASSWORD, etc.
    #
    # defaults:
    #   host => "localost"
    #   port => "5432"
    #
    # lacking PGDATABASE raises an exception, other values 
    # not avaiable in the environment are not returned.

    my %test_connect_opts = config_pg_connect;

=end pod

=finish
