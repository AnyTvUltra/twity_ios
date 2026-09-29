#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Scan lib/**/*.dart for string literals containing Arabic — handles nested
quotes inside ${...} interpolations correctly."""
import os, re, sys, json

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, 'lib')
ARABIC = re.compile(r'[؀-ۿݐ-ݿ]')
SKIP_DIRS = {'l10n'}

def iter_files():
    for dp, dn, fn in os.walk(LIB):
        dn[:] = [d for d in dn if d not in SKIP_DIRS]
        for f in fn:
            if f.endswith('.dart') and not f.endswith('.g.dart'):
                yield os.path.join(dp, f)

def _skip_string(text, i):
    """i points at ' or ". Returns index AFTER the closing quote (handles nested
    ${} interpolations that may contain other string literals)."""
    q = text[i]
    n = len(text)
    if text[i:i+3] == q * 3:            # triple-quoted
        j = text.find(q * 3, i + 3)
        return n if j < 0 else j + 3
    i += 1
    while i < n:
        c = text[i]
        if c == '\\':
            i += 2; continue
        if c == q:
            return i + 1
        if c == '\n':
            return i                    # unterminated — bail at newline
        if c == '$' and i + 1 < n and text[i+1] == '{':
            depth, i = 1, i + 2
            while i < n and depth:
                cc = text[i]
                if cc in '\'"':
                    i = _skip_string(text, i); continue
                if cc == '{': depth += 1
                elif cc == '}': depth -= 1
                i += 1
            continue
        i += 1
    return i

def find_literals(text):
    """(start, end, quote, body, interpolated) for '...'/"..." literals."""
    out = []
    i, n = 0, len(text)
    in_line = in_block = False
    while i < n:
        c = text[i]
        if in_line:
            if c == '\n': in_line = False
            i += 1; continue
        if in_block:
            if c == '*' and i + 1 < n and text[i+1] == '/':
                in_block = False; i += 2; continue
            i += 1; continue
        if c == '/' and i + 1 < n:
            if text[i+1] == '/': in_line = True; i += 2; continue
            if text[i+1] == '*': in_block = True; i += 2; continue
        raw = False
        if c == 'r' and i + 1 < n and text[i+1] in '\'"':
            raw = True
            i += 1
            c = text[i]
        if c in '\'"':
            if text[i:i+3] == c * 3:
                j = text.find(c * 3, i + 3)
                i = n if j < 0 else j + 3
                continue
            # scan body manually collecting interpolation info
            j = i + 1
            body_start = j
            interp = False
            while j < n:
                cj = text[j]
                if not raw and cj == '\\':
                    j += 2; continue
                if cj == c:
                    break
                if cj == '\n':
                    break
                if not raw and cj == '$':
                    if j + 1 < n and text[j+1] == '{':
                        interp = True
                        depth, j = 1, j + 2
                        while j < n and depth:
                            cc = text[j]
                            if cc in '\'"':
                                j = _skip_string(text, j); continue
                            if cc == '{': depth += 1
                            elif cc == '}': depth -= 1
                            j += 1
                        continue
                    if j + 1 < n and re.match(r'[A-Za-z_]', text[j+1]):
                        interp = True
                j += 1
            if j < n and text[j] == c:
                out.append((i, j + 1, c, text[body_start:j], interp, raw))
                i = j + 1
                continue
            i = j + 1
            continue
        i += 1
    return out

def split_interp(body):
    """'a $x b ${d['k']} c' -> ('a {} b {} c', ['x', "d['k']"])"""
    tmpl, args = [], []
    i, n = 0, len(body)
    while i < n:
        c = body[i]
        if c == '\\' and i + 1 < n:
            tmpl.append(body[i:i+2]); i += 2; continue
        if c == '$':
            if i + 1 < n and body[i+1] == '{':
                depth, j = 1, i + 2
                while j < n and depth:
                    cc = body[j]
                    if cc in '\'"':
                        j = _skip_string(body, j); continue
                    if cc == '{': depth += 1
                    elif cc == '}': depth -= 1
                    j += 1
                args.append(body[i+2:j-1].strip())
                tmpl.append('{}'); i = j; continue
            m = re.match(r'\$([A-Za-z_][A-Za-z0-9_]*)', body[i:])
            if m:
                args.append(m.group(1)); tmpl.append('{}')
                i += len(m.group(0)); continue
        tmpl.append(c); i += 1
    return ''.join(tmpl), args

def scan():
    total = {}
    for path in iter_files():
        text = open(path, encoding='utf-8').read()
        for (s, e, q, body, interp, raw) in find_literals(text):
            if not ARABIC.search(body) or raw:
                continue
            rel = os.path.relpath(path, ROOT)
            line = text.count('\n', 0, s) + 1
            key = split_interp(body)[0] if interp else body
            total[key] = (rel, line)
    print(f'UNIQUE: {len(total)}')
    cat = sorted(total.keys())
    with open(os.path.join(ROOT, 'tool', 'catalog.json'), 'w', encoding='utf-8') as f:
        json.dump(cat, f, ensure_ascii=False, indent=0)
    print('catalog -> tool/catalog.json')

if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'scan':
        scan()
