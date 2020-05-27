=begin pod

Before running the tests, prepare the database with something like:

$ mysql -u root -p
CREATE DATABASE dbdishtest;
CREATE USER 'testuser'@'localhost' IDENTIFIED BY 'testpass';
GRANT SELECT         ON   mysql.* TO 'testuser'@'localhost';
GRANT CREATE         ON dbdishtest.* TO 'testuser'@'localhost';
GRANT DROP           ON dbdishtest.* TO 'testuser'@'localhost';
GRANT INSERT         ON dbdishtest.* TO 'testuser'@'localhost';
GRANT DELETE         ON dbdishtest.* TO 'testuser'@'localhost';
GRANT LOCK TABLES    ON dbdishtest.* TO 'testuser'@'localhost';
GRANT SELECT         ON dbdishtest.* TO 'testuser'@'localhost';
# or maybe otherwise
GRANT ALL PRIVILEGES ON dbdishtest.* TO 'testuser'@'localhost';

# This '10-mysql.t' test script is a Perl 6 adaptation of the Perl 5
# based test suite for DBD::mysql version 4.014.  It is experimental and
# needs lots of work to increase coverage.  All the original lines
# containing tests are included here in #comments.

# Please change the Perl 6 parts of the test script freely, preserving
# just the file names from which the sections came, and the operations
# being tested.  And please document generously, so that others less
# clueful than yourself can also join in the fun.

# As yet uncommented Perl 5 code is enclosed in Pod 6 '=begin pod' and
# '=end pod' markers.

=end pod

use Test;

plan 90;

use DBIish;
#use DBDish::mysql;

# The file 'lib.pl' customizes the testing environment per DBD, but all
# this test script currently needs is the variables listed here.
my $mdriver       = 'mysql';
my $host          = 'localhost';
my $port          = 3306;
my $database      = 'dbdishtest';
my $test_user     = 'testuser';
my $test_password = 'testpass';
my $table         = 't1';

#-----------------------------------------------------------------------
# from perl5 DBD/mysql/t/00base.t
#use Test::More tests => 6;
## Base DBD Driver Test
#BEGIN {
#    use_ok('DBI') or BAIL_OUT "Unable to load DBI";
#    use_ok('DBD::mysql') or BAIL_OUT "Unable to load DBD::mysql";
#}
#$switch = DBI->internal;
#cmp_ok ref $switch, 'eq', 'DBI::dr', 'Internal set';
## This is a special case. install_driver should not normally be used.
#$drh= DBI->install_driver($mdriver);
#ok $drh, 'Install driver';
#cmp_ok ref $drh, 'eq', 'DBI::dr', 'DBI::dr set';
#ok $drh->{Version}, "Version $drh->{Version}";
#print "Driver version is ", $drh->{Version}, "\n";my $mdriver = 'mysql';
my $drh;
$drh = DBIish.install-driver($mdriver);
ok $drh, 'Install driver'; # test 1
my $drh_version;
$drh_version = $drh.Version;
ok $drh_version ~~ Version:D, "DBDish::mysql version $drh_version"; # test 2

#-----------------------------------------------------------------------
# from perl5 DBD/mysql/t/10connect.t
#plan tests => 2;
#EVAL {$dbh= DBI->connect($test_dsn, $test_user, $test_password,
#         { RaiseError => 1, PrintError => 1, AutoCommit => 0 });};
#ok defined $dbh, "Connected to database";
#ok $dbh->disconnect();
#
my $dbh = try {
    CATCH { default {
        diag "Connect failed with error $_";
        skip-rest 'prerequisites failed';
        exit;

    }}

    DBIish.connect($mdriver, :user($test_user), :password($test_password),
        :$host, :$port, :$database,
        :RaiseError, :PrintError, :AutoCommit(False)
    );
}

# die "ERROR: {DBIish.errstr}. Can't continue test" if $!.defined;
ok $dbh.defined, "Connected to database"; # test 3
my $result = $dbh.dispose;
ok $result, 'dispose returned true'; # test 4

#-----------------------------------------------------------------------
# from perl5 DBD/mysql/t/20createdrop.t
#plan tests => 4;
#ok(defined $dbh, "Connected to database");
#ok($dbh->do("DROP TABLE IF EXISTS $table"), "making slate clean");
#ok($dbh->do("CREATE TABLE $table (id INT(4), name VARCHAR(64))"), "creating $table");
#ok($dbh->do("DROP TABLE $table"), "dropping created $table");
#$dbh->disconnect();

try {
    $dbh = DBIish.connect( $mdriver, :user($test_user), :password($test_password),
	:$host, :$port, :$database,
        RaiseError => 1, PrintError => 1, AutoCommit => 0 );
    CATCH { die "ERROR: {DBIish.errstr}. Can't continue test\n"; }
}
ok($dbh.defined, "Connected to database"); # test 5
lives-ok({$dbh.do("DROP TABLE IF EXISTS $table")}, "making slate clean"); # test 6
lives-ok({$dbh.do("CREATE TEMPORARY TABLE $table (id INT(4), name VARCHAR(20))")}, "creating $table"); # test 7
lives-ok({$dbh.do("DROP TABLE $table")}, "dropping created $table"); # test 8

#-----------------------------------------------------------------------
# from perl5 DBD/mysql/t/25lockunlock.t
#my $create= <<EOT;
#CREATE TABLE $table (
#    id int(4) NOT NULL default 0,
#    name varchar(64) NOT NULL default ''
#    )
#EOT
#ok $dbh->do("DROP TABLE IF EXISTS $table"), "drop table if exists $table";
#ok $dbh->do($create), "create table $table";
#ok $dbh->do("LOCK TABLES $table WRITE"), "lock table $table";
#ok $dbh->do("INSERT INTO $table VALUES(1, 'Alligator Descartes')"), "Insert ";
#ok $dbh->do("DELETE FROM $table WHERE id = 1"), "Delete";
#EVAL {$sth= $dbh->prepare("SELECT * FROM $table WHERE id = 1")};
#ok !$@, "Prepare of select";
#ok defined($sth), "Prepare of select";
#ok  $sth->execute , "Execute";
#$row = $sth->fetchrow_arrayref;
#$errstr= $sth->errstr;
#ok !defined($row), "Fetch should have failed";
#ok !defined($errstr), "Fetch should have failed";
#ok $dbh->do("UNLOCK TABLES"), "Unlock tables";
#ok $dbh->do("DROP TABLE $table"), "Drop table $table";
my $create="
CREATE TEMPORARY TABLE $table (
    id int(4) NOT NULL default 0,
    name varchar(30) NOT NULL default ''
)
";
lives-ok { $dbh.do("DROP TABLE IF EXISTS $table") }, "drop table if exists $table"; # test 9
lives-ok { $dbh.do($create) }, "create table $table"; # test 10
ok $dbh.do("LOCK TABLES $table WRITE"), "lock tables $table write"; # test 11
ok $dbh.do("INSERT INTO $table VALUES(1, 'Alligator Descartes test 12')"), "Insert"; # test 12
lives-ok {$dbh.do("DELETE FROM $table WHERE id = 1") }, "Delete"; # test 13
my $sth;
try {
    $sth= $dbh.prepare("SELECT * FROM $table WHERE id = 1");
}
ok defined($sth), "Prepare of select"; # test 14
ok $sth.execute , "Execute"; # test 15
my ($row, $errstr);
$row = $sth.fetchrow_arrayref();
$errstr= $sth.errstr;
nok $row, "Fetch should have failed"; # test 16
nok $errstr, "Fetch should have failed"; # test 17
ok $dbh.do("UNLOCK TABLES"), "Unlock tables"; # test 18
ok $dbh.do("DROP TABLE $table"), "Drop table $table"; # test 19

#-----------------------------------------------------------------------
# from perl5 DBD/mysql/t/29warnings.t
#SKIP: {
#  skip "Server doesn't report warnings", 3
#    if $dbh->get_info($GetInfoType{SQL_DBMS_VER}) lt "4.1";
#  my $sth;
#  ok($sth= $dbh->prepare("DROP TABLE IF EXISTS no_such_table"));
#  ok($sth->execute());
#  is($sth->{mysql_warning_count}, 1);
#};
#try {
#    $dbh = DBIish.connect( $test_dsn, $test_user, $test_password,
#        RaiseError => 1, PrintError => 1, AutoCommit => 0 );
#    CATCH { die "ERROR: {DBIish.errstr}. Can't continue test\n"; }
#}
ok($sth= $dbh.prepare("DROP TABLE IF EXISTS no_such_table"), "prepare drop no_such_table"); # test 20
ok($sth.execute(), "execute drop no_such_table..."); # test 21
if $dbh.drv.library.name ~~ /mariadb/ {
   is($sth.mysql_warning_count, 1, "...do returns an error"); # test 22
} else {
   is($sth.mysql_warning_count, 0, "...do not returns an error"); # test 22 (Now fixed in mysql)
}

#-----------------------------------------------------------------------
# from perl5 DBD/mysql/t/30insertfetch.t
#plan tests => 10;
#ok($dbh->do("DROP TABLE IF EXISTS $table"), "making slate clean");
#ok($dbh->do("CREATE TABLE $table (id INT(4), name VARCHAR(64))"), "creating table");
#ok($dbh->do("INSERT INTO $table VALUES(1, 'Alligator Descartes')"), "loading data");
#ok($dbh->do("DELETE FROM $table WHERE id = 1"), "deleting from table $table");
#ok (my $sth= $dbh->prepare("SELECT * FROM $table WHERE id = 1"));
#ok($sth->execute());
#ok(not $sth->fetchrow_arrayref());
#ok($sth->finish());
#ok($dbh->do("DROP TABLE $table"),"Dropping table");

#-----------------------------------------------------------------------
# from perl5 DBD/mysql/t/31insertid.t
#plan tests => 18;
#ok $dbh->do("DROP TABLE IF EXISTS $table");
#my $create = <<EOT;
#CREATE TABLE $table (
#  id INT(3) PRIMARY KEY AUTO_INCREMENT NOT NULL,
#  name VARCHAR(64))
#EOT
#ok $dbh->do($create), "create $table";
#my $query= "INSERT INTO $table (name) VALUES (?)";
#ok ($sth= $dbh->prepare($query));
#ok defined $sth;
#ok $sth->execute("Jochen");
#is $dbh->{'mysql_insertid'}, 1, "insert id == $dbh->{mysql_insertid}";
#ok $sth->execute("Patrick");
#ok (my $sth2= $dbh->prepare("SELECT max(id) FROM $table"));
#ok defined $sth2;
#ok $sth2->execute();
#my $max_id;
#ok ($max_id= $sth2->fetch());
#ok defined $max_id;
#cmp_ok $sth->{'mysql_insertid'}, '==', $max_id->[0], "sth insert id $sth->{'mysql_insertid'} == max(id) $max_id->[0]  in $table";
#cmp_ok $dbh->{'mysql_insertid'}, '==', $max_id->[0], "dbh insert id $dbh->{'mysql_insertid'} == max(id) $max_id->[0] in $table";
#ok $sth->finish();
#ok $sth2->finish();
#ok $dbh->do("DROP TABLE $table");
#ok $dbh->disconnect();
ok $dbh.do("DROP TABLE IF EXISTS $table"), "drop table if exists $table"; # test 23
$create = "
CREATE TEMPORARY TABLE $table (
  id INT(3) PRIMARY KEY AUTO_INCREMENT NOT NULL,
  name VARCHAR(31))
";
ok $dbh.do($create), "create $table"; # test 24
my $query= "INSERT INTO $table (name) VALUES (?)";
ok ($sth= $dbh.prepare($query)), "prepare insert with parameter"; # test 25
ok $sth.execute("Jochen"), "execute insert with parameter"; # test 26
is $dbh.insert-id, 1, "insert id == \$dbh.insert-id (but only int, not long long)"; # test 27
ok $sth.execute("Patrick"), "execute 2nd insert with parameter"; # test 28
ok (my $sth2= $dbh.prepare("SELECT max(id) FROM $table")),"selectg max(id)"; # test 29
ok $sth2.defined,"second prepared statement"; # test 30
ok $sth2.execute(), "execute second prepared statement"; # test 31
my $max_id;
ok ($max_id= $sth2.fetch()),"fetch"; # test 32
ok $max_id.defined,"fetch result defined"; # test 33
is $sth.insert-id, $max_id[0], 'sth insert id $sth.insert-id == max(id) $max_id[0] in '~$table; # test 34
is $dbh.insert-id, $max_id[0], 'dbh insert id $dbh.insert-id == max(id) $max_id[0] in '~$table; # test 35
ok $sth.finish(), "statement 1 finish"; #  test 36
ok $sth2.finish(), "statement 2 finish"; # test 37
ok $dbh.do("DROP TABLE $table"),"drop table $table"; # test 38
# Because the drop table might fail, disconnect and reconnect
$dbh.dispose();
try {
    $dbh = DBIish.connect( $mdriver, :user($test_user), :password($test_password),
	:$host, :$port, :$database,
        RaiseError => 1, PrintError => 1, AutoCommit => 0 );
    CATCH { die "ERROR: {DBIish.errstr}. Can't continue test\n"; }
}

#-----------------------------------------------------------------------
# from perl5 DBD/mysql/t/32insert_error.t
# Test problem in 3.0002_4 and 3.0005 where if a statement is prepared
# and multiple executes are performed, if any execute fails all subsequent
# executes report an error but may have worked.
#plan tests => 9;
#ok $dbh->do("DROP TABLE IF EXISTS $table");
#my $create = <<EOT;
#CREATE TABLE $table (
#    id INT(3) PRIMARY KEY NOT NULL,
#    name VARCHAR(64))
#EOT
#ok $dbh->do($create);
#my $query = "INSERT INTO $table (id, name) VALUES (?,?)";
#ok (my $sth = $dbh->prepare($query));
#ok $sth->execute(1, "Jocken");
#$sth->{PrintError} = 0;
#EVAL {$sth->execute(1, "Jochen")};
#ok defined($@), 'fails with duplicate entry'; # $@ is last EVAL error message
#$sth->{PrintError} = 1;
#ok $sth->execute(2, "Jochen");
#ok $sth->finish;
#ok $dbh->do("DROP TABLE $table");
#ok $dbh->disconnect();
ok $dbh.do("DROP TABLE IF EXISTS $table"),"drop table if exists $table"; # test 39
$create = "
CREATE TEMPORARY TABLE $table (
    id INT(3) PRIMARY KEY NOT NULL,
    name VARCHAR(32))
