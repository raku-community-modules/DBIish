# Makefile for DBIish

PERL_EXE  = perl
PERL6_EXE = perl6
CP        = $(PERL_EXE) -MExtUtils::Command -e cp
MKPATH    = $(PERL_EXE) -MExtUtils::Command -e mkpath
RM_F      = $(PERL_EXE) -MExtUtils::Command -e rm_f
TEST_F    = $(PERL_EXE) -MExtUtils::Command -e test_f
# try to make these OS agnostic (ie use the same definition on Unix and Windows)
LIBSYSTEM = $(shell $(PERL6_EXE) -e 'print @*INC[2]')
LIBUSER   = $(shell $(PERL6_EXE) -e 'print @*INC[1]')

# first (therefore default) target is DBIish.pir
all: lib/DBIish.pir

lib/DBDish.pir: lib/DBDish.pm6
	$(PERL6_EXE) --target=pir --output=lib/DBDish.pir lib/DBDish.pm6

lib/DBDish/CSV.pir: lib/DBDish/CSV.pm6 lib/DBDish.pir
	export PERL6LIB=lib; $(PERL6_EXE) --target=pir --output=lib/DBDish/CSV.pir lib/DBDish/CSV.pm6

lib/DBDish/mysql.pir: lib/DBDish/mysql.pm6 lib/DBDish.pir
	export PERL6LIB=lib; $(PERL6_EXE) --target=pir --output=lib/DBDish/mysql.pir lib/DBDish/mysql.pm6

lib/DBDish/Pg.pir: lib/DBDish/Pg.pm6 lib/DBDish.pir
	export PERL6LIB=lib; $(PERL6_EXE) --target=pir --output=lib/DBDish/Pg.pir lib/DBDish/Pg.pm6

lib/DBDish/SQLite.pir: lib/DBDish/SQLite.pm6 lib/DBDish.pir
	export PERL6LIB=lib; $(PERL6_EXE) --target=pir --output=lib/DBDish/SQLite.pir lib/DBDish/SQLite.pm6

lib/DBIish.pir: lib/DBIish.pm6 lib/DBDish/CSV.pir lib/DBDish/mysql.pir lib/DBDish/Pg.pir lib/DBDish/SQLite.pir
	export PERL6LIB=lib; $(PERL6_EXE) --target=pir --output=lib/DBIish.pir lib/DBIish.pm6

test: lib/DBIish.pir lib/DBDish/CSV.pir lib/DBDish/mysql.pir lib/DBDish/Pg.pir lib/DBDish/SQLite.pir
	@#export PERL6LIB=lib; prove --exec $(PERL6_EXE) t/10-mysql.t
	@#export PERL6LIB=lib; prove --exec $(PERL6_EXE) t/20-CSV-common.t
	@#export PERL6LIB=lib; prove --exec $(PERL6_EXE) t/25-mysql-common.t
	@#export PERL6LIB=lib; prove --exec $(PERL6_EXE) t/30-pgpir.t
	export PERL6LIB=lib; prove --exec $(PERL6_EXE) t/

# standard install is to the shared system wide directory
install: lib/DBIish.pir lib/DBDish.pir lib/DBDish/mysql.pir lib/DBDish/Pg.pir lib/DBDish/SQLite.pir
	@echo "--> $(LIBSYSTEM)"
	@$(CP) lib/DBIish.pm6 lib/DBIish.pir $(LIBSYSTEM)
	@$(CP) lib/DBDish.pm6 lib/DBDish.pir $(LIBSYSTEM)
	@$(MKPATH) $(LIBSYSTEM)/DBDish
	@$(CP) lib/DBDish/CSV.pm6 lib/DBDish/CSV.pir $(LIBSYSTEM)/DBDish
	@$(CP) lib/DBDish/mysql.pm6 lib/DBDish/mysql.pir $(LIBSYSTEM)/DBDish
	@$(CP) lib/DBDish/Pg.pm6 lib/DBDish/Pg.pir $(LIBSYSTEM)/DBDish
	@$(CP) lib/DBDish/SQLite.pm6 lib/DBDish/SQLite.pir $(LIBSYSTEM)/DBDish

# if user has no permission to install globally, try a personal directory 
install-user: lib/DBIish.pir lib/DBDish.pir lib/DBDish/mysql.pir lib/DBDish/Pg.pir lib/DBDish/SQLite.pir
	@echo "--> $(LIBUSER)"
	@$(CP) lib/DBIish.pm6 lib/DBIish.pir $(LIBUSER)
	@$(CP) lib/DBDish.pm6 lib/DBDish.pir $(LIBUSER)
	@$(MKPATH) $(LIBUSER)/DBDish
	@$(CP) lib/DBDish/CSV.pm6 lib/DBDish/CSV.pir $(LIBUSER)/DBDish
	@$(CP) lib/DBDish/mysql.pm6 lib/DBDish/mysql.pir $(LIBUSER)/DBDish
	@$(CP) lib/DBDish/Pg.pm6 lib/DBDish/Pg.pir $(LIBUSER)/DBDish
	@$(CP) lib/DBDish/SQLite.pm6 lib/DBDish/SQLite.pir $(LIBUSER)/DBDish

