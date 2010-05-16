# FakeDBI.pm

class FakeDBI::StatementHandle {
    has $!statement;
    method execute(*@params) {
    }
}

class FakeDBI::DatabaseHandle {
    has $!driver;
    method disconnect() {
        # warn "disconnecting...\n";
        return Bool::True;
    }
    method prepare( Str $statement ) {
        warn "entering FakeDBI::DatabaseHandle.prepare()";
    }
}

class FakeDBI:auth<mberends>:ver<0.0.1> {
#   my $!error_string;
    method connect( $dsn, $username, $password ) {
        # warn "entering FakeDBI.connect('$dsn')";
        # Divide $dsn up into its separate fields.
        my ( $prefix, $drivername, $params ) = $dsn.split(':');
        # warn "connecting prefix=$prefix driver=$drivername";
        my $driver = self.install_driver( "$drivername" );
        $driver.connect( $username, $password, $params );
        my $handle = FakeDBI::DatabaseHandle.bless(
            FakeDBI::DatabaseHandle.CREATE(),
            driver => $driver
        );
        return $handle;
    }
    method install_driver( $drivername ) {
        # warn "begin FakeDBI.install_driver('$drivername')";
        my $result;
        # the need($n, {} ) argument would be a hash of named argements,
        # but it dies with: get_pmc_keyed() not implemented in class ''
        #         Perl6::Module::Loader.need( "FakeDBD::$drivername", {} );
        $result = Perl6::Module::Loader.need( "FakeDBD::$drivername" );
        unless $result {
#           $error_string = "install_driver cannot load FakeDBD::$drivername";
            die "install_driver cannot load FakeDBD::$drivername";
        }
        my $dr;
        given $drivername {
            when 'mysql' { use FakeDBD::mysql; $dr = FakeDBD::mysql.new(); }
            default { die "driver name '$drivername' is not known"; }
        }
        return $dr;
    }
    method data_sources( $driver, %params? ) {
        my @databases = ();
        return @databases;
    }
    method errstr() {
#        return $error_string;
    }
}
