use v6;

unit module DBDish::mysql::Native;
use NativeCall :ALL;
use NativeHelpers::Blob;

sub MyLibName {
    %*ENV<DBIISH_MYSQL_LIB> || guess_library_name(('mysqlclient', v18));
}
constant LIB = &MyLibName;

#From mysql_com.h
enum mysql-field-type is export (
  MYSQL_TYPE_DECIMAL => 0,
  MYSQL_TYPE_TINY => 1,
  MYSQL_TYPE_SHORT => 2,
  MYSQL_TYPE_LONG => 3,
  MYSQL_TYPE_FLOAT => 4,
  MYSQL_TYPE_DOUBLE => 5,
  MYSQL_TYPE_NULL => 6,
  MYSQL_TYPE_TIMESTAMP => 7,
  MYSQL_TYPE_LONGLONG => 8,
  MYSQL_TYPE_INT24 => 9,
  MYSQL_TYPE_DATE => 10,
  MYSQL_TYPE_TIME => 11,
  MYSQL_TYPE_DATETIME => 12,
  MYSQL_TYPE_YEAR => 13,
  MYSQL_TYPE_NEWDATE => 14,
  MYSQL_TYPE_VARCHAR => 15,
  MYSQL_TYPE_BIT => 16,
  MYSQL_TYPE_NEWDECIMAL => 246,
  MYSQL_TYPE_ENUM => 247,
  MYSQL_TYPE_SET => 248,
  MYSQL_TYPE_TINY_BLOB => 249,
  MYSQL_TYPE_MEDIUM_BLOB => 250,
  MYSQL_TYPE_LONG_BLOB => 251,
  MYSQL_TYPE_BLOB => 252,
  MYSQL_TYPE_VAR_STRING => 253,
  MYSQL_TYPE_STRING => 254,
  MYSQL_TYPE_GEOMETRY => 255
);

class MYSQL_FIELD is repr('CStruct') is export {
    has	Str	$.name;
    has Str	$.org_name;
    has Str	$.table;
    has Str	$.org_table;
    has Str	$.db;
    has Str	$.catalog;
    has	Str	$.def;
    has ulong	$.length;
    has ulong	$.max_length;
    has uint32	$.name_length;
    has uint32	$.org_name_length;
    has uint32	$.table_length;
    has	uint32	$.org_table_length;
    has uint32	$.db_length;
    has uint32	$.catalog_length;
    has uint32	$.def_length;
    has uint32	$.flags;
    has uint32	$.decimals;
    has uint32	$.charsetnr;
    has int32	$.type;
    has Pointer $.extension;
}

constant my_bool = int8;

class MYSQL_RES is repr('CPointer') { ... }

# Current rakudo don't allow set a Pointer in a CStruct based class.
# so we use an 'intprt'
constant intptr = nativesizeof(Pointer) == 8 ?? uint64 !! uint32;
class MYSQL_BIND is repr('CStruct') is export {
    #has Pointer[ulong]   $!length is rw;
    has intptr		 $.length is rw;
    #has Pointer[my_bool] $.is_null is rw;
    has intptr		 $.is_null is rw;
    #has Pointer	  $.buffer is rw;
    has intptr		 $.buffer is rw;
    has Pointer[my_bool] $.error;
    has Pointer[uint8]   $.row_ptr;
    has Pointer		 $.store_param_func;
    has Pointer		 $.fetch_result;
    has Pointer		 $.skip_result;
    has ulong		 $.buffer_length is rw;
    has ulong		 $.offset;
    has size_t		 $.param_number is rw;
    has size_t		 $.pack_length;
    has uint32		 $.buffer_type is rw;
    has my_bool		 $.error_value;
    has my_bool		 $.is_unsigned;
    has my_bool		 $.long_data_user;
    has my_bool		 $.is_null_value;
    has Pointer		 $.extension;
}

#note "MYSQL_BIND size: ", nativesizeof(MYSQL_BIND), nativesizeof(CArray[MYSQL_BIND]);

class MyRow does Positional is export {
    has CArray[Pointer] $.car;
    has MYSQL_RES $.rs;
    has $.lon;

    method AT-POS(int $idx) {
	with $!car[$idx] {
	    nativecast(Str, $_);
	} else { Str }
    }
    method want(Int $idx, Mu $t) {
	if $t ~~ Blob {
	    self.blob($idx, $t);
	} else {
	    with self[$idx] { $t($_) } else { $t }
	}
    }
    method blob(Int $idx, Mu $type) {
	blob-from-pointer($!car[$idx], :elems($!lon[$idx]), :$type);
    }
}

class MYSQL_STMT is export is repr('CPointer') {
    method mysql_stmt_prepare(::?CLASS:D: Str, ulong	--> int32) is native(LIB) { * }
    method mysql_stmt_param_count(::?CLASS:D:		--> ulong) is native(LIB) { * }
    method mysql_stmt_bind_param(::?CLASS:D: MYSQL_BIND --> int32) is native(LIB) { * }
    method mysql_stmt_execute(::?CLASS:D:		--> int32) is native(LIB) { * }
    method mysql_stmt_free_result(::?CLASS:D:	      --> my_bool) is native(LIB) { * }
    method mysql_stmt_reset(::?CLASS:D:		      --> my_bool) is native(LIB) { * }
    method mysql_stmt_field_count(::?CLASS:D:		--> int32) is native(LIB) { * }
    method mysql_stmt_close(::?CLASS:D:	              --> my_bool) is native(LIB) { * }
    method mysql_stmt_affected_rows(::?CLASS:D:        --> uint64) is native(LIB) { * }
    method mysql_stmt_result_metadata(::?CLASS:D:   --> MYSQL_RES) is native(LIB) { * }
    method mysql_stmt_store_result(::?CLASS:D:		--> int32) is native(LIB) { * }
    method mysql_stmt_fetch(::?CLASS:D:			--> int32) is native(LIB) { * }
    method mysql_stmt_bind_result(::?CLASS:D:
	MYSQL_BIND				      --> my_bool) is native(LIB) { * }
};