";
ok $dbh.do($create), "create $table"; # test 40
$query = "INSERT INTO $table (id, name) VALUES (?,?)";
ok ($sth = $dbh.prepare($query)),"prepare $query"; #  test 41
ok $sth.execute(1, "Jocken"), "execute insert Jocken"; # test 42
$sth.PrintError = Bool::False;
dies-ok { $sth.execute(1, 'Jochen') }, 'fails with duplicate entry'; # test 43
ok $sth.errstr.defined, '... and got an error in $sth.errstr';       # test 44
$sth.PrintError = Bool::True;


#-----------------------------------------------------------------------
# from perl5 DBD/mysql/t/35limit.t
#plan tests => 111;
#ok($dbh->do("DROP TABLE IF EXISTS $table"), "making slate clean");
#ok($dbh->do("CREATE TABLE $table (id INT(4), name VARCHAR(64))"), "creating table");
#ok(($sth = $dbh->prepare("INSERT INTO $table VALUES (?,?)")));
#print "PERL testing insertion of values from previous prepare of insert statement:\n";
#for (my $i = 0 ; $i < 100; $i++) {
#  my @chars = grep !/[0O1Iil]/, 0..9, 'A'..'Z', 'a'..'z';
#  my $random_chars = join '', map { $chars[rand @chars] } 0 .. 16;
## save these values for later testing
#  $testInsertVals->{$i} = $random_chars;
#  ok(($rows = $sth->execute($i, $random_chars)));
#}
#print "PERL rows : " . $rows . "\n";
#print "PERL testing prepare of select statement with LIMIT placeholders:\n";
#ok($sth = $dbh->prepare("SELECT * FROM $table LIMIT ?, ?"));
#print "PERL testing exec of bind vars for LIMIT\n";
#ok($sth->execute(20, 50));
#my ($row, $errstr, $array_ref);
#ok( (defined($array_ref = $sth->fetchall_arrayref) &&
#  (!defined($errstr = $sth->errstr) || $sth->errstr eq '')));
#ok(@$array_ref == 50);
#ok($sth->finish);
#ok($dbh->do("DROP TABLE $table"));
ok($dbh.do("DROP TABLE IF EXISTS $table"), "making slate clean"); # test 45
ok($dbh.do("CREATE TEMPORARY TABLE $table (id INT(4), name VARCHAR(35))"), "creating table"); # test 46
ok(($sth = $dbh.prepare("INSERT INTO $table (id,name) VALUES (?,?)")),"prepare insert with 2 params"); # test 47
my ( %testInsertVals, $all_ok );
$all_ok = Bool::True;
loop (my $i = 0 ; $i < 100; $i++) {
  my @chars = flat grep /<-[0O1Iil]>/, 0..9, 'A'..'Z', 'a'..'z';
  my $random_chars = @chars.roll(16).join;
  %testInsertVals{$i} = $random_chars; # save these values for later testing
  unless $sth.execute($i, $random_chars) { $all_ok = Bool::False; }
}
ok( $all_ok,"insert 100 rows of random chars"); # test 48
ok($sth = $dbh.prepare("SELECT * FROM $table LIMIT ?, ?"),"prepare of select statement with LIMIT placeholders:"); # test 49
ok($sth.execute(20, 50),"exec of bind vars for LIMIT"); # test 50
my ($array_ref);
ok( (defined($array_ref = $sth.fetchall_arrayref) &&
  (!defined($errstr = $sth.errstr) || $sth.errstr eq '')),"fetchall_arrayref"); # test 51
is($array_ref.elems, 50,"limit 50 works"); # test 52


#-----------------------------------------------------------------------
# from perl5 DBD/mysql/t/35prepare.t
#plan tests => 49;
#ok($dbh->do("DROP TABLE IF EXISTS t1"), "Making slate clean");
#ok($dbh->do("CREATE TABLE t1 (id INT(4), name VARCHAR(64))"),
#  "Creating table");
#ok($sth = $dbh->prepare("SHOW TABLES LIKE 't1'"),
#  "Testing prepare show tables");
#ok($sth->execute(), "Executing 'show tables'");
#ok((defined($row= $sth->fetchrow_arrayref) &&
#  (!defined($errstr = $sth->errstr) || $sth->errstr eq '')),
#  "Testing if result set and no errors");
#ok($row->[0] eq 't1', "Checking if results equal to 't1' \n");
#ok($sth->finish, "Finishing up with statement handle");
#ok($dbh->do("INSERT INTO t1 VALUES (1,'1st first value')"),
#  "Inserting first row");
#ok($sth= $dbh->prepare("INSERT INTO t1 VALUES (2,'2nd second value')"),
#  "Preparing insert of second row");
#ok(($rows = $sth->execute()), "Inserting second row");
#ok($rows == 1, "One row should have been inserted");
#ok($sth->finish, "Finishing up with statement handle");
#ok($sth= $dbh->prepare("SELECT id, name FROM t1 WHERE id = 1"),
#  "Testing prepare of query");
#ok($sth->execute(), "Testing execute of query");
#ok($ret_ref = $sth->fetchall_arrayref(),
#  "Testing fetchall_arrayref of executed query");
#ok($sth= $dbh->prepare("INSERT INTO t1 values (?, ?)"),
#  "Preparing insert, this time using placeholders");
#my $testInsertVals = {};
#for (my $i = 0 ; $i < 10; $i++)
#{
#  my @chars = grep !/[0O1Iil]/, 0..9, 'A'..'Z', 'a'..'z';
#  my $random_chars= join '', map { $chars[rand @chars] } 0 .. 16;
#   # save these values for later testing
#  $testInsertVals->{$i}= $random_chars;
#  ok($rows= $sth->execute($i, $random_chars), "Testing insert row");
#  ok($rows= 1, "Should have inserted one row");
#}
#ok($sth->finish, "Testing closing of statement handle");
#ok($sth= $dbh->prepare("SELECT * FROM t1 WHERE id = ? OR id = ?"),
#  "Testing prepare of query with placeholders");
#ok($rows = $sth->execute(1,2),
#  "Testing execution with values id = 1 or id = 2");
#ok($ret_ref = $sth->fetchall_arrayref(),
#  "Testing fetchall_arrayref (should be four rows)");
#print "RETREF " . scalar @$ret_ref . "\n";
#ok(@{$ret_ref} == 4 , "\$ret_ref should contain four rows in result set");
#ok($sth= $dbh->prepare("DROP TABLE IF EXISTS t1"),
#  "Testing prepare of dropping table");
#ok($sth->execute(), "Executing drop table");
# Bug #20153: Fetching all data from a statement handle does not mark it
# as finished
#ok($sth= $dbh->prepare("SELECT 1"), "Prepare - Testing bug #20153");
#ok($sth->execute(), "Execute - Testing bug #20153");
#ok($sth->fetchrow_arrayref(), "Fetch - Testing bug #20153");
#ok(!($sth->fetchrow_arrayref()),"Not Fetch - Testing bug #20153");
## Install a handler so that a warning about unfreed resources gets caught
#$SIG{__WARN__} = sub { die @_ };
#ok($dbh->disconnect(), "Testing disconnect");
ok($dbh.do("DROP TABLE IF EXISTS t1"), "35prepare.t Making slate clean"); # test 53
ok($dbh.do("CREATE TABLE t1 (id INT(4), name VARCHAR(35))"), "Creating table"); # test 54
ok($sth = $dbh.prepare("SHOW TABLES LIKE 't1'"),"prepare show tables"); # test 55
ok($sth.execute(), "Executing 'show tables'"); # test 56
my @row;
ok((defined(@row = $sth.fetchrow_array) &&
  (!defined($errstr = $sth.errstr) || $sth.errstr eq '')),
  "Testing if result set and no errors"); # test 57
is(@row[0], 't1', "Checking if results equal to 't1'"); # test 58
ok($sth.finish, "Finishing up with statement handle"); # test 59
ok($dbh.do("INSERT INTO t1 VALUES (1,'1st first value')"),"Inserting first row"); # test 60
ok($sth= $dbh.prepare("INSERT INTO t1 VALUES (2,'2nd second value')"),"Preparing insert of second row"); # test 61
my $rows;
ok(($rows = $sth.execute()), "Inserting second row"); # test 62
is($rows, 1, "One row should have been inserted"); # test 63
ok($sth.finish, "Finishing up with statement handle"); # test 64
ok($sth= $dbh.prepare("SELECT id, name FROM t1 WHERE id = 1"),"Testing prepare of query"); # test 65
ok($sth.execute(), "Testing execute of query"); # test 66
ok(my $ret_ref = $sth.fetchall_arrayref(),"Testing fetchall_arrayref of executed query"); # test 67
ok($sth= $dbh.prepare("INSERT INTO t1 values (?, ?)"),"Preparing insert, this time using placeholders"); # test 68
%testInsertVals = ();
$all_ok = Bool::True;
loop ($i = 0 ; $i < 10; $i++) {
  my @chars = grep /<-[0O1Iil]> /, flat 0..9, 'A'..'Z', 'a'..'z';
  my $random_chars= @chars.roll(16).join('');
  %testInsertVals{$i}= $random_chars; # save these values for later testing
  unless $sth.execute($i, $random_chars) { $all_ok = Bool::False; }
}
ok($all_ok, "Should have inserted one row (10 times)"); # test 69
ok($sth.finish, "Testing closing of statement handle"); # test 70
ok($sth= $dbh.prepare("SELECT * FROM t1 WHERE id = ? OR id = ?"),"Testing prepare of query with placeholders"); # test 71
ok($rows = $sth.execute(1,2),"Testing execution with values id = 1 or id = 2"); # test 72
ok($ret_ref = $sth.fetchall_arrayref(),"Testing fetchall_arrayref (should be four rows)"); # test 73
is($ret_ref.elems, 4, "\$ret_ref should contain four rows in result set"); # test 74
is($ret_ref[2][1], %testInsertVals{'1'}, "verify third row"); # test 75
ok($sth= $dbh.prepare("DROP TABLE IF EXISTS t1"),"Testing prepare of dropping table"); # test 76
ok($sth.execute(), "Executing drop table"); # test 77
ok($sth= $dbh.prepare("SELECT 1"), "Prepare - Testing bug #20153"); # test 78
ok($sth.execute(), "Execute - Testing bug #20153"); # test 79
ok($sth.fetchrow_arrayref(), "Fetch - Testing bug #20153"); # test 80
ok(!($sth.fetchrow_arrayref()),"Not Fetch - Testing bug #20153"); # test 81

#-----------------------------------------------------------------------
# from perl5 DBD/mysql/t/40bindparam.t
#plan tests => 41;
#ok ($dbh->do("DROP TABLE IF EXISTS $table"));
#my $create = <<EOT;
#CREATE TABLE $table (
#        id int(4) NOT NULL default 0,
#        name varchar(64) default ''
#        )
#EOT
#ok ($dbh->do($create));
#ok ($sth = $dbh->prepare("INSERT INTO $table VALUES (?, ?)"));
# Automatic type detection
#my $numericVal = 1;
#my $charVal = "Alligator Descartes";
#ok ($sth->execute($numericVal, $charVal));
# Does the driver remember the automatically detected type?
#ok ($sth->execute("3", "Jochen Wiedmann"));
#$numericVal = 2;
#$charVal = "Tim Bunce";
#ok ($sth->execute($numericVal, $charVal));
# Now try the explicit type settings
#ok ($sth->bind_param(1, " 4", SQL_INTEGER()));
# umlaut equivelant is vowel followed by 'e'
#ok ($sth->bind_param(2, 'Andreas Koenig'));
#ok ($sth->execute);
# Works undef -> NULL?
#ok ($sth->bind_param(1, 5, SQL_INTEGER()));
#ok ($sth->bind_param(2, undef));
#ok ($sth->execute);
#ok ($sth->bind_param(1, undef, SQL_INTEGER()));
#ok ($sth->bind_param(2, undef));
#ok ($sth->execute(-1, "abc"));
#ok ($dbh->do("INSERT INTO $table VALUES (6, '?')"));
#ok ($dbh->do('SET @old_sql_mode = @@sql_mode, @@sql_mode = \'\''));
#ok ($dbh->do("INSERT INTO $table VALUES (7, \"?\")"));
#ok ($dbh->do('SET @@sql_mode = @old_sql_mode'));
#ok ($sth = $dbh->prepare("SELECT * FROM $table ORDER BY id"));
#ok($sth->execute);
#ok ($sth->bind_columns(undef, \$id, \$name));
#$ref = $sth->fetch ;
#is $id,  -1, 'id set to -1';
#cmp_ok $name, 'eq', 'abc', 'name eq abc';
#$ref = $sth->fetch;
#is $id, 1, 'id set to 1';
#cmp_ok $name, 'eq', 'Alligator Descartes', '$name set to Alligator Descartes';
#$ref = $sth->fetch;
#is $id, 2, 'id set to 2';
#cmp_ok $name, 'eq', 'Tim Bunce', '$name set to Tim Bunce';
#$ref = $sth->fetch;
#is $id, 3, 'id set to 3';
#cmp_ok $name, 'eq', 'Jochen Wiedmann', '$name set to Jochen Wiedmann';
#$ref = $sth->fetch;
#is $id, 4, 'id set to 4';
#cmp_ok $name, 'eq', 'Andreas Koenig', '$name set to Andreas Koenig';
#$ref = $sth->fetch;
#is $id, 5, 'id set to 5';
#ok !defined($name), 'name not defined';
#$ref = $sth->fetch;
#is $id, 6, 'id set to 6';
#cmp_ok $name, 'eq', '?', "\$name set to '?'";
#$ref = $sth->fetch;
#is $id, 7, '$id set to 7';
#cmp_ok $name, 'eq', '?', "\$name set to '?'";
#ok ($dbh->do("DROP TABLE $table"));
#ok $sth->finish;
#ok $dbh->disconnect;
ok ($dbh.do("DROP TABLE IF EXISTS $table")),"drop table before 40bindparam.t"; # test 82
$create = "
CREATE TEMPORARY TABLE $table (
        id int(4) NOT NULL default 0,
        name varchar(40) default ''
        )
