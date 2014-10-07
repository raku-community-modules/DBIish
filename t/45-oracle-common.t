# DBIish/t/45-oracle-common.t
use v6;
use Test;
use DBIish;

# Define the only database specific values used by the common tests.
my ( $*mdriver, %*opts ) = 'Oracle';
%*opts<host>     = 'localhost';
%*opts<port>     = 1521;
%*opts<database> = 'XE';
%*opts<username> = 'testuser';
%*opts<password> = 'testpass';
my $dbh;

my $post_connect_cb = {
    my $dbh = @_.shift;
};

# Detect and report possible errors from EVAL of the common test script
warn $! if "ok 99-common.pl6" ne EVAL slurp 't/99-common.pl6';

=begin pod

=head1 PREREQUISITES
Your system should already have the Oracle InstantClient and Oracle XE
installed.
Connect to the Oracle XE database and set up a test environment with the
following:

 CREATE USER testuser IDENTIFIED BY testpass;
 GRANT "CONNECT" TO "testuser";

=end pod
