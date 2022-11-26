use v6;

unit module DBDish::Pg::Native;
use NativeCall;
use NativeLibs;
use NativeHelpers::Blob;

constant LIB = NativeLibs::Searcher.at-runtime('pq', 'PQstatus', 5);

#------------ My Visible Types

constant Oid = uint32;
constant OidArray is export = CArray[Oid];

sub PQlibVersion(-->uint32) is native(LIB) is export { * }
sub PQfreemem(Pointer) is native(LIB) { * }
sub PQunescapeBytea(str, size_t is rw --> Pointer) is native(LIB) { * }

sub str-to-blob(Str $value, Mu:U :$type) is export {
    my \ptr = PQunescapeBytea($value, my size_t $elems);
    LEAVE { PQfreemem(ptr) if ptr }
    with ptr {
        blob-from-pointer(ptr, :$elems, :$type)
    } else { die "Can't allocate memory!" };
}

class PGresult    is export is repr('CPointer') {
    method PQclear is native(LIB) { * }
    method PQcmdTuples(--> Str) is native(LIB) { * }
    method PQfname(int32 --> Str) is native(LIB) { * }
    method PQftype(int32 --> int32) is native(LIB) { * };
    method PQparamtype(int32 --> int32) is native(LIB) { * };
    method PQgetisnull(int32, int32 --> int32) is native(LIB) { * }
    method PQgetvalue(int32, int32 --> Str) is native(LIB) { * }
    method PQnfields(--> int32) is native(LIB) { * }
    method PQnparams(--> int32) is native(LIB) { * }
    method PQntuples(--> int32) is native(LIB) { * }
    method PQresultErrorMessage(--> str) is native(LIB) { * }
    method PQresultErrorField(int32 $field_number --> Str) is native(LIB) { * }
    method PQresultStatus(--> int32) is native(LIB) { * }
    method PQgetlength(int32, int32 --> int32) is native(LIB) { * }
    method PQfformat(int32 --> int32) is native(LIB) { * }
    method PQgetvaluePtr(int32, int32 --> Pointer)
            is symbol('PQgetvalue') is native(LIB) { * }

    method is-ok {
        self.PQresultStatus ~~ (0 .. 4);
    }
}

class pg-notify is export {
    has Str   $.relname;
    has int32 $.be_pid;
    has Str   $.extra;
}

class PGconn is export is repr('CPointer') {
    method PQexec(Str --> PGresult) is native(LIB) { * }
    method PQexecPrepared(
        Str $statement_name,
        int32 $n_params,
        CArray[Str] $param_values,
        CArray[int32] $param_length,
        CArray[int32] $param_formats,
        int32 $resultFormat
    ) returns PGresult is native(LIB) { * }

    method PQerrorMessage(--> Str) is native(LIB) { * }
    method PQdescribePrepared(Str --> PGresult) is native(LIB) { * }
    method PQstatus(--> int32) is native(LIB) { * }
    method PQprepare(Str $sth_name, Str $query, int32 $n_params, OidArray --> PGresult)
            is native(LIB) { * }
    method PQfinish is native(LIB) { * }

    method PQescapeByteaConn(Buf, size_t, size_t is rw --> Pointer)
            is native(LIB) { * }
    method escapeBytea(Buf:D $buf) {
        my size_t $sz;
        with self.PQescapeByteaConn($buf, $buf.elems * nativesizeof($buf.of), $sz) {
            LEAVE { PQfreemem($_) }
            nativecast(Str, $_);
        } else {
            die "Can't allocate memory!"
        }
    }

    method PQescapeIdentifier(utf8, size_t --> Pointer) is native(LIB) { * }
    method PQescapeLiteral(utf8, size_t --> Pointer) is native(LIB) { * }
    method quote(Str $str, :$as-id --> Str) {
        with $as-id ?? self.PQescapeIdentifier(|buf-sized($str))
        !! self.PQescapeLiteral(|buf-sized($str)) {
            LEAVE { PQfreemem($_) }
            nativecast(Str, $_);
        } else {
            Nil
        }
    }

    method pg-socket(--> int32) is symbol('PQsocket') is native(LIB) { * }

    method PQconsumeInput( --> int32) is native(LIB) { * }