# Uninstall from the shared system wide directory.
# This might leave an empty DBDish subdirectory behind.
uninstall:
	@echo "x-> $(LIBSYSTEM)"
	@$(TEST_F) $(LIBSYSTEM)/DBIish.pm6
	@$(RM_F)   $(LIBSYSTEM)/DBDish.pm6
	@$(TEST_F) $(LIBSYSTEM)/DBIish.pir
	@$(RM_F)   $(LIBSYSTEM)/DBDish.pir
	@$(TEST_F) $(LIBSYSTEM)/DBDish/CSV.pm6
	@$(RM_F)   $(LIBSYSTEM)/DBDish/CSV.pm6
	@$(TEST_F) $(LIBSYSTEM)/DBDish/CSV.pir
	@$(RM_F)   $(LIBSYSTEM)/DBDish/CSV.pir
	@$(TEST_F) $(LIBSYSTEM)/DBDish/mysql.pm6
	@$(RM_F)   $(LIBSYSTEM)/DBDish/mysql.pm6
	@$(TEST_F) $(LIBSYSTEM)/DBDish/mysql.pir
	@$(RM_F)   $(LIBSYSTEM)/DBDish/mysql.pir
	@$(TEST_F) $(LIBSYSTEM)/DBDish/Pg.pm6
	@$(RM_F)   $(LIBSYSTEM)/DBDish/Pg.pm6
	@$(TEST_F) $(LIBSYSTEM)/DBDish/Pg.pir
	@$(RM_F)   $(LIBSYSTEM)/DBDish/Pg.pir
	@$(TEST_F) $(LIBSYSTEM)/DBDish/SQLite.pm6
	@$(RM_F)   $(LIBSYSTEM)/DBDish/SQLite.pm6
	@$(TEST_F) $(LIBSYSTEM)/DBDish/SQLite.pir
	@$(RM_F)   $(LIBSYSTEM)/DBDish/SQLite.pir

# Uninstall from the user's own Perl 6 directory.
# This might leave an empty DBDish subdirectory behind.
uninstall-user:
	@echo "x-> $(LIBUSER)"
	@$(TEST_F) $(LIBUSER)/DBIish.pm6
	@$(RM_F)   $(LIBUSER)/DBIish.pm6
	@$(TEST_F) $(LIBUSER)/DBIish.pir
	@$(RM_F)   $(LIBUSER)/DBIish.pir
	@$(TEST_F) $(LIBUSER)/DBDish/CSV.pm6
	@$(RM_F)   $(LIBUSER)/DBDish/CSV.pm6
	@$(TEST_F) $(LIBUSER)/DBDish/CSV.pir
	@$(RM_F)   $(LIBUSER)/DBDish/CSV.pir
	@$(TEST_F) $(LIBUSER)/DBDish/mysql.pm6
	@$(RM_F)   $(LIBUSER)/DBDish/mysql.pm6
	@$(TEST_F) $(LIBUSER)/DBDish/mysql.pir
	@$(RM_F)   $(LIBUSER)/DBDish/mysql.pir
	@$(TEST_F) $(LIBUSER)/DBDish/Pg.pm6
	@$(RM_F)   $(LIBUSER)/DBDish/Pg.pm6
	@$(TEST_F) $(LIBUSER)/DBDish/Pg.pir
	@$(RM_F)   $(LIBUSER)/DBDish/Pg.pir
	@$(TEST_F) $(LIBUSER)/DBDish/SQLite.pm6
	@$(RM_F)   $(LIBUSER)/DBDish/SQLite.pm6
	@$(TEST_F) $(LIBUSER)/DBDish/SQLite.pir
	@$(RM_F)   $(LIBUSER)/DBDish/SQLite.pir

clean:
	@# delete compiled files
	$(RM_F) lib/*.pir lib/DBDish/*.pir
	@# delete all editor backup files
	$(RM_F) *~ lib/*~ t/*~ lib/DBDish/*~

help:
	@echo
	@echo "You can make the following in 'DBIish':"
	@echo "clean          removes compiled, temporary and backup files"
	@echo "test           runs a local test suite"
	@echo "install        copies .pm and .pir files to system perl6 lib/"
	@echo "               (may require admin or root permission)"
	@echo "uninstall      removes .pm6 and .pir file(s) from system lib/"
	@echo "install-user   copies .pm and .pir files to user perl6 lib/"
	@echo "uninstall-user removes .pm6 and .pir file(s) from user perl6 lib/"

