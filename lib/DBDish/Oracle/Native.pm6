use v6.c;

use NativeCall;

unit module DBDish::Oracle::Native;

my constant lib = ('clntsh', v12.1);

#------------ Oracle library to NativeCall data type mappings -----------

constant sb1          is export = int8;
constant sb2          is export = int16;
constant sb4          is export = int32;
constant sb8          is export = int64;
constant sword        is export = int32;
constant ub2          is export = uint16;
constant ub4          is export = uint32;

class OCIHandle	    is repr('CPointer') is export {};
class OCIEnv	    is OCIHandle is repr('CPointer') is export {};
class OCIError	    is OCIHandle is repr('CPointer') is export {}
class OCIStmt	    is OCIHandle is repr('CPointer') is export {};
constant OCIBind      is export = Pointer;
constant OCIDefine    is export = Pointer;
constant OCISnapshot  is export = Pointer;
constant OCISvcCtx    is export = Pointer;
constant OraText      is export = Str;


my ub4 constant OCI_DEFAULT     is export = 0;
constant OCI_THREADED           is export = 1;
constant OCI_COMMIT_ON_SUCCESS  is export = 0x00000020;

constant OCI_SUCCESS            is export = 0;
constant OCI_ERROR              is export = -1;
constant OCI_NO_DATA            is export = 100;

constant OCI_HTYPE_ENV          is export = 1;
constant OCI_HTYPE_ERROR        is export = 2;
constant OCI_HTYPE_STMT         is export = 4;

constant OCI_DTYPE_PARAM        is export = 53;

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
constant OCI_ATTR_ROWS_FETCHED  is export = 197;

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

# SELECT NLS_CHARSET_ID('AL32UTF8') FROM dual;
constant AL32UTF8               is export = 873;

#------------ Oracle library functions in alphabetical order ------------

