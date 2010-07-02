# MiniDBI.pm6

class MiniDBI:auth<mberends>:ver<0.1.0> {
    has $!err;
    has $!errstr;
    method connect( $dsn, $username, $password, :$RaiseError=0, :$PrintError=0, :$AutoCommit=1 ) {
        # warn "in MiniDBI.connect('$dsn')";
        # Divide $dsn up into its separate fields.
        my ( $prefix, $drivername, $params ) = $dsn.split(':');
        my $driver = self.install_driver( $drivername );
        # warn "calling MiniDBD::" ~ $drivername ~ ".connect($username,*,$params)";
        my $connection = $driver.connect( $username, $password, $params, $RaiseError );
        return $connection;
    }
    method install_driver( $drivername ) {
        # warn "in MiniDBI.install_driver('$drivername')";
        my $result;
        # the need($n, {} ) argument would be a hash of named argements,
        # but it dies with: get_pmc_keyed() not implemented in class ''
        #         Perl6::Module::Loader.need( "MiniDBD::$drivername", {} );
        $result = Perl6::Module::Loader.need( "MiniDBD::$drivername" );
        unless $result {
            warn "install_driver cannot load MiniDBD::$drivername in $*PROGRAM_NAME";
            exit( 1 ); # instead of dying with an unnecessary stack trace
        }
        my $driver;
        given $drivername {
            when 'CSV'     { eval 'use MiniDBD::CSV;   $driver = MiniDBD::CSV.new()' }
            when 'mysql'   { eval 'use MiniDBD::mysql; $driver = MiniDBD::mysql.new()' }
            when 'PgPir'   { eval 'use MiniDBD::PgPir; $driver = MiniDBD::PgPir.new()' }
            when 'Pg'      { eval 'use MiniDBD::Pg;    $driver = MiniDBD::Pg.new()' }
            default        { die "driver name '$drivername' is not known"; }
        }
        return $driver;
    }
    # TODO: revise error reporting to conform better to Perl 5 DBI
    method err() {
        return $!err; # currently always returns an undefined value
    }
    method errstr() {
        # avoid returning an undefined value
        return $!errstr // ''; # // confuses a P5 syntax highlighter
    }
}

# The following list of SQL constants was produced by the following
# adaptation of the EXPORT_TAGS suggestion in 'perldoc DBI':
#    perl -MDBI -e'for (@{ $DBI::EXPORT_TAGS{sql_types} })
#        { printf "our sub %s { %d }\n", $_, &{"DBI::$_"}; }'
our sub SQL_GUID { -11 }
our sub SQL_WLONGVARCHAR { -10 }
our sub SQL_WVARCHAR { -9 }
our sub SQL_WCHAR { -8 }
our sub SQL_BIGINT { -5 }
our sub SQL_BIT { -7 }
our sub SQL_TINYINT { -6 }
our sub SQL_LONGVARBINARY { -4 }
our sub SQL_VARBINARY { -3 }
our sub SQL_BINARY { -2 }
our sub SQL_LONGVARCHAR { -1 }
our sub SQL_UNKNOWN_TYPE { 0 }
our sub SQL_ALL_TYPES { 0 }
our sub SQL_CHAR { 1 }
our sub SQL_NUMERIC { 2 }
our sub SQL_DECIMAL { 3 }
our sub SQL_INTEGER { 4 }
our sub SQL_SMALLINT { 5 }
our sub SQL_FLOAT { 6 }
our sub SQL_REAL { 7 }
our sub SQL_DOUBLE { 8 }
our sub SQL_DATETIME { 9 }
our sub SQL_DATE { 9 }
our sub SQL_INTERVAL { 10 }
our sub SQL_TIME { 10 }
our sub SQL_TIMESTAMP { 11 }
our sub SQL_VARCHAR { 12 }
our sub SQL_BOOLEAN { 16 }
our sub SQL_UDT { 17 }
our sub SQL_UDT_LOCATOR { 18 }
our sub SQL_ROW { 19 }
our sub SQL_REF { 20 }
our sub SQL_BLOB { 30 }
our sub SQL_BLOB_LOCATOR { 31 }
our sub SQL_CLOB { 40 }
our sub SQL_CLOB_LOCATOR { 41 }
our sub SQL_ARRAY { 50 }
our sub SQL_ARRAY_LOCATOR { 51 }
our sub SQL_MULTISET { 55 }
our sub SQL_MULTISET_LOCATOR { 56 }
our sub SQL_TYPE_DATE { 91 }
our sub SQL_TYPE_TIME { 92 }
our sub SQL_TYPE_TIMESTAMP { 93 }
our sub SQL_TYPE_TIME_WITH_TIMEZONE { 94 }
our sub SQL_TYPE_TIMESTAMP_WITH_TIMEZONE { 95 }
our sub SQL_INTERVAL_YEAR { 101 }
our sub SQL_INTERVAL_MONTH { 102 }
our sub SQL_INTERVAL_DAY { 103 }
our sub SQL_INTERVAL_HOUR { 104 }
our sub SQL_INTERVAL_MINUTE { 105 }
our sub SQL_INTERVAL_SECOND { 106 }
our sub SQL_INTERVAL_YEAR_TO_MONTH { 107 }
our sub SQL_INTERVAL_DAY_TO_HOUR { 108 }
our sub SQL_INTERVAL_DAY_TO_MINUTE { 109 }
our sub SQL_INTERVAL_DAY_TO_SECOND { 110 }
our sub SQL_INTERVAL_HOUR_TO_MINUTE { 111 }
our sub SQL_INTERVAL_HOUR_TO_SECOND { 112 }
our sub SQL_INTERVAL_MINUTE_TO_SECOND { 113 }