    method PQnotifies(--> Pointer) is native(LIB) { * }
    method pg-notifies(--> pg-notify) {
        class PGnotify is repr('CStruct') {
            has Str                           $.relname; # char* relname
            has int32                         $.be_pid; # int be_pid
            has Str                           $.extra; # char* extra
        }

        my \ptr = self.PQnotifies;
        LEAVE { PQfreemem(ptr) if ptr }
        with ptr && nativecast(PGnotify, ptr) -> \self {
            pg-notify.new(:$.relname, :$.be_pid, :$.extra)
        } else { Nil }
    }

    method pg-parameter-status(Str --> Str) is symbol('PQparameterStatus')
                                            is native(LIB) { * }

    sub PQconnectdb(str --> PGconn) is native(LIB) { * };
    multi method new(Str $conninfo) { # Our legacy constructor
        PQconnectdb($conninfo);
    }

    sub PQconnectdbParams(CArray[Str], CArray[Str], int32 --> PGconn)
            is native(LIB) { * };
    multi method new(%connparms) { # Our named constructor

        my $keys = CArray[Str].new; my $vals = CArray[Str].new;
        my int $i = 0;
        for %connparms.kv -> $k,$v {
            next without $v;
            $keys[$i] = $k.subst('-','_');
            $vals[$i] = ~$v; $i++;
        }
        $keys[$i] = Str; $vals[$i] = Str;
        PQconnectdbParams($keys, $vals, 1);
    }
    method pg-db(--> Str) is symbol('PQdb') is native(LIB) { * }
    method pg-user(--> Str) is symbol('PQuser') is native(LIB) { * }
    method pg-pass(--> Str) is symbol('PQpass') is native(LIB) { * }
    method pg-host(--> Str) is symbol('PQhost') is native(LIB) { * }
    method pg-port(--> Str) is symbol('PQport') is native(LIB) { * }
    method pg-options(--> Str) is symbol('PQoptions') is native(LIB) { * }
}

constant Null is export = Pointer;
constant ParamArray is export = CArray[Str];

