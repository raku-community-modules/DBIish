use v6;
use Test;
use NativeCall::TypeDiag;
use DBDish::SQLite::Native;

my @headers = <sqlite3.h>;
my @libs = <-lsqlite3>;
my @fun;
my %typ;

#Turn this False if something fail
$NativeCall::TypeDiag::silent = False;

for DBDish::SQLite::Native::EXPORT::DEFAULT::.keys -> $export {
  if ::($export).REPR eq 'CStruct' {
    %typ{$export} = ::($export);
  }
  if ::($export).does(Callable) and ::($export).^roles.perl ~~ /NativeCall/ {
     @fun.push(::($export));
  }
}

plan 1;

#ok diag-cstructs(:cheaders(@headers), :types(%typ), :clibs(@libs)), "CStruct definition are correct";
ok diag-functions(:functions(@fun)), "Functions signature are good";