";
ok ($dbh.do($create)),"create table with defaults"; # test 83
ok ($sth = $dbh.prepare("INSERT INTO $table VALUES (?, ?)")),"prepare parameterized insert"; # test 84
my $numericVal = 1; # Automatic type detection
my $charVal = "Alligator Descartes";
ok ($sth.execute($numericVal, $charVal)),"execute insert with numeric and char"; # test 85
# Does the driver remember the automatically detected type?
ok ($sth.execute("3", "Jochen Wiedmann")),"insert with string for numeric field"; # test 86
$numericVal = 2;
$charVal = "Tim Bunce";
ok ($sth.execute($numericVal, $charVal)),"insert with number for numeric"; # test 87
# Test quote methods
is $dbh.quote-identifier('ID'), '`ID`',  "Proper legacy quoted identifier";
is $dbh.quote('foo'),       "'foo'",    'Quote literal';
is $dbh.quote('foo'):as-id, '`foo`',    'Quote Id';

# Now try the explicit type settings
#ok ($sth.bind_param(1, " 4", SQL_INTEGER())),"bind_param SQL_INTEGER"; # test 88


#-----------------------------------------------------------------------
# from perl5 DBD/mysql/t/40bindparam2.t
#EVAL {$dbh = DBI->connect($test_dsn, $test_user, $test_password,
#  { RaiseError => 1, AutoCommit => 1}) or ServerError();};
#if ($@) {
#    plan skip_all => "ERROR: $DBI::errstr. Can't continue test";
#}
#plan tests => 13;
#ok $dbh->do("DROP TABLE IF EXISTS $table"), "drop table $table";
#my $create= <<EOT;
#CREATE TABLE $table (
#    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
#    num INT(3))
#EOT
#ok $dbh->do($create), "create table $table";
#ok $dbh->do("INSERT INTO $table VALUES(NULL, 1)"), "insert into $table (null, 1)";
#my $rows;
#ok ($rows= $dbh->selectall_arrayref("SELECT * FROM $table"));
#is $rows->[0][1], 1, "\$rows->[0][1] == 1";
#ok ($sth = $dbh->prepare("UPDATE $table SET num = ? WHERE id = ?"));
#ok ($sth->bind_param(2, 1, SQL_INTEGER()));
#ok ($sth->execute());
#ok ($sth->finish());
#ok ($rows = $dbh->selectall_arrayref("SELECT * FROM $table"));
#ok !defined($rows->[0][1]);
#ok ($dbh->do("DROP TABLE $table"));
#ok ($dbh->disconnect());

#ok $dbh.do("DROP TABLE IF EXISTS $table"), "drop table $table"; # test 87
#$create= "
#CREATE TABLE $table (
#    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
#    num INT(3))
#";
#ok $dbh.do($create), "create table $table"; # test 88
#ok $dbh.do("INSERT INTO $table VALUES(NULL, 1)"), "insert into $table (null, 1)"; # test 89


#-----------------------------------------------------------------------
# from perl5 DBD/mysql/t/40blobs.t
#   This is a test for correct handling of BLOBS; namely $dbh->quote
#   is expected to work correctly.
#sub ShowBlob($) {
#    my ($blob) = @_;
#    for ($i = 0;  $i < 8;  $i++) {
#        if (defined($blob)  &&  length($blob) > $i) {
#            $b = substr($blob, $i*32);
#        }
#        else {
#            $b = "";
#        }
#        printf("%08lx %s\n", $i*32, unpack("H64", $b));
#    }
#}
#my $charset= 'DEFAULT CHARSET=utf8';
#plan tests => 14;
#if ($dbh->get_info($GetInfoType{SQL_DBMS_VER}) lt "4.1") {
#    $charset= '';
#}
#my $size= 128;
#ok $dbh->do("DROP TABLE IF EXISTS $table"), "Drop table if exists $table";
#my $create = <<EOT;
#CREATE TABLE $table (
#    id INT(3) NOT NULL DEFAULT 0,
#    name BLOB ) $charset
#EOT
#ok ($dbh->do($create));
#my ($blob, $qblob) = "";
#my $b = "";
#for ($j = 0;  $j < 256;  $j++) {
#    $b .= chr($j);
#}
#for ($i = 0;  $i < $size;  $i++) {
#    $blob .= $b;
#}
#ok ($qblob = $dbh->quote($blob));
#   Insert a row into the test table.......
#my ($query);
#$query = "INSERT INTO $table VALUES(1, $qblob)";
#ok ($dbh->do($query));
#   Now, try SELECT'ing the row out.
#ok ($sth = $dbh->prepare("SELECT * FROM $table WHERE id = 1"));
#ok ($sth->execute);
#ok ($row = $sth->fetchrow_arrayref);
#ok defined($row), "row returned defined";
#is @$row, 2, "records from $table returned 2";
#is $$row[0], 1, 'id set to 1';
#cmp_ok byte_string($$row[1]), 'eq', byte_string($blob), 'blob set equal to blob returned';
#ShowBlob($blob), ShowBlob(defined($$row[1]) ? $$row[1] : "");
#ok ($sth->finish);
#ok $dbh->do("DROP TABLE $table"), "Drop table $table";
#ok $dbh->disconnect;

=begin pod
#-----------------------------------------------------------------------
# from perl5 DBD/mysql/t/40catalog.t
#EVAL {$dbh= DBI->connect($test_dsn, $test_user, $test_password,
#                      { RaiseError            => 1,
#                        PrintError            => 1,
#                        AutoCommit            => 0,
#                        mysql_server_prepare  => 0 });};
#plan tests => 77;
#ok(defined $dbh, "connecting");
#my $sth;
#my ($version)= $dbh->selectrow_array("SELECT version()")
#  or DbiError($dbh->err, $dbh->errstr);

#
# Bug #26604: foreign_key_info() implementation
#
# The tests for this are adapted from the Connector/J test suite.
#
SKIP: {
  skip "Server is too old to support INFORMATION_SCHEMA for foreign keys", 16
    if substr($version, 0, 1) < 5;

  my ($dummy,$have_innodb)=
    $dbh->selectrow_array("SHOW VARIABLES LIKE 'have_innodb'")
    or DbiError($dbh->err, $dbh->errstr);
  skip "Server doesn't support InnoDB, needed for testing foreign keys", 16
    unless defined $have_innodb && $have_innodb eq "YES";

  ok($dbh->do(qq{DROP TABLE IF EXISTS child, parent}), "cleaning up");

  ok($dbh->do(qq{CREATE TABLE parent(id INT NOT NULL,
                                     PRIMARY KEY (id)) ENGINE=INNODB}));
  ok($dbh->do(qq{CREATE TABLE child(id INT, parent_id INT,
                                    FOREIGN KEY (parent_id)
                                      REFERENCES parent(id) ON DELETE SET NULL)
              ENGINE=INNODB}));

  $sth= $dbh->foreign_key_info(undef, undef, "parent", undef, undef, "child");
  my ($info)= $sth->fetchall_arrayref({});

  is($info->[0]->{PKTABLE_NAME}, "parent");
  is($info->[0]->{PKCOLUMN_NAME}, "id");
  is($info->[0]->{FKTABLE_NAME}, "child");
  is($info->[0]->{FKCOLUMN_NAME}, "parent_id");

  $sth= $dbh->foreign_key_info(undef, undef, "parent", undef, undef, undef);
  ($info)= $sth->fetchall_arrayref({});

  is($info->[0]->{PKTABLE_NAME}, "parent");
  is($info->[0]->{PKCOLUMN_NAME}, "id");
  is($info->[0]->{FKTABLE_NAME}, "child");
  is($info->[0]->{FKCOLUMN_NAME}, "parent_id");

  $sth= $dbh->foreign_key_info(undef, undef, undef, undef, undef, "child");
  ($info)= $sth->fetchall_arrayref({});

  is($info->[0]->{PKTABLE_NAME}, "parent");
  is($info->[0]->{PKCOLUMN_NAME}, "id");
  is($info->[0]->{FKTABLE_NAME}, "child");
  is($info->[0]->{FKCOLUMN_NAME}, "parent_id");

  ok($dbh->do(qq{DROP TABLE IF EXISTS child, parent}), "cleaning up");
};

#
# table_info() tests
#
# These tests assume that no other tables name like 't_dbd_mysql_%' exist on
# the server we are using for testing.
#
SKIP: {
  skip "Server can't handle tricky table names", 33
    if $dbh->get_info($GetInfoType{SQL_DBMS_VER}) lt "4.1";

  my $sth = $dbh->table_info("%", undef, undef, undef);
  is(scalar @{$sth->fetchall_arrayref()}, 0, "No catalogs expected");

  $sth = $dbh->table_info(undef, "%", undef, undef);
  ok(scalar @{$sth->fetchall_arrayref()} > 0, "Some schemas expected");

  $sth = $dbh->table_info(undef, undef, undef, "%");
  ok(scalar @{$sth->fetchall_arrayref()} > 0, "Some table types expected");

  ok($dbh->do(qq{DROP TABLE IF EXISTS t_dbd_mysql_t1, t_dbd_mysql_t11,
                                      t_dbd_mysql_t2, t_dbd_mysqlat2,
                                      `t_dbd_mysql_a'b`,
                                      `t_dbd_mysql_a``b`}),
              "cleaning up");
  ok($dbh->do(qq{CREATE TABLE t_dbd_mysql_t1 (a INT)}) and
     $dbh->do(qq{CREATE TABLE t_dbd_mysql_t11 (a INT)}) and
     $dbh->do(qq{CREATE TABLE t_dbd_mysql_t2 (a INT)}) and
     $dbh->do(qq{CREATE TABLE t_dbd_mysqlat2 (a INT)}) and
     $dbh->do(qq{CREATE TABLE `t_dbd_mysql_a'b` (a INT)}) and
     $dbh->do(qq{CREATE TABLE `t_dbd_mysql_a``b` (a INT)}),
     "creating test tables");

  # $base is our base table name, with the _ escaped to avoid extra matches
  my $esc = $dbh->get_info(14); # SQL_SEARCH_PATTERN_ESCAPE
  (my $base = "t_dbd_mysql_") =~ s/([_%])/$esc$1/g;

  # Test fetching info on a single table
  $sth = $dbh->table_info(undef, undef, $base . "t1", undef);
  my $info = $sth->fetchall_arrayref({});

  is($info->[0]->{TABLE_CAT}, undef);
  is($info->[0]->{TABLE_NAME}, "t_dbd_mysql_t1");
  is($info->[0]->{TABLE_TYPE}, "TABLE");
  is(scalar @$info, 1, "one row expected");

  # Test fetching info on a wildcard
  $sth = $dbh->table_info(undef, undef, $base . "t1%", undef);
  $info = $sth->fetchall_arrayref({});

  is($info->[0]->{TABLE_CAT}, undef);
  is($info->[0]->{TABLE_NAME}, "t_dbd_mysql_t1");
  is($info->[0]->{TABLE_TYPE}, "TABLE");
  is($info->[1]->{TABLE_CAT}, undef);
  is($info->[1]->{TABLE_NAME}, "t_dbd_mysql_t11");
  is($info->[1]->{TABLE_TYPE}, "TABLE");
  is(scalar @$info, 2, "two rows expected");

  # Test fetching info on a single table with escaped wildcards
  $sth = $dbh->table_info(undef, undef, $base . "t2", undef);
  $info = $sth->fetchall_arrayref({});

  is($info->[0]->{TABLE_CAT}, undef);
  is($info->[0]->{TABLE_NAME}, "t_dbd_mysql_t2");
  is($info->[0]->{TABLE_TYPE}, "TABLE");
  is(scalar @$info, 1, "only one table expected");

  # Test fetching info on a single table with ` in name
  $sth = $dbh->table_info(undef, undef, $base . "a`b", undef);
  $info = $sth->fetchall_arrayref({});

  is($info->[0]->{TABLE_CAT}, undef);
  is($info->[0]->{TABLE_NAME}, "t_dbd_mysql_a`b");
  is($info->[0]->{TABLE_TYPE}, "TABLE");
  is(scalar @$info, 1, "only one table expected");

  # Test fetching info on a single table with ' in name
  $sth = $dbh->table_info(undef, undef, $base . "a'b", undef);
  $info = $sth->fetchall_arrayref({});

  is($info->[0]->{TABLE_CAT}, undef);
  is($info->[0]->{TABLE_NAME}, "t_dbd_mysql_a'b");
  is($info->[0]->{TABLE_TYPE}, "TABLE");
  is(scalar @$info, 1, "only one table expected");

  # Test fetching our tables with a wildcard schema
  # NOTE: the performance of this could be bad if the mysql user we
  # are connecting as can see lots of databases.
  $sth = $dbh->table_info(undef, "%", $base . "%", undef);
  $info = $sth->fetchall_arrayref({});

  is(scalar @$info, 5, "five tables expected");

  # Check that tables() finds and escapes the tables named with quotes
  $info = [ $dbh->tables(undef, undef, $base . 'a%') ];
  like($info->[0], qr/\.`t_dbd_mysql_a'b`$/, "table with single quote");
  like($info->[1], qr/\.`t_dbd_mysql_a``b`$/,  "table with back quote");
  is(scalar @$info, 2, "two tables expected");

  # Clean up
  ok($dbh->do(qq{DROP TABLE IF EXISTS t_dbd_mysql_t1, t_dbd_mysql_t11,
                                      t_dbd_mysql_t2, t_dbd_mysqlat2,
                                      `t_dbd_mysql_a'b`,
                                      `t_dbd_mysql_a``b`}),
              "cleaning up");
};