# This list may be largely rebuilt using the below query.
#   SELECT format('%22s => %s,',
#            CASE WHEN typname LIKE '\_%' THEN 'PG_'|| upper(replace(typname, '_', '')) || 'ARRAY'
#              ELSE 'PG_'|| upper(typname) END,
#            oid)
#     FROM pg_type WHERE oid < 4000 AND ORDER BY oid;
enum PGTypes is export (
               PG_BOOL => 16,
              PG_BYTEA => 17,
               PG_CHAR => 18,
               PG_NAME => 19,
               PG_INT8 => 20,
               PG_INT2 => 21,
         PG_INT2VECTOR => 22,
               PG_INT4 => 23,
            PG_REGPROC => 24,
               PG_TEXT => 25,
                PG_OID => 26,
                PG_TID => 27,
                PG_XID => 28,
                PG_CID => 29,
          PG_OIDVECTOR => 30,
     PG_PG_DDL_COMMAND => 32,
            PG_PG_TYPE => 71,
       PG_PG_ATTRIBUTE => 75,
            PG_PG_PROC => 81,
           PG_PG_CLASS => 83,
               PG_JSON => 114,
                PG_XML => 142,
           PG_XMLARRAY => 143,
       PG_PG_NODE_TREE => 194,
          PG_JSONARRAY => 199,
               PG_SMGR => 210, # Removed Pg 12
   PG_TABLE_AM_HANDLER => 269,
   PG_INDEX_AM_HANDLER => 325,
              PG_POINT => 600,
               PG_LSEG => 601,
               PG_PATH => 602,
                PG_BOX => 603,
            PG_POLYGON => 604,
               PG_LINE => 628,
          PG_LINEARRAY => 629,
               PG_CIDR => 650,
          PG_CIDRARRAY => 651,
             PG_FLOAT4 => 700,
             PG_FLOAT8 => 701,
            PG_ABSTIME => 702, # Removed Pg 12
            PG_RELTIME => 703, # Removed Pg 12
          PG_TINTERVAL => 704, # Removed Pg 12
            PG_UNKNOWN => 705,
             PG_CIRCLE => 718,
        PG_CIRCLEARRAY => 719,
           PG_MACADDR8 => 774,
      PG_MACADDR8ARRAY => 775,
              PG_MONEY => 790,
         PG_MONEYARRAY => 791,
            PG_MACADDR => 829,
               PG_INET => 869,
          PG_BOOLARRAY => 1000,
         PG_BYTEAARRAY => 1001,
          PG_CHARARRAY => 1002,
          PG_NAMEARRAY => 1003,
          PG_INT2ARRAY => 1005,
    PG_INT2VECTORARRAY => 1006,
          PG_INT4ARRAY => 1007,
       PG_REGPROCARRAY => 1008,
          PG_TEXTARRAY => 1009,
           PG_TIDARRAY => 1010,
           PG_XIDARRAY => 1011,
           PG_CIDARRAY => 1012,
     PG_OIDVECTORARRAY => 1013,
        PG_BPCHARARRAY => 1014,
       PG_VARCHARARRAY => 1015,
          PG_INT8ARRAY => 1016,
         PG_POINTARRAY => 1017,
          PG_LSEGARRAY => 1018,
          PG_PATHARRAY => 1019,
           PG_BOXARRAY => 1020,
        PG_FLOAT4ARRAY => 1021,
        PG_FLOAT8ARRAY => 1022,
       PG_ABSTIMEARRAY => 1023, # Removed Pg 12
       PG_RELTIMEARRAY => 1024, # Removed Pg 12
     PG_TINTERVALARRAY => 1025, # Removed Pg 12
       PG_POLYGONARRAY => 1027,
           PG_OIDARRAY => 1028,
            PG_ACLITEM => 1033,
       PG_ACLITEMARRAY => 1034,
       PG_MACADDRARRAY => 1040,
          PG_INETARRAY => 1041,
             PG_BPCHAR => 1042,
            PG_VARCHAR => 1043,
               PG_DATE => 1082,
               PG_TIME => 1083,
          PG_TIMESTAMP => 1114,
     PG_TIMESTAMPARRAY => 1115,
          PG_DATEARRAY => 1182,
          PG_TIMEARRAY => 1183,
        PG_TIMESTAMPTZ => 1184,
   PG_TIMESTAMPTZARRAY => 1185,
           PG_INTERVAL => 1186,
      PG_INTERVALARRAY => 1187,
       PG_NUMERICARRAY => 1231,
        PG_PG_DATABASE => 1248,
       PG_CSTRINGARRAY => 1263,
             PG_TIMETZ => 1266,
        PG_TIMETZARRAY => 1270,
                PG_BIT => 1560,
           PG_BITARRAY => 1561,
             PG_VARBIT => 1562,
        PG_VARBITARRAY => 1563,
            PG_NUMERIC => 1700,
          PG_REFCURSOR => 1790,
     PG_REFCURSORARRAY => 2201,
       PG_REGPROCEDURE => 2202,
            PG_REGOPER => 2203,
        PG_REGOPERATOR => 2204,
           PG_REGCLASS => 2205,
            PG_REGTYPE => 2206,
  PG_REGPROCEDUREARRAY => 2207,
       PG_REGOPERARRAY => 2208,
   PG_REGOPERATORARRAY => 2209,
      PG_REGCLASSARRAY => 2210,
       PG_REGTYPEARRAY => 2211,
             PG_RECORD => 2249,
            PG_CSTRING => 2275,
                PG_ANY => 2276,
           PG_ANYARRAY => 2277,
               PG_VOID => 2278,
            PG_TRIGGER => 2279,
   PG_LANGUAGE_HANDLER => 2280,
           PG_INTERNAL => 2281,
             PG_OPAQUE => 2282,
         PG_ANYELEMENT => 2283,
        PG_RECORDARRAY => 2287,
        PG_ANYNONARRAY => 2776,
          PG_PG_AUTHID => 2842,
    PG_PG_AUTH_MEMBERS => 2843,
 PG_TXID_SNAPSHOTARRAY => 2949,
               PG_UUID => 2950,
          PG_UUIDARRAY => 2951,
      PG_TXID_SNAPSHOT => 2970,
        PG_FDW_HANDLER => 3115,
             PG_PG_LSN => 3220,
        PG_PG_LSNARRAY => 3221,
        PG_TSM_HANDLER => 3310,
       PG_PG_NDISTINCT => 3361,
    PG_PG_DEPENDENCIES => 3402,
            PG_ANYENUM => 3500,
           PG_TSVECTOR => 3614,
            PG_TSQUERY => 3615,
          PG_GTSVECTOR => 3642,
      PG_TSVECTORARRAY => 3643,
     PG_GTSVECTORARRAY => 3644,
       PG_TSQUERYARRAY => 3645,
          PG_REGCONFIG => 3734,
     PG_REGCONFIGARRAY => 3735,
      PG_REGDICTIONARY => 3769,
 PG_REGDICTIONARYARRAY => 3770,
              PG_JSONB => 3802,
         PG_JSONBARRAY => 3807,
           PG_ANYRANGE => 3831,
      PG_EVENT_TRIGGER => 3838,
          PG_INT4RANGE => 3904,
     PG_INT4RANGEARRAY => 3905,
           PG_NUMRANGE => 3906,
      PG_NUMRANGEARRAY => 3907,
            PG_TSRANGE => 3908,
       PG_TSRANGEARRAY => 3909,
          PG_TSTZRANGE => 3910,
     PG_TSTZRANGEARRAY => 3911,
          PG_DATERANGE => 3912,
     PG_DATERANGEARRAY => 3913,
          PG_INT8RANGE => 3926,
     PG_INT8RANGEARRAY => 3927
);

