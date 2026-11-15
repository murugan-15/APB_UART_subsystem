#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 murugan-15
"""check_docs.py: the project documents agree with each other and with the repository.

Checks (each prints one line per problem; exit 1 if any):
  1. every decision record has all eight fields and a date, and the ids run D-001, D-002, ...
  2. every D-NNN, BUG-NNN and probe pNN cited in docs/ and tb/probes/README.md exists
  3. every probe directory appears in scripts/probe.sh, tb/probes/expected.txt and the README table
  4. every numbered rule of conventions section 2.2 cites a probe or a bug
  5. conventions section 7 and the Makefile list the same implemented targets
  6. conventions, project_status and the README quote the probe baseline that expected.txt holds

  scripts/check_docs.py            check the repository
  scripts/check_docs.py --selftest plant one error per check in memory; each must be reported
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FIELDS = ('Date:', 'Phase:', 'Decision:', 'Alternatives:', 'Reason:', 'Impact:', 'Decided by:', 'Supersedes:')


def load():
    names = {'dec': 'docs/decisions.md', 'conv': 'docs/conventions.md', 'st': 'docs/project_status.md',
             'bug': 'docs/bug_log.md', 'readme': 'tb/probes/README.md', 'sh': 'scripts/probe.sh',
             'exp': 'tb/probes/expected.txt', 'mk': 'Makefile', 'top': 'README.md'}
    t = {k: (ROOT / v).read_text(encoding='utf-8') for k, v in names.items()}
    t['probes'] = sorted(d.name for d in (ROOT / 'tb/probes').glob('p[0-9][0-9]_*'))
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
                       ('bug_log.md', t['bug']), ('tb/probes/README.md', t['readme'])):
        for d in sorted(set(re.findall(r'\bD-\d{3}\b', text))):
            if d not in ids:
                probs.append(f'2 {name}: cites {d}, which is not in decisions.md')
        for b in sorted(set(re.findall(r'\bBUG-\d{3}\b', text))):
            if f'### {b}' not in t['bug']:
                probs.append(f'2 {name}: cites {b}, which is not in bug_log.md')
        body = conv_rules if name == 'conventions.md' else text
        if name in ('conventions.md', 'project_status.md', 'tb/probes/README.md'):
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
    for name, text in (('conventions.md', t['conv']), ('project_status.md', t['st']), ('README.md', t['top'])):
        if base not in text:
            probs.append(f'6 {name}: does not quote the baseline in expected.txt ({base} / {n_un} UNAVAIL)')
    total = n_pass + n_fail + n_un
    for phrase in (f'over {total} checks', f'{len(t["probes"])} small tests'):
        if phrase not in t['top']:
            probs.append(f'6 README.md: does not say "{phrase}"')
    return probs, (len(ids), len(t['probes']), len(rules), base)


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
    ]


def selftest():
    t0, fails = load(), 0
    clean, _ = check(t0)
    for name, key, old, new, kind in mutations(t0):
        t = dict(t0)
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
