# DBDish::Oracle.pm6

use NativeCall;
use DBDish;     # roles for drivers

my constant lib = 'libclntsh';

#module DBDish:auth<mberends>:ver<0.0.1>;

#------------ Oracle library to NativeCall data type mapping ------------

constant sb2            = int16;
constant sb4            = int32;
constant sb8            = int64;
constant size_t         = long;
constant sword          = int32;
constant ub2            = uint16;
constant ub4            = uint32;

constant OCIBind        = Pointer;
constant OCIDefine      = Pointer;
constant OCIEnv         = Pointer;
constant OCIError       = Pointer;
constant OCISnapshot    = Pointer;
constant OCIStmt        = Pointer;
constant OCISvcCtx      = Pointer;
constant OraText        = Str;

#------------ Oracle library functions in alphabetical order ------------

sub OCIEnvNlsCreate (
        CArray[OCIEnv] $envhpp,
        ub4            $mode,
        Pointer        $ctxp,
        Pointer        $malocfp,
        Pointer        $ralocfp,
        Pointer        $mfreefp,
        size_t         $xtramemsz,
        CArray[Pointer] $usrmempp,
        ub2            $charset,
        ub2            $ncharset,
    )
    returns sword
    is native(lib)
    { ... }

sub OCIErrorGet (
        Pointer       $hndlp,
        ub4           $recordno,
        OraText       $sqlstate,
        CArray[sb4]   $errcodep,
        CArray[int8]  $bufp,
        ub4           $bufsiz,
        ub4           $type,
    )
    returns sword
    is native(lib)
    { ... }

sub OCIHandleAlloc (
        Pointer           $parenth,
        CArray[Pointer]   $hndlpp,
        ub4               $type,
        size_t            $xtramem_sz,
        CArray[Pointer]   $usrmempp,
    )
    returns sword
    is native(lib)
    { ... }

sub OCILogon2 (
        OCIEnv              $envhp,
        OCIError            $errhp,
        CArray[OCISvcCtx]   $svchp,
        OraText             $username is encoded('utf8'),
        ub4                 $uname_len,
        OraText             $password is encoded('utf8'),
        ub4                 $passwd_len,
        OraText             $dbname is encoded('utf8'),
        ub4                 $dbname_len,
        ub4                 $mode,
    )
    returns sword
    is native(lib)
    { ... }

sub OCILogoff (
        OCISvcCtx   $svchp,
        OCIError    $errhp,
    )
    returns sword
    is native(lib)
    { ... }

sub OCIStmtPrepare2 (
        OCISvcCtx           $svchp,
        CArray[OCIStmt]     $stmthp,
        OCIError            $errhp,
        OraText             $stmttext is encoded('utf8'),
        ub4                 $stmt_len,
        OraText             $key is encoded('utf8'),
        ub4                 $keylen,
        ub4                 $language,
        ub4                 $mode,
    )
    returns sword
    is native(lib)
    { ... }

sub OCIAttrGet_Str(
        Pointer[void]           $trgthndlp,
        ub4                     $trghndltyp,
        CArray[Pointer[Str]]    $attributep is encoded('utf8'),
        CArray[ub4]             $sizep,
        ub4                     $attrtype,
        OCIError                $errhp,
    )
    returns sword
    is native(lib)
    is symbol('OCIAttrGet')
    { ... }

sub OCIAttrGet_ub2 (
        Pointer[void]   $trgthndlp,
        ub4             $trghndltyp,
        ub2             $attributep is rw,
        CArray[ub4]     $sizep,
        ub4             $attrtype,
        OCIError        $errhp,
    )
    returns sword
    is native(lib)
    is symbol('OCIAttrGet')
    { ... }

sub OCIAttrGet_ub4 (
        Pointer[void]   $trgthndlp,
        ub4             $trghndltyp,
        ub4             $attributep is rw,
        CArray[ub4]     $sizep,
        ub4             $attrtype,
        OCIError        $errhp,
    )
    returns sword
    is native(lib)
    is symbol('OCIAttrGet')
    { ... }

