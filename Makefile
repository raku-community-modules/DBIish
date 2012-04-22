# Makefile for MiniDBI

PERL_EXE  = perl
PERL6_EXE = perl6
CP        = $(PERL_EXE) -MExtUtils::Command -e cp
MKPATH    = $(PERL_EXE) -MExtUtils::Command -e mkpath
RM_F      = $(PERL_EXE) -MExtUtils::Command -e rm_f
TEST_F    = $(PERL_EXE) -MExtUtils::Command -e test_f
# try to make these OS agnostic (ie use the same definition on Unix and Windows)
LIBSYSTEM = $(shell $(PERL6_EXE) -e 'print @*INC[2]')
LIBUSER   = $(shell $(PERL6_EXE) -e 'print @*INC[1]')

# first (therefore default) target is MiniDBI.pir
all: lib/MiniDBI.pir

lib/MiniDBD.pir: lib/MiniDBD.pm6
	$(PERL6_EXE) --target=pir --output=lib/MiniDBD.pir lib/MiniDBD.pm6

lib/MiniDBD/CSV.pir: lib/MiniDBD/CSV.pm6 lib/MiniDBD.pir
	export PERL6LIB=lib; $(PERL6_EXE) --target=pir --output=lib/MiniDBD/CSV.pir lib/MiniDBD/CSV.pm6

lib/MiniDBD/mysql.pir: lib/MiniDBD/mysql.pm6 lib/MiniDBD.pir
	export PERL6LIB=lib; $(PERL6_EXE) --target=pir --output=lib/MiniDBD/mysql.pir lib/MiniDBD/mysql.pm6

lib/MiniDBD/Pg.pir: lib/MiniDBD/Pg.pm6 lib/MiniDBD.pir
	export PERL6LIB=lib; $(PERL6_EXE) --target=pir --output=lib/MiniDBD/Pg.pir lib/MiniDBD/Pg.pm6

lib/MiniDBD/PgPir.pir: lib/MiniDBD/PgPir.pm6 lib/MiniDBD.pir
	export PERL6LIB=lib; $(PERL6_EXE) --target=pir --output=lib/MiniDBD/PgPir.pir lib/MiniDBD/PgPir.pm6

lib/MiniDBD/SQLite.pir: lib/MiniDBD/SQLite.pm6 lib/MiniDBD.pir
	export PERL6LIB=lib; $(PERL6_EXE) --target=pir --output=lib/MiniDBD/SQLite.pir lib/MiniDBD/SQLite.pm6

lib/MiniDBI.pir: lib/MiniDBI.pm6 lib/MiniDBD/CSV.pir lib/MiniDBD/mysql.pir lib/MiniDBD/PgPir.pir lib/MiniDBD/Pg.pir lib/MiniDBD/SQLite.pir
	export PERL6LIB=lib; $(PERL6_EXE) --target=pir --output=lib/MiniDBI.pir lib/MiniDBI.pm6

test: lib/MiniDBI.pir lib/MiniDBD/CSV.pir lib/MiniDBD/mysql.pir lib/MiniDBD/PgPir.pir lib/MiniDBD/Pg.pir lib/MiniDBD/SQLite.pir
	@#export PERL6LIB=lib; prove --exec $(PERL6_EXE) t/10-mysql.t
	@#export PERL6LIB=lib; prove --exec $(PERL6_EXE) t/20-CSV-common.t
	@#export PERL6LIB=lib; prove --exec $(PERL6_EXE) t/25-mysql-common.t
	@#export PERL6LIB=lib; prove --exec $(PERL6_EXE) t/30-pgpir.t
	export PERL6LIB=lib; prove --exec $(PERL6_EXE) t/

