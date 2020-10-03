#!/usr/bin/env perl6

use v6;
use lib 'lib';
use DBIish;
use NativeCall;

# Windows support
if $*DISTRO.is-win {
    # libpq.dll on windows depends on libeay32.dll which in this path
    my constant PG-HOME   = 'C:\Program Files\PostgreSQL\9.3';
    my $path              = sprintf( 'Path=%s;%s\bin', %*ENV<Path>, PG-HOME );
    %*ENV<DBIISH_PG_LIB>  = (PG-HOME).fmt( '%s\lib\libpq.dll' );

    # Since %*ENV<Path> = ... does not actually own process environment
    # Weird magic but needed atm :)
    sub _putenv(Str) is native('msvcrt') { ... }
    _putenv( $path);
}

my $dbh = DBIish.connect(
        "Pg",
        :database<dbiish>,
        :user<dbiish>,
        );

# Create a temporary table with a type that isn't already converted
# via DBIish. By default DBIish will return the same string that PostgreSQL
# does.
$dbh.execute(q:to/STATEMENT/);
  CREATE TEMPORARY TABLE tab (
      col point NOT NULL
  );
STATEMENT

# The structure of the type within Raku can be nearly anything.
# A Point class with X and Y coordinates will be used for the PostgreSQL point type
class Point {
    has Int $.x is required;
    has Int $.y is required;
}


# Conversion from the DB to the Raku type.
#
# Extract the X/Y pieces from the string PostgreSQL returns and return an instance
# of the point class.
#
# More complex conversions might be needed for PostGIS types, etc.
my $from-db-sub = sub ($value --> Point) {
    if $value ~~ / "(" $<x>=(<[-]>? \d+) "," $<y>=(<[-]>? \d+)  ")"/ {
        return Point.new(x => Int.new(~$<x>), y => Int.new(~$<y>));
    } else {
        die "Value '$value' is not a point";
    }
}

# Conversion routine to create a PostgreSQL string for the Point class.
my $to-db-sub = sub (Point $obj --> Str) {
    # Encode the object value for the database type
    return '(%d,%d)'.sprintf($obj.x, $obj.y);
};

# Register the PG/Raku conversion functions. The type OID will be looked up once per connection
# and used to detect when conversion should occur.
$dbh.register-type-conversion(schema => 'pg_catalog', db-type => 'point', raku-type => Point, :$from-db-sub, :$to-db-sub);

# Roundtrip the datum. Store the Point, then retrieve it back again.
my $point = Point.new(x => 4, y => -8);
$dbh.execute('INSERT INTO tab VALUES ($1)', $point);

for $dbh.execute('SELECT col FROM tab').allrows(:array-of-hash) -> $row {
    # $retrieved-point is a Point object with x and y values set.
    # $point == $retrieved-point;
    my $retrieved-point = $row<col>;

    say "Point: ({$retrieved-point.x}, {$retrieved-point.y})";
}

# Disconnect
$dbh.dispose;