#
# view-related table_info tests
#
SKIP: {
  skip "Server is too old to support views", 19
    if substr($version, 0, 1) < 5;

  #
  # Bug #26603: (one part) support views in table_info()
  #
  ok($dbh->do(qq{DROP VIEW IF EXISTS bug26603_v1}) and
     $dbh->do(qq{DROP TABLE IF EXISTS bug26603_t1}), "cleaning up");

  ok($dbh->do(qq{CREATE TABLE bug26603_t1 (a INT)}) and
     $dbh->do(qq{CREATE VIEW bug26603_v1 AS SELECT * FROM bug26603_t1}),
     "creating resources");

  # Try without any table type specified
  $sth = $dbh->table_info(undef, undef, "bug26603%");
  my $info = $sth->fetchall_arrayref({});
  is($info->[0]->{TABLE_NAME}, "bug26603_t1");
  is($info->[0]->{TABLE_TYPE}, "TABLE");
  is($info->[1]->{TABLE_NAME}, "bug26603_v1");
  is($info->[1]->{TABLE_TYPE}, "VIEW");
  is(scalar @$info, 2, "two rows expected");

  # Just get the view
  $sth = $dbh->table_info(undef, undef, "bug26603%", "VIEW");
  $info = $sth->fetchall_arrayref({});

  is($info->[0]->{TABLE_NAME}, "bug26603_v1");
  is($info->[0]->{TABLE_TYPE}, "VIEW");
  is(scalar @$info, 1, "one row expected");

  # Just get the table
  $sth = $dbh->table_info(undef, undef, "bug26603%", "TABLE");
  $info = $sth->fetchall_arrayref({});

  is($info->[0]->{TABLE_NAME}, "bug26603_t1");
  is($info->[0]->{TABLE_TYPE}, "TABLE");
  is(scalar @$info, 1, "one row expected");

  # Get both tables and views
  $sth = $dbh->table_info(undef, undef, "bug26603%", "'TABLE','VIEW'");
  $info = $sth->fetchall_arrayref({});

  is($info->[0]->{TABLE_NAME}, "bug26603_t1");
  is($info->[0]->{TABLE_TYPE}, "TABLE");
  is($info->[1]->{TABLE_NAME}, "bug26603_v1");
  is($info->[1]->{TABLE_TYPE}, "VIEW");
  is(scalar @$info, 2, "two rows expected");

  ok($dbh->do(qq{DROP VIEW IF EXISTS bug26603_v1}) and
     $dbh->do(qq{DROP TABLE IF EXISTS bug26603_t1}), "cleaning up");

};

#
# column_info() tests
#
SKIP: {
  ok($dbh->do(qq{DROP TABLE IF EXISTS t1}), "cleaning up");
  ok($dbh->do(qq{CREATE TABLE t1 (a INT PRIMARY KEY AUTO_INCREMENT,
                                  b INT,
                                  `a_` INT,
                                  `a'b` INT,
                                  bar INT
                                  )}), "creating table");

  #
  # Bug #26603: (one part) add mysql_is_autoincrement
  #
  $sth= $dbh->column_info(undef, undef, "t1", 'a');
  my ($info)= $sth->fetchall_arrayref({});
  is($info->[0]->{mysql_is_auto_increment}, 1);

  $sth= $dbh->column_info(undef, undef, "t1", 'b');
  ($info)= $sth->fetchall_arrayref({});
  is($info->[0]->{mysql_is_auto_increment}, 0);

  #
  # Test that wildcards and odd names are handled correctly
  #
  $sth= $dbh->column_info(undef, undef, "t1", "a%");
  ($info)= $sth->fetchall_arrayref({});
  is(scalar @$info, 3);
  $sth= $dbh->column_info(undef, undef, "t1", "a" . $dbh->get_info(14) . "_");
  ($info)= $sth->fetchall_arrayref({});
  is(scalar @$info, 1);
  $sth= $dbh->column_info(undef, undef, "t1", "a'b");
  ($info)= $sth->fetchall_arrayref({});
  is(scalar @$info, 1);

  ok($dbh->do(qq{DROP TABLE IF EXISTS t1}), "cleaning up");
  $dbh->disconnect();
};


$dbh->dispose();
#-----------------------------------------------------------------------
#!perl -w
# vim: ft=perl

use Test::More;
use DBI;
use strict;
use lib 't', '.';
require 'lib.pl';
$|= 1;

use vars qw($table $test_dsn $test_user $test_password);
my $dbh;
EVAL {$dbh= DBI->connect($test_dsn, $test_user, $test_password,
                      { RaiseError => 1, PrintError => 1, AutoCommit => 0 });};

if ($@) {
    plan skip_all => "ERROR: $DBI::errstr. Can't continue test";
}
plan tests => 7;

$dbh->{mysql_server_prepare}= 0;

ok(defined $dbh, "Connected to database for key info tests");

ok($dbh->do("DROP TABLE IF EXISTS $table"), "Dropped table");

# Non-primary key is there as a regression test for Bug #26786.
ok($dbh->do("CREATE TABLE $table (a int, b varchar(20), c int,
                                primary key (a,b(10)), key (c))"),
   "Created table $table");

my $sth= $dbh->primary_key_info(undef, undef, $table);
ok($sth, "Got primary key info");

my $key_info= $sth->fetchall_arrayref;

my $expect= [
              [ undef, undef, $table, 'a', '1', 'PRIMARY' ],
              [ undef, undef, $table, 'b', '2', 'PRIMARY' ],
            ];
is_deeply($key_info, $expect, "Check primary_key_info results");

is_deeply([ $dbh->primary_key(undef, undef, $table) ], [ 'a', 'b' ],
          "Check primary_key results");

ok($dbh->do("DROP TABLE $table"), "Dropped table");

$dbh->disconnect();
#-----------------------------------------------------------------------
#!perl -w
# vim: ft=perl
#
#   $Id: 40listfields.t 11244 2008-05-11 15:13:10Z capttofu $
#
#   This is a test for statement attributes being present appropriately.
#


#
#   Include lib.pl
#

use DBI;
use Test::More;
use vars qw($verbose);
use lib '.', 't';
require 'lib.pl';

use vars qw($test_dsn $test_user $test_password);
my $quoted;

my $create;

my $dbh;
EVAL {$dbh= DBI->connect($test_dsn, $test_user, $test_password,
                      { RaiseError => 1, PrintError => 1, AutoCommit => 0 });};

if ($@) {
    plan skip_all => "ERROR: $DBI::errstr. Can't continue test";
}
plan tests => 25;

$dbh->{mysql_server_prepare}= 0;

ok $dbh->do("DROP TABLE IF EXISTS $table"), "drop table if exists $table";

$create = <<EOC;
CREATE TABLE $table (
    id INT(4) NOT NULL,
    name VARCHAR(64),
    key id (id)
    )
EOC

ok $dbh->do($create), "create table $table";

ok $dbh->table_info(undef,undef,$table), "table info for $table";

ok $dbh->column_info(undef,undef,$table,'%'), "column_info for $table";

$sth= $dbh->column_info(undef,undef,"this_does_not_exist",'%');

ok $sth, "\$sth defined";

ok !$sth->err(), "not error";

$sth = $dbh->prepare("SELECT * FROM $table");

ok $sth, "prepare succeeded";

ok $sth->execute, "execute select";

my $res;
$res = $sth->{'NUM_OF_FIELDS'};

ok $res, "$sth->{NUM_OF_FIELDS} defined";

is $res, 2, "\$res $res == 2";

$ref = $sth->{'NAME'};

ok $ref, "\$sth->{NAME} defined";

cmp_ok $$ref[0], 'eq', 'id', "$$ref[0] eq 'id'";

cmp_ok $$ref[1], 'eq', 'name', "$$ref[1] eq 'name'";

$ref = $sth->{'NULLABLE'};

ok $ref, "nullable";

ok !($$ref[0] xor (0 & $COL_NULLABLE));
ok !($$ref[1] xor (1 & $COL_NULLABLE));

$ref = $sth->{TYPE};

cmp_ok $ref->[0], 'eq', DBI::SQL_INTEGER(), "SQL_INTEGER";

cmp_ok $ref->[1], 'eq', DBI::SQL_VARCHAR(), "SQL_VARCHAR";

ok ($sth= $dbh->prepare("DROP TABLE $table"));

ok($sth->execute);

ok (! defined $sth->{'NUM_OF_FIELDS'});

$quoted = EVAL { $dbh->quote(0, DBI::SQL_INTEGER()) };

ok (!$@);

cmp_ok $quoted, 'eq', '0', "equals '0'";

$quoted = EVAL { $dbh->quote('abc', DBI::SQL_VARCHAR()) };

ok (!$@);

cmp_ok $quoted, 'eq', "\'abc\'", "equals 'abc'";
#-----------------------------------------------------------------------
#!perl -w
# vim: ft=perl
#
#   $Id: 40nulls.t 11244 2008-05-11 15:13:10Z capttofu $
#
#   This is a test for correctly handling NULL values.
#
use strict;
use DBI;
use Test::More;
use Carp qw(croak);
use Data::Dumper;
use vars qw($table $test_dsn $test_user $test_password);
use lib 't', '.';
require 'lib.pl';

my ($dbh, $sth);
EVAL {$dbh= DBI->connect($test_dsn, $test_user, $test_password,
                      { RaiseError => 1, PrintError => 1, AutoCommit => 0 });};
if ($@) {
    plan skip_all =>
        "ERROR: $DBI::errstr. Can't continue test";
}
plan tests => 10;

ok $dbh->do("DROP TABLE IF EXISTS $table"), "DROP TABLE IF EXISTS $table";

my $create= <<EOT;
CREATE TEMPORARY TABLE $table (
  id INT(4),
  name VARCHAR(64)
  )
EOT
ok $dbh->do($create), "create table $create";

ok $dbh->do("INSERT INTO $table VALUES ( NULL, 'NULL-valued id' )"), "inserting nulls";

ok ($sth = $dbh->prepare("SELECT * FROM $table WHERE id IS NULL"));

do $sth->execute;

ok (my $aref = $sth->fetchrow_arrayref);

ok !defined($$aref[0]);

ok defined($$aref[1]);

ok $sth->finish;

ok $dbh->do("DROP TABLE $table");

ok $dbh->disconnect;
#-----------------------------------------------------------------------
#!perl -w
# vim: ft=perl
#
#   $Id: 40numrows.t 11244 2008-05-11 15:13:10Z capttofu $
#
#   This tests, whether the number of rows can be retrieved.
#
use strict;
use DBI;
use Test::More;
use Carp qw(croak);
use Data::Dumper;
use vars qw($table $test_dsn $test_user $test_password);
use lib 't', '.';
require 'lib.pl';

my ($dbh, $sth, $aref);
EVAL {$dbh= DBI->connect($test_dsn, $test_user, $test_password,
                      { RaiseError => 1, PrintError => 1, AutoCommit => 0 });};
if ($@) {
    plan skip_all =>
        "ERROR: $DBI::errstr. Can't continue test";
}
plan tests => 30;

ok $dbh->do("DROP TABLE IF EXISTS $table");

my $create= <<EOT;
CREATE TEMPORARY TABLE $table (
  id INT(4) NOT NULL DEFAULT 0,
  name varchar(64) NOT NULL DEFAULT ''
)
EOT

ok $dbh->do($create), "CREATE TABLE $table";

ok $dbh->do("INSERT INTO $table VALUES( 1, 'Alligator Descartes' )"), 'inserting first row';

ok ($sth = $dbh->prepare("SELECT * FROM $table WHERE id = 1"));

ok $sth->execute;

is $sth->rows, 1, '\$sth->rows should be 1';

ok ($aref= $sth->fetchall_arrayref);

is scalar @$aref, 1, 'Verified rows should be 1';

ok $sth->finish;

ok $dbh->do("INSERT INTO $table VALUES( 2, 'Jochen Wiedmann' )"), 'inserting second row';

ok ($sth = $dbh->prepare("SELECT * FROM $table WHERE id >= 1"));

ok $sth->execute;

is $sth->rows, 2, '\$sth->rows should be 2';

ok ($aref= $sth->fetchall_arrayref);

is scalar @$aref, 2, 'Verified rows should be 2';

ok $sth->finish;

ok $dbh->do("INSERT INTO $table VALUES(3, 'Tim Bunce')"), "inserting third row";

ok ($sth = $dbh->prepare("SELECT * FROM $table WHERE id >= 2"));

ok $sth->execute;

is $sth->rows, 2, 'rows should be 2';

ok ($aref= $sth->fetchall_arrayref);

is scalar @$aref, 2, 'Verified rows should be 2';

ok $sth->finish;

ok ($sth = $dbh->prepare("SELECT * FROM $table"));

ok $sth->execute;

is $sth->rows, 3, 'rows should be 3';

ok ($aref= $sth->fetchall_arrayref);

is scalar @$aref, 3, 'Verified rows should be 3';

ok $dbh->do("DROP TABLE $table"), "drop table $table";

ok $dbh->disconnect;
#-----------------------------------------------------------------------
#!perl -w
# vim: ft=perl
# Test problem in 3.0002_4 and 3.0005 where if a statement is prepared
# and multiple executes are performed, if any execute fails all subsequent
# executes report an error but may have worked.

use strict;
use DBI ();
use DBI::Const::GetInfoType;
use Test::More;
use lib '.', 't';
require 'lib.pl';

use vars qw($test_dsn $test_user $test_password);

$test_dsn.= ";mysql_server_prepare=1";
my $dbh;
EVAL {$dbh = DBI->connect($test_dsn, $test_user, $test_password,
  { RaiseError => 1, AutoCommit => 1})};

if ($@) {
    plan skip_all => "ERROR: $@. Can't continue test";
}

#
# DROP/CREATE PROCEDURE will give syntax error
# for versions < 5.0
#
if ($dbh->get_info($GetInfoType{SQL_DBMS_VER}) lt "4.1") {
    plan skip_all =>
        "SKIP TEST: You must have MySQL version 4.1 and greater for this test to run";
}
plan tests => 3;

# execute invalid SQL to make sure we get an error
my $q = "select select select";	# invalid SQL
$dbh->{PrintError} = 0;
$dbh->{PrintWarn} = 0;
my $sth;
EVAL {$sth = $dbh->prepare($q);};
$dbh->{PrintError} = 1;
$dbh->{PrintWarn} = 1;
ok defined($DBI::errstr);
cmp_ok $DBI::errstr, 'ne', '';