constant %oid-to-type is export = Map.new(
      16 => Bool,            # bool
      17 => Buf,             # bytea
      18 => Str,             # char
      19 => Str,             # name
      20 => Int,             # int8
      21 => Int,             # int2
      22 => Str,             # int2vector
      23 => Int,             # int4
      24 => Str,             # regproc
      25 => Str,             # text
      26 => Int,             # oid
      27 => Str,             # tid
      28 => Int,             # xid
      29 => Int,             # cid
      30 => Str,             # oidvector
     114 => Str,             # json
     142 => Str,             # xml
     143 => Array[Str],      # Array(xml)
     199 => Array[Str],      # Array(json)
     269 => Str,             # table_am_handler
     325 => Str,             # index_am_handler
     600 => Str,             # point
     601 => Str,             # lseg
     602 => Str,             # path
     603 => Str,             # box
     604 => Str,             # polygon
     628 => Str,             # line
     629 => Array[Str],      # Array(line)
     650 => Str,             # cidr
     651 => Array[Str],      # Array(cidr)
     700 => Num,             # float4
     701 => Num,             # float8
     705 => Any,             # unknown
     718 => Str,             # circle
     719 => Array[Str],      # Array(circle)
     774 => Str,             # macaddr8
     775 => Array[Str],      # Array(macaddr8)
     790 => Str,             # money
     791 => Array[Str],      # Array(money)
     829 => Str,             # macaddr
     869 => Str,             # inet
    1000 => Array[Bool],     # Array(bool)
    1001 => Array[Buf],      # Array(bytea)
    1002 => Array[Str],      # Array(char)
    1003 => Array[Str],      # Array(name)
    1005 => Array[Int],      # Array(int2)
    1006 => Array[Str],      # Array(int2vector)
    1007 => Array[Int],      # Array(int4)
    1008 => Array[Str],      # Array(regproc)
    1009 => Array[Str],      # Array(text)
    1010 => Array[Str],      # Array(tid)
    1011 => Array[Int],      # Array(xid)
    1012 => Array[Int],      # Array(cid)
    1013 => Array[Str],      # Array(oidvector)
    1014 => Array[Str],      # Array(bpchar)
    1015 => Array[Str],      # Array(varchar)
    1016 => Array[Int],      # Array(int8)
    1017 => Array[Str],      # Array(point)
    1018 => Array[Str],      # Array(lseg)
    1019 => Array[Str],      # Array(path)
    1020 => Array[Str],      # Array(box)
    1021 => Array[Num],      # Array(float4)
    1022 => Array[Num],      # Array(float8)
    1027 => Array[Str],      # Array(polygon)
    1028 => Array[Int],      # Array(oid)
    1033 => Str,             # aclitem
    1034 => Array[Str],      # Array(aclitem)
    1040 => Array[Str],      # Array(macaddr)
    1041 => Array[Str],      # Array(inet)
    1042 => Str,             # bpchar
    1043 => Str,             # varchar
    1082 => Date,            # date
    1083 => Str,             # time
    1114 => DateTime,        # timestamp
    1115 => Array[DateTime], # Array(timestamp)
    1182 => Array[Date],     # Array(date)
    1183 => Array[Str],      # Array(time)
    1184 => DateTime,        # timestamptz
    1185 => Array[DateTime], # Array(timestamptz)
    1186 => Str,             # interval
    1187 => Array[Str],      # Array(interval)
    1231 => Array[FatRat],   # Array(numeric)
    1263 => Array[Str],      # Array(cstring)
    1266 => Str,             # timetz
    1270 => Array[Str],      # Array(timetz)
    1560 => Str,             # bit
    1561 => Array[Str],      # Array(bit)
    1562 => Str,             # varbit
    1563 => Array[Str],      # Array(varbit)
    1700 => FatRat,          # numeric
    1790 => Str,             # refcursor
    2201 => Array[Str],      # Array(refcursor)
    2202 => Str,             # regprocedure
    2203 => Str,             # regoper
    2204 => Str,             # regoperator
    2205 => Str,             # regclass
    2206 => Str,             # regtype
    2207 => Array[Str],      # Array(regprocedure)
    2208 => Array[Str],      # Array(regoper)
    2209 => Array[Str],      # Array(regoperator)
    2210 => Array[Str],      # Array(regclass)
    2211 => Array[Str],      # Array(regtype)
    2249 => Str,             # record
    2275 => Str,             # cstring
    2276 => Str,             # any
    2277 => Str,             # anyarray
    2278 => Str,             # void
    2279 => Str,             # trigger
    2280 => Str,             # language_handler
    2281 => Str,             # internal
    2282 => Str,             # opaque
    2283 => Str,             # anyelement
    2287 => Array[Str],      # Array(_record)
    2776 => Str,             # anynonarray
    2949 => Array[Str],      # Array(txid_snapshot)
    2950 => Str,             # uuid
    2951 => Array[Str],      # Array(uuid)
    2970 => Str,             # txid_snapshot
    3115 => Str,             # fdw_handler
    3221 => Array[Str],      # Array(pg_lsn)
    3310 => Str,             # tsm_handler
    3500 => Str,             # anyenum
    3614 => Str,             # tsvector
    3615 => Str,             # tsquery
    3642 => Str,             # gtsvector
    3643 => Array[Str],      # Array(tsvector)
    3644 => Array[Str],      # Array(gtsvector)
    3645 => Array[Str],      # Array(tsquery)
    3734 => Str,             # regconfig
    3735 => Array[Str],      # Array(regconfig)
    3769 => Str,             # regdictionary
    3770 => Array[Str],      # Array(regdictionary)
    3802 => Str,             # jsonb
    3807 => Array[Str],      # Array(jsonb)
    3831 => Str,             # anyrange
    3838 => Str,             # event_trigger
    3904 => Str,             # int4range
    3905 => Array[Str],      # Array(int4range)
    3906 => Str,             # numrange
    3907 => Array[Str],      # Array(numrange)
    3908 => Str,             # tsrange
    3909 => Array[Str],      # Array(tsrange)
    3910 => Str,             # tstzrange
    3911 => Array[Str],      # Array(tstzrange)
    3912 => Str,             # daterange
    3913 => Array[Str],      # Array(daterange)
    3926 => Str,             # int8range
    3927 => Array[Str],      # Array(int8range)
);

