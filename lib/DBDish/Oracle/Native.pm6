use v6.c;

unit module DBDish::Oracle::Native;
use NativeCall;
use NativeHelpers::Blob;

my constant libver is export = v12.1;
my constant lib = ('clntsh', libver);

#------------ Oracle library to NativeCall data type mappings -----------
constant sb1          is export = int8;
constant sb2          is export = int16;
constant sb4          is export = int32;
constant sb8          is export = int64;
constant sword        is export = int32;
constant ub2          is export = uint16;
constant ub4          is export = uint32;
constant OraText      is export = Str;
constant NULL         is export = Pointer;

# Current rakudo don't allow set a Pointer in a CStruct based class.
# so we use an 'intprt'
constant ptrsize    is export = nativesizeof(Pointer);
constant intptr     is export = ptrsize == 8 ?? uint64 !! uint32;


# SELECT NLS_CHARSET_ID('AL32UTF8') FROM dual;
constant AL32UTF8               is export = 873;

# Handler Types
constant OCI_HTYPE_ENV          is export = 1;
constant OCI_HTYPE_ERROR        is export = 2;
constant OCI_HTYPE_SVCCTX       is export = 3;
constant OCI_HTYPE_STMT         is export = 4;
constant OCI_HTYPE_BIND         is export = 5;
constant OCI_HTYPE_DEFINE       is export = 6;
constant OCI_HTYPE_DESCRIBE     is export = 7;
constant OCI_DTYPE_PARAM        is export = 53;

constant OCI_DEFAULT            is export = 0;
constant OCI_THREADED           is export = 1;

constant OCI_STMT_SCROLLABLE_READONLY is export = 0x00000008;
constant OCI_DESCRIBE_ONLY            is export = 0x00000010;
constant OCI_COMMIT_ON_SUCCESS        is export = 0x00000020;

constant OCI_SUCCESS            is export =   0;
constant OCI_SUCCESS_WITH_INFO  is export =   1;
constant OCI_ERROR              is export =  -1;
constant OCI_NO_DATA            is export = 100;

constant OCI_LOGON2_STMTCACHE   is export = 4;

constant OCI_NTV_SYNTAX         is export = 1;

constant OCI_ATTR_DATA_SIZE     is export = 1;
constant OCI_ATTR_DATA_TYPE     is export = 2;
constant OCI_ATTR_NAME          is export = 4;
constant OCI_ATTR_PRECISION     is export = 5;
constant OCI_ATTR_SCALE         is export = 6;
constant OCI_ATTR_ROW_COUNT     is export = 9;
constant OCI_ATTR_PARAM_COUNT   is export = 18;
constant OCI_ATTR_STMT_TYPE     is export = 24;
constant OCI_ATTR_BIND_COUNT    is export = 190;
constant PCI_ATTR_HANDLE_POSITION is export = 192;
constant OCI_ATTR_ROWS_FETCHED  is export = 197;
constant OCI_ATTR_TYPECODE      is export = 216;
constant OCI_ATTR_IMPLICIT_RESULT_COUNT is export = 463;

constant OCI_STMT_UNKNOWN       is export = 0;
constant OCI_STMT_SELECT        is export = 1;
constant OCI_STMT_UPDATE        is export = 2;
constant OCI_STMT_DELETE        is export = 3;
constant OCI_STMT_INSERT        is export = 4;
constant OCI_STMT_CREATE        is export = 5;
constant OCI_STMT_DROP          is export = 6;
constant OCI_STMT_ALTER         is export = 7;
constant OCI_STMT_BEGIN         is export = 8;
constant OCI_STMT_DECLARE       is export = 9;
constant OCI_STMT_CALL          is export = 10;

constant SQLT_CHR               is export = 1;
constant SQLT_NUM               is export = 2;
constant SQLT_INT               is export = 3;
constant SQLT_FLT               is export = 4;
constant SQLT_STR               is export = 5;
constant SQLT_BIN               is export = 23;

constant %sqltype-map is export = {
    +(SQLT_CHR) => Str,
    +(SQLT_NUM) => Rat,
    +(SQLT_INT) => Int,
    +(SQLT_FLT) => Num,
    +(SQLT_BIN) => Buf
};

constant OCISnapshot  is export = Pointer;

class OCIErr is Cool is export {
    has $.Str;
    has $.Numeric;
}

class OCIHandle is repr('CPointer') is export {
    method h-type { 0 }