print "errstr $DBI::errstr\n" if $DBI::errstr;
ok $dbh->disconnect();
#!perl -w
# vim: ft=perl

use strict;
use Test::More;
use DBI;
use lib 't', '.';
require 'lib.pl';
use vars qw($table $test_dsn $test_user $test_password);

$|= 1;

$test_dsn.= ";mysql_server_prepare=1";

my $dbh;
EVAL {$dbh= DBI->connect($test_dsn, $test_user, $test_password,
                      { RaiseError => 1, PrintError => 1, AutoCommit => 0 });};

if ($@) {
    plan skip_all => "ERROR: $@. Can't continue test";
}
plan tests => 21;

ok(defined $dbh, "connecting");

ok($dbh->do(qq{DROP TABLE IF EXISTS t1}), "making slate clean");

#
# Bug #20559: Program crashes when using server-side prepare
#
ok($dbh->do(qq{CREATE TABLE t1 (id INT, num DOUBLE)}), "creating table");

my $sth;
ok($sth= $dbh->prepare(qq{INSERT INTO t1 VALUES (?,?),(?,?)}), "loading data");
ok($sth->execute(1, 3.0, 2, -4.5));

ok ($sth= $dbh->prepare("SELECT num FROM t1 WHERE id = ? FOR UPDATE"));

ok ($sth->bind_param(1, 1), "binding parameter");

ok ($sth->execute(), "fetching data");

is_deeply($sth->fetchall_arrayref({}), [ { 'num' => '3' } ]);

ok ($sth->finish);

ok ($dbh->do(qq{DROP TABLE t1}), "cleaning up");

#
# Bug #42723: Binding server side integer parameters results in corrupt data
#
ok($dbh->do(qq{DROP TABLE IF EXISTS t2}), "making slate clean");

ok($dbh->do(q{CREATE TABLE `t2` (`i` int,`si` smallint,`ti` tinyint,`bi` bigint)}), "creating test table");

my $sth2;
ok($sth2 = $dbh->prepare('INSERT INTO t2 VALUES (?,?,?,?)'));

#bind test values
ok($sth2->bind_param(1, 101, DBI::SQL_INTEGER), "binding int");
ok($sth2->bind_param(2, 102, DBI::SQL_SMALLINT), "binding smallint");
ok($sth2->bind_param(3, 103, DBI::SQL_TINYINT), "binding tinyint");
ok($sth2->bind_param(4, 104, DBI::SQL_INTEGER), "binding bigint");

ok($sth2->execute(), "inserting data");

is_deeply($dbh->selectall_arrayref('SELECT * FROM t2'), [[101, 102, 103, 104]]);

ok ($dbh->do(qq{DROP TABLE t2}), "cleaning up");

$dbh->disconnect();
#-----------------------------------------------------------------------
#!perl -w
# vim: ft=perl

use Test::More;
use DBI;
use DBI::Const::GetInfoType;
use lib '.', 't';
require 'lib.pl';
use strict;
$|= 1;

use vars qw($table $test_dsn $test_user $test_password);

my $dbh;
EVAL {$dbh= DBI->connect($test_dsn, $test_user, $test_password,
                      { RaiseError => 1, PrintError => 1, AutoCommit => 0 });};
print "err perl $@\n";
if ($@) {
    plan skip_all =>
        "ERROR: $DBI::errstr. Can't continue test";
}
plan tests => 20;

ok(defined $dbh, "Connected to database");

SKIP: {
skip "New Data types not supported by server", 19
  if $dbh->get_info($GetInfoType{SQL_DBMS_VER}) lt "5.0";

ok($dbh->do(qq{DROP TABLE IF EXISTS t1}), "making slate clean");

ok($dbh->do(qq{CREATE TABLE t1 (d DECIMAL(5,2))}), "creating table");

my $sth= $dbh->prepare("SELECT * FROM t1 WHERE 1 = 0");
ok($sth->execute(), "getting table information");

is_deeply($sth->{TYPE}, [ 3 ], "checking column type");

ok($sth->finish);

ok($dbh->do(qq{DROP TABLE t1}), "cleaning up");

#
# Bug #23936: bind_param() doesn't work with SQL_DOUBLE datatype
# Bug #24256: Another failure in bind_param() with SQL_DOUBLE datatype
#
ok($dbh->do(qq{CREATE TABLE t1 (num DOUBLE)}), "creating table");

$sth= $dbh->prepare("INSERT INTO t1 VALUES (?)");
ok($sth->bind_param(1, 2.1, DBI::SQL_DOUBLE), "binding parameter");
ok($sth->execute(), "inserting data");
ok($sth->finish);
ok($sth->bind_param(1, -1, DBI::SQL_DOUBLE), "binding parameter");
ok($sth->execute(), "inserting data");
ok($sth->finish);

is_deeply($dbh->selectall_arrayref("SELECT * FROM t1"), [ ['2.1'],  ['-1'] ]);

ok($dbh->do(qq{DROP TABLE t1}), "cleaning up");

#
# [rt.cpan.org #19212] Mysql Unsigned Integer Fields
#
ok($dbh->do(qq{CREATE TABLE t1 (num INT UNSIGNED)}), "creating table");
ok($dbh->do(qq{INSERT INTO t1 VALUES (0),(4294967295)}), "loading data");

is_deeply($dbh->selectall_arrayref("SELECT * FROM t1"),
          [ ['0'],  ['4294967295'] ]);

ok($dbh->do(qq{DROP TABLE t1}), "cleaning up");
};

$dbh->disconnect();

#-----------------------------------------------------------------------
#!perl -w

use strict;
use DBI;
use Test::More;
use Carp qw(croak);
use Data::Dumper;
use vars qw($table $test_dsn $test_user $test_password);
use lib 't', '.';
require 'lib.pl';

my ($dbh, $sth);
EVAL {$dbh= DBI->connect($test_dsn, $test_user, $test_password,
                      { RaiseError => 1, PrintError => 1, AutoCommit => 0 });};
if ($@) {
    plan skip_all =>
        "ERROR: $DBI::errstr. Can't continue test";
}
plan tests => 11;

my ($rows, $errstr, $ret_ref);
ok $dbh->do("drop table if exists $table"), "drop table $table";

ok $dbh->do("create table $table (a int not null, primary key (a))"), "create table $table";

ok ($sth= $dbh->prepare("insert into $table values (?)"));

ok $sth->bind_param(1,10000,DBI::SQL_INTEGER), "bind param 10000 col1";

ok $sth->execute(), 'execute';

ok $sth->bind_param(1,10001,DBI::SQL_INTEGER), "bind param 10001 col1";

ok $sth->execute(), 'execute';

ok ($sth= $dbh->prepare("DROP TABLE $table"));

ok $sth->execute();

ok $sth->finish;

ok $dbh->disconnect;
#-----------------------------------------------------------------------
#!perl
# vim: ft=perl
#
#   $Id: 40blobs.t 1103 2008-04-29 02:53:28Z capttofu $
#
#   This is a test for correct handling of BLOBS; namely $dbh->quote
#   is expected to work correctly.
#

#
# Thank you to Brad Choate for finding the bug that resulted in this test,
# which he kindly sent code that this test uses!
#

use strict;
use DBI;
use Test::More;

my $update_blob;
use vars qw($table $test_dsn $test_user $test_password);
use lib 't', '.';
require 'lib.pl';

my ($dbh, $row);
EVAL {$dbh= DBI->connect($test_dsn, $test_user, $test_password,
                      { RaiseError => 1, PrintError => 1, AutoCommit => 0 });};
if ($@) {
    plan skip_all => "ERROR: $DBI::errstr. Can't continue test";
}
plan tests => 25;

my @chars = grep {!m/[0O1Iil]/}, flat 0..9, 'A'..'Z', 'a'..'z';
my $blob1= @chars.roll(10000).join;
my $blob2 = '"' x 10000;

sub ShowBlob($) {
  my ($blob) = @_;
  my $b;
  for(my $i = 0;  $i < 8;  $i++) {
    if (defined($blob)  &&  length($blob) > $i) {
      $b = substr($blob, $i*32);
    }
    else {
      $b = "";
    }
    printf("%08lx %s\n", $i*32, unpack("H64", $b));
  }
}

my $create = <<EOT;
CREATE TABLE $table (
  id int(4),
  name text)
EOT

ok $dbh->do("DROP TABLE IF EXISTS $table"), "drop table if exists $table";

ok $dbh->do($create), "create table $table";

my $query = "INSERT INTO $table VALUES(?, ?)";
my $sth;
ok ($sth= $dbh->prepare($query));

ok defined($sth);

ok $sth->execute(1, $blob1), "inserting \$blob1";

ok $sth->finish;

ok ($sth= $dbh->prepare("SELECT * FROM $table WHERE id = 1"));

ok $sth->execute, "select from $table";

ok ($row = $sth->fetchrow_arrayref);

is @$row, 2, "two rows fetched";

is $$row[0], 1, "first row id == 1";

cmp_ok $$row[1], 'eq', $blob1, ShowBlob($blob1);

ok $sth->finish;

ok ($sth= $dbh->prepare("UPDATE $table SET name = ? WHERE id = 1"));

ok $sth->execute($blob2), 'inserting $blob2';

ok ($sth->finish);

ok ($sth= $dbh->prepare("SELECT * FROM $table WHERE id = 1"));

ok ($sth->execute);

ok ($row = $sth->fetchrow_arrayref);

is scalar @$row, 2, 'two rows';

is $$row[0], 1, 'row id == 1';

cmp_ok $$row[1], 'eq', $blob2, ShowBlob($blob2);

ok ($sth->finish);

ok $dbh->do("DROP TABLE $table"), "drop $table";

ok $dbh->disconnect;
#-----------------------------------------------------------------------
#!perl -w
# vim: ft=perl

use strict;
use vars qw($table $test_dsn $test_user $test_password $mdriver);
use Test::More;
use DBI;
use Carp qw(croak);
use lib 't', '.';
require 'lib.pl';

my $dbh;
EVAL {$dbh= DBI->connect($test_dsn, $test_user, $test_password,
                      { RaiseError => 1, PrintError => 1, AutoCommit => 0 });};
if ($@) {
    plan skip_all => "ERROR: $@. Can't continue test";
}
plan tests => 12;

ok $dbh->do("drop table if exists $table");

my $create= <<EOT;
create table $table (
    a int not null,
    b double,
    primary key (a))
EOT

ok $dbh->do($create);

ok (my $sth= $dbh->prepare("insert into $table values (?, ?)"));

ok $sth->bind_param(1,"10000 ",DBI::SQL_INTEGER);

ok $sth->bind_param(2,"1.22 ",DBI::SQL_DOUBLE);

ok $sth->execute();

ok $sth->bind_param(1,10001,DBI::SQL_INTEGER);

ok $sth->bind_param(2,.3333333,DBI::SQL_DOUBLE);

ok $sth->execute();

ok $dbh->do("DROP TABLE $table");

ok $sth->finish;

ok $dbh->disconnect;
#-----------------------------------------------------------------------
#!perl -w
# vim: ft=perl
#
#   $Id: 50chopblanks.t 11650 2008-08-15 13:58:29Z capttofu $
#
#   This driver should check whether 'ChopBlanks' works.
#

use strict;
use DBI;
use DBI::Const::GetInfoType;
use Test::More;
use lib 't', '.';
require 'lib.pl';

use vars qw($test_dsn $test_user $test_password $table);

my $dbh;
EVAL {$dbh= DBI->connect($test_dsn, $test_user, $test_password,
                      { RaiseError => 1, PrintError => 1, AutoCommit => 0 });};
if ($@) {
    plan skip_all =>
        "ERROR: $DBI::errstr. Can't continue test";
}
plan tests => 29;

ok $dbh->do("DROP TABLE IF EXISTS $table"), "drop table if exists $table";

my $create= <<EOT;
CREATE TABLE $table (
  id INT(4),
  name VARCHAR(64)
)
EOT

ok $dbh->do($create), "create table $table";

ok (my $sth= $dbh->prepare("INSERT INTO $table (id, name) VALUES (?, ?)"));

ok (my $sth2= $dbh->prepare("SELECT id, name FROM $table WHERE id = ?"));

my $rows;

if ($dbh->get_info($GetInfoType{SQL_DBMS_VER}) lt "4.1") {
    $rows = [ [1, ''], [2, ''], [3, ' a b c']];
}
else {
    $rows = [ [1, ''], [2, ' '], [3, ' a b c ']];
}

my $ref;
for $ref (@$rows) {
	my ($id, $name) = @$ref;
    ok $sth->execute($id, $name), "inserting ($id, $name) into $table";
	ok $sth2->execute($id), "selecting where id = $id";

	# First try to retreive without chopping blanks.
	$sth2->{'ChopBlanks'} = 0;
	ok ($ref = $sth2->fetchrow_arrayref);
	cmp_ok $$ref[1], 'eq', $name, "\$name should not have blanks chopped";

	# Now try to retreive with chopping blanks.
	$sth2->{'ChopBlanks'} = 1;

	ok $sth2->execute($id);

	my $n = $name;
	$n =~ s/\s+$//;
	ok ($ref = $sth2->fetchrow_arrayref);

	cmp_ok $$ref[1], 'eq', $n, "should have blanks chopped";

}
ok $sth->finish;
ok $sth2->finish;
ok $dbh->do("DROP TABLE $table"), "drop $table";
ok $dbh->disconnect;
#!perl -w
#
#   $Id: 50commit.t 11645 2008-08-15 11:36:38Z capttofu $
#
#   This is testing the transaction support.
#


use DBI;
use Test::More;
use lib 't', '.';
require 'lib.pl';

use vars qw($got_warning $test_dsn $test_user $test_password $table);

my $dbh;
EVAL {$dbh= DBI->connect($test_dsn, $test_user, $test_password,
                      { RaiseError => 1, PrintError => 1, AutoCommit => 0 });};
if ($@) {
    plan skip_all =>
        "ERROR: $DBI::errstr. Can't continue test";
}

sub catch_warning ($) {
    $got_warning = 1;
}

