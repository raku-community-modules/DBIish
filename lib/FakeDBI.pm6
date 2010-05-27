# FakeDBI.pm6

class FakeDBI:auth<mberends>:ver<0.0.1> {
    has $!errstr;
    method connect( $dsn, $username, $password, :$RaiseError=0, :$PrintError=0, :$AutoCommit=1 ) {
        # warn "in FakeDBI.connect('$dsn')";
        # Divide $dsn up into its separate fields.
        my ( $prefix, $drivername, $params ) = $dsn.split(':');
        my $driver = self.install_driver( $drivername );
        # warn "calling FakeDBD::" ~ $drivername ~ ".connect($username,*,$params)";
        my $connection = $driver.connect( $username, $password, $params, $RaiseError );
        return $connection;
    }
    method install_driver( $drivername ) {
        # warn "in FakeDBI.install_driver('$drivername')";
        my $result;
        # the need($n, {} ) argument would be a hash of named argements,
        # but it dies with: get_pmc_keyed() not implemented in class ''
        #         Perl6::Module::Loader.need( "FakeDBD::$drivername", {} );
        $result = Perl6::Module::Loader.need( "FakeDBD::$drivername" );
        unless $result {
            warn "install_driver cannot load FakeDBD::$drivername in $*PROGRAM_NAME";
            exit( 1 ); # instead of dying with an unnecessary stack trace
        }
        my $driver;
        given $drivername {
            when 'mysql' { use FakeDBD::mysql; $driver = FakeDBD::mysql.new(); }
            default      { die "driver name '$drivername' is not known"; }
        }
        return $driver;
    }
    method errstr() {
        # avoid returning an undefined value
        return $!errstr // ''; # // confuses a P5 syntax highlighter
    }
}

=begin pod
=head1 SYNOPSIS
 # the list is from Perl 5 DBI, uncommented is working here
 use FakeDBI;
 # TODO: @driver_names = DBI.available_drivers;
 # TODO: %drivers      = DBI.installed_drivers;
 # TODO: @data_sources = DBI.data_sources($driver_name, \%attr);

 $dbh = FakeDBI.connect($data_source, $username, $auth, \%attr);

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

 # TODO: @row_ary  = $sth.fetchrow_array;
 $ary_ref  = $sth.fetchrow_arrayref;
 # TODO: $hash_ref = $sth.fetchrow_hashref;

 # TODO: $ary_ref  = $sth.fetchall_arrayref;
 # TODO: $ary_ref  = $sth.fetchall_arrayref( $slice, $max_rows );

 # TODO: $hash_ref = $sth.fetchall_hashref( $key_field );

 # TODO: $rv  = $sth.rows;

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
The name C<FakeDBI> has several meanings.  In lowercase it indicates the
github project that 

=head1 FakeDBI CLASSES

=head2 FakeDBI

=head1 SEE ALSO
L<http://dbi.perl.org>
=end pod
