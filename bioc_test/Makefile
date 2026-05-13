SCRIPT := test_bioc_version.R
LOG    := test_bioc_version.log

.PHONY: all test log clean help

all: test

test:
	Rscript $(SCRIPT) 2>&1 | tee $(LOG)

log:
	@test -f $(LOG) && cat $(LOG) || echo "No log yet. Run 'make test' first."

clean:
	rm -rf renv/ renv.lock .Rprofile $(LOG) .Rhistory .RData

help:
	@echo "Targets:"
	@echo "  test   Run $(SCRIPT) under Rscript and tee output to $(LOG)"
	@echo "  log    Print the most recent run log"
	@echo "  clean  Remove the renv project state and log"