sub num_rows($$$) {
    my($dbh, $table, $num) = @_;
    my($sth, $got);

    if (!($sth = $dbh->prepare("SELECT * FROM $table"))) {
      return "Failed to prepare: err " . $dbh->err . ", errstr "
        . $dbh->errstr;
    }
    if (!$sth->execute) {
      return "Failed to execute: err " . $dbh->err . ", errstr "
        . $dbh->errstr;
    }
    $got = 0;
    while ($sth->fetchrow_arrayref) {
      ++$got;
    }
    if ($got ne $num) {
      return "Wrong result: Expected $num rows, got $got.\n";
    }
    return '';
}

$have_transactions = have_transactions($dbh);
my $engine= $have_transactions ? 'InnoDB' : 'MyISAM';

if ($have_transactions) {
  plan tests => 21;

  ok $dbh->do("DROP TABLE IF EXISTS $table"), "drop table if exists $table";
  my $create =<<EOT;
CREATE TABLE $table (
    id INT(4) NOT NULL default 0,
    name VARCHAR(64) NOT NULL default ''
) ENGINE=$engine
EOT

  ok $dbh->do($create), 'create $table';

  ok !$dbh->{AutoCommit}, "\$dbh->{AutoCommit} not defined |$dbh->{AutoCommit}|";

  $dbh->{AutoCommit} = 0;
  ok !$dbh->err;
  ok !$dbh->errstr;
  ok !$dbh->{AutoCommit};

  ok $dbh->do("INSERT INTO $table VALUES (1, 'Jochen')"),
  "insert into $table (1, 'Jochen')";

  my $msg;
  $msg = num_rows($dbh, $table, 1);
  ok !$msg;

  ok $dbh->rollback, 'rollback';

  $msg = num_rows($dbh, $table, 0);
  ok !$msg;

  ok $dbh->do("DELETE FROM $table WHERE id = 1"), "delete from $table where id = 1";

  $msg = num_rows($dbh, $table, 0);
  ok !$msg;
  ok $dbh->commit, 'commit';

  $msg = num_rows($dbh, $table, 0);
  ok !$msg;

  # Check auto rollback after disconnect
  ok $dbh->do("INSERT INTO $table VALUES (1, 'Jochen')");

  $msg = num_rows($dbh, $table, 1);
  ok !$msg;

  ok $dbh->disconnect;

  ok ($dbh = DBI->connect($test_dsn, $test_user, $test_password));

  ok $dbh, "connected";

  $msg = num_rows($dbh, $table, 0);
  ok !$msg;

  ok $dbh->{AutoCommit}, "\$dbh->{AutoCommit} $dbh->{AutoCommit}";

}
else {
  plan tests => 13;

  ok $dbh->do("DROP TABLE IF EXISTS $table"), "drop table if exists $table";
  my $create =<<EOT;
  CREATE TABLE $table (
      id INT(4) NOT NULL default 0,
      name VARCHAR(64) NOT NULL default ''
      ) ENGINE=$engine
EOT

  ok $dbh->do($create), 'create $table';

  # Tests for databases that don't support transactions
  # Check whether AutoCommit mode works.

  ok $dbh->do("INSERT INTO $table VALUES (1, 'Jochen')");
  $msg = num_rows($dbh, $table, 1);
  ok !$msg;

  ok $dbh->disconnect;

  ok ($dbh = DBI->connect($test_dsn, $test_user, $test_password));

  $msg = num_rows($dbh, $table, 1);
  ok !$msg;

  ok $dbh->do("INSERT INTO $table VALUES (2, 'Tim')");

  my $result;
  $@ = '';

  $SIG{__WARN__} = \&catch_warning;

  $got_warning = 0;

  EVAL { $result = $dbh->commit; };

  $SIG{__WARN__} = 'DEFAULT';

  ok $got_warning;

#   Check whether rollback issues a warning in AutoCommit mode
#   We accept error messages as being legal, because the DBI
#   requirement of just issuing a warning seems scary.
  ok $dbh->do("INSERT INTO $table VALUES (3, 'Alligator')");

  $@ = '';
  $SIG{__WARN__} = \&catch_warning;
  $got_warning = 0;
  EVAL { $result = $dbh->rollback; };
  $SIG{__WARN__} = 'DEFAULT';

  ok $got_warning, "Should be warning defined upon rollback of non-trx table";

  ok $dbh->do("DROP TABLE $table");
  ok $dbh->disconnect();
}
#-----------------------------------------------------------------------
#!/usr/bin/perl

use strict;
use warnings;

use DBI;
use DBI::Const::GetInfoType;
use Test::More;
use lib 't', '.';
require 'lib.pl';

use vars qw($test_dsn $test_user $test_password $table);

my $dbh;
EVAL {$dbh= DBI->connect($test_dsn, $test_user, $test_password,
                      { RaiseError => 1, PrintError => 1, AutoCommit => 0 });};
if ($@) {
    plan skip_all =>
        "ERROR: $DBI::errstr. Can't continue test";
}
plan tests => 25;

ok $dbh->do("DROP TABLE IF EXISTS $table"), "drop table if exists $table";

my $create= <<"EOTABLE";
create table $table (
    id bigint unsigned not null default 0
    )
EOTABLE


ok $dbh->do($create), "creating table";

my $statement= "insert into $table (id) values (?)";

my $sth1;
ok $sth1= $dbh->prepare($statement);

my $rows;
ok $rows= $sth1->execute('9999999999999999');
cmp_ok $rows, '==',  1;

$statement= "update $table set id = ?";
my $sth2;
ok $sth2= $dbh->prepare($statement);

ok $rows= $sth2->execute('9999999999999998');
cmp_ok $rows, '==',  1;

$dbh->{mysql_bind_type_guessing}= 1;
ok $rows= $sth1->execute('9999999999999997');
cmp_ok $rows, '==',  1;

$statement= "update $table set id = ? where id = ?";

ok $sth2= $dbh->prepare($statement);
ok $rows= $sth2->execute('9999999999999996', '9999999999999997');

my $retref;
ok $retref= $dbh->selectall_arrayref("select * from $table");

cmp_ok $retref->[0][0], '==', 9999999999999998;
cmp_ok $retref->[1][0], '==', 9999999999999996;

# checking varchars/empty strings/misidentification:
$create= <<"EOTABLE";
create table $table (
    str varchar(80),
    num bigint
    )
EOTABLE
ok $dbh->do("DROP TABLE IF EXISTS $table"), "drop table if exists $table";
ok $dbh->do($create), "creating table w/ varchar";
my $sth3;
ok $sth3= $dbh->prepare("insert into $table (str, num) values (?, ?)");
ok $rows= $sth3->execute(52.3, 44);
ok $rows= $sth3->execute('', '     77');
ok $rows= $sth3->execute(undef, undef);

ok $sth3= $dbh->prepare("select * from $table limit ?");
ok $rows= $sth3->execute(1);
ok $rows= $sth3->execute('   1');
$sth3->finish();

ok $dbh->disconnect;
#-----------------------------------------------------------------------
#!perl -w
# vim: ft=perl
#
#   This checks for UTF-8 support.
#

use strict;
use DBI;
use DBI::Const::GetInfoType;
use Carp qw(croak);
use Test::More;
use vars qw($table $test_dsn $test_user $test_password);
use vars qw($COL_NULLABLE $COL_KEY);
use lib 't', '.';
require 'lib.pl';

my $dbh;
EVAL {$dbh= DBI->connect($test_dsn, $test_user, $test_password,
                      { RaiseError => 1, PrintError => 1, AutoCommit => 0 });};
if ($@) {
    plan skip_all => "ERROR: $@. Can't continue test";
}

#
# DROP/CREATE PROCEDURE will give syntax error for these versions
#
if ($dbh->get_info($GetInfoType{SQL_DBMS_VER}) lt "5.0") {
    plan skip_all =>
        "SKIP TEST: You must have MySQL version 5.0 and greater for this test to run";
}
plan tests => 15;

ok $dbh->do("DROP TABLE IF EXISTS $table");

my $create =<<EOT;
CREATE TABLE $table (
    name VARCHAR(64) CHARACTER SET utf8,
    bincol BLOB,
    shape GEOMETRY,
    binutf VARCHAR(64) CHARACTER SET utf8 COLLATE utf8_bin
)
EOT

ok $dbh->do($create);

my $utf8_str        = "\x{0100}dam";     # "Adam" with a macron.
my $quoted_utf8_str = "'\x{0100}dam'";

my $blob = "\x{c4}\x{80}dam"; # same as utf8_str but not utf8 encoded
my $quoted_blob = "'\x{c4}\x{80}dam'";

cmp_ok $dbh->quote($utf8_str), 'eq', $quoted_utf8_str, 'testing quoting of utf 8 string';

cmp_ok $dbh->quote($blob), 'eq', $quoted_blob, 'testing quoting of blob';

#ok $dbh->{mysql_enable_utf8}, "mysql_enable_utf8 survive connect()";
$dbh->{mysql_enable_utf8}=1;

my $query = <<EOI;
INSERT INTO $table (name, bincol, shape, binutf)
    VALUES (?,?, GeomFromText('Point(132865 501937)'), ?)
EOI

ok $dbh->do($query, {}, $utf8_str,$blob, $utf8_str), "INSERT query $query\n";

$query = "SELECT name,bincol,asbinary(shape), binutf FROM $table LIMIT 1";
my $sth = $dbh->prepare($query) or die "$DBI::errstr";

ok $sth->execute;

my $ref;
$ref = $sth->fetchrow_arrayref ;

ok defined $ref;

cmp_ok $ref->[0], 'eq', $utf8_str;

cmp_ok $ref->[3], 'eq', $utf8_str;

SKIP: {
        EVAL {use Encode;};
          skip "Can't test is_utf8 tests 'use Encode;' not available", 2, if $@;
          ok !Encode::is_utf8($ref->[1]), "blob was made utf8!.";

          ok !Encode::is_utf8($ref->[2]), "shape was made utf8!.";
      }

cmp_ok $ref->[1], 'eq', $blob, "compare $ref->[1] eq $blob";

ok $sth->finish;

ok $dbh->do("DROP TABLE $table");

ok $dbh->disconnect;
#-----------------------------------------------------------------------
#!perl -w
#
#   $Id: 60leaks.t 11244 2008-05-11 15:13:10Z capttofu $
#
#   This is a skeleton test. For writing new tests, take this file
#   and modify/extend it.
#
use strict;
use DBI;
use Test::More;
use Carp qw(croak);
use Data::Dumper;
use vars qw($table $test_dsn $test_user $test_password);
use lib 't', '.';
require 'lib.pl';

my $COUNT_CONNECT = 4000;   # Number of connect/disconnect iterations
my $COUNT_PREPARE = 10000;  # Number of prepare/execute/finish iterations

my $have_storable;

if (!$ENV{SLOW_TESTS}) {
    plan skip_all => "Skip \$ENV{SLOW_TESTS} is not set\n";
}

EVAL { require Proc::ProcessTable; };
if ($@) {
    plan skip_all => "Skip Proc::ProcessTable not installed \n";
}

EVAL { require Storable };
$have_storable = $@ ? 0 : 1;

my ($dbh, $sth);
EVAL {$dbh= DBI->connect($test_dsn, $test_user, $test_password,
                      { RaiseError => 1, PrintError => 1, AutoCommit => 0 });};
if ($@) {
    plan skip_all =>
        "ERROR: $@. Can't continue test";
}
plan tests => 21;

sub size {
  my($p, $pt);
  $pt = Proc::ProcessTable->new('cache_ttys' => $have_storable);
  for $p (@{$pt->table()}) {
    if ($p->pid() == $$) {
      return $p->size();
    }
  }
  die "Cannot find my own process?!?\n";
  exit 0;
}

ok $dbh->do("DROP TABLE IF EXISTS $table");

my $create= <<EOT;
CREATE TABLE $table (
  id INT(4) NOT NULL DEFAULT 0,
  name VARCHAR(64) NOT NULL DEFAULT ''
  )
EOT

ok $dbh->do($create);

my ($size, $prev_size, $ok, $not_ok, $dbh2, $msg);
print "Testing memory leaks in connect/disconnect\n";
$msg = "Possible memory leak in connect/disconnect detected";

$ok = 0;
$not_ok = 0;
$prev_size= undef;

for (my $i = 0;  $i < $COUNT_CONNECT;  $i++) {
  EVAL {$dbh2 = DBI->connect($test_dsn, $test_user, $test_password,
    { RaiseError => 1, PrintError => 1, AutoCommit => 0 });};
  if ($@) {
    $not_ok++;
    last;
  }

	if ($i % 100  ==  99) {
    $size = size();
    if (defined($prev_size)) {
      if ($size == $prev_size) {
        $ok++;
      }
      else {
        $not_ok++;
      }
    }
		$prev_size = $size;
  }
}
$dbh2->disconnect;

ok $ok, "\$ok $ok";
ok !$not_ok, "\$not_ok $not_ok";
cmp_ok $ok, '>', $not_ok, "\$ok $ok \$not_ok $not_ok";

print "Testing memory leaks in prepare/execute/finish\n";
$msg = "Possible memory leak in prepare/execute/finish detected";

$ok = 0;
$not_ok = 0;
undef $prev_size;

for (my $i = 0;  $i < $COUNT_PREPARE;  $i++) {
  my $sth = $dbh->prepare("SELECT * FROM $table");
  $sth->execute();
  $sth->finish();

  if ($i % 100  ==  99) {
    $size = size();
    if (defined($prev_size))
    {
      if ($size == $prev_size) {
        $ok++;
      }
      else {
        $not_ok++;
      }
    }
    $prev_size = $size;
  }
}

ok $ok;
ok !$not_ok, "\$ok $ok \$not_ok $not_ok";
cmp_ok $ok, '>', $not_ok, "\$ok $ok \$not_ok $not_ok";

print "Testing memory leaks in fetchrow_arrayref\n";
$msg= "Possible memory leak in fetchrow_arrayref detected";

$sth= $dbh->prepare("INSERT INTO $table VALUES (?, ?)") ;