constant CONNECTION_OK         is export = 0;
constant CONNECTION_BAD        is export = 1;

constant PGRES_EMPTY_QUERY     is export = 0;
constant PGRES_COMMAND_OK      is export = 1;
constant PGRES_TUPLES_OK       is export = 2;
constant PGRES_COPY_OUT        is export = 3;
constant PGRES_COPY_IN         is export = 4;
constant PGRES_BAD_RESPONSE    is export = 5;
constant PGRES_NON_FATAL_ERROR is export = 6;
constant PGRES_FATAL_ERROR     is export = 7;
constant PGRES_COPY_BOTH       is export = 8;
constant PGRES_SINGLE_TUPLE    is export = 9;

enum ResultErrorField is export (
    PG_DIAG_SEVERITY              => ord('S'),
    PG_DIAG_SEVERITY_NONLOCALIZED => ord('V'),
    PG_DIAG_SQLSTATE              => ord('C'),
    PG_DIAG_MESSAGE_PRIMARY       => ord('M'),
    PG_DIAG_MESSAGE_DETAIL        => ord('D'),
    PG_DIAG_MESSAGE_HINT          => ord('H'),
    PG_DIAG_STATEMENT_POSITION    => ord('P'),
    PG_DIAG_INTERNAL_POSITION     => ord('p'),
    PG_DIAG_INTERNAL_QUERY        => ord('q'),
    PG_DIAG_CONTEXT               => ord('W'),
    PG_DIAG_SCHEMA_NAME           => ord('s'),
    PG_DIAG_TABLE_NAME            => ord('t'),
    PG_DIAG_COLUMN_NAME           => ord('c'),
    PG_DIAG_DATATYPE_NAME         => ord('d'),
    PG_DIAG_CONSTRAINT_NAME       => ord('n'),
    PG_DIAG_SOURCE_FILE           => ord('F'),
    PG_DIAG_SOURCE_LINE           => ord('L'),
    PG_DIAG_SOURCE_FUNCTION       => ord('R'),
);

# vim: ft=perl6 et
