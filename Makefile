PERL ?= perl
PROVE ?= prove

.PHONY: test compare run-compare reference golden demo-output

test:
	$(PERL) -e 'use v5.36; say "Perl $$^V"'
	$(PERL) -S $(PROVE) -Ilib -r t

compare:
	PERL="$(PERL)" bash xt/compare.sh all

run-compare:
	PERL="$(PERL)" sh xt/run_compare.sh

reference:
	sh xt/fetch_reference.sh

golden:
	sh xt/make_golden.sh

demo-output:
	PERL="$(PERL)" sh xt/collect_demo.sh
