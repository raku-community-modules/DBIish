use v6;
need DBDish;

unit class DBDish::Pg::Connection does DBDish::Connection;
use DBDish::Pg::Native;
need DBDish::Pg::StatementHandle;

has PGconn $!pg_conn is required handles <
    pg-notifies pg-socket pg-parameter-status
    pg-db pg-user pg-pass pg-host
    pg-port pg-options quote>;
has $.AutoCommit is rw = True;
has $.in_transaction is rw = False;

submethod BUILD(:$!pg_conn, :$!parent!, :$!AutoCommit) { }

method prepare(Str $statement, *%args) {
    state $statement_postfix = 0;
    my $statement_name = join '_', 'pg', $*PID, $statement_postfix++;
    my $munged = DBDish::Pg::pg-replace-placeholder($statement);
    my $result = $!pg_conn.PQprepare($statement_name, $munged, 0, OidArray);
    LEAVE { $result.PQclear if $result }
    if $result && $result.is-ok {
        self.reset-err;

        DBDish::Pg::StatementHandle.new(
            :$!pg_conn,
            :parent(self),
            :$statement,
            :$.RaiseError,
            :$statement_name,
            |%args
        );
    } else {
        if $result {
            self!set-err($result.PQresultStatus, $result.PQresultErrorMessage);
        } else {
            self!set-err(PGRES_FATAL_ERROR, $!pg_conn.PQerrorMessage);
        }
    }
}

method execute(Str $statement, *%args) {
    DBDish::Pg::StatementHandle.new(
        :$!pg_conn, :parent(self), :$statement, |%args
    ).execute;
}

method server-version() {
    $ = Version.new($!pg_conn.pg-parameter-status('server_version'));
}

method selectrow_arrayref(Str $statement, $attr?, *@bind is copy) {
    with self.prepare($statement, $attr) {
        .execute(@bind) and .fetchrow_arrayref;
    } else {
        .fail;
    }
}

method selectrow_hashref(Str $statement, $attr?, *@bind is copy) {
    with self.prepare($statement, $attr) {
        .execute(@bind) and .fetchrow_hashref;
    } else {
        .fail;
    }
}

method selectall_arrayref(Str $statement, $attr?, *@bind is copy) {
    with self.prepare($statement, $attr) {
        .execute(@bind) and .fetchall_arrayref;
    } else {
        .fail;
    }
}

method selectall_hashref(Str $statement, Str $key, $attr?, *@bind is copy) {
    with self.prepare($statement, $attr) {
        .execute(@bind) and .fetchall_hashref($key);
    } else {
        .fail;
    }
}

method selectcol_arrayref(Str $statement, $attr?, *@bind is copy) {
    with self.prepare($statement, $attr) {
        .execute(@bind) and do {
            my @results;
            while (my $row = .fetchrow_arrayref) {
                @results.push($row[0]);
            }
            item @results;
        }
    } else {
        .fail;
    }
}

method commit {
    if $!AutoCommit {
        warn "Commit ineffective while AutoCommit is on";
        return;
    };
    $!pg_conn.PQexec("COMMIT");
    $.in_transaction = False;
}

method rollback {
    if $!AutoCommit {
        warn "Rollback ineffective while AutoCommit is on";
        return;
    };
    $!pg_conn.PQexec("ROLLBACK");
    $.in_transaction = False;
}

method ping {
    with $!pg_conn {
        $_.PQstatus == CONNECTION_OK;
    } else {
        False;
    }
}

method _disconnect() {
    .PQfinish with $!pg_conn;
    $!pg_conn = Nil;
}

