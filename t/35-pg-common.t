# DBIish/t/35-pg-common.t
use v6;
need DBIish::CommonTesting;

my %opts;
# If env var set, no parameter needed.
%opts<database> = 'dbdishtest' unless %*ENV<PGDATABASE>;
%opts<user> = 'postgres' unless %*ENV<PGUSER>;

DBIish::CommonTesting.new(
    :dbd<Pg>,
    :%opts,
    post_connect_cb => sub {
	# We want to see some messages
        $^dbh.do( 'SET client_min_messages = warning' );
    }
).run-tests;

=begin pod

=head1 PREREQUISITES

Your system should already have PostgreSQL server installed and running.

DBDish uses the standard PG* environment variables to determine the
connection arguments, the tests by default use a 'dbdishtest' database,
that you can create with:

    psql -c 'CREATE DATABASE dbdishtest;' -U postgres

If you want to use a different database or other connection parameters,
set the corresponding environment variable, for example:

    export PGDATABASE = 'public';

This will connect to the 'public' on 'localhost' at port 5432.

The user should have connect and create table priv's on the database.

=end pod
