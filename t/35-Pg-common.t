# DBIish/t/35-Pg-common.t
use v6;
use Test;
use DBIish;

use lib 't/lib';
use Test::Config::Pg;

# Define the only database specific values used by the common tests.

my $*mdriver    = 'Pg';
my %*opts       = config_pg_connect;

my $post_connect_cb =
{
    my $dbh = @_.shift;

    $dbh.do( 'SET client_min_messages = warning' );
};

# Detect and report possible errors from EVAL of the common test script

warn $! if "ok 99-common.pl6" ne EVAL slurp 't/99-common.pl6';

=begin pod

=head1 PREREQUISITES

Your system should already have libpq-dev installed. 

This uses the standard PG* environment variables to determine the 
connection arguments:

    export PGDATABASE = 'public';   # mininum required

This will connect to the 'public' on 'localhost' at port 5432.

The user should have connect, create table priv's on the database.

=head1 SEE ALSO

=over 4

=item t/lib/Test/Config/Pg.pm

Env var's used to configure connection.

=back

=end pod
