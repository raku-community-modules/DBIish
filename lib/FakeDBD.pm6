# FakeDBD.pm6
# Provide default methods for all database drivers

role FakeDBD::StatementHandle {
    has $!errstr;
    method errstr() {
        return defined $!errstr ?? $!errstr !! '';
    }
}

role FakeDBD::Connection {
    has $!errstr;
    method do( Str $statement, *@params ) {
        # warn "in FakeDBD::Connection.do('$statement')";
        my $sth = self.prepare($statement) or return fail();
        $sth.execute(@params) or return fail();
    }
    method disconnect() {
        # warn "in FakeDBI::DatabaseHandle.disconnect()";
        return Bool::True;
    }
    method errstr() {
        return $!errstr;
    }
}