# standard install is to the shared system wide directory
install: lib/MiniDBI.pir lib/MiniDBD.pir lib/MiniDBD/mysql.pir lib/MiniDBD/PgPir.pir lib/MiniDBD/Pg.pir lib/MiniDBD/SQLite.pir
	@echo "--> $(LIBSYSTEM)"
	@$(CP) lib/MiniDBI.pm6 lib/MiniDBI.pir $(LIBSYSTEM)
	@$(CP) lib/MiniDBD.pm6 lib/MiniDBD.pir $(LIBSYSTEM)
	@$(MKPATH) $(LIBSYSTEM)/MiniDBD
	@$(CP) lib/MiniDBD/CSV.pm6 lib/MiniDBD/CSV.pir $(LIBSYSTEM)/MiniDBD
	@$(CP) lib/MiniDBD/mysql.pm6 lib/MiniDBD/mysql.pir $(LIBSYSTEM)/MiniDBD
	@$(CP) lib/MiniDBD/PgPir.pm6 lib/MiniDBD/PgPir.pir $(LIBSYSTEM)/MiniDBD
	@$(CP) lib/MiniDBD/Pg.pm6 lib/MiniDBD/Pg.pir $(LIBSYSTEM)/MiniDBD
	@$(CP) lib/MiniDBD/SQLite.pm6 lib/MiniDBD/SQLite.pir $(LIBSYSTEM)/MiniDBD

# if user has no permission to install globally, try a personal directory 
install-user: lib/MiniDBI.pir lib/MiniDBD.pir lib/MiniDBD/mysql.pir lib/MiniDBD/PgPir.pir lib/MiniDBD/Pg.pir lib/MiniDBD/SQLite.pir
	@echo "--> $(LIBUSER)"
	@$(CP) lib/MiniDBI.pm6 lib/MiniDBI.pir $(LIBUSER)
	@$(CP) lib/MiniDBD.pm6 lib/MiniDBD.pir $(LIBUSER)
	@$(MKPATH) $(LIBUSER)/MiniDBD
	@$(CP) lib/MiniDBD/CSV.pm6 lib/MiniDBD/CSV.pir $(LIBUSER)/MiniDBD
	@$(CP) lib/MiniDBD/mysql.pm6 lib/MiniDBD/mysql.pir $(LIBUSER)/MiniDBD
	@$(CP) lib/MiniDBD/PgPir.pm6 lib/MiniDBD/PgPir.pir $(LIBUSER)/MiniDBD
	@$(CP) lib/MiniDBD/Pg.pm6 lib/MiniDBD/Pg.pir $(LIBUSER)/MiniDBD
	@$(CP) lib/MiniDBD/SQLite.pm6 lib/MiniDBD/SQLite.pir $(LIBUSER)/MiniDBD

# Uninstall from the shared system wide directory.
# This might leave an empty MiniDBD subdirectory behind.
uninstall:
	@echo "x-> $(LIBSYSTEM)"
	@$(TEST_F) $(LIBSYSTEM)/MiniDBI.pm6
	@$(RM_F)   $(LIBSYSTEM)/MiniDBD.pm6
	@$(TEST_F) $(LIBSYSTEM)/MiniDBI.pir
	@$(RM_F)   $(LIBSYSTEM)/MiniDBD.pir
	@$(TEST_F) $(LIBSYSTEM)/MiniDBD/CSV.pm6
	@$(RM_F)   $(LIBSYSTEM)/MiniDBD/CSV.pm6
	@$(TEST_F) $(LIBSYSTEM)/MiniDBD/CSV.pir
	@$(RM_F)   $(LIBSYSTEM)/MiniDBD/CSV.pir
	@$(TEST_F) $(LIBSYSTEM)/MiniDBD/mysql.pm6
	@$(RM_F)   $(LIBSYSTEM)/MiniDBD/mysql.pm6
	@$(TEST_F) $(LIBSYSTEM)/MiniDBD/mysql.pir
	@$(RM_F)   $(LIBSYSTEM)/MiniDBD/mysql.pir
	@$(TEST_F) $(LIBSYSTEM)/MiniDBD/PgPir.pm6
	@$(RM_F)   $(LIBSYSTEM)/MiniDBD/PgPir.pm6
	@$(TEST_F) $(LIBSYSTEM)/MiniDBD/PgPir.pir
	@$(RM_F)   $(LIBSYSTEM)/MiniDBD/PgPir.pir
	@$(TEST_F) $(LIBSYSTEM)/MiniDBD/Pg.pm6
	@$(RM_F)   $(LIBSYSTEM)/MiniDBD/Pg.pm6
	@$(TEST_F) $(LIBSYSTEM)/MiniDBD/Pg.pir
	@$(RM_F)   $(LIBSYSTEM)/MiniDBD/Pg.pir
	@$(TEST_F) $(LIBSYSTEM)/MiniDBD/SQLite.pm6
	@$(RM_F)   $(LIBSYSTEM)/MiniDBD/SQLite.pm6
	@$(TEST_F) $(LIBSYSTEM)/MiniDBD/SQLite.pir
	@$(RM_F)   $(LIBSYSTEM)/MiniDBD/SQLite.pir

