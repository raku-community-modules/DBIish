use v6;
use Test;
use DBIish::CommonTesting;
need DBDish::Pg::ErrorHandling;

plan 9;

my %con-parms;
# If env var set, no parameter needed.
%con-parms<database> = 'dbdishtest' unless %*ENV<PGDATABASE>;
%con-parms<user> = 'postgres' unless %*ENV<PGUSER>;
my $dbh = DBIish::CommonTesting.connect-or-skip('Pg', |%con-parms);

ok $dbh,    'Connected';

my $db-version = $dbh.server-version;
if $db-version !~~ /^ '9.'<[3 .. 6]> | 1\d / {
    skip-rest "Pg $db-version does not support full exception structure";
    exit;
}

# Typical error from Pg
{
    my $ex;
    my $query = q{SELECT nocolumn FROM pg_class;};
    throws-like {
        $dbh.execute($query);

        CATCH {
            default {
                $ex = $_;
                .rethrow;
            }
        }
    }, X::DBDish::DBError::Pg, 'Incorrect column',
            message => /'column "nocolumn" does not exist'/,
            sqlstate   => '42703',
            type    => 'ERROR',
            type-localized => /^ .+ $/,
            source-file   => 'parse_relation.c',
            source-line   => / \d+ /,
            source-function => 'errorMissingColumn',
            statement => $query,
            statement-name => / \w+ /,
            dbname => %*ENV<PGDATABASE>,
            host => / \w+ /,
            port => / \d+ /,
            user => %*ENV<PGUSER>;
    ok $ex.is-temporary === False, 'Incorrect column: not temporary';
}

# Typical error from Pg prepare
{
    my $ex;
    my $query = q{SELECT nocolumn FROM pg_class;};
    throws-like {
        $dbh.prepare($query);

        CATCH {
            default {
                $ex = $_;
                .rethrow;
            }
        }
    }, X::DBDish::DBError::Pg, 'Incorrect column for prepared statement',
            message => /'column "nocolumn" does not exist'/,
            sqlstate => '42703',
            type => 'ERROR',
            type-localized => /^ .+ $/,
            source-file => 'parse_relation.c',
            source-line => / \d+ /,
            source-function => 'errorMissingColumn',
            statement => $query,
            statement-name => / \w+ /,
            dbname => %*ENV<PGDATABASE>,
            host => / \w+ /,
            port => / \d+ /,
            user => %*ENV<PGUSER>;
    ok $ex.is-temporary === False, 'Incorrect column: not temporary';
}

# All parameters
{
    my $ex;
    my $query = q:to/_QUERY_/;
        DO LANGUAGE plpgsql $$
          BEGIN RAISE EXCEPTION 'Field Test' USING
                ERRCODE = 'ERR99', DETAIL = 'Detail', HINT = 'Hint',
                COLUMN = 'Column', CONSTRAINT = 'Constraint', DATATYPE = 'Datatype',
                TABLE = 'Table', SCHEMA = 'Schema';
        END;$$;
    _QUERY_

    throws-like {
        $dbh.execute($query);

        # Copy needed for additional testing. throws-like cannot handle Bool type
        CATCH {
            default {
                $ex = $_;
                .rethrow;
            }
        }
    }, X::DBDish::DBError::Pg, 'Raise Exception',
            sqlstate => 'ERR99',
            message => /'DBDish::Pg:' .* 'Error: Field Test'/,
            native-message => 'Field Test',
            message-detail => 'Detail',
            message-hint => 'Hint',
            context => 'PL/pgSQL function inline_code_block line 2 at RAISE',
            type    => 'ERROR',
            schema => 'Schema',
            table => 'Table',
            column => 'Column',
            datatype => 'Datatype',
            constraint => 'Constraint',
            type-localized => /^ .+ $/,
            source-file => 'pl_exec.c',
            source-line => / \d+ /,
            source-function => 'exec_stmt_raise',
            statement => $query,
            statement-name => /^ .+ $/,
            dbname => %*ENV<PGDATABASE>,
            host => / \w+ /,
            port => / \d+ /,
            user => %*ENV<PGUSER>;
    ok $ex.is-temporary === False, 'Raise Exception: not temporary';
}


# Sample of a retryable error (result may be different on immediate retry).
{
    my $ex;
    my $query = q:to/_QUERY_/;
      DO LANGUAGE plpgsql $$
        BEGIN RAISE EXCEPTION 'Fake serialization failure' USING ERRCODE = '40001';
      END;$$;
    _QUERY_

    throws-like {
        my $sth = $dbh.execute($query);
        CATCH {
            default {
                $ex = $_;
                .rethrow;
            }
        }
    }, X::DBDish::DBError::Pg, 'Raise Temporary Exception',
            message => /'Fake serialization failure'/,
            context => 'PL/pgSQL function inline_code_block line 2 at RAISE',
            sqlstate   => '40001',
            type    => 'ERROR',
            type-localized => /^ .+ $/,
            source-file => 'pl_exec.c',
            source-line => / \d+ /,
            source-function => 'exec_stmt_raise',
            statement => $query,
            statement-name => / \w+ /,
            dbname => %*ENV<PGDATABASE>,
            host => / \w+ /,
            port => / \d+ /,
            user => %*ENV<PGUSER>;
    ok $ex.is-temporary === True, 'Raise Temporary Exception: temporary';
}

