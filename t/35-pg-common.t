# DBIish/t/35-Pg-common.t
use v6;
use Test;
use DBIish;
use lib 't/lib';
use Test::DBDish;
use Test::Config::Pg;

if not %*ENV<PGDATABASE>:exists {
   plan 1;
   skip "'PGDATABASE' not set, skipping";
   exit;
}

my $test-dbdish = Test::DBDish.new(
    dbd => 'Pg',
    opts => config_pg_connect,
    post_connect_cb => sub {
        my $dbh = @_.shift;

        $dbh.do( 'SET client_min_messages = warning' );
    },
);

$test-dbdish.run-tests;

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
