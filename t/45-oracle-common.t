# DBIish/t/45-oracle-common.t
use v6;
need DBIish::CommonTesting;

DBIish::CommonTesting.new(
    dbd => 'Oracle',
    opts => {
        database => 'XE',
        username => 'TESTUSER',
        password => 'Testpass',
    },
    drop-table-sql => "
        BEGIN
           EXECUTE IMMEDIATE 'DROP TABLE nom';
        EXCEPTION
           WHEN OTHERS THEN
              IF SQLCODE != -942 THEN
                 RAISE;
              END IF;
        END;",
    create-table-sql => "
            CREATE TABLE nom (
                name        VARCHAR2(4),
                description VARCHAR2(30),
                quantity    NUMBER(20),
                price       NUMBER(5,2)
            )
        ",
    select-null-query => "SELECT NULL FROM DUAL",
).run-tests;

=begin pod

=head1 PREREQUISITES
Your system should already have the Oracle InstantClient and Oracle XE
installed.
Connect to the Oracle XE database and set up a test environment with the
following:

 CREATE USER "TESTUSER" IDENTIFIED BY Testpass DEFAULT TABLESPACE "USERS" TEMPORARY TABLESPACE "TEMP";
 ALTER USER "TESTUSER" QUOTA UNLIMITED ON USERS;
 GRANT "CONNECT" TO "TESTUSER";
 GRANT CREATE TABLE TO "TESTUSER";
 GRANT CREATE VIEW TO "TESTUSER";

=end pod
