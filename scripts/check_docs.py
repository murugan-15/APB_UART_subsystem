#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 Ramasubbu Bala Murugan
"""check_docs.py: the project documents agree with each other and with the repository.

Checks (each prints one line per problem; exit 1 if any):
  1. every decision record has all eight fields and a date, and the ids run D-001, D-002, ...
  2. every D-NNN, BUG-NNN and probe pNN cited in docs/, README.md and tb/probes/README.md exists
     (bug_log.md is not searched for probes: its first entries use the Mac suite's numbers)
  3. every probe directory appears in scripts/probe.sh, tb/probes/expected.txt and the README table
  4. every numbered rule of conventions section 2.2 cites a probe or a bug-log entry
  5. conventions section 7 and the Makefile list the same implemented targets
  6. conventions, project_status and the README quote the probe baseline that expected.txt holds:
     PASS, FAIL and UNAVAIL counts, the number of checks, and (conventions, README) of probes;
     project_status also gives the right short form (P / F / U), self-test count and last decision,
     and conventions the number of rules in .svlint.toml
  7. no comment in a SystemVerilog or .vlt file starts with the word "verilator" unless it is a
     pragma: Verilator reads such a comment as one and stops (conventions section 2.4)
  8. docs/spec.md (D-021): every requirement is a table row whose ID cell is REQ-<AREA>-NNN, unique, in a
     table with ID, Basis and Verify columns; its Basis names at least one of [Rn §x] (Rn in the references
     of context_note.md or spec.md), D-NNN (in decisions.md) or "seed: <item>" (a feature-table area or a
     draft register of uart_spec_seed.md), every reference it names exists, and it never names the study
     material (guide, cards, Doubts, MCQ, a study Set); its Verify cell ("how would you verify it?") is not
     empty. Before spec.md exists the self-test runs the check on a built-in fixture.
Not checked (read these by eye): a second, stale quote beside a correct one; whether a cited probe
tests the claim that cites it; tool versions in section 1.1; numbers a probe asserts (38 of 40).

  scripts/check_docs.py            check the repository
  scripts/check_docs.py --selftest plant one error per check in memory; each must be reported
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PRAGMAS = ('lint_off', 'lint_on', 'lint_save', 'lint_restore', 'coverage_off', 'coverage_on', 'tracing_off',
           'tracing_on', 'public', 'public_flat', 'public_flat_rd', 'public_flat_rw', 'no_inline_module',
           'inline_module', 'no_inline_task', 'sc_bv', 'sformat', 'clock_enable', 'split_var', 'isolate_assignments')
FIELDS = ('Date:', 'Phase:', 'Decision:', 'Alternatives:', 'Reason:', 'Impact:', 'Decided by:', 'Supersedes:')


def load():
    names = {'dec': 'docs/decisions.md', 'conv': 'docs/conventions.md', 'st': 'docs/project_status.md',
             'bug': 'docs/bug_log.md', 'readme': 'tb/probes/README.md', 'sh': 'scripts/probe.sh',
             'exp': 'tb/probes/expected.txt', 'mk': 'Makefile', 'top': 'README.md', 'sv': '.svlint.toml',
             'seed': 'docs/uart_spec_seed.md', 'ctx': 'docs/context_note.md'}
    t = {k: (ROOT / v).read_text(encoding='utf-8') for k, v in names.items()}
    spec = ROOT / 'docs/spec.md'
    t['spec'] = spec.read_text(encoding='utf-8') if spec.exists() else None
    t['probes'] = sorted(d.name for d in (ROOT / 'tb/probes').glob('p[0-9][0-9]_*'))
    t['hdl'] = {str(f.relative_to(ROOT)): f.read_text(encoding='utf-8', errors='replace')
                for d in ('rtl', 'tb', 'formal', 'assertions') for f in sorted((ROOT / d).rglob('*'))
                if f.suffix in ('.sv', '.svh', '.v', '.vlt') and 'mac_suite' not in f.parts}
    return t


def check(t):
    probs = []
    recs = [r for r in re.findall(r'^### (D-\d{3}) — (.+)\n((?:.+\n)+)', t['dec'], re.M) if '<title>' not in r[1]]
    ids = [r[0] for r in recs]
    if ids != [f'D-{i:03d}' for i in range(1, len(ids) + 1)]:
        probs.append(f'1 decisions.md: ids are not D-001 .. D-{len(ids):03d} in order: {ids}')
    for i, _title, body in recs:
        for f in FIELDS:
            if f not in body:
                probs.append(f'1 {i}: field "{f}" missing')
        if not re.search(r'Date:\s+20\d\d-\d\d-\d\d', body):
            probs.append(f'1 {i}: no date')
    known_p = {p[:3] for p in t['probes']}
    conv_rules = t['conv'].split('### 2.3')[0] + t['conv'].split('## 3. RTL')[-1]      # 2.3 and 2.4 cite the Mac suite's own probe numbers
    for name, text in (('conventions.md', t['conv']), ('project_status.md', t['st']), ('decisions.md', t['dec']),
                       ('bug_log.md', t['bug']), ('tb/probes/README.md', t['readme']), ('README.md', t['top'])):
        for d in sorted(set(re.findall(r'\bD-\d{3}\b', text))):
            if d not in ids:
                probs.append(f'2 {name}: cites {d}, which is not in decisions.md')
        for b in sorted(set(re.findall(r'\bBUG-\d{3}\b', text))):
            if f'### {b}' not in t['bug']:
                probs.append(f'2 {name}: cites {b}, which is not in bug_log.md')
        body = conv_rules if name == 'conventions.md' else text
        if name != 'bug_log.md':
            for p in sorted(set(re.findall(r'\bp\d\d(?=\b|_)', body))):       # p16 and p16_struct_port alike
                if p not in known_p:
                    probs.append(f'2 {name}: cites probe {p}, which has no directory in tb/probes/')
    for p in t['probes']:
        for name, text in (('scripts/probe.sh', t['sh']), ('tb/probes/expected.txt', t['exp']), ('tb/probes/README.md', t['readme'])):
            if p not in text:
                probs.append(f'3 probe {p} is missing from {name}')
    rules = re.findall(r'^(\d+)\. \*\*(.+?)(?=^\d+\. \*\*|^\*\*[A-Z]|^### |\Z)', t['conv'].split('### 2.2 Rules')[1].split('### 2.3')[0], re.M | re.S)
    for n, body in rules:
        if not re.search(r'\bp\d\d\b|BUG-\d{3}', body):
            probs.append(f'4 conventions rule {n} cites no probe and no bug')
    targets = set(re.findall(r'^([a-z][a-z-]*):', t['mk'], re.M)) - {'help'}
    rows = re.findall(r'^\| `make ([a-z-]+)[^|]*\|.*\| (yes|planned) \|$', t['conv'], re.M)
    for name, state in rows:
        if (state == 'yes') != (name in targets):
            probs.append(f'5 make {name}: conventions says "{state}", the Makefile {"has" if name in targets else "lacks"} it')
    for name in sorted(targets - {r[0] for r in rows}):
        probs.append(f'5 make {name}: in the Makefile but not in conventions section 7')
    n_pass, n_fail, n_un = (len(re.findall(rf' {k}$', t['exp'], re.M)) for k in ('PASS', 'FAIL', 'UNAVAIL'))
    base = f'{n_pass} PASS / {n_fail} FAIL'
    total = n_pass + n_fail + n_un
    # the UNAVAIL count is written "0 UNAVAIL", or "known tool limits / 0 UNAVAIL" in project_status
    full = re.compile(rf'{n_pass} PASS / {n_fail} FAIL(?: known tool limits)? / {n_un} UNAVAIL\S* \(?(?:over )?{total} checks')
    for name, text in (('conventions.md', t['conv']), ('project_status.md', t['st']), ('README.md', t['top'])):
        if not full.search(text):
            probs.append(f'6 {name}: does not quote the baseline in expected.txt ({base} / {n_un} UNAVAIL over {total} checks)')
    for name, text, phrase in (('README.md', t['top'], f'{len(t["probes"])} small tests'),
                               ('conventions.md', t['conv'], f'{total} checks, {len(t["probes"])} probes')):
        if phrase not in text:
            probs.append(f'6 {name}: does not say "{phrase}"')
    for name, text in t['hdl'].items():
        for n, line in enumerate(text.splitlines(), 1):
            m = re.match(r'\s*(?://|/\*)\s*verilator\b\s*(\w*)', line, re.I)
            if m and m.group(1) not in PRAGMAS:
                probs.append(f'7 {name}:{n}: a comment starts with "verilator"; Verilator will read it as a pragma')
    for short in re.findall(r'`make probe` (\d+ / \d+ / \d+)', t['st']):
        if short != f'{n_pass} / {n_fail} / {n_un}':
            probs.append(f'6 project_status.md: quotes `make probe` {short}; expected.txt holds {n_pass} / {n_fail} / {n_un}')
    n_mut = len(mutations(t))
    for a, b in re.findall(r'self-test (\d+) of (\d+)', t['st']):
        if (int(a), int(b)) != (n_mut, n_mut):
            probs.append(f'6 project_status.md: says self-test {a} of {b}; check_docs has {n_mut} planted errors')
    if ids and f'(D-001 to {ids[-1]})' not in t['st']:
        probs.append(f'6 project_status.md: does not say the decisions run "(D-001 to {ids[-1]})"')
    n_sv = len(re.findall(r'^[a-z_]+ = true', t['sv'], re.M))
    for n in re.findall(r'each of its (\d+) rules', t['conv']):
        if int(n) != n_sv:
            probs.append(f'6 conventions.md: says svlint has {n} rules; .svlint.toml switches on {n_sv}')
    if t['spec'] is not None:
        probs += check_spec(t, ids)
    return probs, (len(ids), len(t['probes']), len(rules), base)


STUDY = re.compile(r'\b(guide|cards?|doubts?|MCQ|cheat sheet|learning[_ ]log|checkpoint|Set (?:0|L\d|M0|G1|CP))\b', re.I)
FIXTURE = '''# Fixture (check_docs self-test only)

| ID | Requirement | Basis | Verify |
|---|---|---|---|
| REQ-BUS-001 | The slave completes a transfer in two cycles when PREADY is held high. | [R4 §3.1]; seed: Bus | directed test: one write, one read, cycle count |
| REQ-FRM-001 | A frame is sent LSB first. | seed: Frame | line monitor decodes a known byte |
| REQ-RST-001 | Reset asserts asynchronously and releases synchronously. | D-001 | assertion on the reset synchronizer |
'''


def check_spec(t, ids):
    probs, seen = [], set()
    refs = set(re.findall(r'^\| (R\d+) \|', t['ctx'] + '\n' + t['spec'], re.M))
    seed_feat = t['seed'].split('## Proposed feature set')[1].split('\n## ')[0]
    seed_map = t['seed'].split('## Draft register map')[1].split('\n## ')[0]
    items = {c.strip().lower() for c in re.findall(r'^\| ([^|]+?) \|', seed_feat, re.M)} - {'area', '---'}
    items |= {c.strip().lower() for c in re.findall(r'^\| 0x[0-9A-F]+ \| (\w+) \|', seed_map, re.M)}
    for block in re.findall(r'^(\|.+\|\n\|[-| :]+\|\n(?:\|.+\|\n?)*)', t['spec'], re.M):
        rows = [[c.strip() for c in r.strip().strip('|').split('|')] for r in block.strip().splitlines()]
        head = [h.split(' (')[0].lower() for h in rows[0]]
        body = [r for r in rows[2:] if r and r[0].startswith('REQ-')]
        if not body:
            continue
        missing = [c for c in ('id', 'basis', 'verify') if c not in head]
        if missing:
            probs.append(f'8 spec.md: a requirement table lacks the column(s) {", ".join(missing)}')
            continue
        ib, iv = head.index('basis'), head.index('verify')
        for r in body:
            rid = r[0]
            basis = r[ib] if ib < len(r) else ''
            verify = r[iv] if iv < len(r) else ''
            if not re.fullmatch(r'REQ-[A-Z]+-\d{3}', rid):
                probs.append(f'8 spec.md: {rid}: the ID is not REQ-<AREA>-NNN')
            if rid in seen:
                probs.append(f'8 spec.md: {rid}: the ID is used twice')
            seen.add(rid)
            cites = re.findall(r'\[(R\d+) §[^\]]+\]', basis)
            decs = re.findall(r'\bD-\d{3}\b', basis)
            seeds = [x.strip().lower() for x in re.findall(r'seed: ([^;,\]]+)', basis)]
            if not (cites or decs or seeds):
                probs.append(f'8 spec.md: {rid}: the Basis names no [Rn §x], D-NNN or "seed: <item>"')
            for c in cites:
                if c not in refs:
                    probs.append(f'8 spec.md: {rid}: the Basis cites {c}, which is in no reference list')
            for d in decs:
                if d not in ids:
                    probs.append(f'8 spec.md: {rid}: the Basis cites {d}, which is not in decisions.md')
            for x in seeds:
                if x not in items:
                    probs.append(f'8 spec.md: {rid}: the Basis cites "seed: {x}", which is no seed area or register')
            m = STUDY.search(basis)
            if m:
                probs.append(f'8 spec.md: {rid}: the Basis names the study material ("{m.group()}"; D-021)')
            if not verify:
                probs.append(f'8 spec.md: {rid}: the Verify cell is empty')
    if not seen:
        probs.append('8 spec.md: no requirement row (an ID cell REQ-<AREA>-NNN in a table with ID, Basis and Verify)')
    return probs


# one planted error per check: (name, key of the text to change, old, new, the check that must report it)
def mutations(t):
    last = re.findall(r'^### (D-\d{3}) ', t['dec'], re.M)[-1]
    base = re.search(r'\d+ PASS / \d+ FAIL', t['conv']).group()
    return [
        ('a decision without its Reason', 'dec', 'Reason:', 'Because:', '1'),
        ('a decision that does not exist', 'st', last, 'D-999', '2'),
        ('a probe that does not exist', 'readme', 'p01_sv_basics', 'p99_nothing', '2'),
        ('a probe left out of the baseline', 'exp', 'p02_interfaces', 'pXX_interfaces', '3'),
        ('a rule with no probe', 'conv', '(p03)', '', '4'),
        ('a target claimed but not implemented', 'mk', 'license:', 'licence:', '5'),
        ('a stale baseline', 'st', base, '1 PASS / 1 FAIL', '6'),
        ('a stale number of checks', 'conv', re.search(r'\((\d+ checks), \d+ probes', t['conv']).group(1), '1 checks', '6'),
        ('a probe that does not exist, cited by a decision', 'dec', 'p17 to p23', 'p17 to p93', '2'),
        ('a decision that does not exist, cited by the README', 'top', 'D-003', 'D-903', '2'),
        ('a stale short baseline in the status file', 'st', '`make probe` ' + re.search(r'`make probe` (\d+ / \d+ / \d+)', t['st']).group(1), '`make probe` 1 / 1 / 1', '6'),
        ('a stale self-test count', 'st', 'self-test ', 'self-test 3 of 3, not ', '6'),
        ('a stale last decision', 'st', f'(D-001 to {last})', '(D-001 to D-002)', '6'),
        ('a comment that Verilator reads as a pragma', 'hdl', None, None, '7'),
        ('a stale number of svlint rules', 'conv', 'each of its ', 'each of its 99 rules, not ', '6'),
        ('a requirement with an empty basis', 'spec', '| seed: Frame |', '|  |', '8'),
        ('a requirement based on the study guide', 'spec', '| D-001 |', '| D-001; guide Set L4 |', '8'),
        ('a requirement citing a decision that does not exist', 'spec', '| D-001 |', '| D-999 |', '8'),
        ('a requirement citing a reference in no list', 'spec', '[R4 §3.1]', '[R99 §3.1]', '8'),
        ('a requirement citing no seed item', 'spec', 'seed: Frame', 'seed: Framing', '8'),
        ('a requirement ID used twice', 'spec', 'REQ-FRM-001', 'REQ-BUS-001', '8'),
        ('a requirement with no verify question', 'spec', '| line monitor decodes a known byte |', '|  |', '8'),
        ('a requirement table without a Basis column', 'spec', '| Basis |', '| Source |', '8'),
    ]


def selftest():
    t0, fails = load(), 0
    if t0['spec'] is None:                    # before spec.md exists: run check 8 on the fixture
        t0['spec'] = FIXTURE
    clean, _ = check(t0)
    for name, key, old, new, kind in mutations(t0):
        t = dict(t0)
        if key == 'hdl':                      # plant the comment in a copy of the first HDL file
            first = sorted(t['hdl'])[0]
            t['hdl'] = dict(t['hdl'], **{first: '// Verilator must reject this file.\n' + t['hdl'][first]})
            hit = [p for p in check(t)[0] if p.startswith(kind + ' ') and p not in clean]
            print(f'{"PASS" if hit else "MISS"}   {name}')
            fails += not hit
            continue
        if old not in t[key]:
            print(f'SETUP  {name}: anchor not found')
            fails += 1
            continue
        t[key] = t[key].replace(old, new)
        hit = [p for p in check(t)[0] if p.startswith(kind + ' ') and p not in clean]
        print(f'{"PASS" if hit else "MISS"}   {name}')
        fails += not hit
    n = len(mutations(t0))
    print(f'check_docs self-test: {"pass" if not fails else "FAIL"} ({n - fails} of {n} caught)')
    return 1 if fails else 0


def main(argv):
    if '--selftest' in argv:
        return selftest()
    probs, (n_dec, n_probe, n_rule, base) = check(load())
    for p in probs:
        print(p)
    print(f'check_docs: {"pass" if not probs else "FAIL"} ({n_dec} decisions, {n_probe} probes, {n_rule} rules, baseline {base})')
    return 1 if probs else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