class MYSQL_RES is export {
    method fetch_row(MYSQL_RES:D: --> MyRow) {
	sub mysql_fetch_row(MYSQL_RES $result_set )
	    returns CArray[Pointer] is native(LIB) { * }
	sub mysql_fetch_lengths(MYSQL_RES)
	    returns CArray[ulong] is native(LIB) { * }

	my $car = mysql_fetch_row(self);
	my $lon = mysql_fetch_lengths(self);

	$car.defined ?? MyRow.new(:$car, :rs(self), :$lon) !! MyRow;
    }

    method mysql_fetch_field(MYSQL_RES:D: --> MYSQL_FIELD) is native(LIB) { * }
    method mysql_free_result(MYSQL_RES:D:                ) is native(LIB) { * }
    method mysql_num_rows(MYSQL_RES:D:         --> uint64) is native(LIB) { * }
}

class MYSQL is export is repr('CPointer') {

    multi method escape(Blob $b, :$bin --> Str) {
	sub mysql_real_escape_string(MYSQL, Blob, Blob, ulong)
	    returns ulong is native(LIB) { * };
	if $bin { # HACK: mysql_real_scape assumes latin1 :(
	    $b.list.fmt('%02x','');
	} else {
	    my \r = blob-allocate(Blob, $b.bytes * 2 + 1);
	    my $res = mysql_real_escape_string(self, r, $b, $b.bytes);
	    r.subbuf(0, $res).decode.Str;
	}
    }
    multi method escape(Str $s --> Str) {
	self.escape($s.encode);
    }

    # Native methods
    method mysql_affected_rows(MYSQL:D:          --> int32) is native(LIB) { * }
    method mysql_close(MYSQL:D:                           ) is native(LIB) { * }
    method mysql_errno(MYSQL:D:                  --> int32) is native(LIB) { * }
    method mysql_error(MYSQL:D:                    --> Str) is native(LIB) { * }
    method mysql_field_count( MYSQL:D:          --> uint32) is native(LIB) { * }
    method mysql_init(MYSQL:U:                   --> MYSQL) is native(LIB) { * }
    method mysql_insert_id(MYSQL:D:             --> uint64) is native(LIB) { * }
    method mysql_query( MYSQL:D: Str $sql        --> int32) is native(LIB) { * }
    method mysql_real_connect(MYSQL:D:
	Str $host, Str $user, Str $password,
	Str $database, int32 $port, Str $socket,
	ulong $flag                              --> MYSQL) is native(LIB) { * }
    method mysql_set_character_set(MYSQL:D:  Str --> int32) is native(LIB) { * }
    method mysql_character_set_name(MYSQL:D:       --> Str) is native(LIB) { * }
    method mysql_store_result(MYSQL:D:       --> MYSQL_RES) is native(LIB) { * }
    method mysql_use_result(MYSQL:D:         --> MYSQL_RES) is native(LIB) { * }
    method mysql_warning_count(MYSQL:D:         --> uint32) is native(LIB) { * }
    method mysql_ping(MYSQL:D:                   --> int32) is native(LIB) { * }
    method mysql_stmt_init(MYSQL:D:         --> MYSQL_STMT) is native(LIB) { * }
}

constant %mysql-type-conv is export = map(
    {+mysql-field-type::{.key} => .value}, (
  MYSQL_TYPE_DECIMAL => Rat,
  MYSQL_TYPE_TINY => Int,
  MYSQL_TYPE_SHORT => Int,
  MYSQL_TYPE_LONG => Int,
  MYSQL_TYPE_FLOAT => Num,
  MYSQL_TYPE_DOUBLE => Num,
  MYSQL_TYPE_NULL => Str,
  MYSQL_TYPE_TIMESTAMP => Int,
  MYSQL_TYPE_LONGLONG => Int,
  MYSQL_TYPE_INT24 => Int,
  MYSQL_TYPE_DATE => Str,
  MYSQL_TYPE_TIME => Str,
  MYSQL_TYPE_DATETIME => Str,
  MYSQL_TYPE_YEAR => Int,
  MYSQL_TYPE_NEWDATE => Str,
  MYSQL_TYPE_VARCHAR => Str,
  MYSQL_TYPE_BIT => Int,
  MYSQL_TYPE_NEWDECIMAL => Rat,
  MYSQL_TYPE_ENUM => Str,
  MYSQL_TYPE_VAR_STRING  => Str,
  MYSQL_TYPE_STRING  => Str,
  MYSQL_TYPE_TINY_BLOB => Buf,
  MYSQL_TYPE_MEDIUM_BLOB => Buf,
  MYSQL_TYPE_LONG_BLOB => Buf,
  MYSQL_TYPE_BLOB => Buf,
)).hash;