=begin pod
=head1 SYNOPSIS
 # the list is from Perl 5 DBI, uncommented is working here
 use MiniDBI;
 # TODO: @driver_names = DBI.available_drivers;
 # TODO: %drivers      = DBI.installed_drivers;
 # TODO: @data_sources = DBI.data_sources($driver_name, \%attr);

 $dbh = MiniDBI.connect($data_source, $username, $auth, \%attr);

 $rv  = $dbh.do($statement);
 # TODO: $rv  = $dbh.do($statement, \%attr);
 # TODO: $rv  = $dbh.do($statement, \%attr, @bind_values);

 # TODO: $ary_ref  = $dbh.selectall_arrayref($statement);
 # TODO: $hash_ref = $dbh.selectall_hashref($statement, $key_field);

 # TODO: $ary_ref  = $dbh.selectcol_arrayref($statement);
 # TODO: $ary_ref  = $dbh.selectcol_arrayref($statement, \%attr);

 # TODO: @row_ary  = $dbh.selectrow_array($statement);
 # TODO: $ary_ref  = $dbh.selectrow_arrayref($statement);
 # TODO: $hash_ref = $dbh.selectrow_hashref($statement);

 $sth = $dbh.prepare($statement);
 # TODO: $sth = $dbh.prepare_cached($statement);

 # TODO: $rc = $sth.bind_param($p_num, $bind_value);
 # TODO: $rc = $sth.bind_param($p_num, $bind_value, $bind_type);
 # TODO: $rc = $sth.bind_param($p_num, $bind_value, \%attr);

 $rv = $sth.execute;
 $rv = $sth.execute(@bind_values);
 # TODO: $rv = $sth.execute_array(\%attr, ...);

 # TODO: $rc = $sth.bind_col($col_num, \$col_variable);
 # TODO: $rc = $sth.bind_columns(@list_of_refs_to_vars_to_bind);

 @row_ary  = $sth.fetchrow_array;
 $ary_ref  = $sth.fetchrow_arrayref;
 $hash_ref = $sth.fetchrow_hashref;

 # TODO: $ary_ref  = $sth.fetchall_arrayref;
 # TODO: $ary_ref  = $sth.fetchall_arrayref( $slice, $max_rows );

 # TODO: $hash_ref = $sth.fetchall_hashref( $key_field );

 $rv  = $sth.rows;

 # TODO: $rc  = $dbh.begin_work;
 # TODO: $rc  = $dbh.commit;
 # TODO: $rc  = $dbh.rollback;

 # TODO: $quoted_string = $dbh.quote($string);

 # TODO: $rc  = $h.err;
 $str = $h.errstr;
 # TODO: $rv  = $h.state;

 $rc  = $dbh.disconnect;

The (Perl 5) synopsis above only lists the major methods and parameters.

=head1 DESCRIPTION
The name C<MiniDBI> has two meanings.  In lowercase it indicates the
github project being used for development.  In mixed case it is the
module name and class name that database client applications should use.

=head1 MiniDBI CLASSES and ROLES

=head2 MiniDBI
The C<MiniDBI> class exists mainly to provide the F<connect> method,
which acts as a constructor for database connections.

=head2 MiniDBD
The C<MiniDBD> role should only be used with 'does' to provide standard
members for MiniDBD classes.

=head1 SEE ALSO
L<http://dbi.perl.org>
=end pod
