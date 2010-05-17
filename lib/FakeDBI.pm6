# FakeDBI.pm6

#class FakeDBI::DatabaseHandle {
#    has $!driver;
#    has $.connection;
#    method prepare( Str $statement ) {
#        warn "in FakeDBI::DatabaseHandle.prepare()";
#        my $statement_handle = FakeDBI::StatementHandle.bless(
#            FakeDBI::StatementHandle.CREATE(),
#            database_handle => self,
#            statement => $statement
#        );
#        return $statement_handle;
#    }
#}

class FakeDBI:auth<mberends>:ver<0.0.1> {
    method connect( $dsn, $username, $password ) {
        # warn "in FakeDBI.connect('$dsn')";
        # Divide $dsn up into its separate fields.
        my ( $prefix, $drivername, $params ) = $dsn.split(':');
        my $driver = self.install_driver( $drivername );
        # warn "calling FakeDBD::" ~ $drivername ~ ".connect($username,*,$params)";
        my $connection = $driver.connect( $username, $password, $params );
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
#        return $!errstr;
    }
}
