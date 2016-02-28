use v6;
no precompilation;
need DBDish;

unit class DBDish::Oracle::StatementHandle does DBDish::StatementHandle;
use NativeCall;
use DBDish::Oracle::Native;

has $!statement;
has $!statementtype;
has $!svchp;
has $!errhp;
has $!stmthp;
has Int $!state = 0; # execute (1) has to happen before fetch (2)
#    has $!param_count;
has $.dbh;
has $!result;
#    has $!affected_rows;
has @!column_names;
has Int $!field_count;
has %!parmd;
has @!out-binds;
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

    my sb4 $value_sz;

    my ub2 $alen = 0;
    my $alenp = Pointer[ub2].new($alen);
    my ub2 $rcode = 0;
    my $rcodep = Pointer[ub2].new($rcode);
    my ub4 $maxarr_len = 0;
    my ub4 $curele = 0;
    my $curelep = Pointer[ub4].new($curele);

    my @in-binds;

    # bind placeholder values
    for @params.kv -> $k, $v {
        my $bindpp = CArray[OCIBind].new;
        $bindpp[0] = OCIBind;

        my OraText $placeholder = ":p$k";
        my sb4 $placeh_len = $placeholder.encode('utf8').bytes;

        # -1 tells OCI to set the value to NULL
        my sb2 $ind = $v.chars == 0
            ?? -1
            !! 0;
        my $indp = CArray[sb2].new;
        $indp[0] = $ind;

        my $errcode;
        given $v {
            when Int {
                my long $value = $v;
                my $valuep = CArray[long].new;
                $valuep[0] = $value;
                @in-binds.push($bindpp, $valuep, $indp);
                # see multi sub definition for the C data type
                $value_sz = nativesizeof(long);
                #warn "binding '$placeholder' ($placeh_len): '$value' ($value_sz) as OCI type 'SQLT_INT' Perl type '$v.^name()' NULL '$ind'\n";
                $errcode = OCIBindByName_Int(
                    $!stmthp,
                    $bindpp,
                    $!errhp,
                    $placeholder,
                    $placeh_len,
                    $valuep,
                    $value_sz,
                    SQLT_INT,
                    $indp,
                    $alenp,
                    $rcodep,
                    $maxarr_len,
                    $curelep,
                    OCI_DEFAULT,
                );
            }
            # match after Int to handle Num and Rat and all other (custom)
            # types that do Real
            when Real {
                my num64 $value = $v.Num;
                my $valuep = CArray[num64].new;
                $valuep[0] = $value;
                @in-binds.push($bindpp, $valuep, $indp);
                # see multi sub definition for the C data type
                $value_sz = nativesizeof(num64);
                #warn "binding '$placeholder' ($placeh_len): '$valuep' ($value_sz) as OCI type 'SQLT_FLT' Perl type '$v.^name()' NULL '$ind'\n";
                $errcode = OCIBindByName_Real(
                    $!stmthp,
                    $bindpp,
                    $!errhp,
                    $placeholder,
                    $placeh_len,
                    $valuep,
                    $value_sz,
                    SQLT_FLT,
                    $indp,
                    $alenp,
                    $rcodep,
                    $maxarr_len,
                    $curelep,
                    OCI_DEFAULT,
                );
            }
            when Str {
                my Str $valuep = $v;
                explicitly-manage($valuep);
                @in-binds.push($bindpp, $valuep, $indp);
                $value_sz = $v.encode('utf8').bytes;
                #warn "binding '$placeholder' ($placeh_len): '$valuep' ($value_sz) as OCI type 'SQLT_CHR' Perl type '$v.^name()' NULL '$ind'\n";
                $errcode = OCIBindByName_Str(
                    $!stmthp,
                    $bindpp,
                    $!errhp,
                    $placeholder,
                    $placeh_len,
                    $valuep,
                    $value_sz,
                    SQLT_CHR,
                    $indp,
                    $alenp,
                    $rcodep,
                    $maxarr_len,
                    $curelep,
                    OCI_DEFAULT,
                );
            }
            default {
                die "unhandled type: {$v.^name}";
            }
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
    # TODO: handle OCI_NO_DATA
    if $errcode ne OCI_SUCCESS {
        my $errortext = get_errortext($!errhp);
        # TODO: handle OCI_SUCCESS_WITH_INFO
        die "execute of '$!statement' failed ($errcode): '$errortext'";
    }
    #warn "successfully executed $!dbh.AutoCommit()";

    # for DDL statements, no further steps are necessary
    # if $!statementtype ~~ ( OCI_STMT_CREATE, OCI_STMT_DROP, OCI_STMT_ALTER );

    $!state = 1;
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
        # FIXME: this returns the number of rows already fetched,
        #        not the number of rows available!
        my $errcode = OCIAttrGet_ub4($!stmthp, OCI_HTYPE_STMT, $row_count, Pointer, OCI_ATTR_ROW_COUNT, $!errhp);
        if $errcode ne OCI_SUCCESS {
            my $errortext = get_errortext($!errhp);
            die "statement type get failed ($errcode): '$errortext'";
        }
        $!row_count = $row_count;
    }

    #warn "row_count: $!row_count";

    if defined $!row_count {
        return ($!row_count == 0) ?? "0E0" !! $!row_count;
    }
}