# strings
sub OCIBindByName_Str (
        OCIStmt             $stmtp,
        CArray[OCIBind]     $bindpp,
        #CArray              $bindpp,
        #OCIBind             $bindpp is rw,
        OCIError            $errhp,
        OraText             $placeholder is encoded('utf8'),
        sb4                 $placeh_len,
        Str                 $valuep is encoded('utf8'),
        sb4                 $value_sz,
        ub2                 $dty,
        sb2                 $indp is rw,
        Pointer[ub2]        $alenp,
        Pointer[ub2]        $rcodep,
        ub4                 $maxarr_len,
        Pointer[ub4]        $curelep,
        ub4                 $mode,
    )
    returns sword
    is native(lib)
    is symbol('OCIBindByName')
    { ... }

# ints
sub OCIBindByName_Int (
        OCIStmt             $stmtp,
        CArray[OCIBind]     $bindpp,
        #CArray              $bindpp,
        #OCIBind             $bindpp is rw,
        OCIError            $errhp,
        OraText             $placeholder is encoded('utf8'),
        sb4                 $placeh_len,
        long                $valuep is rw,
        sb4                 $value_sz,
        ub2                 $dty,
        sb2                 $indp is rw,
        Pointer[ub2]        $alenp,
        Pointer[ub2]        $rcodep,
        ub4                 $maxarr_len,
        Pointer[ub4]        $curelep,
        ub4                 $mode,
    )
    returns sword
    is native(lib)
    is symbol('OCIBindByName')
    { ... }

# floats
sub OCIBindByName_Real (
        OCIStmt             $stmtp,
        CArray[OCIBind]     $bindpp,
        #CArray              $bindpp,
        #OCIBind             $bindpp is rw,
        OCIError            $errhp,
        OraText             $placeholder is encoded('utf8'),
        sb4                 $placeh_len,
        num64               $valuep is rw,
        sb4                 $value_sz,
        ub2                 $dty,
        sb2                 $indp is rw,
        Pointer[ub2]        $alenp,
        Pointer[ub2]        $rcodep,
        ub4                 $maxarr_len,
        Pointer[ub4]        $curelep,
        ub4                 $mode,
    )
    returns sword
    is native(lib)
    is symbol('OCIBindByName')
    { ... }

sub OCIBindByPos2_Str (
        OCIStmt             $stmtp,
        CArray[OCIDefine]   $defnpp,
        OCIError            $errhp,
        ub4                 $position,
        Str                 $valuep is encoded('utf8'),
        sb8                 $value_sz,
        ub2                 $dty,
        sb2                 $indp is rw, # sb2 only for non-array binds
        ub4                 $rlenp is rw,
        ub2                 $rcodep is rw,
        ub4                 $mode,
    )
    returns sword
    is native(lib)
    is symbol('OCIBindByPos2')
    { ... }

sub OCIBindByPos2_Int (
        OCIStmt             $stmtp,
        CArray[OCIDefine]   $defnpp,
        OCIError            $errhp,
        ub4                 $position,
        long                $valuep is rw,
        sb8                 $value_sz,
        ub2                 $dty,
        sb2                 $indp is rw, # sb2 only for non-array binds
        ub4                 $rlenp is rw,
        ub2                 $rcodep is rw,
        ub4                 $mode,
    )
    returns sword
    is native(lib)
    is symbol('OCIBindByPos2')
    { ... }

sub OCIBindByPos2_Real (
        OCIStmt             $stmtp,
        CArray[OCIDefine]   $defnpp,
        OCIError            $errhp,
        ub4                 $position,
        num64               $valuep is rw,
        sb8                 $value_sz,
        ub2                 $dty,
        sb2                 $indp is rw, # sb2 only for non-array binds
        ub4                 $rlenp is rw,
        ub2                 $rcodep is rw,
        ub4                 $mode,
    )
    returns sword
    is native(lib)
    is symbol('OCIBindByPos2')
    { ... }

sub OCIStmtExecute (
        OCISvcCtx       $svchp,
        OCIStmt         $stmtp,
        OCIError        $errhp,
        ub4             $iters,
        ub4             $rowoff,
        OCISnapshot     $snap_in,
        OCISnapshot     $snap_out,
        ub4             $mode,
    )
    returns sword
    is native(lib)
    { ... }

