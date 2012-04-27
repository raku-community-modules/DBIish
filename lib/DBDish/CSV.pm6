# DBDish/CSV.pm6

use DBDish;

grammar DBDish::CSV::SQL {
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

class DBDish::CSV::SQL::actions {
    method create_table(Match $m) {
        print "doing CREATE TABLE ";
        my $table_name = ~$m<table_name>;
        say $table_name;
    }
    method drop_table(Match $m) {
        print "doing DROP TABLE ";
        my $table_name = ~$m<table_name>;
        say $table_name;
    }
    method insert(Match $m) { say "doing INSERT" }
    method update(Match $m) { say "doing UPDATE" }
    method delete(Match $m) { say "doing DELETE" }
    method select(Match $m) { say "doing SELECT" }
}

class DBDish::CSV::StatementHandle does DBDish::StatementHandle {
    has $!RaiseError;
    has $!sql_command;
    method execute(*@params is copy) {
        #say "executing: $!sql_command";
        my Match $sql_match = DBDish::CSV::SQL.parse( $!sql_command,
                        :actions( DBDish::CSV::SQL::actions ) );
        say "execute " ~ $sql_match.perl;
        return Bool::True;
    }
    method rows() {
        return 0;
    }
    method fetchall_arrayref() {
        return [];
    }
}

class DBDish::CSV::Connection does DBDish::Connection {
    has $!RaiseError;
    method prepare( Str $sql_command ) {
        my $statement_handle;
        $statement_handle = DBDish::CSV::StatementHandle.bless(
            DBDish::CSV::StatementHandle.CREATE(),
            RaiseError => $!RaiseError,
            sql_command => $sql_command
        );
        return $statement_handle;
    }
}

class DBDish::CSV:auth<mberends>:ver<0.0.1> {

    has $.Version = 0.01;

    method connect(:$RaiseError ) {
        #warn "in DBDish::CSV.connect('$user',*,'$params')";
        my $connection = DBDish::CSV::Connection.bless(
            DBDish::CSV::Connection.CREATE(),
            :$RaiseError
        );
        return $connection;
    }
}

=begin pod

=head1 SEE ALSO
The Perl 5 L<doc:DBD::CSV>.

=end pod
