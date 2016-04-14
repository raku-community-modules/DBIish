use v6;

unit module NativeLibs:auth<sortiz>:ver<0.0.2>;
use NativeCall :ALL;

class Loader {
    # Right now NC::cglobal unload loaded libraries too fast, so we need our own loader
    class DLLib is repr('CPointer') { };
    has Str   $.name;
    has DLLib $.library;

    method load(::?CLASS:U: $libname) {
	my sub dlLoadLibrary(Str -->DLLib) is native { * };
	with dlLoadLibrary($libname) {
	    self.bless(:name($libname), :library($_));
	} else {
	    die "Cannot load native library '$libname'";
	}
    }
    method dispose {
	sub dlFreeLibrary(DLLib) is native { * };
	with $!library {
	    dlFreeLibrary($_);
	    $_ = Nil;
	}
    }
}

class Searcher {
    method !test($try, $wks) {
	(try cglobal($try, $wks, Pointer)) ~~ Pointer ?? $try !! Nil
    }
    method try-versions(Str $libname, Str $wks, *@vers) {
	my $wlibname;
	for @vers {
	    my $ver = $_.defined ?? Version.new($_) !! Version;
	    $wlibname = $_ and last with self!test:
		$*VM.platform-library-name($libname.IO, :version($ver)).Str, $wks;
	}
	$wlibname //= self!test: $*VM.platform-library-name($libname.IO), $wks
	    unless @vers; # Try unversionized
	$wlibname;
    }
    method at-runtime($libname, $wks, *@vers) {
	-> {
	    with self.try-versions($libname, $wks, |@vers) {
		$_
	    } else {
		# The sensate thing to do is die, but somehow that don't work
		#   ( 'Cannot invoke this object' ... )
		# so let NC::!setup die for us returning $libname.
		# die "Cannot locate native library '$libname'"
		$libname;
	    }
	}
    }
}
# Reexport on demand all of NativeCall
CHECK for NativeCall::EXPORT::.keys {
    UNIT::EXPORT::{$_} := NativeCall::EXPORT::{$_};
}
