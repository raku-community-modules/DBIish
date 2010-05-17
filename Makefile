# Makefile for FakeDBI

PERL_EXE  = perl
PERL6_EXE = perl6
CP        = $(PERL_EXE) -MExtUtils::Command -e cp
MKPATH    = $(PERL_EXE) -MExtUtils::Command -e mkpath
RM_F      = $(PERL_EXE) -MExtUtils::Command -e rm_f
TEST_F    = $(PERL_EXE) -MExtUtils::Command -e test_f
# try to make these OS agnostic (ie use the same definition on Unix and Windows)
LIBSYSTEM = $(shell $(PERL6_EXE) -e 'print @*INC[2]')
LIBUSER   = $(shell $(PERL6_EXE) -e 'print @*INC[1]')

# first (therefore default) target is FakeDBI.pir
all: lib/FakeDBI.pir

lib/FakeDBD.pir: lib/FakeDBD.pm6
	$(PERL6_EXE) --target=pir --output=lib/FakeDBD.pir lib/FakeDBD.pm6

lib/FakeDBD/mysql.pir: lib/FakeDBD/mysql.pm6 lib/FakeDBD.pir
	export PERL6LIB=lib; $(PERL6_EXE) --target=pir --output=lib/FakeDBD/mysql.pir lib/FakeDBD/mysql.pm6

lib/FakeDBI.pir: lib/FakeDBI.pm6 lib/FakeDBD/mysql.pir
	export PERL6LIB=lib; $(PERL6_EXE) --target=pir --output=lib/FakeDBI.pir lib/FakeDBI.pm6

test: lib/FakeDBI.pir lib/FakeDBD/mysql.pir
	export PERL6LIB=lib; prove --exec $(PERL6_EXE) t/10-mysql.t

# standard install is to the shared system wide directory
install: lib/FakeDBI.pir lib/FakeDBD.pir lib/FakeDBD/mysql.pir
	@echo "--> $(LIBSYSTEM)"
	@$(CP) lib/FakeDBI.pm6 lib/FakeDBI.pir $(LIBSYSTEM)
	@$(CP) lib/FakeDBD.pm6 lib/FakeDBD.pir $(LIBSYSTEM)
	@$(MKPATH) $(LIBSYSTEM)/FakeDBD
	@$(CP) lib/FakeDBD/mysql.pm6 lib/FakeDBD/mysql.pir $(LIBSYSTEM)/FakeDBD

# if user has no permission to install globally, try a personal directory 
install-user: lib/FakeDBI.pir lib/FakeDBD.pir lib/FakeDBD/mysql.pir
	@echo "--> $(LIBUSER)"
	@$(CP) lib/FakeDBI.pm6 lib/FakeDBI.pir $(LIBUSER)
	@$(CP) lib/FakeDBD.pm6 lib/FakeDBD.pir $(LIBUSER)
	@$(MKPATH) $(LIBUSER)/FakeDBD
	@$(CP) lib/FakeDBD/mysql.pm6 lib/FakeDBD/mysql.pir $(LIBUSER)/FakeDBD

# Uninstall from the shared system wide directory.
# This might leave an empty FakeDBD subdirectory behind.
uninstall:
	@echo "x-> $(LIBSYSTEM)"
	@$(TEST_F) $(LIBSYSTEM)/FakeDBI.pm6
	@$(RM_F)   $(LIBSYSTEM)/FakeDBD.pm6
	@$(TEST_F) $(LIBSYSTEM)/FakeDBI.pir
	@$(RM_F)   $(LIBSYSTEM)/FakeDBD.pir
	@$(TEST_F) $(LIBSYSTEM)/FakeDBD/mysql.pm6
	@$(RM_F)   $(LIBSYSTEM)/FakeDBD/mysql.pm6
	@$(TEST_F) $(LIBSYSTEM)/FakeDBD/mysql.pir
	@$(RM_F)   $(LIBSYSTEM)/FakeDBD/mysql.pir

# Uninstall from the user's own Perl 6 directory.
# This might leave an empty FakeDBD subdirectory behind.
uninstall-user:
	@echo "x-> $(LIBUSER)"
	@$(TEST_F) $(LIBUSER)/FakeDBI.pm6
	@$(RM_F)   $(LIBUSER)/FakeDBI.pm6
	@$(TEST_F) $(LIBUSER)/FakeDBI.pir
	@$(RM_F)   $(LIBUSER)/FakeDBI.pir
	@$(TEST_F) $(LIBUSER)/FakeDBD/mysql.pm6
	@$(RM_F)   $(LIBUSER)/FakeDBD/mysql.pm6
	@$(TEST_F) $(LIBUSER)/FakeDBD/mysql.pir
	@$(RM_F)   $(LIBUSER)/FakeDBD/mysql.pir

clean:
	@# delete compiled files
	$(RM_F) lib/*.pir lib/FakeDBD/*.pir
	@# delete all editor backup files
	$(RM_F) *~ lib/*~ t/*~ lib/FakeDBD/*~

help:
	@echo
	@echo "You can make the following in 'FakeDBI':"
	@echo "clean          removes compiled, temporary and backup files"
	@echo "test           runs a local test suite"
	@echo "install        copies .pm and .pir files to system perl6 lib/"
	@echo "               (may require admin or root permission)"
	@echo "uninstall      removes .pm6 and .pir file(s) from system lib/"
	@echo "install-user   copies .pm and .pir files to user perl6 lib/"
	@echo "uninstall-user removes .pm6 and .pir file(s) from user perl6 lib/"

