TEST_VERBOSE=0
TEST_FILES = ./*.t
INST_LIB=../lib
INST_ARCHLIB=../lib

all:
	@echo 'none...'

check:
	$(PERL) "-MExtUtils::Command::MM" "-e" "test_harness($(TEST_VERBOSE), '$(INST_LIB)', '$(INST_ARCHLIB)')" $(TEST_FILES)