method !parmd {
    # caching
    unless %!parmd {
        for 1 .. self.field_count -> $field_index {
            my @parmdpp := CArray[Pointer].new;
            @parmdpp[0] = Pointer;
            my $errcode = OCIParamGet($!stmthp, OCI_HTYPE_STMT, $!errhp, @parmdpp, $field_index);
            # that might be required for some queries
            # if $errcode eq OCI_ERROR {
            #     warn "no parameter for position $field_index, skipping";
            #     next;
            # }
            if $errcode ne OCI_SUCCESS {
                my $errortext = get_errortext($!errhp);
                die "parmd get for column $field_index failed ($errcode): '$errortext'";
            }
            %!parmd{$field_index} = @parmdpp[0];
            #warn "parmd for column $field_index fetched";
        }
    }

    return %!parmd;
}

method _row(:$hash) {
    die "Can't fetch without execute first"
        unless $!state >= 1;

    my ub2 $rcode = 0;
    my $rcodep = CArray[ub2].new;
    $rcodep[0] = $rcode;

    # only declare the first time a row is fetched
    unless @!out-binds.elems {
        # OCIDefineByPos2 docs state that position is 1-based,
        # 0 selects rowids
        #warn "SQL: $!statement";
        my %parmd = self!parmd;
        for 1 .. self.field_count -> $field_index {
            #warn "binding out-value for column $field_index";
            my $parmdp = %parmd{$field_index};

            # retrieve the data type
            my ub2 $dty;
            my $errcode = OCIAttrGet_ub2($parmdp, OCI_DTYPE_PARAM, $dty, Pointer, OCI_ATTR_DATA_TYPE, $!errhp);
            #warn "DATA TYPE: $dty";

            if $dty eq SQLT_NUM {
                my sb2 $precision;
                $errcode = OCIAttrGet_sb2($parmdp, OCI_DTYPE_PARAM, $precision, Pointer, OCI_ATTR_PRECISION, $!errhp);
                #warn "PRECISION: $precision";

                my sb1 $scale;
                $errcode = OCIAttrGet_sb1($parmdp, OCI_DTYPE_PARAM, $scale, Pointer, OCI_ATTR_SCALE, $!errhp);
                #warn "SCALE: $scale";

                # to not have to handle Oracles binary NUMBER format
                if $scale > 0 {
                    $dty = SQLT_FLT;
                }
                # numeric columns that result of a calculation
                # default to float to not lose precision
                elsif $precision == 0 && $scale == 0 {
                    $dty = SQLT_FLT;
                }
                else {
                    $dty = SQLT_INT;
                }
                #warn "DATA TYPE NUM: $dty";
            }

            # retrieve the data length
            my ub4 $datalen;
            $errcode = OCIAttrGet_ub4($parmdp, OCI_DTYPE_PARAM, $datalen, Pointer, OCI_ATTR_DATA_SIZE, $!errhp);
            #warn "DATA LENGTH: $datalen";

            # bind select list items
            #my CArray[OCIDefine] $defnpp.=new;
            my $defnpp = CArray[OCIDefine].new;
            $defnpp[0] = OCIDefine.new;

            my ub4 $rlen = 0;
            my $rlenp = CArray[sb4].new;
            $rlenp[0] = $rlen;
            # http://docs.oracle.com/database/121/LNOCI/oci02bas.htm#LNOCI16231
            my sb2 $ind = 0;
            my $indp = CArray[sb2].new;
            $indp[0] = $ind;

            given $dty {
                when SQLT_CHR {
                    #warn "defining #$field_index '$col_name'($datalen) as CHR($dty)";
                    my $valuep = CArray[int8].new;
                    $valuep[$_] = 0
                        for ^$datalen;
                    my sb8 $value_sz = $datalen;

                    @!out-binds.push({defnpp => $defnpp, valuep => $valuep, dty => $dty, indp => $indp, rlenp => $rlenp});
                    $errcode = OCIDefineByPos2_Str(
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
                when SQLT_INT {
                    #warn "defining #$field_index '$col_name'($datalen) as INT|NUM($dty)";
                    my long $value = 0;
                    my $valuep = CArray[long].new;
                    $valuep[0] = $value;
                    my sb8 $value_sz = nativesizeof(long);
                    @!out-binds.push({defnpp => $defnpp, valuep => $valuep, dty => $dty, indp => $indp, rlenp => $rlenp});
                    $errcode = OCIDefineByPos2_Int(
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
                when SQLT_FLT {
                    #warn "defining #$field_index '$col_name'($datalen) as FLT($dty)";
                    my num64 $value;
                    my $valuep = CArray[num64].new;
                    $valuep[0] = $value;
                    my sb8 $value_sz = nativesizeof(num64);
                    @!out-binds.push({defnpp => $defnpp, valuep => $valuep, dty => $dty, indp => $indp, rlenp => $rlenp});
                    $errcode = OCIDefineByPos2_Real(
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
                default {
                    die "unhandled type: $dty";
                }
            }
            if $errcode ne OCI_SUCCESS {
                my $errortext = get_errortext($!errhp);
                die "define failed ($errcode): '$errortext'";
            }
        }
        #warn 'defining complete';
    }

    my $errcode = OCIStmtFetch2($!stmthp, $!errhp, 1, OCI_DEFAULT, 0, OCI_DEFAULT);

    # no data is no exception
    $hash ?? return {} !! return []
        if $errcode eq OCI_NO_DATA;

    if $errcode ne OCI_SUCCESS {
        my $errortext = get_errortext($!errhp);
        die "fetch failed ($errcode): '$errortext'";
    }

    #my ub4 $row_count;
    #$errcode = OCIAttrGet_ub4($!stmthp, OCI_HTYPE_STMT, $row_count, Pointer, OCI_ATTR_ROWS_FETCHED, $!errhp);
    #if $errcode ne OCI_SUCCESS {
    #    my $errortext = get_errortext($!errhp);
    #    die "statement type get failed ($errcode): '$errortext'";
    #}
    #warn "ROWS FETCHED: $row_count";

    my @row;

    # now unpack the returned data
    for @!out-binds -> $col {
        #say $col.gist;
        # http://docs.oracle.com/database/121/LNOCI/oci02bas.htm#LNOCI16231
        given $col<indp>[0] {
            when -2 {
                die "the length of the item is greater than the length of the output variable";
            }
            # null
            when -1 {
                given $col<dty> {
                    when SQLT_CHR {
                        @row.push(Str);
                    }
                    when SQLT_INT {
                        @row.push(Int);
                    }
                    when SQLT_FLT {
                        @row.push(Rat);
                    }
                    default {
                        die "unhandled datatype $col<dty>";
                    }
                }
            }
            when 0 {
                #say "$col<dty> $col<valuep>";
                given $col<dty> {
                    when SQLT_CHR {
                        my @textary;
                        @textary[$_] = $col<valuep>[$_]
                            for ^$col<rlenp>[0];
                        @row.push(Buf.new(@textary).decode());
                    }
                    when SQLT_INT {
                        @row.push($col<valuep>[0].Int);
                    }
                    when SQLT_FLT {
                        @row.push($col<valuep>[0].Rat);
                    }
                    default {
                        die "unhandled datatype $col<dty>";
                    }
                }
                #say "$col<dty> $col<valuep> { @row[*-1].^name }";
            }
            default {
                die "the length of the item is greater than the length of the output variable, length returned was $col<indp>";
            }
        }
    }

    #say @row.gist;
    return (self.column_names Z=> @row).hash
        if $hash;

    return @row;
}

method fetchrow {
    return self._row;
}

method field_count {
    # TODO: what should be returned before the statement has been executed?
    unless $!field_count.defined {
        # TODO: because 2015.11: 'Natively typed state variables not yet implemented'
        my ub4 $field_count_native;
        my $errcode = OCIAttrGet_ub4($!stmthp, OCI_HTYPE_STMT, $field_count_native,
                              Pointer, OCI_ATTR_PARAM_COUNT, $!errhp);
        $!field_count = $field_count_native;
        # FIXME: error handling
    }
    return $!field_count;
}

method column_names {
   unless @!column_names {
        my %parmd = self!parmd;
        #say $!statement;
        for 1 .. self.field_count -> $field_index {
            my $parmdp = %parmd{$field_index};

            # retrieve the column name
            #my CArray[Pointer[Str]] $col_namepp.=new;
            #$col_namepp[0] = Pointer[Str].new;
            #my Str $col_name;
            my CArray[CArray[int8]] $col_namep .= new;
            $col_namep[0] = CArray[int8].new;

            my @col_name_len := CArray[ub4].new;
            @col_name_len[0] = 0;

            my $errcode = OCIAttrGet_Str($parmdp, OCI_DTYPE_PARAM, $col_namep, @col_name_len, OCI_ATTR_NAME, $!errhp);

            #my Str $col_name = $col_namepp[0].deref;

            # not needed, NativeCall can handle null-terminated strings itself
            my $col_name_len = @col_name_len[0];
            #warn "COLUMN LEN: $col_name_len";
            my @textary;
            @textary[$_] = $col_namep[0][$_]
                for ^$col_name_len;
            my Str $col_name = Buf.new(@textary).decode();

            #warn "COLUMN $field_index: $col_name";

            # Oracle returns the column names uppercase if they wheren't
            # quoted in the DDL statement
            @!column_names.push($col_name.lc);
        }
    }
    return @!column_names;
}

method finish() {
    if defined($!result) {
        #PQclear($!result);
        #$!result       = Any;
        #@!column_names = ();
    }
    return Bool::True;
}
