use v6;

unit module NativeLibs:auth<sortiz>:ver<0.0.1>;
use NativeCall :ALL;

class Searcher {
    method !test($try, $wks) {
	(try cglobal($try, $wks, Pointer)) ~~ Pointer ?? $try !! Nil
    }
    method search(Str $libname, Str $wks, *@vers) {
	my $wlibname;
	for @vers {
	    my $ver = $_.defined ?? Version.new($_) !! Version;
	    $wlibname = $_ and last with self!test:
		$*VM.platform-library-name($libname.IO, :version($ver)).Str, $wks;
	}
	$wlibname //= self!test: guess_library_name($libname), $wks unless @vers;
	$wlibname;
    }
    method at-runtime($libname, $wks, *@vers) {
	-> {
	    with self.search($libname, $wks, |@vers) {
		$_
	    } else {
		# The sensate thing to do is die, but somehow that don't work
		# so let NC::!setup die for us returning $libname.
		# die "Cannot locate native library '$libname'"
		$libname;
	    }
	}
    }
}
# Reexport all NativeCall
CHECK for NativeCall::EXPORT::.keys {
    UNIT::EXPORT::{$_} := NativeCall::EXPORT::{$_};
}
