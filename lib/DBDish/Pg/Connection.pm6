use v6;
need DBDish;

unit class DBDish::Pg::Connection does DBDish::Connection;
use DBDish::Pg::Native;
need DBDish::Pg::StatementHandle;
need DBDish::TestMock;
use DBIish::Common;

has PGconn $!pg_conn handles <
    pg-notifies pg-socket pg-parameter-status
    pg-db pg-user pg-pass pg-host
    pg-port pg-options quote>;
has $.AutoCommit is rw = True;
has $.in_transaction is rw = False;
has %.Converter is DBDish::TypeConverter;
has %.dynamic-types = %oid-to-type;

submethod BUILD(:$!pg_conn!, :$!parent!, :$!AutoCommit) {
    %!Converter =
       method (--> Bool) { self eq 't' },
       method (--> DateTime) { DateTime.new(self.split(' ').join('T')) },
       :Buf(&str-to-blob);
}

has $!statement-posfix = 0;
method prepare(Str $statement, *%args) {
    my $statement-name = join '_', 'pg', $*PID, $!statement-posfix++;
    my $munged = DBDish::Pg::pg-replace-placeholder($statement);
    die "Can't prepare this: '$statement'!" unless $munged;
    my $result = $!pg_conn.PQprepare($statement-name, $munged, 0, OidArray);
    LEAVE { $result.PQclear if $result }
    if $result && $result.is-ok {
        self.reset-err;

        DBDish::Pg::StatementHandle.new(
            :$!pg_conn,
            :parent(self),
            :$statement,
            :$.RaiseError,
            :$statement-name,
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

    $!parent.protect-connection: {
        $!pg_conn.PQexec("COMMIT");
    };
    $.in_transaction = False;
}

method rollback {
    if $!AutoCommit {
        warn "Rollback ineffective while AutoCommit is on";
        return;
    };

    $!parent.protect-connection: {
        $!pg_conn.PQexec("ROLLBACK");
    };
    $.in_transaction = False;
}

method ping {
    with $!pg_conn {
        $_.PQstatus == CONNECTION_OK;
    } else {
        False;
    }
}

method pg-consume-input(--> Bool) {
    my $status = $!pg_conn.PQconsumeInput();
    if (0 == $status) {
        self!set-err(PGRES_FATAL_ERROR, $!pg_conn.PQerrorMessage);
    }
    return ?$status;
}

method _disconnect() {
    .PQfinish with $!pg_conn;
    $!pg_conn = Nil;
}

constant %pg-to-sql is export = Map.new: map(
    { +PGTypes::{.key} => .value }, (
  PG_BOOL        => SQLType::SQL_BOOLEAN,
  PG_BPCHAR      => SQLType::SQL_CHAR,
  PG_BYTEA       => SQLType::SQL_VARBINARY,
  PG_CHAR        => SQLType::SQL_CHAR,
  PG_DATE        => SQLType::SQL_TYPE_DATE,
  PG_FLOAT8      => SQLType::SQL_FLOAT,
  PG_INT2        => SQLType::SQL_SMALLINT,
  PG_INT4        => SQLType::SQL_INTEGER,
  PG_INT8        => SQLType::SQL_BIGINT,
  PG_NAME        => SQLType::SQL_VARCHAR,
  PG_NUMERIC     => SQLType::SQL_DECIMAL,
  PG_TEXT        => SQLType::SQL_LONGVARCHAR,
  PG_TIME        => SQLType::SQL_TYPE_TIME,
  PG_TIMESTAMP   => SQLType::SQL_TIMESTAMP,
  PG_TIMESTAMPTZ => SQLType::SQL_TYPE_TIMESTAMP_WITH_TIMEZONE,
  PG_VARCHAR     => SQLType::SQL_VARCHAR,
));

my sub calc-col-size($mod, $size) {
    if $size.defined && $size > 0 {
        $size;
    } elsif $mod > 0xffff {
        my $prec = ($mod +& 0xffff) - 4;
        $mod +>= 16;
        #my $dig = $mod;
        "$prec,$mod";
    } elsif $mod >= 4 {
        $mod - 4;
    } else {
        $size
    }
}

my sub prepare-from-data($parent, $statement, List() $rows, $col-names, $col-types) {
    my $mock = DBDish::TestMock.new(:$parent).connect
        .prepare('col-info',:$rows,:$col-names,:$col-types);
    $mock.execute;
    $mock;
}

# If the ID has an underscore or a %, use a LIKE comparison
method !make-comp($id, $field) {
    "$field " ~ ($id ~~ / '_' | '%' / ?? 'LIKE ' !! '= ') ~ self.quote($id);
}

method column-info(:$catalog, :$schema, :$table, :$column) {
    my @search = '';
    @search.push(self!make-comp($schema, 'n.nspname')) if $schema;
    @search.push(self!make-comp($table,  'c.relname')) if $table;
    @search.push(self!make-comp($column, 'a.attname')) if $column;

    my $col-info-sql = qq«
      SELECT
        NULL::text AS "TABLE_CAT"
        , quote_ident(n.nspname) AS "TABLE_SCHEM"
        , quote_ident(c.relname) AS "TABLE_NAME"
        , quote_ident(a.attname) AS "COLUMN_NAME"
        , a.atttypid AS "DATA_TYPE"
        , pg_catalog.format_type(a.atttypid, NULL) AS "TYPE_NAME"
        , a.attlen AS "COLUMN_SIZE"
        , NULL::text AS "BUFFER_LENGTH"
        , NULL::text AS "DECIMAL_DIGITS"
        , NULL::text AS "NUM_PREC_RADIX"
        , CASE a.attnotnull WHEN 't' THEN 0 ELSE 1 END AS "NULLABLE"
        , pg_catalog.col_description(a.attrelid, a.attnum) AS "REMARKS"
        , pg_catalog.pg_get_expr(af.adbin, af.adrelid) AS "COLUMN_DEF"
        , NULL::text AS "SQL_DATA_TYPE"
        , NULL::text AS "SQL_DATETIME_SUB"
        , NULL::text AS "CHAR_OCTET_LENGTH"
        , a.attnum AS "ORDINAL_POSITION"
        , CASE a.attnotnull WHEN 't' THEN 'NO' ELSE 'YES' END AS "IS_NULLABLE"
        , pg_catalog.format_type(a.atttypid, a.atttypmod) AS "pg_type"
        , '?' AS "pg_constraint"
        , n.nspname AS "pg_schema"
        , c.relname AS "pg_table"
        , a.attname AS "pg_column"
        , a.attrelid AS "pg_attrelid"
        , a.attnum AS "pg_attnum"
        , a.atttypmod AS "pg_atttypmod"
        , t.typtype AS "_pg_typtype"
        , t.oid AS "_pg_oid"
      FROM
        pg_catalog.pg_type t
        JOIN pg_catalog.pg_attribute a ON (t.oid = a.atttypid)
        JOIN pg_catalog.pg_class c ON (a.attrelid = c.oid)
        LEFT JOIN pg_catalog.pg_attrdef af ON (a.attnum = af.adnum AND a.attrelid = af.adrelid)
        JOIN pg_catalog.pg_namespace n ON (n.oid = c.relnamespace)
      WHERE
        a.attnum >= 0
        AND c.relkind IN ('r','v','m'){ @search.join("\n\tAND ") }
      ORDER BY "TABLE_SCHEM", "TABLE_NAME", "ORDINAL_POSITION"»;

    my $sth = self.prepare($col-info-sql);
    my %col-map := ($sth.column-names Z=> (0..*)).Map;

    my $sth-info = self.prepare(q{
        SELECT "substring"(pg_get_constraintdef(con.oid), 7) AS consrc
        FROM pg_catalog.pg_constraint AS con
        WHERE contype = 'c' AND conrelid = ? AND conkey = ?
    });

    $sth.execute;
    # We need to process the data
    my $data = $sth.allrows.map(-> @row {
        # The last five are internal only
        my ($aid, $attnum, $typmod, $typtype, $typoid) =
          @row[%col-map<pg_attrelid pg_attnum pg_atttypmod _pg_typtype _pg_oid>]:delete;

        @row[%col-map<COLUMN_SIZE>] = calc-col-size($typmod, @row[%col-map<COLUMN_SIZE>]);

        # Replace the Pg type oid with the PG_/SQL_ type
        with PGTypes(@row[%col-map<DATA_TYPE>]) {
            @row[%col-map<DATA_TYPE>] = $_;
            @row[%col-map<SQL_DATA_TYPE>] = %pg-to-sql{+$_} || SQLType::SQL_UNKNOWN_TYPE;
        }

        # Add pg_constraint
        with $sth-info.execute($aid, $attnum) && $sth-info.allrows {
            @row[%col-map<pg_constraint>] = $_ ?? $_[0][0] !! Any;
        }

        if $typtype eq 'e'  {
            my $sth = self.prepare( "SELECT enumlabel FROM pg_catalog.pg_enum WHERE enumtypid = ? ORDER BY " ~
                                    (self.server-version ~~ v9.1.0+ ?? 'enumsortorder' !! 'oid'));
            $sth.execute($typoid);
            @row.push( $sth.allrows() );
        }
        else {
            @row.push: Any;
        }
        @row;
    });

    # Since we've processed the data in Perl, we have to jump through a hoop
    # to turn it back into a statement handle
    my @col-types = (|$sth.column-types[^23], Str);
    @col-types[%col-map<DATA_TYPE>, %col-map<SQL_DATA_TYPE>] = Mu;
    prepare-from-data(self.drv.parent,
         'column_info',
         $data,
         $(|$sth.column-names[^23], 'pg_enum_values'),
         @col-types
    );
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

        if $schema.defined && $schema.chars {
            @search.push: self!make-comp($schema, 'n.nspname');
        }
        if $table.defined && $table.chars {
            @search.push: self!make-comp($table, 'c.relname');
        }

        my $TSJOIN = self.server-version lt v8.0.0
            ?? '(SELECT 0 AS oid, 0 AS spcname, 0 AS spclocation LIMIT 0) AS t ON (t.oid=1)'
            !! 'pg_catalog.pg_tablespace t ON (t.oid = c.reltablespace)';

        my $whereclause = @search.join("\n\t\t\t\t\tAND ");
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