sub OCIEnvNlsCreate (
        OCIEnv $envhpp is rw,
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
    is export
    { ... }

sub OCIErrorGet (
        OCIHandle     $hndlp,
        ub4           $recordno,
        OraText       $sqlstate,
        CArray[sb4]   $errcodep,
        CArray[int8]  $bufp,
        ub4           $bufsiz,
        ub4           $type,
    )
    returns sword
    is native(lib)
    is export
    { ... }

sub OCIHandleAlloc (
        OCIHandle         $parenth,
        OCIHandle	  $hndlpp is rw,
        ub4               $type,
        size_t            $xtramem_sz,
        CArray[Pointer]   $usrmempp,
    )
    returns sword
    is native(lib)
    is export
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
    is export
    { ... }

sub OCILogoff (
        OCISvcCtx   $svchp,
        OCIError    $errhp,
    )
    returns sword
    is native(lib)
    is export
    { ... }

sub OCIStmtPrepare2 (
        OCISvcCtx           $svchp,
        OCIStmt	            $stmthp is rw,
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
    is export
    { ... }

sub OCIAttrGet_Str(
        Pointer[void]           $trgthndlp,
        ub4                     $trghndltyp,
        CArray[CArray[int8]]    $attributep,
        CArray[ub4]             $sizep,
        ub4                     $attrtype,
        OCIError                $errhp,
    )
    returns sword
    is native(lib)
    is export
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
    is export
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
    is export
    is symbol('OCIAttrGet')
    { ... }

sub OCIAttrGet_sb1 (
        Pointer[void]   $trgthndlp,
        ub4             $trghndltyp,
        sb1             $attributep is rw,
        CArray[ub4]     $sizep,
        ub4             $attrtype,
        OCIError        $errhp,
    )
    returns sword
    is native(lib)
    is export
    is symbol('OCIAttrGet')
    { ... }

sub OCIAttrGet_sb2 (
        Pointer[void]   $trgthndlp,
        ub4             $trghndltyp,
        sb2             $attributep is rw,
        CArray[ub4]     $sizep,
        ub4             $attrtype,
        OCIError        $errhp,
    )
    returns sword
    is native(lib)
    is export
    is symbol('OCIAttrGet')
    { ... }

# strings
sub OCIBindByName_Str (
        OCIStmt             $stmtp,
        CArray[OCIBind]     $bindpp,
        #OCIBind             $bindpp is rw,
        OCIError            $errhp,
        OraText             $placeholder is encoded('utf8'),
        sb4                 $placeh_len,
        Str                 $valuep is encoded('utf8'),
        sb4                 $value_sz,
        ub2                 $dty,
        #sb2                 $indp is rw,
        CArray[sb2]         $indp,
        Pointer[ub2]        $alenp,
        #ub2                 $alenp is rw,
        Pointer[ub2]        $rcodep,
        #ub2                 $rcodep is rw,
        ub4                 $maxarr_len,
        Pointer[ub4]        $curelep,
        #ub4                 $curelep is rw,
        ub4                 $mode,
    )
    returns sword
    is native(lib)
    is export
    is symbol('OCIBindByName')
    { ... }

# ints
sub OCIBindByName_Int (
        OCIStmt             $stmtp,
        CArray[OCIBind]     $bindpp,
        #OCIBind             $bindpp is rw,
        OCIError            $errhp,
        OraText             $placeholder is encoded('utf8'),
        sb4                 $placeh_len,
        # use long to have the maximum precision supported by the platform
        CArray[long]        $valuep,
        sb4                 $value_sz,
        ub2                 $dty,
        #sb2                 $indp is rw,
        CArray[sb2]         $indp,
        Pointer[ub2]        $alenp,
        #ub2                 $alenp is rw,
        Pointer[ub2]        $rcodep,
        #ub2                 $rcodep is rw,
        ub4                 $maxarr_len,
        Pointer[ub4]        $curelep,
        #ub4                 $curelep is rw,
        ub4                 $mode,
    )
    returns sword
    is native(lib)
    is export
    is symbol('OCIBindByName')
    { ... }

# floats
sub OCIBindByName_Real (
        OCIStmt             $stmtp,
        CArray[OCIBind]     $bindpp,
        #OCIBind             $bindpp is rw,
        OCIError            $errhp,
        OraText             $placeholder is encoded('utf8'),
        sb4                 $placeh_len,
        # num32 did result in ORA-01438: value larger than specified precision
        # allowed for this column
        CArray[num64]       $valuep,
        sb4                 $value_sz,
        ub2                 $dty,
        #sb2                 $indp is rw,
        CArray[sb2]         $indp,
        Pointer[ub2]        $alenp,
        #ub2                 $alenp is rw,
        Pointer[ub2]        $rcodep,
        #ub2                 $rcodep is rw,
        ub4                 $maxarr_len,
        Pointer[ub4]        $curelep,
        #ub4                 $curelep is rw,
        ub4                 $mode,
    )
    returns sword
    is native(lib)
    is export
    is symbol('OCIBindByName')
    { ... }

sub OCIDefineByPos2_Str (
        OCIStmt                 $stmtp,
        CArray[OCIDefine]       $defnpp,
        OCIError                $errhp,
        ub4                     $position,
        CArray[int8]            $valuep,
        sb8                     $value_sz,
        ub2                     $dty,
        # sb2 only for non-array binds
        CArray[sb2]             $indp,
        CArray[ub4]             $rlenp,
        CArray[ub2]             $rcodep,
        ub4                     $mode,
    )
    returns sword
    is native(lib)
    is export
    is symbol('OCIDefineByPos2')
    { ... }

sub OCIDefineByPos2_Int (
        OCIStmt             $stmtp,
        CArray[OCIDefine]   $defnpp,
        OCIError            $errhp,
        ub4                 $position,
        CArray[long]        $valuep,
        sb8                 $value_sz,
        ub2                 $dty,
        # sb2 only for non-array binds
        CArray[sb2]             $indp,
        CArray[ub4]             $rlenp,
        CArray[ub2]             $rcodep,
        ub4                 $mode,
    )
    returns sword
    is native(lib)
    is export
    is symbol('OCIDefineByPos2')
    { ... }

sub OCIDefineByPos2_Real (
        OCIStmt             $stmtp,
        CArray[OCIDefine]   $defnpp,
        OCIError            $errhp,
        ub4                 $position,
        CArray[num64]       $valuep,
        sb8                 $value_sz,
        ub2                 $dty,
        # sb2 only for non-array binds
        CArray[sb2]         $indp,
        CArray[ub4]         $rlenp,
        CArray[ub2]         $rcodep,
        ub4                 $mode,
    )
    returns sword
    is native(lib)
    is export
    is symbol('OCIDefineByPos2')
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
    is export
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
    is export
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
    is export
    { ... }

sub get_errortext(OCIError $handle, $handle_type = OCI_HTYPE_ERROR) is export {
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
