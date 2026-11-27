"""Fold interpreter-floor evidence (floor_coverage.toml) into game/profile.discovery.toml for the next regen.

Every floor entry is code the interpreter really ran. Targets inside an already generated function's span
are skipped: the recompiler ends a function at the next function start, so seeding one there would
truncate the parent. Usage: fold_floor.py GENERATED_DIR OUT_TOML FLOOR_TOML [FLOOR_TOML...]"""
import re, sys
from pathlib import Path

gen_dir, out = Path(sys.argv[1]), Path(sys.argv[2])
spans, starts = [], set()
for f in gen_dir.glob('*_part*.c'):
    cur, addrs = None, []
    for line in f.read_text(errors='replace').splitlines():
        m = re.match(r'^void func_([0-9A-F]{6})\(void\)', line)
        if m:
            if cur is not None and addrs: spans.append((min(addrs), max(addrs)))
            cur, addrs = int(m.group(1), 16), []
            starts.add(cur)
            continue
        if cur is not None:
            addrs += [int(a, 16) for a in re.findall(r'/\* \$([0-9A-F]{6}) \*/', line)]
    if cur is not None and addrs: spans.append((min(addrs), max(addrs)))

def inside(a):
    return any(lo < a <= hi for lo, hi in spans)

keep = set()
if out.exists():
    keep = {int(x, 16) for x in re.findall(r'0x([0-9A-Fa-f]{6})', out.read_text())}
new = set()
for ft in sys.argv[3:]:
    p = Path(ft)
    if not p.exists(): continue
    for x in re.findall(r'^\s*0x([0-9A-Fa-f]{6}),', p.read_text(), re.M):
        a = int(x, 16)
        if a & 1 or a in starts or inside(a): continue
        new.add(a)
allv = sorted(keep | new)
out.write_text('# preenchido pelas rodadas de perfil (tools/fold_floor.py)\n[functions]\nlate_extra = [\n'
               + ''.join(f'  0x{a:06X},\n' for a in allv) + ']\n')
print(f'{len(new - keep)} novas raízes, {len(allv)} no total')
