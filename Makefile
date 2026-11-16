# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 Ramasubbu Bala Murugan
SHELL := /bin/bash
EDA   ?= /opt/eda
export PATH := $(EDA)/bin:$(PATH)

.PHONY: help toolchain probe probe-accept probe-mac license check-docs clean

help:
	@echo "make toolchain     build pinned EDA tools into $(EDA) (sudo, est. 40-60 min)"
	@echo "make probe         run M0 capability probes, diff against baseline"
	@echo "make probe-accept  overwrite the baseline with the latest results"
	@echo "make probe-mac     run the original Mac M0 suite (tb/probes/mac_suite)"
	@echo "make license       check SPDX license headers on every file (reuse lint)"
	@echo "make check-docs    the project documents agree with each other and with the repository"
	@echo "make clean         remove build/"

toolchain:
	scripts/install_toolchain.sh $(EDA)

probe:
	scripts/probe.sh

# Deliberate step: review build/probe/diff.txt first, and record why the
# baseline moved in docs/bug_log.md or conventions.md.
probe-accept:
	cp build/probe/results.txt tb/probes/expected.txt

# Original Mac M0 suite, kept as a separate suite; M0b ported its four extra constructs (tb/probes/mac_suite/README.md).
probe-mac:
	bash tb/probes/mac_suite/probe.sh

# Every tracked file must carry SPDX license and copyright information (D-009, D-014).
license:
	reuse lint

# Decisions, conventions, status, probes and Makefile must agree (scripts/check_docs.py).
check-docs:
	python3 scripts/check_docs.py --selftest
	python3 scripts/check_docs.py

clean:
	rm -rf build
