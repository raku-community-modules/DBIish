use v6;

unit module DBDish::Pg::Native;
use NativeCall :ALL :EXPORT;

sub MyLibName {
    %*ENV<DBIISH_PG_LIB> || guess_library_name(('pq', v5));
}
constant LIB = &MyLibName;

#------------ Pg library functions in alphabetical order ------------

sub PQexec (OpaquePointer $conn, str $statement)
    returns OpaquePointer
    is native(LIB)
    is export
    { ... }

sub PQprepare (OpaquePointer $conn, str $statement_name, str $query, int32 $n_params, OpaquePointer $paramTypes)
    returns OpaquePointer
    is native(LIB)
    is export
    { ... }

sub PQexecPrepared(
        OpaquePointer $conn,
        str $statement_name,
        int32 $n_params,
        CArray[Str] $param_values,
        CArray[int32] $param_length,
        CArray[int32] $param_formats,
        int32 $resultFormat
    )
    returns OpaquePointer
    is native(LIB)
    is export
    { ... }

sub PQnparams (OpaquePointer)
    returns int32
    is native(LIB)
    is export
    { ... }

sub PQdescribePrepared (OpaquePointer, str)
    returns OpaquePointer
    is native(LIB)
    is export
    { ... }


sub PQresultStatus (OpaquePointer $result)
    returns int32
    is native(LIB)
    is export
    { ... }

sub PQerrorMessage (OpaquePointer $conn)
    returns str
    is native(LIB)
    is export
    { ... }

sub PQresultErrorMessage (OpaquePointer $result)
    returns str
    is native(LIB)
    is export
    { ... }

sub PQconnectdb (str $conninfo)
    returns OpaquePointer
    is native(LIB)
    is export
    { ... }

sub PQstatus (OpaquePointer $conn)
    returns int32
    is native(LIB)
    is export
    { ... }

sub PQnfields (OpaquePointer $result)
    returns int32
    is native(LIB)
    is export
    { ... }

sub PQntuples (OpaquePointer $result)
    returns int32
    is native(LIB)
    is export
    { ... }

sub PQcmdTuples (OpaquePointer $result)
    returns str
    is native(LIB)
    is export
    { ... }

sub PQgetvalue (OpaquePointer $result, int32 $row, int32 $col)
    returns Str
    is native(LIB)
    is export
    { ... }

sub PQgetisnull (OpaquePointer $result, int32 $row, int32 $col)
    returns int32
    is native(LIB)
    is export
    { ... }

sub PQfname (OpaquePointer $result, int32 $col)
    returns str
    is native(LIB)
    is export
    { ... }

sub PQclear (OpaquePointer $result)
    is native(LIB)
    is export
    { ... }

sub PQfinish(OpaquePointer) 
    is native(LIB)
    is export
    { ... }

sub PQftype(OpaquePointer, int32)
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
       700  => 'Rat',   # float4
       701  => 'Rat',   # float8
      1000  => 'Bool',  # _bool
      1001  => 'Buf',   # _bytea
      1005  => 'Array<Int>',     # Array(int2)
      1007  => 'Array<Int>',     # Array(int4)
      1009  => 'Array<Str>',     # Array(text)
      1015  => 'Str',            # _varchar

      1021  => 'Array<Rat>',     # Array(float4)
      1022  => 'Array<Rat>',     # Array(float4)
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