method table-info(:$catalog, :$schema, :$table, :$type) {

    my $tbl_sql;

    my $extracols = q{,NULL::text AS pg_schema, NULL::text AS pg_table};
    if  # Rule 19a
        ($catalog && $catalog eq '%') and
        ($schema ~~ Bool && $schema) and
        ($table ~~ Bool && $table)
        #(defined $catalog and $catalog eq '%')
        #and (defined $schema and $schema eq '')
        #and (defined $table and $table eq '')
    {
        $tbl_sql = qq{
            SELECT
               NULL::text AS "TABLE_CAT"
             , NULL::text AS "TABLE_SCHEM"
             , NULL::text AS "TABLE_NAME"
             , NULL::text AS "TABLE_TYPE"
             , NULL::text AS "REMARKS"
             $extracols
        };
    }
    elsif # Rule 19b
        ($catalog ~~ Bool && $catalog) and
        ($schema && $schema eq '%') and
        ($table ~~ Bool && $table)
        #(defined $catalog and $catalog eq '')
        #and (defined $schema and $schema eq '%')
        #and (defined $table and $table eq '')
    {
        $extracols = q{,n.nspname AS pg_schema, NULL::text AS pg_table};
        $tbl_sql = qq{
            SELECT
               NULL::text AS "TABLE_CAT"
             , quote_ident(n.nspname) AS "TABLE_SCHEM"
             , NULL::text AS "TABLE_NAME"
             , NULL::text AS "TABLE_TYPE"
             , CASE WHEN n.nspname ~ '^pg_'
                 THEN 'system schema'
                 ELSE 'owned by ' || pg_get_userbyid(n.nspowner)
               END AS "REMARKS"
               $extracols
            FROM pg_catalog.pg_namespace n
            ORDER BY "TABLE_SCHEM"
        };
    }
    elsif # Rule 19c
        ($catalog ~~ Bool && $catalog) and
        ($schema ~~ Bool && $schema) and
        ($table ~~ Bool && $table) and
        ($type && $type eq '%')
        #(defined $catalog and $catalog eq '')
        #and (defined $schema and $schema eq '')
        #and (defined $table and $table eq '')
        #and (defined $type and $type eq '%')
    {
        $tbl_sql = q{
            SELECT "TABLE_CAT"
                 , "TABLE_SCHEM"
                 , "TABLE_NAME"
                 , "TABLE_TYPE"
                 , "REMARKS"
            FROM
              (SELECT NULL::text AS "TABLE_CAT"
                    , NULL::text AS "TABLE_SCHEM"
                    , NULL::text AS "TABLE_NAME") dummy_cols
            CROSS JOIN
              (SELECT 'TABLE'        AS "TABLE_TYPE"
                    , 'relkind: r'   AS "REMARKS"
               UNION
               SELECT 'SYSTEM TABLE'
                    , 'relkind: r; nspname ~ ^pg_(catalog|toast)$'
               UNION
               SELECT 'VIEW'
                    , 'relkind: v'
               UNION
               SELECT 'SYSTEM VIEW'
                    , 'relkind: v; nspname ~ ^pg_(catalog|toast)$'
               UNION
               SELECT 'MATERIALIZED VIEW'
                    , 'relkind: m'
               UNION
               SELECT 'SYSTEM MATERIALIZED VIEW'
                    , 'relkind: m; nspname ~ ^pg_(catalog|toast)$'
               UNION
               SELECT 'LOCAL TEMPORARY'
                    , 'relkind: r; nspname ~ ^pg_(toast_)?temp') type_info
             ORDER BY "TABLE_TYPE" ASC
        };
    }
    else { # Default SQL
        $extracols = q{,n.nspname AS pg_schema, c.relname AS pg_table};
        my @search =
            q{c.relkind IN ('r', 'v', 'm')}, # No sequences, etc. for now
            q{NOT (quote_ident(n.nspname) ~ '^pg_(toast_)?temp_' AND NOT has_schema_privilege(n.nspname, 'USAGE'))}; # No others' temp objects

        my $showtablespace =
            ', quote_ident(t.spcname) AS "pg_tablespace_name", quote_ident(' ~
            ( self.server-version ge v9.2.0
              ?? 'pg_tablespace_location(t.oid)'
              !! 't.spclocation'
            ) ~ ') AS "pg_tablespace_location"';

        ## If the schema or table has an underscore or a %, use a LIKE comparison
        if ($schema.defined && $schema.chars) {
            @search.push: 'n.nspname ' ~ ($schema ~~ / '_' | '%' / ?? 'LIKE ' !! '= ') ~ self.quote($schema);
        }
        if ($table.defined && $table.chars) {
            @search.push: 'c.relname ' ~ ($table ~~ / '_' | '%' / ?? 'LIKE ' !! '= ') ~ self.quote($table);
        }

        my $TSJOIN = self.server-version lt v8.0.0
            ?? '(SELECT 0 AS oid, 0 AS spcname, 0 AS spclocation LIMIT 0) AS t ON (t.oid=1)'
            !! 'pg_catalog.pg_tablespace t ON (t.oid = c.reltablespace)';

        my $whereclause = @search.join("\n\t\t\t\t\t AND ");
        $tbl_sql = qq{
            SELECT NULL::text AS "TABLE_CAT"
             , quote_ident(n.nspname) AS "TABLE_SCHEM"
             , quote_ident(c.relname) AS "TABLE_NAME"
               -- any temp table or temp view is LOCAL TEMPORARY for us
             , CASE WHEN quote_ident(n.nspname) ~ '^pg_(toast_)?temp_' THEN
                         'LOCAL TEMPORARY'
                    WHEN c.relkind = 'r' THEN
                         CASE WHEN quote_ident(n.nspname) ~ '^pg_' THEN
                                   'SYSTEM TABLE'
                              ELSE 'TABLE'
                          END
                    WHEN c.relkind = 'v' THEN
                         CASE WHEN quote_ident(n.nspname) ~ '^pg_' THEN
                                   'SYSTEM VIEW'
                              ELSE 'VIEW'
                          END
                    WHEN c.relkind = 'm' THEN
                         CASE WHEN quote_ident(n.nspname) ~ '^pg_' THEN
                                   'SYSTEM MATERIALIZED VIEW'
                              ELSE 'MATERIALIZED VIEW'
                          END
                    ELSE 'UNKNOWN'
                 END AS "TABLE_TYPE"
             , d.description AS "REMARKS"
               $showtablespace $extracols
            FROM pg_catalog.pg_class AS c
            LEFT JOIN pg_catalog.pg_description AS d
               ON (c.oid = d.objoid AND c.tableoid = d.classoid AND d.objsubid = 0)
            LEFT JOIN pg_catalog.pg_namespace n ON (n.oid = c.relnamespace)
            LEFT JOIN $TSJOIN
            WHERE $whereclause
            ORDER BY "TABLE_TYPE", "TABLE_CAT", "TABLE_SCHEM", "TABLE_NAME"
        };

        if $type && $type ne '%' {
            my $type_restrict =
                join ', ',
                    map({ / ^ "'"/ ?? $_ !! self.quote($_) }, #
                        grep({ .chars },
                            split(',', $type)
                        )
                    );

            $tbl_sql = qq{
                SELECT * FROM ($tbl_sql) ti
                WHERE "TABLE_TYPE" IN ($type_restrict)
            };
        }
    }
    with self.prepare( $tbl_sql ) {
        .execute;
        $_;
    } else {
        .fail;
    }
}

# vim: ft=perl6 et
