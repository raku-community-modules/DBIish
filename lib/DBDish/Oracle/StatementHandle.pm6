use v6;
no precompilation;
need DBDish;

unit class DBDish::Oracle::StatementHandle does DBDish::StatementHandle;
use NativeHelpers::Blob;
use DBDish::Oracle::Native;

has OCISvcCtx $!svch is required;
has OCIError  $!errh is required;
has OCIStmt   $!stmth is required;
has $!statement;
has $!stmttype;
# For input parameters
has $!param-count;
has @!in-binds;
has $!in-indicator;
# For outputs
has $!field_count;
has @!out-binds;
has @!out-buffs;
has $!out-indicator;
has $!out-lengths;

method !handle-err($res) {
    $res ~~ OCIErr ?? self!set-err(+$res, ~$res) !! $res;
}

submethod BUILD(:$!parent!, :$!statement!, :$!RaiseError,
    :$!svch, :$!errh, :$!stmth,
) {
    $!stmttype = $!stmth.AttrGet($!errh, ub2, OCI_ATTR_STMT_TYPE);
    if $!param-count = $!stmth.AttrGet($!errh, ub4, OCI_ATTR_BIND_COUNT) -> $pn {
        @!in-binds.push(OCIBind.new) for ^$pn;
        $!in-indicator = blob-allocate(Buf[sb2], $pn);
    }
    self;
}

method !get-meta {
    $!field_count = self!handle-err: $!stmth.AttrGet($!errh, ub4, OCI_ATTR_PARAM_COUNT);
    if $!field_count {
        my $indp = pointer-to(
            $!out-indicator = blob-allocate(Buf[sb2], $!field_count)
        ).Int;
        my $lenp = pointer-to(
            $!out-lengths   = blob-allocate(Buf[sb8], $!field_count)
        ).Int;

        for ^$!field_count -> $col {
            with self!handle-err: $!stmth.ParamGet($!errh, $col + 1) -> $parmd {
                my $col_name = $parmd.AttrGet($!errh, utf8, OCI_ATTR_NAME);
                my $dtype    = $parmd.AttrGet($!errh, ub2, OCI_ATTR_DATA_TYPE);
                my $datalen  = $parmd.AttrGet($!errh, ub4, OCI_ATTR_DATA_SIZE);
                my $wtype    = SQLT_CHR;
                my $buff     = do given $dtype {
                    #note "$col_name: $dtype ($datalen)";
                    when SQLT_NUM {
                        my $prec = $parmd.AttrGet($!errh, sb2, OCI_ATTR_PRECISION);
                        my $scale = $parmd.AttrGet($!errh, sb1, OCI_ATTR_SCALE);
                        $_ = SQLT_INT and proceed if $prec > 0 && $scale == 0;
                        $_ = SQLT_FLT and proceed if $scale == -127;
                        blob-allocate(utf8, 40);
                    }
                    when SQLT_FLT { $wtype = $_; array[num64].new(0e0); }
                    when SQLT_INT { $wtype = $_; Buf[int64].new(0); }
                    when SQLT_BIN { $wtype = $_; proceed; }
                    default { blob-allocate(Buf, $datalen); }
                }
                my $bind = OCIDefine.new;
                $!stmth.DefineByPos($bind, $!errh, $col + 1, |ptr-sized($buff),
                                    $wtype, $indp + $col*2, $lenp + $col*8,
                                    NULL, OCI_DEFAULT)
                    and self!handle-err($!errh.gen-error).fail;
                @!out-binds.push:   $bind;
                @!out-buffs.push:   $buff;
                @!column-name.push: $col_name.decode.lc;
                warn "No map defined for type $dtype\n"
                    unless %sqltype-map{$dtype}:exists;
                @!column-type.push: %sqltype-map{$dtype};
            } else { .fail }
        }
    }
}

method execute(*@params) {
    self!enter-execute(@params.elems, $!param-count);

    # bind placeholder values
    my @in-bufs;
    my $indp = pointer-to($!in-indicator).Int if $!param-count;
    for @params.kv -> $k, $v {
        my $btype = SQLT_CHR;
        my $buf = do with $v {
            $!in-indicator[$k] = 0;
            when Blob { $btype = SQLT_BIN; $v }
            when Str { .encode }
            default { .Str.encode}
        } else {
            $!in-indicator[$k] = -1;
            utf8.new;
        };
        $!stmth.BindByPos(
            @!in-binds[$k], $!errh, $k+1, |ptr-sized($buf), $btype,
            $indp + $k*2, NULL, NULL, 0, NULL, OCI_DEFAULT
        ) and self!handle-err($!errh.gen-error).fail;
        @in-bufs.push: $buf; # Keep till execute
    }

    my $errcode = $!svch.StmtExecute($!stmth, $!errh,
        $!stmttype != OCI_STMT_SELECT, # 0 Select, 1 Non Select
        :AutoCommit($!parent.AutoCommit)
    );
    given $errcode {
        when OCI_ERROR { self!handle-err($!errh.gen-error) }
        my $rows = 0;
        when OCI_NO_DATA { proceed; }
        when OCI_SUCCESS_WITH_INFO {
            # TODO
            proceed;
        }
        default { # OCI_SUCCESS
            self!get-meta without $!field_count;
            unless $!stmttype ~~ ( OCI_STMT_CREATE, OCI_STMT_DROP, OCI_STMT_ALTER ) {
                $rows = $!stmth.AttrGet($!errh, ub4, OCI_ATTR_ROW_COUNT);
            }
            self!done-execute($rows, $!field_count);
        }
    }
}

method _row() {
    my $list = ();
    if $!field_count {
        my $errcode = $!stmth.StmtFetch($!errh);
        if $errcode == OCI_SUCCESS {
            $list = do for ^$!field_count -> $col {
                given $!out-indicator[$col] {
                    when -1 { @!column-type[$col] } # NULL
                    when  0 {
                        my $res = @!out-buffs[$col];
                        given @!column-type[$col] {
                            when Int | Num { $res[0] }
                            $res .= subbuf(0, $!out-lengths[$col]);
                            when Blob { $res }
                            $res .= decode;
                            when Rat { $res.Rat }
                            default { $res }
                        }
                    }
                    default {
                        die "the length of the item is greater than the length of the output variable, length returned was $col<indp>";
                    }
                }
            }
            $!affected_rows++;
            self.reset-err;
        } elsif $errcode == OCI_NO_DATA {
            self.finish;
        } else {
            self!handle-err($!errh.gen-error);
        }
    }
    $list;
}

method _free() {
    with $!stmth {
        .HandleFree;
        $_ = Nil;
    }
}
method finish() {
    #TODO
    $!Finished = True;
}

# vim: ft=perl6 expandtab
