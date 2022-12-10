use v6;
use Test;
use NativeCall::TypeDiag;
use NativeCall :TEST;
use DBDish::Oracle::Native;

#my @headers = <oci.h>;
#my @libs = <-lclntsh>;
my @fun;
my %typ;

#Turn this False if something fail
$NativeCall::TypeDiag::silent = False;

for DBDish::Oracle::Native::EXPORT::DEFAULT::.keys -> $export {
  if ::($export).REPR eq 'CStruct' {
    %typ{$export} = ::($export);
  }
  if ::($export).does(Callable) and ::($export).^roles.perl ~~ /NativeCall/ {
     @fun.push(::($export));
  }
}

plan +@fun;

#ok diag-cstructs(:cheaders(@headers), :types(%typ), :clibs(@libs)), "CStruct definition are correct";
for @fun -> &func {
    my $sane = True;
    my $msg;
    CONTROL {
        when CX::Warn {
            $sane = False;
            $msg = .message;
            .resume;
        }
    }
    check_routine_sanity(&func);
    ok $sane, &func.name ~ " is sane";
    diag $msg unless $sane;
}
