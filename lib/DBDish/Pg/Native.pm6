use v6;

unit module DBDish::Pg::Native;
use NativeCall :ALL;

sub MyLibName {
    %*ENV<DBIISH_PG_LIB> || guess_library_name(('pq', v5));
}
constant LIB = &MyLibName;

#------------ My Visible Pointers

class PGconn is export is repr('CPointer') { };
class PGresult	is export is repr('CPointer') { };
class Oid	is export is repr('CPointer') { };

#------------ Pg library functions in alphabetical order ------------

sub PQexec (PGconn $conn, str $statement)
    returns PGresult
    is native(LIB)
    is export
    { ... }

sub PQprepare (PGconn $conn, str $statement_name, str $query, int32 $n_params, Oid $paramTypes)
    returns PGresult
    is native(LIB)
    is export
    { ... }

sub PQexecPrepared(
        PGconn $conn,
        str $statement_name,
        int32 $n_params,
        CArray[Str] $param_values,
        CArray[int32] $param_length,
        CArray[int32] $param_formats,
        int32 $resultFormat
    )
    returns PGresult
    is native(LIB)
    is export
    { ... }

sub PQnparams (OpaquePointer)
    returns int32
    is native(LIB)
    is export
    { ... }

sub PQdescribePrepared (PGconn, str)
    returns OpaquePointer
    is native(LIB)
    is export
    { ... }


sub PQresultStatus (PGresult $result)
    returns int32
    is native(LIB)
    is export
    { ... }

sub PQerrorMessage (PGconn $conn)
    returns str
    is native(LIB)
    is export
    { ... }

sub PQresultErrorMessage (PGresult $result)
    returns str
    is native(LIB)
    is export
    { ... }

sub PQconnectdb (str $conninfo)
    returns PGconn
    is native(LIB)
    is export
    { ... }

sub PQstatus (PGconn $conn)
    returns int32
    is native(LIB)
    is export
    { ... }

sub PQnfields (PGresult $result)
    returns int32
    is native(LIB)
    is export
    { ... }

sub PQntuples (PGresult $result)
    returns int32
    is native(LIB)
    is export
    { ... }

sub PQcmdTuples (PGresult $result)
    returns str
    is native(LIB)
    is export
    { ... }

sub PQgetvalue (PGresult $result, int32 $row, int32 $col)
    returns Str
    is native(LIB)
    is export
    { ... }

sub PQgetisnull (PGresult $result, int32 $row, int32 $col)
    returns int32
    is native(LIB)
    is export
    { ... }

sub PQfname (PGresult $result, int32 $col)
    returns str
    is native(LIB)
    is export
    { ... }

sub PQclear (PGresult $result)
    is native(LIB)
    is export
    { ... }

sub PQfinish(PGconn)
    is native(LIB)
    is export
    { ... }

sub PQftype(PGresult, int32)
    is native(LIB)
    is export
    returns int32
    { ... }

# from pg_type.h
constant %oid-to-type-name is export = (
        16  => 'Bool',  # bool
        17  => 'Buf',   # bytea
        20  => 'Int',   # int8
        21  => 'Int',   # int2
        23  => 'Int',   # int4
        25  => 'Str',   # text
       700  => 'Num',   # float4
       701  => 'Num',   # float8
      1000  => 'Bool',  # _bool
      1001  => 'Buf',   # _bytea
      1005  => 'Array<Int>',     # Array(int2)
      1007  => 'Array<Int>',     # Array(int4)
      1009  => 'Array<Str>',     # Array(text)
      1015  => 'Str',            # _varchar

      1021  => 'Array<Num>',     # Array(float4)
      1022  => 'Array<Num>',     # Array(float4)
      1028  => 'Array<Int>',     # Array<oid>
      1043  => 'Str',            # varchar
      1114  => 'Str',   # Timestamp
      1263  => 'Array<Str>',     # Array<varchar>
      1700  => 'Real',  # numeric
      2950  => 'Str',   # uuid
      2951  => 'Str',   # _uuid
).hash;


constant CONNECTION_OK         is export = 0;
constant CONNECTION_BAD        is export = 1;

constant PGRES_EMPTY_QUERY = 0;
constant PGRES_COMMAND_OK  = 1;
constant PGRES_TUPLES_OK   = 2;
constant PGRES_COPY_OUT    = 3;
constant PGRES_COPY_IN     = 4;

sub status-is-ok($status)    is export { $status ~~ (0..4) }

#-----------------------------------------------------------------------
