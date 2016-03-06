use v6;

use NativeCall :ALL;

unit module DBDish::mysql::Native;

sub MyLibName {
    %*ENV<DBIISH_MYSQL_LIB> || guess_library_name(('mysqlclient', v18));
}
constant LIB = &MyLibName;

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

class MYSQL_RES is repr('CPointer') { ... }

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
	sub buf-from-pointer(Pointer \ptr, Int :$elems!, Mu :$type = uint8) {
            # Stolen from NativeHelpers::Blob ;-)
	    my sub memcpy(Blob:D $dest, Pointer $src, size_t $size)
		returns Pointer is native() { * };
	    my \t = ptr.of ~~ void ?? $type !! ptr.of;
	    my $b = (t === uint8) ?? Buf !! Buf.^parameterize($type);
	    with ptr {
		$b .= allocate($elems);
		memcpy($b, ptr, $elems * nativesizeof(t));
	    }
	    $b;
	}

	my $itype = $type.HOW ~~ Metamodel::CurriedRoleHOW ??
	    $type.^role_arguments[0] !! uint8;
	buf-from-pointer($!car[$idx], :elems($!lon[$idx]), :type($itype));
    }
}

class MYSQL_STMT is export is repr('CPointer') { };

class MYSQL_RES is export {

    method fetch_row(--> MyRow) {
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
	    my $r = Blob.allocate($b.bytes * 2 + 1);
	    my $res = mysql_real_escape_string(self, $r, $b, $b.bytes);
	    $r.subbuf(0, $res).decode.Str;
	}
    }
    multi method escape(Str $s --> Str) {
	self.escape($s.encode);
    }

    # Native methods
    method mysql_affected_rows(MYSQL:D:          --> int32) is native(LIB) { * }
    method mysql_close(MYSQL:D:                           ) is native(LIB) { * }
    method mysql_errno( MYSQL:D:                 --> int32) is native(LIB) { * }
    method mysql_error( MYSQL:D:                   --> Str) is native(LIB) { * }
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
    method mysql_stmt_init(MYSQL:D:         --> MYSQL_STMT) is native(LIB) { * }
    method mysql_ping(MYSQL:D:                   --> int32) is native(LIB) { * }
}

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

sub mysql_stmt_prepare( OpaquePointer $mysql_stmt, Str, ulong $length )
    returns OpaquePointer
    is native(LIB)
    is export
    { ... }

