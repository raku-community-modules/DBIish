# DBIish/t/45-oracle-common.t
use v6;
use Test;
use DBIish;

# Define the only database specific values used by the common tests.
my ( $*mdriver, %*opts, %*query ) = 'Oracle';
# DBDish::Oracle doesn't allow to pass host and port at the moment
#%*opts<host>     = 'localhost';
#%*opts<port>     = 1521;
%*opts<database> = 'XE';
%*opts<username> = 'testuser';
%*opts<password> = 'testpass';

# from http://stackoverflow.com/questions/1799128/oracle-if-table-exists
%*query<drop_table> = "
BEGIN
   EXECUTE IMMEDIATE 'DROP TABLE nom';
EXCEPTION
   WHEN OTHERS THEN
      IF SQLCODE != -942 THEN
         RAISE;
      END IF;
END;
";

my $dbh;

# Detect and report possible errors from EVAL of the common test script
warn $! if "ok 99-common.pl6" ne EVAL slurp 't/99-common.pl6';

=begin pod

=head1 PREREQUISITES
Your system should already have the Oracle InstantClient and Oracle XE
installed.
Connect to the Oracle XE database and set up a test environment with the
following:

 CREATE USER "testuser" IDENTIFIED BY testpass DEFAULT TABLESPACE "USERS" TEMPORARY TABLESPACE "TEMP";
 ALTER USER "testuser" QUOTA UNLIMITED ON USERS;
 GRANT "CONNECT" TO "testuser";
 GRANT CREATE TABLE TO "testuser";
 GRANT CREATE VIEW TO "testuser";

=end pod
