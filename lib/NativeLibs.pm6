use v6;

unit module NativeLibs:auth<sortiz>:ver<0.0.3>;
use NativeCall :ALL;

our constant is-win = Rakudo::Internals.IS-WIN();

our proto sub cannon-name(|) { * }
multi sub cannon-name(Str $libname, Version $version = Version) {
    with $libname.IO {
	if .extension {
	    .Str; # Assume resolved, so don't touch
	} else {
	    $*VM.platform-library-name($_, :$version).Str;
	}
    }
}
multi sub cannon-name(Str $libname, Cool $ver) {
    cannon-name($libname, Version.new($ver));
}

class Loader {
    # Right now NC::cglobal unload loaded libraries too fast, so we need our own loader
    class DLLib is repr('CPointer') { };

    my \dyncall = $*VM.config<nativecall_backend> eq 'dyncall';

    has Str   $.name;
    has DLLib $.library;

    my sub dlerror(--> Str)         is native { * } # For linux or darwin/OS X
    my sub GetLastError(--> uint32) is native('kernel32') { * } # On Microsoft land
    method !dlerror() {
	given $*VM.config<osname>.lc {
	    when 'linux' | 'darwin' {
		dlerror() // '';
	    }
	    when 'mswin32' | 'mingw' | 'msys' | 'cygwin' {
		"error({ GetLastError })";
	    }
	}
    }

    my sub dlLoadLibrary(Str --> DLLib)  is native { * } # dyncall
    my sub dlopen(Str, uint32 --> DLLib) is native { * } # libffi
    my sub LoadLibraryA(Str --> DLLib) is native('kernel32') { * }
    method !dlLoadLibrary(Str $libname --> DLLib) {
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

    sub dlFreeLibrary(DLLib) is native { * };
    method dispose {
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
	return $wlibname unless $libname; # Nothing to test
	for @vers {
	    my $ver = $_.defined ?? Version.new($_) !! Version;
	    $wlibname = $_ and last with self!test:
		cannon-name($libname, $ver), $wks;
	}
	# Try unversionized
	$wlibname //= self!test: cannon-name($libname), $wks unless @vers;
	# Try common practice in Windows;
	$wlibname //= self!test: "lib$libname.dll", $wks;
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