my $dataref= [[1, 'Jochen Wiedmann'],
  [2, 'Andreas König'],
  [3, 'Tim Bunce'],
  [4, 'Alligator Descartes'],
  [5, 'Jonathan Leffler']];

for (@$dataref) {
  ok $sth->execute($_->[0], $_->[1]),
    "insert into $table values ($_->[0], '$_->[1]')";
}

$ok = 0;
$not_ok = 0;
undef $prev_size;

for (my $i = 0;  $i < $COUNT_PREPARE;  $i++) {
  {
    my $sth = $dbh->prepare("SELECT * FROM $table");
    $sth->execute();
    my $row;
    while ($row = $sth->fetchrow_arrayref()) { }
    $sth->finish();
  }

  if ($i % 100  ==  99) {
    $size = size();
    if (defined($prev_size)) {
      if ($size == $prev_size) {
        ++$ok;
      }
      else {
        ++$not_ok;
      }
    }
    $prev_size = $size;
  }
}

ok $ok;
ok !$not_ok, "\$ok $ok \$not_ok $not_ok";
cmp_ok $ok, '>', $not_ok, "\$ok $ok \$not_ok $not_ok";

print "Testing memory leaks in fetchrow_hashref\n";
$msg = "Possible memory leak in fetchrow_hashref detected";

$ok = 0;
$not_ok = 0;
undef $prev_size;

for (my $i = 0;  $i < $COUNT_PREPARE;  $i++) {
  {
    my $sth = $dbh->prepare("SELECT * FROM $table");
    $sth->execute();
    my $row;
    while ($row = $sth->fetchrow_hashref()) { }
    $sth->finish();
  }

  if ($i % 100  ==  99) {
    $size = size();
    if (defined($prev_size)) {
      if ($size == $prev_size) {
        ++$ok;
      }
      else {
        ++$not_ok;
      }
    }
    $prev_size = $size;
  }
}

ok $ok;
ok !$not_ok, "\$ok $ok \$not_ok $not_ok";
cmp_ok $ok, '>', $not_ok, "\$ok $ok \$not_ok $not_ok";

ok $dbh->do("DROP TABLE $table");
ok $dbh->disconnect;
#-----------------------------------------------------------------------
#!perl -w
# vim: ft=perl

use strict;
use vars qw($table $test_dsn $test_user $test_password);
use Test::More;
use DBI;
use Carp qw(croak);
use lib 't', '.';
require 'lib.pl';

my $dbh;
EVAL {$dbh= DBI->connect($test_dsn, $test_user, $test_password,
                      { RaiseError => 1, PrintError => 1, AutoCommit => 0 });};
if ($@) {
    plan skip_all => "ERROR: $@. Can't continue test";
}
plan tests => 19;

ok $dbh->do("drop table if exists $table");

my $create= <<EOT;
create table $table (
    a int,
    primary key (a)
)
EOT

ok $dbh->do($create);

my $sth;
EVAL {$sth= $dbh->prepare("insert into $table values (?)")};

ok ! $@, "prepare: $@";

ok $sth->bind_param(1,10000,DBI::SQL_INTEGER);

ok $sth->execute();

ok $sth->bind_param(1,10001,DBI::SQL_INTEGER);

ok $sth->execute();

ok $dbh->do("DROP TABLE $table");

ok $dbh->do("create table $table (a int, b double, primary key (a))");

EVAL { $sth= $dbh->prepare("insert into $table values (?, ?)")};

ok ! $@, "prepare: $@";

ok $sth->bind_param(1,"10000 ",DBI::SQL_INTEGER);

ok $sth->bind_param(2,"1.22 ",DBI::SQL_DOUBLE);

ok $sth->execute();

ok $sth->bind_param(1,10001,DBI::SQL_INTEGER);

ok $sth->bind_param(2,.3333333,DBI::SQL_DOUBLE);

ok $sth->execute();

ok $sth->finish;

ok $dbh->do("DROP TABLE $table");

ok $dbh->disconnect;
#-----------------------------------------------------------------------
#!perl -w
# vim: ft=perl

#
#   $Id: 70takeimp.t 11993 2008-10-22 00:49:10Z capttofu $
#
#   This is a skeleton test. For writing new tests, take this file
#   and modify/extend it.
#

use strict;
use Test::More;
use DBI ();
use lib 't', '.';
require 'lib.pl';
$|= 1;
use vars qw($table $test_dsn $test_user $test_password);

my $drh;
EVAL {$drh = DBI->install_driver('mysql')};

if ($@) {
    plan skip_all => "Can't obtain driver handle ERROR: $@. Can't continue test";
}

my $dbh;
EVAL {$dbh= DBI->connect($test_dsn, $test_user, $test_password,
                      { RaiseError => 1, PrintError => 1, AutoCommit => 0 })};

if ($@) {
    plan skip_all => "Can't connect to database ERROR: $@. Can't continue test";
}
unless ($DBI::VERSION ge '1.607') {
    plan skip_all => "version of DBI $DBI::VERSION doesn't support this test. Can't continue test";
}
unless ($dbh->can('take_imp_data')) {
    plan skip_all => "version of DBI $DBI::VERSION doesn't support this test. Can't continue test";
}
plan tests => 21;

pass("obtained driver handle");
pass("connected to database");

my $id= connection_id($dbh);
ok defined($id), "Initial connection: $id\n";

$drh = $dbh->{Driver};
ok $drh, "Driver handle defined\n";

my $imp_data;
$imp_data = $dbh->take_imp_data;

ok $imp_data, "Didn't get imp_data";

my $imp_data_length= length($imp_data);
cmp_ok $imp_data_length, '>=', 80,
    "test that our imp_data is greater than or equal to 80, actual $imp_data_length";

is $drh->{Kids}, 0,
    'our Driver should have 0 Kid(s) after calling take_imp_data';

{
    my $warn;
    local $SIG{__WARN__} = sub { ++$warn if $_[0] =~ /after take_imp_data/ };

    my $drh = $dbh->{Driver};
    ok !defined($drh), '... our Driver should be undefined';

    my $trace_level = $dbh->{TraceLevel};
    ok !defined($trace_level) ,'our TraceLevel should be undefined';

    ok !defined($dbh->disconnect), 'disconnect should return undef';

    ok !defined($dbh->quote(42)), 'quote should return undefined';

    is $warn, 4, 'we should have received 4 warnings';
}

print "here\n";
my $dbh2 = DBI->connect($test_dsn, $test_user, $test_password,
    { dbi_imp_data => $imp_data });
print "there\n";

# XXX: how can we test that the same connection is used?
my $id2 = connection_id($dbh2);
print "Overridden connection: $id2\n";

cmp_ok $id,'==', $id2, "the same connection: $id => $id2\n";

my $drh2;
ok $drh2 = $dbh2->{Driver}, "can't get the driver\n";

ok $dbh2->isa("DBI::db"), 'isa test';
# need a way to test dbi_imp_data has been used

is $drh2->{Kids}, 1,
    "our Driver should have 1 Kid(s) again: having " .  $drh2->{Kids} . "\n";

is $drh2->{ActiveKids}, 1,
    "our Driver should have 1 ActiveKid again: having " .  $drh2->{ActiveKids} . "\n";

read_write_test($dbh2);

# must cut the connection data again
ok ($imp_data = $dbh2->take_imp_data), "didn't get imp_data";


sub read_write_test {
    my ($dbh)= @_;

    # now the actual test:

    my $table= 't1';
    ok $dbh->do("DROP TABLE IF EXISTS $table");

    my $create= <<EOT;
CREATE TABLE $table (
        id int(4) NOT NULL default 0,
        name varchar(64) NOT NULL default '' );
EOT

    ok $dbh->do($create);

    ok $dbh->do("DROP TABLE $table");
}

#-----------------------------------------------------------------------
#!/usr/bin/perl
$| = 1;

use strict;
use DBI;
use lib 't', '.';
require 'lib.pl';

use Test::More;

use vars qw($test_dsn $test_user $test_password);

my $dbh;
EVAL {$dbh= DBI->connect( $test_dsn, $test_user, $test_password);};
if ($@) {
    plan skip_all => "$@. Can't continue test";
}

my $drh    = $dbh->{Driver};
if (! defined $drh) {
    plan skip_all => "Can't obtain driver handle. Can't continue test";
}

unless ($DBI::VERSION ge '1.607') {
    plan skip_all => "version of DBI $DBI::VERSION doesn't support this test. Can't continue test";
}
unless ($dbh->can('take_imp_data')) {
    plan skip_all => "version of DBI $DBI::VERSION doesn't support this test. Can't continue test";
}
plan tests => 10;

pass("Connected to database");
pass("Obtained driver handle");

my $connection_id1 = connection_id($dbh);

is $drh->{Kids},       1, "1 kid";
is $drh->{ActiveKids}, 1, "1 active kid";

my $imp_data = $dbh->take_imp_data;
is $drh->{Kids},       0, "no kids";
is $drh->{ActiveKids}, 0, "no active kids";
$dbh = DBI->connect( $test_dsn, $test_user, $test_password,
      { dbi_imp_data => $imp_data } );
my $connection_id2 = connection_id($dbh);
is $connection_id1, $connection_id2, "got same session";

is $drh->{Kids},       1, "1 kid";
is $drh->{ActiveKids}, 1, "1 active kid";

ok $dbh->disconnect, "Disconnect OK";
#-----------------------------------------------------------------------
#!perl -w

use strict;
use vars qw($table $test_dsn $test_user $test_password);
use Carp qw(croak);
use DBI ();
use Test::More;
use lib 't', '.';
require 'lib.pl';

my ($row, $vers, $test_procs);

my $dbh;
EVAL {$dbh = DBI->connect($test_dsn, $test_user, $test_password,
  { RaiseError => 1, AutoCommit => 1})};

if ($@) {
  plan skip_all => "ERROR: $DBI::errstr. Can't continue test";
}
plan tests => 12;

ok $dbh->do("DROP TABLE IF EXISTS $table");

my $create = <<EOT;
CREATE TABLE $table (
  id INT(4),
  name VARCHAR(32)
  )
EOT

ok $dbh->do($create),"create $table";

my $sth;
ok ($sth= $dbh->prepare("SHOW TABLES LIKE '$table'"));

ok $sth->execute();

ok ($row= $sth->fetchrow_arrayref);

cmp_ok $row->[0], 'eq', $table, "\$row->[0] eq $table";

ok $sth->finish;

ok $dbh->do("DROP TABLE $table"), "drop $table";

ok $dbh->do("CREATE TABLE $table (a int)"), "creating $table again with 1 col";

ok $dbh->do("ALTER TABLE $table ADD COLUMN b varchar(31)"), "alter $table ADD COLUMN";

ok $dbh->do("DROP TABLE $table"), "drop $table";

ok $dbh->disconnect;
#-----------------------------------------------------------------------
#!perl -w
# vim: ft=perl

use strict;
use Test::More;
use DBI;
use DBI::Const::GetInfoType;
use lib 't', '.';
require 'lib.pl';
$|= 1;

use vars qw($table $test_dsn $test_user $test_password);

my $dbh;
EVAL {$dbh= DBI->connect($test_dsn, $test_user, $test_password,
                      { RaiseError => 1, PrintError => 1, AutoCommit => 0,
                        mysql_multi_statements => 1 });};

if ($@) {
    plan skip_all => "ERROR: $@. Can't continue test";
}
plan tests => 24;

ok (defined $dbh, "Connected to database with multi statement support");

$dbh->{mysql_server_prepare}= 0;

SKIP: {
  skip "Server doesn't support multi statements", 23
    if $dbh->get_info($GetInfoType{SQL_DBMS_VER}) lt "4.1";

  ok($dbh->do("DROP TABLE IF EXISTS $table"), "clean up");

  ok($dbh->do("CREATE TABLE $table (a INT)"), "create table");

  ok($dbh->do("INSERT INTO $table VALUES (1); INSERT INTO $table VALUES (2);"), "2 inserts");

   # Check that a second do() doesn't fail with an 'Out of sync' error
  ok($dbh->do("INSERT INTO $table VALUES (3); INSERT INTO $table VALUES (4);"), "2 more inserts");

  # Check that more_results works for non-SELECT results too
  my $sth;
  ok($sth = $dbh->prepare("UPDATE $table SET a=5 WHERE a=1; UPDATE $table SET a='6-' WHERE a<4"));
  ok($sth->execute(), "Execute updates");
  is($sth->rows, 1, "First update affected 1 row");
  is($sth->{mysql_warning_count}, 0, "First update had no warnings");
  ok($sth->{Active}, "Statement handle is Active");
  ok($sth->more_results());
  is($sth->rows, 2, "Second update affected 2 rows");
  is($sth->{mysql_warning_count}, 2, "Second update had 2 warnings");
  ok(not $sth->more_results());
  ok($sth->finish());

  # Now run it again without calling more_results().
  ok($sth->execute(), "Execute updates again");
  ok($sth->finish());

  # Check that do() doesn't fail with an 'Out of sync' error
  is($dbh->do("DELETE FROM $table"), 4, "Delete all rows");

  # Test that do() reports errors from all result sets
  $dbh->{RaiseError} = $dbh->{PrintError} = 0;
  ok(!$dbh->do("INSERT INTO $table VALUES (1); INSERT INTO bad_$table VALUES (2);"), "do() reports errors");

  # Test that execute() reports errors from only the first result set
  ok($sth = $dbh->prepare("UPDATE $table SET a=2; UPDATE bad_$table SET a=3"));
  ok($sth->execute(), "Execute updates");
  ok(!$sth->err(), "Err was not set after execute");
  ok(!$sth->more_results());
  ok($sth->err(), "Err was set after more_results");
};

$dbh->disconnect();
#-----------------------------------------------------------------------
#!perl -w
# vim: ft=perl

use strict;
use lib 't', '.';
require 'lib.pl';
use DBI;
use DBI::Const::GetInfoType;
use Test::More;
use Carp qw(croak);
use vars qw($table $test_dsn $test_user $test_password);

my ($row, $vers, $test_procs, $dbh, $sth);
EVAL {$dbh = DBI->connect($test_dsn, $test_user, $test_password,
  { RaiseError => 1, AutoCommit => 1})};

