use v6;
need DBDish::ErrorHandling;
use DBDish::Pg::Native;

package X::DBDish {
    class DBError::Pg is X::DBDish::DBError {
        has $.sqlstate is required;

        has $.message-detail;
        has $.message-hint;
        has $.context;
        has $.type;
        has $.type-localized;

        has $.dbname;
        has $.user;
        has $.host;
        has $.port;

        has $.statement;
        has $.statement-name;
        has $.statement-position;
        has $.internal-position;
        has $.internal-query;

        has $.schema;
        has $.table;
        has $.column;
        has $.datatype;
        has $.constraint;

        has $.source-file;
        has $.source-line;
        has $.source-function;

        has $.result;

        submethod BUILD(:$!result, :$statement-handle, :$statement, :$statement-name = "", :$pg_conn) {
            $!sqlstate = $!result.PQresultErrorField(PG_DIAG_SQLSTATE);

            $!message-detail = $!result.PQresultErrorField(PG_DIAG_MESSAGE_DETAIL);
            $!message-hint = $!result.PQresultErrorField(PG_DIAG_MESSAGE_HINT);
            $!context = $!result.PQresultErrorField(PG_DIAG_CONTEXT);
            $!type = $!result.PQresultErrorField(PG_DIAG_SEVERITY_NONLOCALIZED);
            $!type-localized = $!result.PQresultErrorField(PG_DIAG_SEVERITY);

            $!statement-position = $!result.PQresultErrorField(PG_DIAG_STATEMENT_POSITION);
            $!internal-position = $!result.PQresultErrorField(PG_DIAG_INTERNAL_POSITION);
            $!internal-query = $!result.PQresultErrorField(PG_DIAG_INTERNAL_QUERY);

            $!schema = $!result.PQresultErrorField(PG_DIAG_SCHEMA_NAME);
            $!table = $!result.PQresultErrorField(PG_DIAG_TABLE_NAME);
            $!column = $!result.PQresultErrorField(PG_DIAG_COLUMN_NAME);
            $!datatype = $!result.PQresultErrorField(PG_DIAG_DATATYPE_NAME);
            $!constraint = $!result.PQresultErrorField(PG_DIAG_CONSTRAINT_NAME);

            $!source-file = $!result.PQresultErrorField(PG_DIAG_SOURCE_FILE);
            $!source-line = $!result.PQresultErrorField(PG_DIAG_SOURCE_LINE);
            $!source-function = $!result.PQresultErrorField(PG_DIAG_SOURCE_FUNCTION);

            with $statement-handle {
                $!statement = $statement-handle.statement;
                $!statement-name = $statement-handle.statement-name;
            } orwith $statement {
                # If prepare failed then a statement name does not exist. "" matches
                # what $statement-handle.statement-name would be if a name is not set.
                $!statement = $statement;
                $!statement-name = $statement-name;
            }

            # Copy data to ensure it survives dispose()
            with $pg_conn {
                $!dbname = $pg_conn.pg-db;
                $!user = $pg_conn.pg-user;
                $!host = $pg_conn.pg-host;
                $!port = $pg_conn.pg-port;
            }
        }

        # Errors which should cause a retry loop within the calling application include:
        #  - Class 08\w{3}: All connection exceptions (possible network issues)
        #  - 40001 serialization_failure
        #  - 40P01 deadlock_detected
        #  - Class 57\w{3}: Operator Intervention (early/forced connection termination)
        #  - 72000 snapshot_too_old
        method is-temporary {
           so $.sqlstate ~~ /^ '08'<alnum> ** 3 | '40001'| '40P01' | '57'<alnum> ** 3 | '72000' $/;
        }
    }
}
