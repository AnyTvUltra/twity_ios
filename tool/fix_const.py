#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Fix 'Extension methods can't be used in constant expressions' errors.
For each reported file:line:col, find the nearest preceding `const` token with
no statement boundary (';') between it and the error position, then:
  - `const name =` / `const Type name =`  -> `final`
  - `const <ctor>(...)` / `const [...]`   -> drop the keyword
Repeats until analyze is clean (run analyze separately between passes).
"""
import os, re, sys, subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def analyze_errors():
    p = subprocess.run(
        [r'C:\src\flutter\bin\flutter.bat', 'analyze', '--no-pub'], cwd=ROOT,
        capture_output=True, text=True, encoding='utf-8', errors='replace')
    out = p.stdout + p.stderr
    errs = []
    for m in re.finditer(r'error - [^-]* - ([\w\\\./ ]+\.dart):(\d+):(\d+)', out):
        errs.append((m.group(1).strip(), int(m.group(2)), int(m.group(3))))
    return errs, out

def pos(text, line, col):
    """1-based line/col -> absolute offset"""
    off = 0
    for _ in range(line - 1):
        off = text.index('\n', off) + 1
    return off + col - 1

def fix(path, err_positions):
    text = open(path, encoding='utf-8').read()
    # collect absolute positions of each reported error (the .tr use)
    pts = sorted((pos(text, l, c) for l, c in err_positions), reverse=True)
    n_edits = 0
    for pt in pts:
        # find const tokens before pt, nearest first
        toks = [m for m in re.finditer(r'\bconst\b', text[:pt])]
        target = None
        for m in reversed(toks):
            gap = text[m.end():pt]
            # statement boundary or enclosing block end => not governing
            if ';' in gap or gap.count('}') > gap.count('{'):
                continue
            # must not sit inside a line comment
            line_start = text.rfind('\n', 0, m.start()) + 1
            if '//' in text[line_start:m.start()]:
                continue
            target = m
            break
        if target is None:
            continue
        # what follows the const keyword?
        after = text[target.end():target.end() + 60]
        ma = re.match(r'(\s+[\w<>\?,\[\] ]*?[A-Za-z_\$][\w\$]*)\s*=(?!=)', after)
        if ma and not re.match(r'\s*\(', after) and not re.match(r'\s*[A-Z]', after.strip()[:1] + ' '):
            # declaration `const x = ...`  (allow Type generics roughly)
            # heuristic: identifier sequence ending with '=' before any '('
            head = after.lstrip()
            if re.match(r'[A-Za-z_][\w<>\?, ]* =', head):
                text = text[:target.start()] + 'final' + text[target.end():]
                n_edits += 1
                continue
        # plain const expression -> delete keyword + one following space
        end = target.end()
        if text[end:end+1] == ' ':
            end += 1
        text = text[:target.start()] + text[end:]
        n_edits += 1
    if n_edits:
        open(path, 'w', encoding='utf-8').write(text)
    return n_edits

def main():
    for round_ in range(12):
        errs, out = analyze_errors()
        if not errs:
            print(f'CLEAN after {round_} passes')
            return
        by_file = {}
        for f, l, c in errs:
            by_file.setdefault(f, []).append((l, c))
        total = 0
        for f, positions in by_file.items():
            ap = os.path.join(ROOT, f.replace('\\', os.sep))
            if not os.path.exists(ap):
                continue
            total += fix(ap, positions)
        print(f'pass {round_}: {len(errs)} errors, {total} fixes')
        if total == 0:
            print('remaining errors need manual fixes:')
            print('\n'.join(f'{f}:{l}:{c}' for f, l, c in errs[:40]))
            return

if __name__ == '__main__':
    main()