sub OCIParamGet (
        Pointer                 $hndlp,
        ub4                     $htype,
        OCIError                $errhp,
        CArray[Pointer]         $parmdpp,
        ub4                     $pos,
    )
    returns sword
    is native(lib)
    { ... }

sub OCIStmtFetch2 (
        OCIStmt     $stmtp,
        OCIError    $errhp,
        ub4         $nrows,
        ub2         $orientation,
        sb4         $fetchOffset,
        ub4         $mode,
    )
    returns sword
    is native(lib)
    { ... }

#-----

my ub4 constant OCI_DEFAULT     = 0;
constant OCI_THREADED           = 1;
constant OCI_COMMIT_ON_SUCCESS  = 0x00000020;

constant OCI_SUCCESS            = 0;
constant OCI_ERROR              = -1;

constant OCI_HTYPE_ENV          = 1;
constant OCI_HTYPE_ERROR        = 2;
constant OCI_HTYPE_STMT         = 4;

constant OCI_DTYPE_PARAM        = 53;

constant OCI_LOGON2_STMTCACHE   = 4;

constant OCI_NTV_SYNTAX         = 1;

constant OCI_ATTR_DATA_TYPE     = 2;
constant OCI_ATTR_NAME          = 4;
constant OCI_ATTR_ROW_COUNT     = 9;
constant OCI_ATTR_PARAM_COUNT   = 18;
constant OCI_ATTR_STMT_TYPE     = 24;

constant OCI_STMT_UNKNOWN       = 0;
constant OCI_STMT_SELECT        = 1;
constant OCI_STMT_UPDATE        = 2;
constant OCI_STMT_DELETE        = 3;
constant OCI_STMT_INSERT        = 4;
constant OCI_STMT_CREATE        = 5;
constant OCI_STMT_DROP          = 6;
constant OCI_STMT_ALTER         = 7;
constant OCI_STMT_BEGIN         = 8;
constant OCI_STMT_DECLARE       = 9;
constant OCI_STMT_CALL          = 10;

constant SQLT_CHR               = 1;
constant SQLT_NUM               = 2;
constant SQLT_INT               = 3;
constant SQLT_FLT               = 4;

# SELECT NLS_CHARSET_ID('AL32UTF8') FROM dual;
constant AL32UTF8               = 873;

sub get_errortext(OCIError $handle, $handle_type = OCI_HTYPE_ERROR) {
    my @errorcodep := CArray[sb4].new;
    @errorcodep[0] = 0;
    my @errortextp := CArray[int8].new;
    @errortextp[$_] = 0
        for ^512;

    OCIErrorGet( $handle, 1, OraText, @errorcodep, @errortextp, 512, $handle_type );
    my @errortextary;
    @errortextary[$_] = @errortextp[$_]
        for ^512;
    return Buf.new(@errortextary).decode();
}

#sub status-is-ok($status) { $status ~~ 0..4 }

#-----------------------------------------------------------------------

