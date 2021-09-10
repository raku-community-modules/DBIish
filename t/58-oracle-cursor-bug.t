use v6;
use Test;
use DBIish;

plan 122;

# Convert to TEMPORARY table instead?
without %*ENV<DBIISH_WRITE_TEST> {
    skip-rest 'Set environment variable DBIISH_WRITE_TEST=YES to run this test';
    exit;
}

my %con-parms = :database<XE>, :username<TESTUSER>, :password<Testpass>;
my $dbh;

try {
    $dbh = DBIish.connect('Oracle', |%con-parms);
    CATCH {
        when X::DBIish::LibraryMissing | X::DBDish::ConnectionFailed {
            diag "$_\nCan't continue.";
        }
        default { .rethrow; }
    }
}
without $dbh {
    skip-rest 'prerequisites failed';
    exit;
}

ok $dbh,    'Connected';
my $dropper = q|
    BEGIN
    -- Saved for a rainy day -or- spring cleaning
    -- EXECUTE IMMEDIATE 'PURGE RECYCLEBIN';
       EXECUTE IMMEDIATE 'DROP TABLE test_cursor CASCADE CONSTRAINTS PURGE';
    EXCEPTION
       WHEN OTHERS THEN
          IF SQLCODE != -942 THEN
             RAISE;
          END IF;
    END;|;

lives-ok { $dbh.execute($dropper) }, 'Clean';
lives-ok {
    $dbh.execute(qq|
    CREATE TABLE test_cursor (
        id INTEGER,
        name     VARCHAR2(24),
        address  VARCHAR2(24),
        city     VARCHAR2(24),
        zipcode  VARCHAR2(12),
        province VARCHAR2(12),
        country  VARCHAR2(12)
    )|);
}, 'Table created';

my $sth = $dbh.prepare(
    q|INSERT INTO test_cursor ( id, name, address, city, zipcode, province, country ) VALUES(?,?,?,?,?,?,?)|);
my $now = DateTime.now;

sub mk-address   { return join ' ', 100+(9000).rand.Int, <Summer Winter Spring Fall>.pick, <St. Ave. Rd.>.pick }
sub mk-city      { return <Amsterdam Houston New-York Dallas Moscow>.pick }
sub mk-zipcode   { return <75091 90210 E7P 490-1402>.pick }
sub mk-country   { return <US Canada Mexico Japan>.pick }
sub mk-name ($v) { return sprintf 'city-%02d', $v }

for 1 .. 99 -> $rownum
{
  my $name = mk-name($rownum);
  my $city = mk-city();
  my $addr = mk-address();
  my $zipc = mk-zipcode();
  my $prov = '';
  my $ctry = mk-country();
  lives-ok {
    $sth.execute( $rownum, $name, $addr, $city, $zipc, $prov, $ctry );
  }, 'Can insert made up data';
}

is $sth.dispose, True, '.dispose (INSERT)';

$sth = $dbh.prepare('SELECT COUNT(*) FROM test_cursor');
is-deeply $sth.column-types, [Rat], 'COUNT(*) type';
lives-ok { is $sth.execute(), $sth, 'count all rows'; for $sth.allrows() -> $i { is $i, 99, 'verifiy expected rows' }}, 'checked';
is $sth.dispose, True, '.dispose (COUNT)';


$sth = $dbh.prepare('SELECT * FROM test_cursor ORDER BY ID');
my @coltype = $sth.column-types;
is-deeply @coltype, [Int, Str, Str, Str, Str, Str, Str], 'Column-types match';

SCOPE:
{
  $sth.execute;
  my ($id, $name, $addr, $city, $zipc, $prov, $country ) = $sth.row;
  isa-ok $id, Int;
  isa-ok $name, Str;
  isa-ok $addr, Str;
  isa-ok $city, Str;
  isa-ok $zipc, Str;
  isa-ok $prov, Str;
  isa-ok $country, Str;

  is $id, 1, 'First Entry by ID';
  say '# STD-isa = ', $sth.^name;
  is $sth.dispose, True, '.dispose (TYPES)';
}

## CURSOR BUG
if %*ENV<RUN_CURSOR_CHECK>
{
  ## Known fields
  my @fields = < id name address city zipcode province country >;
  ## We expect it to happen before we hit 1000 .prepare(...)'s
  for 1.. 1100 -> $i
  {
    my @selected-fields = @fields[0 .. (@fields.elems-1).rand.Int];
    my $sql = sprintf 'SELECT %s FROM test_cursor WHERE ROWNUM <= ?', join(', ', @selected-fields );
    say '# ', $sql;
    $sth = $dbh.prepare( $sql );
    $sth.execute(300+(700).rand.Int);
    my $rows = $sth.allrows;
    ok $rows, sprintf 'read try:%d rows:%d fields:%d', $i, $rows.elems, @selected-fields.elems;
    $sth.dispose;
  }
}

is $dbh.execute('DELETE FROM test_cursor WHERE ID IS NOT NULL').dispose, True, 'Delete all rows';
is $dbh.execute('SELECT * FROM test_cursor').allrows.elems, 0, 'Perfect table is empty!';

# Done
ok $dbh.execute($dropper), 'Table Cleanup';
ok $dbh.dispose, 'Say good night!';

# vim: ft=perl6 expandtab
## END
