########################################################################
# housekeeping
########################################################################

use v6;
use Test;

use lib 't/lib';
use Test::Config::Pg;

my @keyz    = < database user password host port >;
my @varz    
= map
{
    "PG{$_.uc}"
},
@keyz;

dies-ok
{
    temp %*ENV< PGDATABASE > = '';
    config_pg_connect;
},
"False PGDATABASE dies ({$!//''})";

diag "Using PGDATABASE: " ~ (%*ENV< PGDATABASE > // '(none)');

lives-ok
{
    temp %*ENV< PGDATABASE > = 'foobar';

    given config_pg_connect() -> %optz 
    {
        ok %optz< database > eq %*ENV< PGDATABASE >, 
        'database matches PGDATABASE';
    }
},
"True PGDATABASE lives ({$!//''})";

lives-ok
{
    temp %*ENV< PGDATABASE  > = 'foobar';
    temp %*ENV< PGUSER      > = 'bletch';
    temp %*ENV< PGPASSWORD  > = 'blort';
    temp %*ENV< PGHOST      > = Nil;
    temp %*ENV< PGPORT      > = Nil;

    given config_pg_connect() -> %optz 
    {
        ok %optz< database  > eq %*ENV< PGDATABASE >, 
        'database matches PGDATABASE';

        ok %optz< user      > eq %*ENV< PGUSER     >, 
        'user matches PGUSER';

        ok %optz< password  > eq %*ENV< PGPASSWORD >, 
        'password matches PGPASSWORD';

        ok %optz< host      > eq 'localhost',
        'host is localhost';

        ok %optz< port      > eq '5432',
        'port is 5432';
    }
},
"True PGDATABASE lives ({$!//''})";

lives-ok
{
    temp %*ENV< PGDATABASE  > = 'foobar';
    temp %*ENV< PGUSER      > = 'bletch';
    temp %*ENV< PGPASSWORD  > = 'blort';
    temp %*ENV< PGHOST      > = 'bim';
    temp %*ENV< PGPORT      > = 'bam';

    given config_pg_connect() -> %optz 
    {
        ok %optz< database  > eq %*ENV< PGDATABASE  >, 
        'database matches PGDATABASE';

        ok %optz< user      > eq %*ENV< PGUSER      >, 
        'user matches PGUSER';

        ok %optz< password  > eq %*ENV< PGPASSWORD  >, 
        'password matches PGPASSWORD';

        ok %optz< host      > eq %*ENV< PGHOST      >, 
        'host is localhost';

        ok %optz< port      > eq %*ENV< PGPORT      >, 
        'port is 5432';
    }
},
"True PGDATABASE lives ({$!//''})";

done-testing;

=finish
