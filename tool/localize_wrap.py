#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Wrap Arabic string literals in lib/**/*.dart with .tr / .trp([...])."""
import os, re, sys, json
from localize_scan import iter_files, find_literals, split_interp, ARABIC, ROOT

def wrap_file(path, keys):
    text = open(path, encoding='utf-8').read()
    if 'part of ' in text:
        return False
    lits = [l for l in find_literals(text) if ARABIC.search(l[3]) and not l[5]]
    if not lits:
        return False
    lines = text.split('\n')
    edits = []
    const_fix = set()
    for (s, e, q, body, interp, raw) in lits:
        if text[e:e+4].startswith('.tr'):
            continue
        if text[e:e+1] == ':':                    # map key
            continue
        before = text[max(0, s-12):s]
        if re.search(r'case\s*$', before):
            continue
        line_no = text.count('\n', 0, s)
        col = s - (text.rfind('\n', 0, s) + 1)
        if interp:
            tmpl, args = split_interp(body)
            new = f"{q}{tmpl}{q}.trp([{', '.join(args)}])"
            key = tmpl
        else:
            new = f"{q}{body}{q}.tr"
            key = body
        edits.append((s, e, new))
        keys.add(key)
        if re.search(r'\bconst\b', lines[line_no][:col]):
            const_fix.add(line_no)
    for (s, e, new) in sorted(edits, key=lambda t: -t[0]):
        text = text[:s] + new + text[e:]
    lines = text.split('\n')
    for ln in sorted(const_fix):
        i = lines[ln].find('const ')
        if i >= 0:
            lines[ln] = lines[ln][:i] + lines[ln][i + 6:]
    text = '\n'.join(lines)
    rel = os.path.relpath(os.path.join(ROOT, 'lib', 'l10n', 'app_lang.dart'),
                          os.path.dirname(path)).replace('\\', '/')
    if 'app_lang.dart' not in text:
        imp = f"import '{rel}';"
        m = list(re.finditer(r'^import .+;$', text, re.M))
        if m:
            text = text[:m[-1].end()] + '\n' + imp + text[m[-1].end():]
        else:
            text = imp + '\n' + text
    open(path, 'w', encoding='utf-8').write(text)
    return True

def main():
    keys = set()
    changed = []
    for path in iter_files():
        if wrap_file(path, keys):
            changed.append(os.path.relpath(path, ROOT))
    json.dump(sorted(keys),
              open(os.path.join(ROOT, 'tool', 'catalog.json'), 'w', encoding='utf-8'),
              ensure_ascii=False, indent=0)
    print(f'wrapped files: {len(changed)}  unique keys: {len(keys)}')

if __name__ == '__main__':
    main()
