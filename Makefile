SHELL := /bin/bash
EDA   ?= /opt/eda
export PATH := $(EDA)/bin:$(PATH)

.PHONY: help toolchain probe probe-accept clean

help:
	@echo "make toolchain     build pinned EDA tools into $(EDA) (sudo, ~40 min)"
	@echo "make probe         run M0 capability probes, diff against baseline"
	@echo "make probe-accept  overwrite the baseline with the latest results"
	@echo "make clean         remove build/"

toolchain:
	scripts/install_toolchain.sh $(EDA)

probe:
	scripts/probe.sh

# Deliberate step: review build/probe/diff.txt first, and record why the
# baseline moved in docs/bug_log.md or conventions.md.
probe-accept:
	cp build/probe/results.txt tb/probes/expected.txt

clean:
	rm -rf build