    method gen-error(OCIHandle:D:) {
        sub OCIErrorGet (
            OCIHandle $hndl,
            ub4       $recordno,
            OraText   $sqlstate,
            sb4       $errcodep is rw,
            utf8      $bufp,
            ub4       $bufsiz,
            ub4       $type
            --> sword ) is native(lib) { * }

        my $errtxt = blob-allocate(utf8, 512);
        OCIErrorGet(self, 1, OraText, my sb4 $errcode, $errtxt, 512, self.h-type);
        OCIErr.new(:Str(~$errtxt), :Numeric($errcode));
    }

    method HandleAlloc(OCIHandle:D: OCIHandle:U $want) {
        sub OCIHandleAlloc (
            OCIHandle $parenth,
            OCIHandle $hndl is rw,
            ub4       $type,
            size_t    $xtramem_sz,
            Pointer   $usrmempp
            --> sword ) is native(lib) { * }

        my $nh = $want.new;
        OCIHandleAlloc(self, $nh, $want.h-type, 0, Pointer)
            ?? self.gen-error
            !! $nh;
    }

    method HandleFree(OCIHandle:D:) {
        sub OCIHandleFree (OCIHandle, ub4 --> sword ) is native(lib) { * }

        OCIHandleFree(self, self.h-type);
    }

    method AttrGet(OCIHandle:D: OCIHandle $errh, Mu:U $want, $type) {
        sub OCIAttrGet (OCIHandle, ub4, Buf, ub4 $size is rw, ub4 $type, OCIHandle
            --> sword ) is native(lib) { * }

        my $buf = blob-allocate($want ~~ Blob ?? Buf[intptr] !! Buf[$want], 1);
        if OCIAttrGet(self, self.h-type, $buf, my ub4 $size, $type, $errh) {
            $errh.gen-error;
        } else {
            $want ~~ Blob
                ?? blob-from-pointer(Pointer.new($buf[0]), :elems($size), :type(utf8))
                !! $buf[0];
        }
    }

    method ParamGet(OCIHandle:D: OCIHandle $errh, OCIHandle $want, $pos) {
        sub OCIParamGet(OCIHandle, ub4, OCIHandle, OCIHandle is rw, ub4
            --> sword ) is native(lib) { * }

        my $parh = $want.new;
        OCIParamGet(self, self.h-type, $errh, $parh, $pos)
            ?? $errh.gen-error
            !! $parh;
    }
}

class OCIError is OCIHandle is repr('CPointer') is export {
    method h-type { OCI_HTYPE_ERROR }
}

class OCIParam is OCIHandle is repr('CPointer') is export {
    method h-type { OCI_DTYPE_PARAM }
}

class OCIBind is OCIHandle is repr('CPointer') is export {
    method h-type { OCI_HTYPE_BIND }
}

class OCIDefine is OCIHandle is repr('CPointer') is export {
    method h-type { OCI_HTYPE_DEFINE }
}

class OCIStmt is OCIHandle is repr('CPointer') is export {
    method h-type { OCI_HTYPE_STMT }

    method ParamGet(OCIError $errh, $pos) {
        callwith($errh, OCIParam, $pos);
    }

    method BindByName(OCIError $errh, Str $ph, Int $phl) {
        sub OCIBindByName (
            OCIStmt      $stmt,
            OCIBind      $bind is rw,
            OCIError     $errh,
            utf8         $placeholder,
            sb4          $placeh_len,
            Pointer      $value,
            sb4          $value_sz,
            ub2          $dty,
            intptr       $ind,
            Pointer[ub2] $alen,
            Pointer[ub2] $rcode,
            ub4          $maxarr_len,
            Pointer[ub4] $curele,
            ub4          $mode
            --> sword ) is native(lib) { * }

        #TODO When needed
    }

    method BindByPos(OCIStmt:D $stmt:
        OCIBind      $bind is rw,
        OCIError     $errh,
        ub4          $position,
        Pointer      $value,
        sb4          $value_sz,
        ub2          $dty,
        intptr       $ind,
        Pointer[ub2] $alen,
        Pointer[ub2] $rcode,
        ub4          $maxarr_len,
        Pointer[ub4] $curele,
        ub4          $mode
        --> sword ) is symbol('OCIBindByPos') is native(lib) { * }

