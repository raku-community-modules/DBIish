# FakeDBD/CSV.pm6

use FakeDBD;

grammar FakeDBD::CSV::SQL {
    # note: token means regex :ratchet, rule means token :sigspace
    regex TOP { ^ [ <create_table> | <drop_table> | <insert> | <update>
                | <delete> | <select> ] }
    rule create_table {:i create table <table_name> '(' <col_defs> }
    rule col_defs {<col_def>}
    rule col_def {<column_name>}
    rule drop_table {:i drop table <table_name>}
    rule insert {:i insert <table_name>}
    rule update {:i update <table_name>}
    rule delete {:i delete <table_name>}
    rule select {:i select from <table_name>}
    token table_name { <alpha><alnum>+ }
    token column_name { <alpha><alnum>+ }
    token column_type {:i int|char|numeric}
}

class FakeDBD::CSV::SQL_Actions {
    method create_table(Match $m) { print "doing CREATE TABLE ";
        say ~$m<table_name> }
    method drop_table(Match $m) { print "doing DROP TABLE ";
        say ~$m<table_name> }
    method insert(Match $m) { say "doing INSERT" }
    method update(Match $m) { say "doing UPDATE" }
    method delete(Match $m) { say "doing DELETE" }
    method select(Match $m) { say "doing SELECT" }
}

class FakeDBD::CSV::StatementHandle does FakeDBD::StatementHandle {
    has $!RaiseError;
    has $!sql_command;
    method execute(*@params is copy) {
        #say "executing: $!sql_command";
        my $result = FakeDBD::CSV::SQL.parse( $!sql_command,
                        :actions( FakeDBD::CSV::SQL_Actions ) );
        return Bool::True;
    }
}

class FakeDBD::CSV::Connection does FakeDBD::Connection {
    has $!RaiseError;
    method prepare( Str $sql_command ) {
        my $statement_handle;
        $statement_handle = FakeDBD::CSV::StatementHandle.bless(
            FakeDBD::CSV::StatementHandle.CREATE(),
            RaiseError => $!RaiseError,
            sql_command => $sql_command
        );
        return $statement_handle;
    }
}

class FakeDBD::CSV:auth<mberends>:ver<0.0.1> {

    has $.Version = 0.01;

    method connect( Str $user, Str $password, Str $params, $RaiseError ) {
        #warn "in FakeDBD::CSV.connect('$user',*,'$params')";
        my $connection;
        $connection = FakeDBD::CSV::Connection.bless(
            FakeDBD::CSV::Connection.CREATE(),
            RaiseError => $RaiseError
        );
        return $connection;
    }
}

#warn "module FakeDBD::CSV.pm has loaded";

=begin pod

=head1 SEE ALSO
The Perl 5 L<doc:DBD::CSV>.

=end pod