if ($@) {
    plan skip_all =>
        "ERROR: $DBI::errstr. Can't continue test";
}

#
# DROP/CREATE PROCEDURE will give syntax error
# for versions < 5.0
#
if ($dbh->get_info($GetInfoType{SQL_DBMS_VER}) lt "5.0") {
    plan skip_all =>
        "SKIP TEST: You must have MySQL version 5.0 and greater for this test to run";
}
plan tests => 29;

$dbh->disconnect();

ok ($dbh = DBI->connect($test_dsn, $test_user, $test_password,
  { RaiseError => 1, AutoCommit => 1}));

ok $dbh->do("DROP TABLE IF EXISTS $table");

my $drop_proc= "DROP PROCEDURE IF EXISTS testproc";

ok $dbh->do($drop_proc);


my $proc_create = <<EOPROC;
create procedure testproc() deterministic
  begin
    declare a,b,c,d int;
    set a=1;
    set b=2;
    set c=3;
    set d=4;
    select a, b, c, d;
    select d, c, b, a;
    select b, a, c, d;
    select c, b, d, a;
  end
EOPROC

ok $dbh->do($proc_create);

my $proc_call = 'CALL testproc()';

ok $dbh->do($proc_call);

my $proc_select = 'SELECT @a';
ok ($sth = $dbh->prepare($proc_select));

ok $sth->execute();

ok $sth->finish;

ok $dbh->do("DROP PROCEDURE testproc");

ok $dbh->do("drop procedure if exists test_multi_sets");

$proc_create = <<EOT;
        create procedure test_multi_sets ()
        deterministic
        begin
        select user() as first_col;
        select user() as first_col, now() as second_col;
        select user() as first_col, now() as second_col, now() as third_col;
        end
EOT

ok $dbh->do($proc_create);

ok ($sth = $dbh->prepare("call test_multi_sets()"));

ok $sth->execute();

is $sth->{NUM_OF_FIELDS}, 1, "num_of_fields == 1";

my $resultset;
ok ($resultset = $sth->fetchrow_arrayref());

ok defined $resultset;

is @$resultset, 1, "1 row in resultset";

undef $resultset;

ok $sth->more_results();

is $sth->{NUM_OF_FIELDS}, 2, "NUM_OF_FIELDS == 2";

ok ($resultset= $sth->fetchrow_arrayref());

ok defined $resultset;

is @$resultset, 2, "2 rows in resultset";

undef $resultset;

ok $sth->more_results();

is $sth->{NUM_OF_FIELDS}, 3, "NUM_OF_FIELDS == 3";

ok ($resultset= $sth->fetchrow_arrayref());

ok defined $resultset;

is @$resultset, 3, "3 Rows in resultset";

local $SIG{__WARN__} = sub { die @_ };

ok $sth->finish;

ok $dbh->disconnect();
#-----------------------------------------------------------------------
#!perl -w
# vim: ft=perl

use Test::More;
use DBI;
use DBI::Const::GetInfoType;
use strict;
$|= 1;

use vars qw($table $test_dsn $test_user $test_password);
use lib 't', '.';
require 'lib.pl';

my $dbh;
EVAL {$dbh= DBI->connect($test_dsn, $test_user, $test_password,
    { RaiseError => 1, PrintError => 1, AutoCommit => 0, mysql_init_command => 'SET SESSION wait_timeout=7' });};
if ($@) {
    plan skip_all => "ERROR: $DBI::errstr. Can't continue test";
}
plan tests => 5;

ok(defined $dbh, "Connected to database");

ok(my $sth=$dbh->prepare("SHOW SESSION VARIABLES like 'wait_timeout'"));

ok($sth->execute());

ok(my @fetchrow = $sth->fetchrow_array());

is($fetchrow[1],'7','session variable is 7');

$sth->finish();

$dbh->disconnect();
#   Hej, Emacs, give us -*- perl mode here!
#
#   $Id: lib.pl 11207 2008-05-07 11:22:16Z capttofu $
#
#   lib.pl is the file where database specific things should live,
#   whereever possible. For example, you define certain constants
#   here and the like.
#
# All this code is subject to being GUTTED soon
#
use strict;
use vars qw($table $mdriver $dbdriver $childPid $test_dsn $test_user $test_password);
$table= 't1';

$| = 1; # flush stdout asap to keep in sync with stderr

#
#   Driver names; EDIT THIS!
#
$mdriver = 'mysql';
$dbdriver = $mdriver; # $dbdriver is usually just the same as $mdriver.
                      # The exception is DBD::pNET where we have to
                      # to separate between local driver (pNET) and
                      # the remote driver ($dbdriver)


#
#   DSN being used; do not edit this, edit "$dbdriver.dbtest" instead
#


$::COL_NULLABLE = 1;
$::COL_KEY = 2;


my $file;
if (-f ($file = "t/$dbdriver.dbtest")  ||
    -f ($file = "$dbdriver.dbtest")    ||
    -f ($file = "../tests/$dbdriver.dbtest")  ||
    -f ($file = "tests/$dbdriver.dbtest")) {
    EVAL { require $file; };
    if ($@) {
	print STDERR "Cannot execute $file: $@.\n";
	print "1..0\n";
	exit 0;
    }
    $::test_dsn      = $::test_dsn || $ENV{'DBI_DSN'} || 'DBI:mysql:database=test';
    $::test_user     = $::test_user|| $ENV{'DBI_USER'}  ||  '';
    $::test_password = $::test_password || $ENV{'DBI_PASS'}  ||  '';
}
if (-f ($file = "t/$mdriver.mtest")  ||
    -f ($file = "$mdriver.mtest")    ||
    -f ($file = "../tests/$mdriver.mtest")  ||
    -f ($file = "tests/$mdriver.mtest")) {
    EVAL { require $file; };
    if ($@) {
	print STDERR "Cannot execute $file: $@.\n";
	print "1..0\n";
	exit 0;
    }
}


#
#   The Testing() function builds the frame of the test; it can be called
#   in many ways, see below.
#
#   Usually there's no need for you to modify this function.
#
#       Testing() (without arguments) indicates the beginning of the
#           main loop; it will return, if the main loop should be
#           entered (which will happen twice, once with $state = 1 and
#           once with $state = 0)
#       Testing('off') disables any further tests until the loop ends
#       Testing('group') indicates the begin of a group of tests; you
#           may use this, for example, if there's a certain test within
#           the group that should make all other tests fail.
#       Testing('disable') disables further tests within the group; must
#           not be called without a preceding Testing('group'); by default
#           tests are enabled
#       Testing('enabled') reenables tests after calling Testing('disable')
#       Testing('finish') terminates a group; any Testing('group') must
#           be paired with Testing('finish')
#
#   You may nest test groups.
#
{
    # Note the use of the pairing {} in order to get local, but static,
    # variables.
    my (@stateStack, $count, $off, $skip_all_reason, $skip_n_reason, @skip_n);

    $count = 0;
    @skip_n = ();

    sub Testing(;$) {
	my ($command) = shift;
	if (!defined($command)) {
	    @stateStack = ();
	    $off = 0;
	    if ($count == 0) {
		++$count;
		$::state = 1;
	    } elsif ($count == 1) {
		my($d);
		if ($off) {
		    print "1..0\n";
		    exit 0;
		}
		++$count;
		$::state = 0;
		print "1..$::numTests\n";
	    } else {
		return 0;
	    }
	    if ($off) {
		$::state = 1;
	    }
	    $::numTests = 0;
	} elsif ($command eq 'off') {
	    $off = 1;
	    $::state = 0;
	} elsif ($command eq 'group') {
	    push(@stateStack, $::state);
	} elsif ($command eq 'disable') {
	    $::state = 0;
	} elsif ($command eq 'enable') {
	    if ($off) {
		$::state = 0;
	    } else {
		my $s;
		$::state = 1;
		foreach $s (@stateStack) {
		    if (!$s) {
			$::state = 0;
			last;
		    }
		}
	    }
	    return;
	} elsif ($command eq 'finish') {
	    $::state = pop(@stateStack);
	} else {
	    die("Testing: Unknown argument\n");
	}
	return 1;
    }


#
#   Read a single test result
#
    sub Test ($;$$) {
	my($result, $error, $diag) = @_;
	return Skip($skip_all_reason) if (defined($skip_all_reason));
	if (scalar(@skip_n)) {
	    my $skipped = 0;
	    my $t = $::numTests + 1;
	    foreach my $n (@skip_n) {
		return Skip($skip_n_reason) if ($n == $t);
	    }
	}
	++$::numTests;
	if ($count == 2) {
	    if (defined($diag)) {
	        printf("$diag%s", (($diag =~ /\n$/) ? "" : "\n"));
	    }
	    if ($::state || $result) {
		print "ok $::numTests\n";
		return 1;
	    } else {
		my ($pack, $file, $line) = caller();
		printf("not ok $::numTests%s at line $line\n",
			(defined($error) ? " $error" : ""));
		return 0;
	    }
	}
	return 1;
    }

#
#   Skip some test
#
    sub Skip ($) {
	my $reason = shift;
	++$::numTests;
	if ($count == 2) {
	    if ($reason) {
		print "ok $::numTests # Skip $reason\n";
	    } else {
		print "ok $::numTests # Skip\n";
	    }
	}
	return 1;
    }
    sub SkipAll($) {
	$skip_all_reason = shift;
    }
    sub SkipN($@) {
	$skip_n_reason = shift;
	@skip_n = @_;
    }
}


#
#   Print a DBI error message
#
# TODO - This is on the chopping block
sub DbiError ($$) {
    my ($rc, $err) = @_;
    $rc ||= 0;
    $err ||= '';
    print "Test $::numTests: DBI error $rc, $err\n";
}


#
#   These functions generates a list of possible DSN's aka
#   databases and returns a possible table name for a new
#   table being created.
#
{
    my(@tables, $testtable, $listed);

    $testtable = "testaa";
    $listed = 0;

    sub FindNewTable($) {
	my($dbh) = @_;

	if (UNIVERSAL::isa($dbh, "Mysql")) {
	    $dbh = $dbh->{'dbh'};
	}

	if (!$listed) {
	    @tables = grep {s/(?:^.*\.)|`//g} $dbh->tables();
	    $listed = 1;
	}

	# A small loop to find a free test table we can use to mangle stuff in
	# and out of. This starts at testaa and loops until testaz, then testba
	# - testbz and so on until testzz.
	my $foundtesttable = 1;
	my $table;
	while ($foundtesttable) {
	    $foundtesttable = 0;
	    foreach $table (@tables) {
		if ($table eq $testtable) {
		    $testtable++;
		    $foundtesttable = 1;
		}
	    }
	}
	$table = $testtable;
	$testtable++;
	$table;
    }
}

sub connection_id {
    my $dbh = shift;
    return 0 unless $dbh;

    # Paul DuBois says the following is more reliable than
    # $dbh->{'mysql_thread_id'};
    my @row = $dbh->selectrow_array("SELECT CONNECTION_ID()");

    return $row[0];
}

# nice function I saw in DBD::Pg test code
sub byte_string {
    my $ret = join( "|" ,unpack( "C*" ,$_[0] ) );
    return $ret;
}

sub SQL_VARCHAR { 12 };
sub SQL_INTEGER { 4 };

sub ErrMsg (@) { print (@_); }
sub ErrMsgF (@) { printf (@_); }


1;
# Hej, Emacs, give us -*- perl -*- mode here!
#
#   $Id: mysql.dbtest 11207 2008-05-07 11:22:16Z capttofu $
#
# database specific definitions for a 'mysql' database

my $have_transactions;


#
#   This function generates a list of tables associated to a
#   given DSN.
#
sub ListTables(@) {
    my($dbh) = shift;
    my(@tables);

    @tables = $dbh->func('_ListTables');
    if ($dbh->errstr) {
	die "Cannot create table list: " . $dbh->errstr;
    }
    @tables;
}


#
#   This function is called by DBD::pNET; given a hostname and a
#   dsn without hostname, return a dsn for connecting to dsn at
#   host.
sub HostDsn ($$) {
    my($hostname, $dsn) = @_;
    "$dsn:$hostname";
}

#
#   Return TRUE, if database supports transactions
#
sub have_transactions () {
    my ($dbh) = @_;
    return 1 unless $dbh;
    if (!defined($have_transactions)) {
        $have_transactions = "";
        my $sth = $dbh->prepare("SHOW VARIABLES");
        $sth->execute();
        while (my $row = $sth->fetchrow_hashref()) {
            if ($row->{'Variable_name'} eq 'have_bdb'  &&
                $row->{'Value'} eq 'YES') {
                $have_transactions = "bdb";
                last;
            }
            if ($row->{'Variable_name'} eq 'have_innodb'  &&
                $row->{'Value'} eq 'YES') {
                $have_transactions = "innodb";
                last;
            }
            if ($row->{'Variable_name'} eq 'have_gemini'  &&
                $row->{'Value'} eq 'YES') {
                $have_transactions = "gemini";
                last;
            }
        }
    }
    return $have_transactions;
}


1;
{ local $opt = {
         'mysql_config' => 'mysql_config',
         'embedded' => '',
         'ssl' => 0,
         'nocatchstderr' => 0,
         'libs' => '-Wl,-Bsymbolic-functions -L/usr/lib/mysql -lmysqlclient',
         'testhost' => '',
         'nofoundrows' => 0,
         'testdb' => 'test',
         'cflags' => '-I/usr/include/mysql -DBIG_JOINS=1 -fPIC',
         'testuser' => 'root',
         'testpassword' => '',
         'testsocket' => ''
       };
$::test_host = $opt->{'testhost'};
$::test_port = $opt->{'testport'};
$::test_user = $opt->{'testuser'};
$::test_socket = $opt->{'testsocket'};
$::test_password = $opt->{'testpassword'};
$::test_db = $opt->{'testdb'};
$::test_dsn = "DBI:mysql:$::test_db";
$::test_dsn .= ";mysql_socket=$::test_socket" if $::test_socket;
$::test_dsn .= ":$::test_host" if $::test_host;
$::test_dsn .= ":$::test_port" if $::test_port;
} 1;

=end pod
# vim: ft=perl6 et
