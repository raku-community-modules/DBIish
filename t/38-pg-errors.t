use v6;
use Test;
use DBIish;
need DBDish::Pg::ErrorHandling;

plan 7;

my %con-parms;
# If env var set, no parameter needed.
%con-parms<database> = 'dbdishtest' unless %*ENV<PGDATABASE>;
%con-parms<user> = 'postgres' unless %*ENV<PGUSER>;
my $dbh;

try {
  $dbh = DBIish.connect('Pg', |%con-parms);
  CATCH {
    when X::DBIish::LibraryMissing | X::DBDish::ConnectionFailed {
        diag "$_\nCan't continue.";
    }
    default { .throw; }
  }
}
without $dbh {
    skip-rest 'prerequisites failed';
    exit;
}

ok $dbh,    'Connected';

my $db-version = $dbh.server-version;
if $db-version !~~ /^ '9.'<[3 .. 6]> | 1\d / {
   skip-rest "Pg $db-version does not support full exception structure";
   exit;
}

# Typical error from Pg
my $ex;
throws-like {
    $dbh.do(q{SELECT nocolumn FROM pg_class;});

    CATCH {
        default {
            $ex = $_;
            .throw;
        }
    }
}, X::DBDish::DBError::Pg, 'Incorrect column',
    message => /'column "nocolumn" does not exist'/,
    sqlstate   => '42703',
    type    => 'ERROR',
    type-localized => /^ .+ $/,
    source-file   => 'parse_relation.c',
    source-line   => / \d+ /,
    source-function => 'errorMissingColumn';
ok $ex.is-temporary === False, 'Incorrect column: not temporary';


# All parameters
throws-like {
    $dbh.do(q:to/_QUERY_/);
      DO LANGUAGE plpgsql $$
        BEGIN RAISE EXCEPTION 'Field Test' USING
                ERRCODE = 'ERR99', DETAIL = 'Detail', HINT = 'Hint',
                COLUMN = 'Column', CONSTRAINT = 'Constraint', DATATYPE = 'Datatype',
                TABLE = 'Table', SCHEMA = 'Schema';
        END;$$;
    _QUERY_

    # Copy needed for additional testing. throws-like cannot handle Bool type
    CATCH {
        default {
            $ex = $_;
            .throw;
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
    source-function => 'exec_stmt_raise';
ok $ex.is-temporary === False, 'Raise Exception: not temporary';


# Sample of a retryable error (result may be different on immediate retry).
throws-like {
    $dbh.do(q:to/_QUERY_/);
      DO LANGUAGE plpgsql $$
        BEGIN RAISE EXCEPTION 'Fake serialization failure' USING ERRCODE = '40001';
      END;$$;
    _QUERY_

    CATCH {
        default {
            $ex = $_;
            .throw;
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
    source-function => 'exec_stmt_raise';
ok $ex.is-temporary === True, 'Raise Temporary Exception: temporary';

