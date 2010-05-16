role FakeDBD {
    has $.name;
    has $.handle is rw;
    method do( Str $statement, *@params ) {
        my $sth = self.prepare($statement) or return fail();
        $sth.execute(@params) or return fail();
        my $rows = $sth.rows;
        ($rows == 0) ?? "0E0" !! $rows;
    }
}
