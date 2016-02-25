use v6;

unit module DBDish::Pg::Native;
use NativeCall :ALL;

sub MyLibName {
    %*ENV<DBIISH_PG_LIB> || guess_library_name(('pq', v5));
}
constant LIB = &MyLibName;

#------------ My Visible Pointers

class PGresult	is export is repr('CPointer') {
    method PQclear is native(LIB) { * }
    method PQcmdTuples(--> str) is native(LIB) { * }
    method PQfname(int32 --> str) is native(LIB) { * }
    method PQftype(int32 --> int32) is native(LIB) { * };
    method PQgetisnull(int32, int32 --> int32) is native(LIB) { * }
    method PQgetvalue(int32, int32 --> str) is native(LIB) { * }
    method PQnfields(--> int32) is native(LIB) { * }
    method PQnparams(--> int32) is native(LIB) { * }
    method PQntuples(--> int32) is native(LIB) { * }
    method PQresultErrorMessage(--> str) is native(LIB) { * }
    method PQresultStatus(--> int32) is native(LIB) { * }

    method is-ok {
	self.PQresultStatus ~~ (0 .. 4);
    }
}

class Oid is export is repr('CPointer') { }

class PGconn is export is repr('CPointer') {
    method PQexec(--> PGresult) is native(LIB) { * }
    method PQexecPrepared(
        str $statement_name,
        int32 $n_params,
        CArray[Str] $param_values,
        CArray[int32] $param_length,
        CArray[int32] $param_formats,
        int32 $resultFormat
    ) returns PGresult is native(LIB) { * }

    method PQerrorMessage(--> str) is native(LIB) { * }
    method PQdescribePrepared(str --> PGresult) is native(LIB) { * }
    method PQstatus(--> int32) is native(LIB) { * }
    method PQprepare(str $sth_name, str $query, int32 $n_params, Oid $paramTypes --> PGresult)
	is native(LIB) { * }
    method PQfinish is native(LIB) { * }

    method new(Str $conninfo) { # Our constructor
	sub PQconnectdb(str --> PGconn) is native(LIB) { * };
	PQconnectdb($conninfo);
    }
}

constant Null is export = Pointer;
constant ParamArray is export = CArray[Str];

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