# Uninstall from the user's own Perl 6 directory.
# This might leave an empty MiniDBD subdirectory behind.
uninstall-user:
	@echo "x-> $(LIBUSER)"
	@$(TEST_F) $(LIBUSER)/MiniDBI.pm6
	@$(RM_F)   $(LIBUSER)/MiniDBI.pm6
	@$(TEST_F) $(LIBUSER)/MiniDBI.pir
	@$(RM_F)   $(LIBUSER)/MiniDBI.pir
	@$(TEST_F) $(LIBUSER)/MiniDBD/CSV.pm6
	@$(RM_F)   $(LIBUSER)/MiniDBD/CSV.pm6
	@$(TEST_F) $(LIBUSER)/MiniDBD/CSV.pir
	@$(RM_F)   $(LIBUSER)/MiniDBD/CSV.pir
	@$(TEST_F) $(LIBUSER)/MiniDBD/mysql.pm6
	@$(RM_F)   $(LIBUSER)/MiniDBD/mysql.pm6
	@$(TEST_F) $(LIBUSER)/MiniDBD/mysql.pir
	@$(RM_F)   $(LIBUSER)/MiniDBD/mysql.pir
	@$(TEST_F) $(LIBUSER)/MiniDBD/PgPir.pm6
	@$(RM_F)   $(LIBUSER)/MiniDBD/PgPir.pm6
	@$(TEST_F) $(LIBUSER)/MiniDBD/PgPir.pir
	@$(RM_F)   $(LIBUSER)/MiniDBD/PgPir.pir
	@$(TEST_F) $(LIBUSER)/MiniDBD/Pg.pm6
	@$(RM_F)   $(LIBUSER)/MiniDBD/Pg.pm6
	@$(TEST_F) $(LIBUSER)/MiniDBD/Pg.pir
	@$(RM_F)   $(LIBUSER)/MiniDBD/Pg.pir
	@$(TEST_F) $(LIBUSER)/MiniDBD/SQLite.pm6
	@$(RM_F)   $(LIBUSER)/MiniDBD/SQLite.pm6
	@$(TEST_F) $(LIBUSER)/MiniDBD/SQLite.pir
	@$(RM_F)   $(LIBUSER)/MiniDBD/SQLite.pir

clean:
	@# delete compiled files
	$(RM_F) lib/*.pir lib/MiniDBD/*.pir
	@# delete all editor backup files
	$(RM_F) *~ lib/*~ t/*~ lib/MiniDBD/*~

help:
	@echo
	@echo "You can make the following in 'MiniDBI':"
	@echo "clean          removes compiled, temporary and backup files"
	@echo "test           runs a local test suite"
	@echo "install        copies .pm and .pir files to system perl6 lib/"
	@echo "               (may require admin or root permission)"
	@echo "uninstall      removes .pm6 and .pir file(s) from system lib/"
	@echo "install-user   copies .pm and .pir files to user perl6 lib/"
	@echo "uninstall-user removes .pm6 and .pir file(s) from user perl6 lib/"

