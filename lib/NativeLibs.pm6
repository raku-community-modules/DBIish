use v6;

unit module NativeLibs:auth<sortiz>:ver<0.0.2>;
use NativeCall :ALL;

our constant is-win = Rakudo::Internals.IS-WIN();

class Loader {
    # Right now NC::cglobal unload loaded libraries too fast, so we need our own loader
    class DLLib is repr('CPointer') { };

    my \dyncall = $*VM.config<nativecall_backend> eq 'dyncall';

    has Str   $.name;
    has DLLib $.library;

    method !dlerror() {
	my sub dlerror(--> Str)         is native { * } # For linux or darwin/OS X
	my sub GetLastError(--> uint32) is native('kernel32') { * } # On Microsoft land
	given $*VM.config<osname>.lc {
	    when 'linux' | 'darwin' {
		dlerror() // '';
	    }
	    when 'mswin32' | 'mingw' | 'msys' | 'cygwin' {
		"error({ GetLastError })";
	    }
	}
    }

    method !dlLoadLibrary(Str $libname --> DLLib) {
	my sub dlLoadLibrary(Str --> DLLib)  is native { * } # dyncall
	my sub dlopen(Str, uint32 --> DLLib) is native { * } # libffi
        my sub LoadLibraryA(Str --> DLLib) is native('kernel32') { * }

        is-win  ?? LoadLibraryA($libname) !!
        dyncall ?? dlLoadLibrary($libname) !!
        dlopen($libname, 0x102); # RTLD_GLOBAL | RTLD_NOW

    }

    method load(::?CLASS:U: $libname) {
	with self!dlLoadLibrary($libname) {
	    self.bless(:name($libname), :library($_));
	} else {
	    fail "Cannot load native library '$libname'" ~ self!dlerror();
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
    method !test(Str() $try, $wks) {
	(try cglobal($try, $wks, Pointer)) ~~ Pointer ?? $try !! Nil
    }
    method try-versions(Str $libname, Str $wks, *@vers) {
	my $wlibname;
	for @vers {
	    my $ver = $_.defined ?? Version.new($_) !! Version;
	    $wlibname = $_ and last with self!test:
		$*VM.platform-library-name($libname.IO, :version($ver)), $wks;
	}
	$wlibname //= self!test: $*VM.platform-library-name($libname.IO), $wks
	    unless @vers; # Try unversionized
	# Try common practice in Windows;
	$wlibname //= self!test: $*VM.platform-library-name("lib$libname".IO), $wks;
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