my grammar OracleTokenizer {
    token TOP {
        ^
        (
            | <normal>
            | <placeholder>
            | <single_quote>
            | <double_quote>
        )*
        $
    }
    token normal { <-[?"']>+ }
    token placeholder { '?' }
    token double_quote_normal { <-[\\"]>+ }
    token double_quote_escape { [\\ . ]+ }
    token double_quote {
        \"
        [
            | <.double_quote_normal>
            | <.double_quote_escape>
        ]*
        \"
    }
    token single_quote_normal { <-['\\]>+ }
    token single_quote_escape { [ \'\' || \\ . ]+ }
    token single_quote {
        \'
        [
            | <.single_quote_normal>
            | <.single_quote_escape>
        ]*
        \'
    }
}

my class OracleTokenizer::Actions {
    has $.counter = 0;
    method TOP($/) {
        make $0.map({.values[0].ast}).join;
    }
    method normal($/)       { make $/.Str }
    # replace each ? placeholder with a named one
    method placeholder($/)  { make ':p' ~ $!counter++ }
    method single_quote($/) { make $/.Str }
    method double_quote($/) { make $/.Str }
}


class DBDish::Oracle::StatementHandle does DBDish::StatementHandle {
    has $!statement;
    has $!statementtype;
    has $!svchp;
    has $!errhp;
    has $!stmthp;
#    has $!param_count;
    has $.dbh;
    has $!result;
#    has $!affected_rows;
#    has @!column_names;
    has Int $!row_count;
#    has $!current_row = 0;
#
#    method !handle-errors {
#        my $status = PQresultStatus($!result);
#        if status-is-ok($status) {
#            self!reset_errstr;
#            return True;
#        }
#        else {
#            self!set_errstr(PQresultErrorMessage($!result));
#            die self.errstr if $.RaiseError;
#            return Nil;
#        }
#    }
#
#    method !munge_statement {
#        my $count = 0;
#        $!statement.subst(:g, '?', { '$' ~ ++$count});
#    }
#
    submethod BUILD(:$!statement!, :$!statementtype!, :$!svchp!, :$!errhp!, :$!stmthp!, :$!dbh!) { }

    method execute(*@params is copy) {
#        $!current_row = 0;
#        die "Wrong number of arguments to method execute: got @params.elems(), expected $!param_count" if @params != $!param_count;

        # bind placeholder values
        for @params.kv -> $k, $v {
            my @bindpp := CArray[OCIBind].new;
            @bindpp[0]  = OCIBind;
            #my OCIBind $bindpp;

            my OraText $placeholder = ":p$k";
            my sb4 $placeh_len = $placeholder.encode('utf8').bytes;

            my sb4 $value_sz;
            my ub2 $dty;
            # -1 tells OCI to set the value to NULL
            my sb2 $indp = $v.chars == 0
                ?? -1
                !! 0;
            my Pointer[ub2] $alenp;
            my Pointer[ub2] $rcodep;
            my ub4 $maxarr_len  = 0;
            my Pointer[ub4] $curelep;
            my $errcode;
            if $v ~~ Int {
                $dty = SQLT_INT;
                my long $valuep = $v;
                # see multi sub defition for the C data type
                $value_sz = nativesizeof(long);
                #warn "binding '$placeholder' ($placeh_len): '$valuep' ($value_sz) as OCI type '$dty' Perl type '$v.^name()' NULL '$indp'\n";
                #$method = &OCIBindByName_Int;
                $errcode = OCIBindByName_Int(
                    $!stmthp,
                    @bindpp,
                    $!errhp,
                    $placeholder,
                    $placeh_len,
                    $valuep,
                    $value_sz,
                    $dty,
                    $indp,
                    $alenp,
                    $rcodep,
                    $maxarr_len,
                    $curelep,
                    OCI_DEFAULT,
                );
            }
            elsif $v ~~ Real {
                $dty = SQLT_FLT;
                my num64 $valuep = $v.Num;
                # see multi sub defition for the C data type
                $value_sz = nativesizeof(num64);
                #warn "binding '$placeholder' ($placeh_len): '$valuep' ($value_sz) as OCI type '$dty' Perl type '$v.^name()' NULL '$indp'\n";
                #$method = &OCIBindByName_Real;
                $errcode = OCIBindByName_Real(
                    $!stmthp,
                    @bindpp,
                    $!errhp,
                    $placeholder,
                    $placeh_len,
                    $valuep,
                    $value_sz,
                    $dty,
                    $indp,
                    $alenp,
                    $rcodep,
                    $maxarr_len,
                    $curelep,
                    OCI_DEFAULT,
                );
            }
            elsif $v ~~ Str {
                $dty = SQLT_CHR;
                my Str $valuep = $v;
                $value_sz = $v.encode('utf8').bytes;
                #warn "binding '$placeholder' ($placeh_len): '$valuep' ($value_sz) as OCI type '$dty' Perl type '$v.^name()' NULL '$indp'\n";
                #$method = &OCIBindByName_Str;
                $errcode = OCIBindByName_Str(
                    $!stmthp,
                    @bindpp,
                    $!errhp,
                    $placeholder,
                    $placeh_len,
                    $valuep,
                    $value_sz,
                    $dty,
                    $indp,
                    $alenp,
                    $rcodep,
                    $maxarr_len,
                    $curelep,
                    OCI_DEFAULT,
                );
            }
            else {
                die "unhandled type: $v";
            }
            if $errcode ne OCI_SUCCESS {
                my $errortext = get_errortext($!errhp);
                die "bind of param '$placeholder' with value '$v' of statement '$!statement' failed ($errcode): '$errortext'";
            }
            #warn "bind of param '$placeholder' with value '$v' succeeded";
        }

        my ub4 $iters = $!statementtype eq OCI_STMT_SELECT ?? 0 !! 1;
        my ub4 $rowoff = 0;

        my $errcode = OCIStmtExecute(
            $!svchp,
            $!stmthp,
            $!errhp,
            $iters,
            $rowoff,
            Pointer,
            Pointer,
            $!dbh.AutoCommit ?? OCI_COMMIT_ON_SUCCESS !! OCI_DEFAULT,
        );
        if $errcode ne OCI_SUCCESS {
            my $errortext = get_errortext($!errhp);
            # TODO: handle OCI_SUCCESS_WITH_INFO
            die "execute of '$!statement' failed ($errcode): '$errortext'";
        }
        #warn "successfully executed $!dbh.AutoCommit()";

        # for DDL statements, no further steps are necessary
        # if $!statementtype ~~ ( OCI_STMT_CREATE, OCI_STMT_DROP, OCI_STMT_ALTER );

        return self.rows;
    }

    # do() and execute() return the number of affected rows directly or:
    # rows() is called on the statement handle $sth.
    method rows() {
        # DDL statements always return 0E0
        return "0E0"
            if $!statementtype ~~ ( OCI_STMT_CREATE, OCI_STMT_DROP, OCI_STMT_ALTER );

        unless defined $!row_count {
            my ub4 $row_count;
            my $errcode = OCIAttrGet_ub4($!stmthp, OCI_HTYPE_STMT, $row_count, Pointer, OCI_ATTR_ROW_COUNT, $!errhp);
            if $errcode ne OCI_SUCCESS {
                my $errortext = get_errortext($!errhp);
                die "statement type get failed ($errcode): '$errortext'";
            }
            $!row_count = $row_count;
        }

        if defined $!row_count {
            return ($!row_count == 0) ?? "0E0" !! $!row_count;
        }
    }

    method fetchrow() {
        my @row;
        for 1 .. self.field_count -> $field_index {
            my @parmdpp := CArray[Pointer].new;
            @parmdpp[0]  = Pointer;
            my $errcode = OCIParamGet($!stmthp, OCI_HTYPE_STMT, $!errhp, @parmdpp, $field_index);
            if $errcode ne OCI_SUCCESS {
                my $errortext = get_errortext($!errhp);
                die "param get failed ($errcode): '$errortext'";
            }

            # retrieve the data type
            my ub2 $dty;
            $errcode = OCIAttrGet_ub2(@parmdpp[0], OCI_DTYPE_PARAM, $dty, Pointer, OCI_ATTR_DATA_TYPE, $!errhp);
            #warn "DATA TYPE: $dty";

            # retrieve the column name
            my CArray[Pointer] $col_namepp.=new;
            $col_namepp[0] = Pointer[Str].new;

            my @col_name_len := CArray[ub4].new;
            @col_name_len[0] = 0;

            $errcode = OCIAttrGet_Str(@parmdpp[0], OCI_DTYPE_PARAM, $col_namepp, @col_name_len, OCI_ATTR_NAME, $!errhp);
            my $col_name = nativecast(Str, $col_namepp[0]);
            # FIXME: NativeCall fails currently 2015.07.2
            #say $col_namepp[0].deref;

            # not needed, NativeCall can handle null-terminated strings itself
            #my $col_name_len = @col_name_len[0];

            #warn "COLUMN: $col_name";
            # bind select list items
            my CArray[OCIDefine] $defnpp.=new;
            $defnpp[0] = OCIDefine.new;
            my sb2 $indp;
            my ub4 $rlenp;
            my ub2 $rcodep;
            if $dty == SQLT_CHR {
                warn "binding $field_index '$col_name' as CHR";
                my Str $valuep;
                @row.push($valuep);
                my sb8 $value_sz;# = $valuep.encode('utf8').bytes;
                $errcode = OCIBindByPos2_Str(
                    $!stmthp,
                    $defnpp,
                    $!errhp,
                    $field_index,
                    $valuep,
                    $value_sz,
                    $dty,
                    $indp,
                    $rlenp,
                    $rcodep,
                    OCI_DEFAULT,
                );
            }
            elsif $dty == SQLT_INT, SQLT_NUM {
                warn "binding $field_index '$col_name' as INT|NUM";
                my long $valuep;
                @row.push($valuep);
                my sb8 $value_sz = nativesizeof(long);
                $errcode = OCIBindByPos2_Int(
                    $!stmthp,
                    $defnpp,
                    $!errhp,
                    $field_index,
                    $valuep,
                    $value_sz,
                    $dty,
                    $indp,
                    $rlenp,
                    $rcodep,
                    OCI_DEFAULT,
                );
            }
            elsif $dty == SQLT_FLT {
                warn "binding $field_index '$col_name' as FLT";
                my num64 $valuep;
                @row.push($valuep);
                my sb8 $value_sz = nativesizeof(num64);
                $errcode = OCIBindByPos2_Real(
                    $!stmthp,
                    $defnpp,
                    $!errhp,
                    $field_index,
                    $valuep,
                    $value_sz,
                    $dty,
                    $indp,
                    $rlenp,
                    $rcodep,
                    OCI_DEFAULT,
                );
            }
            else {
                die "unhandled type: $dty";
            }
        }

        my $errcode = OCIStmtFetch2($!stmthp, $!errhp, 1, OCI_DEFAULT, 0, OCI_DEFAULT);
        say @row.perl;
        if $errcode ne OCI_SUCCESS {
            my $errortext = get_errortext($!errhp);
            die "fetch failed ($errcode): '$errortext'";
        }


#        return if $!current_row >= $!row_count;
#
#        if defined $!result {
#            self!reset_errstr;

#            for ^$!field_count {
#                @row_array.push(PQgetvalue($!result, $!current_row, $_));
#            }
#            $!current_row++;
#            self!handle-errors;
#
#            if ! @row_array { self.finish; }
#        }
        return @row;
    }

    method field_count {
        # cache field count
        state Int $field_count;
        # TODO: what should be returned before the statement has been executed?
        unless $field_count.defined {
            # TODO: because 2015.07.2: 'Natively typed state variables not yet implemented'
            my ub4 $field_count_native;
            my $errcode = OCIAttrGet_ub4($!stmthp, OCI_HTYPE_STMT, $field_count_native,
                                  Pointer, OCI_ATTR_PARAM_COUNT, $!errhp);
            $field_count = $field_count_native;
            # FIXME: error handling
        }
        return $field_count;
    }

#    method column_names {
#        $!field_count = PQnfields($!result);
#        unless @!column_names {
#            for ^$!field_count {
#                my $column_name = PQfname($!result, $_);
#                @!column_names.push($column_name);
#            }
#        }
#        @!column_names
#    }
#
#    # for debugging only so far
#    method column_oids {
#        $!field_count = PQnfields($!result);
#        my @res;
#        for ^$!field_count {
#            @res.push: PQftype($!result, $_);
#        }
#        @res;
#    }
#
#    method fetchall_hashref(Str $key) {
#        my %results;
#
#        return if $!current_row >= $!row_count;
#
#        while my $row = self.fetchrow_hashref {
#            %results{$row{$key}} = $row;
#        }
#
#        my $results_ref = %results;
#        return $results_ref;
#    }

    method finish() {
        if defined($!result) {
            #PQclear($!result);
            #$!result       = Any;
            #@!column_names = ();
        }
        return Bool::True;
    }

#    method !get_row {
#        my @data;
#        for ^$!field_count {
#            @data.push(PQgetvalue($!result, $!current_row, $_));
#        }
#        $!current_row++;
#
#        return @data;
#    }
}

class DBDish::Oracle::Connection does DBDish::Connection {
    has $!svchp;
    has $!errhp;
    has $.AutoCommit is rw;
    has $.in_transaction is rw;
    submethod BUILD(:$!svchp!, :$!errhp!, :$!AutoCommit = 1) { }

    method prepare(Str $statement, $attr?) {
        my $oracle_statement = DBDish::Oracle::oracle-replace-placeholder($statement);
        my @stmthpp := CArray[OCIStmt].new;
        @stmthpp[0]  = OCIStmt;
        my $errcode = OCIStmtPrepare2(
                $!svchp,
                @stmthpp,
                $!errhp,
                $oracle_statement,
                $oracle_statement.encode('utf8').bytes,
                OraText,
                0,
                OCI_NTV_SYNTAX,
                OCI_DEFAULT,
            );
        if $errcode ne OCI_SUCCESS {
            my $errortext = get_errortext($!errhp);
            die "prepare failed ($errcode): '$errortext'";
#            die self.errstr if $.RaiseError;
#            return Nil;
        }
        my $stmthp = @stmthpp[0];

        my ub2 $statementtype;
        $errcode = OCIAttrGet_ub2($stmthp, OCI_HTYPE_STMT, $statementtype, Pointer, OCI_ATTR_STMT_TYPE, $!errhp);
        if $errcode ne OCI_SUCCESS {
            my $errortext = get_errortext($!errhp);
            die "statement type get failed ($errcode): '$errortext'";
        }

#        my $info = PQdescribePrepared($!pg_conn, $statement_name);
#        my $param_count = PQnparams($info);

        my $statement_handle = DBDish::Oracle::StatementHandle.bless(
            # TODO: pass the original or the Oracle statment here?
            statement => $oracle_statement,
            #:$statement,
            :$statementtype,
            :$!svchp,
            :$!errhp,
            :$stmthp,
            #:$.RaiseError,
            :dbh(self),
        );
        return $statement_handle;
    }

    method do(Str $statement, *@bind is copy) {
        my $sth = self.prepare($statement);
        return $sth.execute(@bind);
    }

#    method selectrow_arrayref(Str $statement, $attr?, *@bind is copy) {
#        my $sth = self.prepare($statement, $attr);
#        $sth.execute(@bind);
#        return $sth.fetchrow_arrayref;
#    }
#
#    method selectrow_hashref(Str $statement, $attr?, *@bind is copy) {
#        my $sth = self.prepare($statement, $attr);
#        $sth.execute(@bind);
#        return $sth.fetchrow_hashref;
#    }
#
#    method selectall_arrayref(Str $statement, $attr?, *@bind is copy) {
#        my $sth = self.prepare($statement, $attr);
#        $sth.execute(@bind);
#        return $sth.fetchall_arrayref;
#    }
#
#    method selectall_hashref(Str $statement, Str $key, $attr?, *@bind is copy) {
#        my $sth = self.prepare($statement, $attr);
#        $sth.execute(@bind);
#        return $sth.fetchall_hashref($key);
#    }
#
#    method selectcol_arrayref(Str $statement, $attr?, *@bind is copy) {
#        my @results;
#
#        my $sth = self.prepare($statement, $attr);
#        $sth.execute(@bind);
#        while (my $row = $sth.fetchrow_arrayref) {
#            @results.push($row[0]);
#        }
#
#        my $aref = @results;
#        return $aref;
#    }
#
    method commit {
        if $!AutoCommit {
            warn "Commit ineffective while AutoCommit is on";
            return;
        };
        self.do("COMMIT");
        $.in_transaction = 0;
    }

    method rollback {
        if $!AutoCommit {
            warn "Rollback ineffective while AutoCommit is on";
            return;
        };
        self.do("ROLLBACK");
        $.in_transaction = 0;
    }

#    method ping {
#        PQstatus($!pg_conn) == CONNECTION_OK
#    }

    method disconnect() {
        OCILogoff($!svchp, $!errhp);
        True;
    }
}

class DBDish::Oracle:auth<mberends>:ver<0.0.1> {

    our sub oracle-replace-placeholder(Str $query) is export {
        OracleTokenizer.parse($query, :actions(OracleTokenizer::Actions.new))
            and $/.ast;
    }

    has $.Version = 0.01;
    #has $!errstr;
    #method !errstr() is rw { $!errstr }
    #method errstr() { $!errstr }

    #sub quote-and-escape($s) {
    #    "'" ~ $s.trans([q{'}, q{\\]}] => [q{\\\'}, q{\\\\}])
    #        ~ "'"
    #}

#------------------ methods to be called from DBIish ------------------
    method connect(*%params) {
        # TODO: the dbname from tnsnames.ora includes the host and port config
        #my $host     = %params<host>     // 'localhost';
        #my $port     = %params<port>     // 1521;
        my $database = %params<database> // die 'Missing <database> config';
        my $username = %params<username> // die 'Missing <username> config';
        my $password = %params<password> // die 'Missing <password> config';

        # create the environment handle
        my @envhpp := CArray[Pointer].new;
        @envhpp[0]  = Pointer;
        my Pointer $ctxp,

        my sword $errcode = OCIEnvNlsCreate(
            @envhpp,
            OCI_DEFAULT,
            $ctxp,
            Pointer,
            Pointer,
            Pointer,
            0,
            Pointer,
            AL32UTF8,
            AL32UTF8,
        );

        # fetch environment handle from pointer
        my $envhp = @envhpp[0];

        if $errcode ne OCI_SUCCESS {
            my $errortext = get_errortext( $envhp, OCI_HTYPE_ENV );
            die "OCIEnvNlsCreate failed: '$errortext'";
        }

        # allocate the error handle
        my @errhpp := CArray[Pointer].new;
        @errhpp[0]  = Pointer;
        $errcode = OCIHandleAlloc($envhp, @errhpp, OCI_HTYPE_ERROR, 0, Pointer );
        if $errcode ne OCI_SUCCESS {
            die "OCIHandleAlloc failed: '$errcode'";
        }
        my $errhp = @errhpp[0];

        my @svchp := CArray[OCISvcCtx].new;
        @svchp[0]  = OCISvcCtx;

        $errcode = OCILogon2(
            $envhp,
            $errhp,
            @svchp,
            $username,
            $username.encode('utf8').bytes,
            $password,
            $password.encode('utf8').bytes,
            $database,
            $database.encode('utf8').bytes,
            OCI_LOGON2_STMTCACHE,
        );
        if $errcode ne OCI_SUCCESS {
            my $errortext = get_errortext($errhp);
            die "OCILogon2 failed: '$errortext'";
        }
        my $svchp = @svchp[0];

        my $connection = DBDish::Oracle::Connection.bless(
                :$svchp,
                :$errhp,
                :AutoCommit(%params<AutoCommit>),
                #:RaiseError(%params<RaiseError>),
            );
        return $connection;
    }
}

=begin pod

=head1 DESCRIPTION
# 'zavolaj' is a Native Call Interface for Rakudo/Parrot. 'DBIish' and
# 'DBDish::Oracle' are Perl 6 modules that use 'zavolaj' to use the
# standard libclntsh library.  There is a long term Parrot based
# project to develop a new, comprehensive DBI architecture for Parrot
# and Perl 6.  DBIish is not that, it is a naive rewrite of the
# similarly named Perl 5 modules.  Hence the 'Mini' part of the name.

=head1 CLASSES
The DBDish::Oracle module contains the same classes and methods as every
database driver.  Therefore read the main documentation of usage in
L<doc:DBIish> and internal architecture in L<doc:DBDish>.  Below are
only notes about code unique to the DBDish::Oracle implementation.

=head1 SEE ALSO
The Oracle OCI Documentation, C Library.
L<http://docs.oracle.com/cd/E11882_01/appdev.112/e10646/oci02bas.htm#LNOCI16208>

=end pod