    method DefineByPos(OCIStmt:D $stmt:
        OCIDefine    $bind is rw,
        OCIError     $errh,
        ub4          $position,
        Pointer      $value,
        sb8          $value_sz,
        ub2          $dty,
        intptr       $ind,
        intptr       $rlen,
        Pointer[ub2] $rcode,
        ub4          $mode
        --> sword ) is symbol('OCIDefineByPos2') is native(lib) { * }

    method StmtFetch(OCIError $errh) {
        sub OCIStmtFetch2 (
            OCIStmt  $stmt,
            OCIError $errh,
            ub4      $nrows,
            ub2      $orientation,
            sb4      $fetchOffset,
            ub4      $mode
            --> sword ) is native(lib) { * }

        OCIStmtFetch2(self, $errh, 1, OCI_DEFAULT, 0, OCI_DEFAULT)
    }
}

class OCISvcCtx is OCIHandle is repr('CPointer') is export {
    method h-type { OCI_HTYPE_SVCCTX }

    method StmtPrepare($stmttext, OCIError :$errh!) {
        sub OCIStmtPrepare2 (
            OCISvcCtx $svch,
            OCIStmt   $stmt is rw,
            OCIError  $errh,
            utf8      $stmttext,
            ub4       $stmt_len,
            utf8      $key,
            ub4       $keylen,
            ub4       $language,
            ub4       $mode
            --> sword ) is native(lib) { * }

        my $stmt = OCIStmt.new;
        OCIStmtPrepare2(self, $stmt, $errh, |buf-sized($stmttext),
            utf8, 0, OCI_NTV_SYNTAX, OCI_DEFAULT)
            ?? $errh.gen-error
            !! $stmt;
    }
    my sub OCIStmtExecute (
        OCISvcCtx       $svch,
        OCIStmt         $stmt,
        OCIError        $errh,
        ub4             $iters,
        ub4             $rowoff,
        OCISnapshot     $snap_in,
        OCISnapshot     $snap_out,
        ub4             $mode
        --> sword ) is native(lib) { * }

    method StmtDescribe(OCIStmt $stmt, OCIError $errh) {
        OCIStmtExecute(self, $stmt, $errh, 0, 0, NULL, NULL, OCI_DESCRIBE_ONLY)
            and $errh.gen-error;
    }

    method StmtExecute(OCIStmt $stmt, OCIError $errh, $iters, :$AutoCommit) {
        OCIStmtExecute(self, $stmt, $errh, $iters, 0, NULL, NULL,
                       $AutoCommit ?? OCI_COMMIT_ON_SUCCESS !! OCI_DEFAULT);
    }

    method Ping(OCISvcCtx:D: OCIError $errh, ub4 $mode --> sword)
        is symbol('OCIPing') is native(lib) { * }

    method Logoff(OCISvcCtx:D: OCIError $errh --> sword)
        is symbol('OCILogoff') is native(lib) { * }
}

class OCIEnv is OCIHandle is repr('CPointer') is export {
    method h-type { OCI_HTYPE_ENV }

    method NlsCreate(:$mode = OCI_DEFAULT, :$charset = AL32UTF8, :$ncharset = AL32UTF8) {
        sub OCIEnvNlsCreate (
            OCIEnv  is rw,
            ub4     $mode,
            Pointer $ctxp,
            Pointer $malocfp,
            Pointer $ralocfp,
            Pointer $mfreefp,
            size_t  $xtramemsz,
            Pointer $usrmempp,
            ub2     $charset,
            ub2     $ncharset
            --> sword ) is native(lib) { * }

        my $env = self.new;
        if OCIEnvNlsCreate($env, $mode,
            my Pointer $ctxp, NULL, NULL, NULL, 0, Pointer,
            $charset, $ncharset
        ) -> $err {
            OCIErr.new(:Str("Can't allocate Environment"), :Numeric($err));
        } else {
            $env
        }
    }

    method Logon(OCIError :$errh, Int :$mode, :$dbname, :$username, :$password) {
        sub OCILogon2 (
            OCIEnv    $envh,
            OCIError  $errh,
            OCISvcCtx $svch is rw,
            utf8      $username,
            ub4       $uname_len,
            utf8      $password,
            ub4       $passwd_len,
            utf8      $dbname,
            ub4       $dbname_len,
            ub4       $mode
            --> sword ) is native(lib) { * }

        my $svch = OCISvcCtx.new;
        OCILogon2(self, $errh, $svch, |buf-sized($username), |buf-sized($password),
                  |buf-sized($dbname), $mode)
            ?? $errh.gen-error
            !! $svch;
    }
}

# vim: ft=perl6 expandtab
