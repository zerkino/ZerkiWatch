#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""zw.py - outil des lots d'optimisation de ZerkiWatch (base : commit d7999d5, v7.0.0).

Tout est dans ce fichier : le moteur de modification, les 8 lots, les fichiers qu'ils ajoutent et les tests de labo.
Une session n'a PAS besoin de le lire : elle le lance depuis la racine du depot.

  python3 zw.py status              lots deja appliques, commit courant
  python3 zw.py apply N             applique le lot N (tout ou rien), puis lance check
  python3 zw.py check               ASCII + CRLF, check-syntax, check-lang, analyse de tools/*.ps1, C# 5
  python3 zw.py tests N|all|NOM     tests de labo (PowerShell 7 sous Linux) du lot N, tous, ou un seul
  python3 zw.py commit "message"    commit au nom de zerkino, sans aucune ligne ajoutee (refuse toute mention d'un outil d'IA / Co-Authored-By)
  python3 zw.py show N              liste les operations du lot N
  python3 zw.py pwsh                installe PowerShell 7.4.6 dans ~/pwsh si absent

Un lot = une session = un commit. Les modifications sont faites en memoire puis ecrites en une fois : si un texte
ancre est introuvable, RIEN n'est ecrit (message 'PATCH: ...'). Dans ce cas ne rien forcer.
"""
import os, sys, re, subprocess, shutil, hashlib, tempfile

BASE = 'd7999d5'
IDENT = ['-c', 'user.name=zerkino', '-c', 'user.email=zerkino@users.noreply.github.com']
FILES = {}      # texte des fichiers ajoutes ou inseres par les lots (fins de ligne LF)
LOTSRC = {}     # numero de lot -> source Python de sa specification (N, MARK, OPS)
TESTSRC = {}    # nom -> script PowerShell du test de labo
TESTMAP = {0: ['perf'], 1: ['log', 'mutex', 'lang_real', 'hist'], 2: ['ranges', 'net', 'dispatch'], 3: ['series']}
ALWAYS = ['cs5']

import os, sys, hashlib

def _fail(msg):
    sys.stderr.write('PATCH: ' + msg + '\n')
    sys.exit(1)

def _lang_hashes(root):
    # same formula as Get-TextHash in the app: UTF-8 text (BOM removed), CRLF -> LF, trimmed, SHA256, first 16 hex digits
    out = []
    d = os.path.join(root, 'lang')
    for fn in sorted(os.listdir(d)):
        if fn.endswith('.txt'):
            t = open(os.path.join(d, fn), 'rb').read().decode('utf-8-sig').replace('\r\n', '\n').strip()
            out.append((fn[:-4].lower(), hashlib.sha256(t.encode('utf-8')).hexdigest()[:16]))
    return out

def run_ops(root, ops, mark=None):
    staged = {}   # relative path -> text with LF
    crlf = {}     # relative path -> keep CRLF when writing
    def get(rel):
        if rel not in staged:
            raw = open(os.path.join(root, rel), 'rb').read()
            crlf[rel] = (rel == 'ZerkiWatch.bat') or (b'\r\n' in raw)
            staged[rel] = raw.decode('ascii' if rel == 'ZerkiWatch.bat' else 'utf-8').replace('\r\n', '\n')
        return staged[rel]
    def count(text, old, want, what):
        n = text.count(old)
        if n != want:
            _fail('%s: found %d time(s), expected %d: %r' % (what, n, want, old[:110]))
    bat = 'ZerkiWatch.bat'
    if mark:
        mp, mt = (bat, mark) if isinstance(mark, str) else mark
        if mt in get(mp):
            print('deja applique (marqueur trouve dans %s): %s' % (mp, mt))
            return False
    for i, op in enumerate(ops):
        k = op[0]
        tag = 'op %d (%s)' % (i + 1, k)
        if k in ('bat_edit', 'file_edit'):
            rel = bat if k == 'bat_edit' else op[1]
            old, new = (op[1], op[2]) if k == 'bat_edit' else (op[2], op[3])
            want = (op[3] if len(op) > 3 else 1) if k == 'bat_edit' else (op[4] if len(op) > 4 else 1)
            t = get(rel)
            count(t, old, want, tag)
            staged[rel] = t.replace(old, new)
        elif k == 'bat_between':
            t = get(bat)
            start, end, new = op[1], op[2], op[3]
            count(t, start, 1, tag + ' start')
            a = t.index(start)
            b = t.find(end, a + len(start))
            if b < 0:
                _fail(tag + ': end marker not found after start: %r' % (end[:110],))
            staged[bat] = t[:a] + new + t[b:]
        elif k == 'bat_langhash':
            t = get(bat)
            line = '$langHash = @{ ' + '; '.join("'%s' = '%s'" % (c, h) for c, h in _lang_hashes(root)) + ' }\n'
            if '\n$langHash = @{' in t:
                a = t.index('\n$langHash = @{') + 1
                b = t.index('\n', a) + 1
                staged[bat] = t[:a] + line + t[b:]
            else:
                m = "'@\n# LANGDATA END"
                count(t, m, 1, tag)
                staged[bat] = t.replace(m, "'@\n" + line + '# LANGDATA END')
        elif k == 'file_append':
            rel, text = op[1], op[2]
            t = get(rel)
            if not t.endswith('\n'):
                t += '\n'
            staged[rel] = t + text
        elif k == 'file':
            rel, text = op[1], op[2]
            staged[rel] = text
            crlf[rel] = False
        else:
            _fail('unknown op ' + k)
    for rel, t in staged.items():
        if rel == bat:
            bad = [c for c in t if ord(c) >= 128]
            if bad:
                _fail('non-ASCII character(s) in ZerkiWatch.bat: %r' % (bad[:5],))
        p = os.path.join(root, rel)
        d = os.path.dirname(p)
        if d and not os.path.isdir(d):
            os.makedirs(d)
        data = t.replace('\n', '\r\n') if crlf.get(rel) else t
        open(p, 'wb').write(data.encode('ascii' if rel == bat else 'utf-8'))
    print('ok: %d operation(s), %d file(s) written' % (len(ops), len(staged)))
    return True

def fail(msg):
    sys.stderr.write('zw: ' + msg + '\n')
    sys.exit(1)

def git(root, *args, **kw):
    r = subprocess.run(['git', '-C', root] + list(args), stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True, errors='replace')
    if kw.get('check') and r.returncode != 0:
        fail('git ' + ' '.join(args) + ' : ' + r.stderr.strip())
    return r

def find_root():
    r = subprocess.run(['git', 'rev-parse', '--show-toplevel'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
    root = r.stdout.strip() if r.returncode == 0 else os.getcwd()
    if not os.path.exists(os.path.join(root, 'ZerkiWatch.bat')):
        fail('ZerkiWatch.bat introuvable : lance zw.py depuis le depot ZerkiWatch')
    return root

def load_lot(n):
    if n not in LOTSRC:
        fail('le lot %d n\'a pas de script (le lot 5 est une decision a prendre apres mesure : voir le prompt)' % n)
    ns = {'F': lambda name: FILES[name]}
    exec(compile(LOTSRC[n], 'lot%d' % n, 'exec'), ns)
    return ns

def lot_numbers():
    return sorted(LOTSRC.keys())

def is_applied(root, ns):
    mark = ns['MARK']
    mp, mt = ('ZerkiWatch.bat', mark) if isinstance(mark, str) else mark
    try:
        raw = open(os.path.join(root, mp), 'rb').read().decode('utf-8', 'replace')
    except IOError:
        return False
    return mt in raw

def pwsh_path(install=True):
    for c in (os.path.expanduser('~/pwsh/pwsh'), shutil.which('pwsh')):
        if c and os.path.exists(c):
            return c
    if not install:
        return None
    d = os.path.expanduser('~/pwsh')
    os.makedirs(d, exist_ok=True)
    print('Installation de PowerShell 7.4.6 dans ~/pwsh (une seule fois) ...')
    url = 'https://github.com/PowerShell/PowerShell/releases/download/v7.4.6/powershell-7.4.6-linux-x64.tar.gz'
    subprocess.call('curl -sSL "%s" | tar xz -C "%s"' % (url, d), shell=True)
    p = os.path.join(d, 'pwsh')
    if not os.path.exists(p):
        fail('installation de PowerShell impossible (reseau ?) : demande a Big Boss ou saute les controles pwsh en le disant')
    os.chmod(p, 0o755)
    return p

def run_pwsh(pw, args, cwd):
    env = dict(os.environ)
    env.update({'NO_COLOR': '1', 'POWERSHELL_TELEMETRY_OPTOUT': '1', 'DOTNET_CLI_TELEMETRY_OPTOUT': '1'})
    r = subprocess.run([pw, '-NoLogo', '-NoProfile', '-NonInteractive'] + args, cwd=cwd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True, errors='replace', timeout=900)
    return r.returncode, r.stdout

def tail(text, n):
    lines = [l for l in text.replace('\r', '').split('\n') if l.strip() != '']
    return '\n'.join('      ' + l for l in lines[-n:])

# ---------------------------------------------------------------- commandes

def cmd_status(args):
    root = find_root()
    print('depot : ' + root)
    print('commit : ' + git(root, 'log', '-1', '--oneline').stdout.strip() + '   (base de ce document : ' + BASE + ')')
    print('branche : ' + git(root, 'rev-parse', '--abbrev-ref', 'HEAD').stdout.strip())
    st = git(root, 'status', '--short').stdout.strip()
    print('arbre : ' + ('propre' if st == '' else 'modifie :\n' + st))
    print('lots :')
    for n in lot_numbers():
        print('  LOT %d : %s' % (n, 'DEJA APPLIQUE (marqueur present)' if is_applied(root, load_lot(n)) else 'a faire'))
    print('  LOT 5 : decision apres mesure (pas de script)')
    pw = pwsh_path(False)
    print('pwsh : ' + (pw if pw else 'absent (python3 zw.py pwsh pour l\'installer)'))
    return 0

def cmd_show(args):
    if not args:
        fail('usage : zw.py show N')
    ns = load_lot(int(args[0]))
    print('LOT %d, marqueur : %r' % (ns['N'], ns['MARK']))
    for i, op in enumerate(ns['OPS']):
        k = op[0]
        if k in ('bat_edit',):
            print('%2d  bat_edit      %r' % (i + 1, op[1][:90]))
        elif k == 'bat_between':
            print('%2d  bat_between   de %r a %r' % (i + 1, op[1][:60], op[2][:40]))
        elif k == 'bat_langhash':
            print('%2d  bat_langhash  ligne $langHash recalculee' % (i + 1))
        else:
            print('%2d  %-12s %s' % (i + 1, k, op[1]))
    return 0

def cmd_apply(args):
    root = find_root()
    if not args:
        fail('usage : zw.py apply N')
    nums = [int(a) for a in args]
    if git(root, 'status', '--short').stdout.strip() != '':
        print('ATTENTION : l\'arbre de travail n\'est pas propre (git status). Un lot = un commit : verifie que seules les modifs de ce lot y seront.')
    for n in nums:
        ns = load_lot(n)
        print('== LOT %d ==' % n)
        run_ops(root, ns['OPS'], ns['MARK'])
    print('')
    rc = cmd_check([])
    print('')
    print(git(root, 'status', '--short').stdout.strip())
    print(git(root, 'diff', '--stat').stdout.strip().split('\n')[-1] if git(root, 'diff', '--stat').stdout.strip() else '')
    return rc

def cmd_check(args):
    root = find_root()
    bad = 0
    b = open(os.path.join(root, 'ZerkiWatch.bat'), 'rb').read()
    if any(c >= 128 for c in b):
        print('FAIL  ZerkiWatch.bat contient un octet non ASCII'); bad += 1
    elif b.count(b'\r\n') != b.count(b'\n'):
        print('FAIL  ZerkiWatch.bat : LF sans CR'); bad += 1
    else:
        print('ok    ZerkiWatch.bat ASCII + CRLF (%d lignes)' % b.count(b'\n'))
    wf = os.path.join(root, '.github', 'workflows')
    if os.path.isdir(wf):
        for fn in sorted(os.listdir(wf)):
            if fn.endswith('.yml') and b'\t' in open(os.path.join(wf, fn), 'rb').read():
                print('FAIL  %s contient une tabulation (YAML invalide)' % fn); bad += 1
    pw = pwsh_path(True)
    steps = [
        ('check-syntax', ['-File', os.path.join('tools', 'check-syntax.ps1')]),
        ('check-lang', ['-File', os.path.join('tools', 'check-lang.ps1')]),
        ('analyse de tools/*.ps1', ['-Command', "$bad = 0; foreach ($f in Get-ChildItem tools -Recurse -Filter *.ps1) { $e = $null; [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$e); if ($e.Count -gt 0) { $bad++; foreach ($x in $e) { Write-Host ($f.Name + ': ' + $x.Message) } } }; if ($bad -gt 0) { exit 1 }"]),
    ]
    for name, a in steps:
        rc, out = run_pwsh(pw, a, root)
        print(('ok    ' if rc == 0 else 'FAIL  ') + name)
        if rc != 0:
            bad += 1
            print(tail(out, 12))
    if os.path.exists(os.path.join(os.path.dirname(os.path.realpath(pw)), 'Microsoft.CodeAnalysis.CSharp.dll')):
        rc = run_test(root, pw, 'cs5', None)
        if rc != 0:
            bad += 1
    else:
        print('--    controle C# 5 saute (Roslyn absent de ce pwsh : python3 zw.py pwsh)')
    print('CHECK ' + ('OK' if bad == 0 else 'ECHEC (%d)' % bad))
    return 1 if bad else 0

_old = {}
def old_bat(root, tmp):
    if 'p' in _old:
        return _old['p']
    for ref in (BASE, 'HEAD'):
        r = subprocess.run(['git', '-C', root, 'show', ref + ':ZerkiWatch.bat'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if r.returncode == 0:
            if ref != BASE:
                print('ATTENTION : le commit %s est introuvable (depot superficiel ?) : comparaison avec HEAD, valable seulement si HEAD n\'a pas encore le lot' % BASE)
            p = os.path.join(tmp, 'old.bat')
            open(p, 'wb').write(r.stdout.replace(b'\r\n', b'\n'))
            _old['p'] = p
            return p
    fail('impossible de lire ZerkiWatch.bat dans git')

def run_test(root, pw, name, tmp):
    own = tmp is None
    if own:
        tmp = tempfile.mkdtemp(prefix='zwt')
    try:
        p = os.path.join(tmp, 't_' + name + '.ps1')
        open(p, 'w', encoding='utf-8', newline='\n').write(TESTSRC[name])
        rc, out = run_pwsh(pw, ['-File', p, '-OldBat', old_bat(root, tmp), '-NewBat', os.path.join(root, 'ZerkiWatch.bat'), '-Root', root], root)
        print(('ok    ' if rc == 0 else 'FAIL  ') + 'test ' + name)
        print(tail(out, 40 if rc != 0 else 3))
        return rc
    finally:
        if own:
            shutil.rmtree(tmp, ignore_errors=True)

def cmd_tests(args):
    root = find_root()
    if not args:
        fail('usage : zw.py tests N | all | NOM')
    a = args[0]
    if a == 'all':
        names = sorted(TESTSRC.keys())
    elif a.isdigit():
        names = TESTMAP.get(int(a), []) + ALWAYS
    elif a in TESTSRC:
        names = [a]
    else:
        fail('test inconnu : %s (disponibles : %s)' % (a, ', '.join(sorted(TESTSRC))))
    pw = pwsh_path(True)
    tmp = tempfile.mkdtemp(prefix='zwt')
    bad = 0
    try:
        for n in names:
            if run_test(root, pw, n, tmp) != 0:
                bad += 1
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    print('TESTS ' + ('OK' if bad == 0 else 'ECHEC (%d)' % bad))
    return 1 if bad else 0

def allowed_paths():
    out = set(['ZerkiWatch.bat'])
    for n in lot_numbers():
        for op in load_lot(n)['OPS']:
            if op[0] in ('file', 'file_edit', 'file_append'):
                out.add(op[1])
    return out

def cmd_commit(args):
    root = find_root()
    if len(args) != 1:
        fail('usage : zw.py commit "message"')
    msg = args[0].strip()
    if re.search(r'claude|co-authored-by|generated with|anthropic|noreply@anthropic', msg, re.I):
        fail('message refuse : aucune mention d\'un outil d\'IA, aucun Co-Authored-By, aucune ligne Generated with (regle de Big Boss)')
    if '\n' in msg:
        fail('message sur UNE ligne, en anglais, style de l\'historique (7.0.0: ...)')
    ok = allowed_paths()
    changed = []
    for line in git(root, 'status', '--porcelain', '--untracked-files=all').stdout.split('\n'):
        if line.strip() != '':
            changed.append(line[3:].strip().strip('"'))
    mine = [p for p in changed if p in ok]
    other = [p for p in changed if p not in ok]
    if not mine:
        fail('rien a commiter parmi les fichiers des lots')
    if other:
        print('ATTENTION, fichiers modifies HORS lot, non commites : ' + ', '.join(other))
    git(root, 'add', '--', *mine, check=True)
    r = subprocess.run(['git', '-C', root] + IDENT + ['commit', '-q', '-m', msg], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)
    print(r.stdout.strip())
    if r.returncode != 0:
        return 1
    print(git(root, 'log', '-1', '--format=%h  auteur: %an <%ae>  committeur: %cn <%ce>%n%B').stdout.rstrip())
    print(git(root, 'show', '--stat', '--format=', 'HEAD').stdout.rstrip())
    print('-> pousser avec : git push origin main')
    return 0

def cmd_pwsh(args):
    print(pwsh_path(True))
    return 0

COMMANDS = {'status': cmd_status, 'show': cmd_show, 'apply': cmd_apply, 'check': cmd_check, 'tests': cmd_tests, 'commit': cmd_commit, 'pwsh': cmd_pwsh}

def main():
    if len(sys.argv) < 2 or sys.argv[1] not in COMMANDS:
        print(__doc__)
        return 0 if len(sys.argv) < 2 else 2
    return COMMANDS[sys.argv[1]](sys.argv[2:])

# ================================================================ CHARGE UTILE (ne pas lire : lance zw.py)
FILES['bench.ps1'] = r'''# tools/bench.ps1 - run by the "bench" workflow on windows-latest (Windows PowerShell 5.1). Prints ms per run.
function Measure-Ms([string]$label, [scriptblock]$sb, [int]$n = 1) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt $n; $i++) { $null = & $sb }
    $sw.Stop()
    Write-Host ('{0,-60} {1,10:N1} ms/run' -f $label, ($sw.Elapsed.TotalMilliseconds / $n))
}
Write-Host ('PowerShell ' + $PSVersionTable.PSVersion + ' | ' + [Environment]::OSVersion.VersionString + ' | CPUs=' + [Environment]::ProcessorCount)
$root = Split-Path -Parent $PSScriptRoot
$t = [IO.File]::ReadAllText((Join-Path $root 'ZerkiWatch.bat'))
$code = $t.Substring($t.IndexOf('#PS' + 'START') + 8)
Add-Type -AssemblyName System.Drawing
Measure-Ms 'parse the whole script (AST)' { $e = $null; $k = $null; [void][System.Management.Automation.Language.Parser]::ParseInput($code, [ref]$k, [ref]$e) } 3

# --- languages: the loader of the base commit (functions between "function ConvertFrom-LangEsc" and "# LANGDATA BEGIN") ---
$la = $t.IndexOf('function ConvertFrom-LangEsc'); $lb = $t.IndexOf('# LANGDATA BEGIN')
$ga = $t.IndexOf("`$langData = @'"); $gb = $t.IndexOf("'@", $ga + 20)
if (($la -ge 0) -and ($lb -gt $la) -and ($ga -gt 0)) {
    $langData = $t.Substring($ga + 15, $gb - ($ga + 15))
    $LangDb = @{}
    Invoke-Expression $t.Substring($la, $lb - $la)
    Measure-Ms 'languages: embedded text, current loader' { $LangDb.Clear(); Add-LangLines ($langData -split "`n") '' }
    Measure-Ms 'languages: shipped lang\*.txt (read twice today), same loader' {
        $LangDb.Clear()
        foreach ($lf in @(Get-ChildItem -LiteralPath (Join-Path $root 'lang') -Filter '*.txt')) { Add-LangLines ([System.IO.File]::ReadAllLines($lf.FullName, [System.Text.Encoding]::UTF8)) ($lf.BaseName.ToLower()) }
    }
}

# --- history: the Load-History loop on 10 080 synthetic lines (7 days) ---
$invc = [System.Globalization.CultureInfo]::InvariantCulture
$histEpoch = [DateTime]'2020-01-01'
function Get-MinIdx([DateTime]$d) { return [long][math]::Floor(($d - $histEpoch).TotalMinutes) }
$hl = New-Object System.Collections.ArrayList
$h0 = (Get-Date).AddDays(-6.5)
for ($m = 0; $m -lt 10080; $m++) { [void]$hl.Add($h0.AddMinutes($m).ToString('yyyyMMddHHmm', $invc) + ',12.345,1.234,23.4,45.6,7.8,123456,23456') }
$hlines = $hl.ToArray()
Measure-Ms 'history: Load-History loop, 10 080 lines' {
    $mem = New-Object System.Collections.ArrayList
    $cut = (Get-Date).AddDays(-7)
    foreach ($ln in $hlines) {
        $p = $ln.Split(',')
        if ($p.Count -lt 8) { continue }
        try {
            $dt = [DateTime]::ParseExact($p[0], 'yyyyMMddHHmm', $invc)
            if ($dt -lt $cut) { continue }
            $rec = New-Object 'double[]' 8
            $rec[0] = [double](Get-MinIdx $dt)
            for ($i = 1; $i -lt 8; $i++) { $rec[$i] = [double]::Parse($p[$i], $invc) }
            [void]$mem.Add($rec)
        } catch { }
    }
}

# --- painting ---
Measure-Ms 'New-Object System.Drawing.PointF x 20 000' { for ($i = 0; $i -lt 20000; $i++) { $p = New-Object System.Drawing.PointF([single]$i, [single]2) } }
Measure-Ms '[System.Drawing.PointF]::new x 20 000' { for ($i = 0; $i -lt 20000; $i++) { $p = [System.Drawing.PointF]::new([single]$i, [single]2) } }
Measure-Ms 'New-Object SolidBrush + Dispose x 2 000' { for ($i = 0; $i -lt 2000; $i++) { $b = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Red); $b.Dispose() } }

# --- services (background job of the app) ---
Measure-Ms 'services: Get-CimInstance Win32_Service (running)' { Get-CimInstance -ClassName Win32_Service -Filter "State='Running'" | Out-Null } 3

# --- firewall on a throw-away group with TEST-NET ranges (NEVER the real ZerkiWatch rules) ---
$grp = 'ZW-BENCH'
$rng = @('192.0.2.0-192.0.2.255', '198.51.100.0-198.51.100.255')
Measure-Ms 'cmdlet  Get-NetFirewallRule -Group (first call)' { Get-NetFirewallRule -Group $grp -ErrorAction SilentlyContinue }
Measure-Ms 'cmdlet  create 2 rules + remove them' {
    1..2 | ForEach-Object { New-NetFirewallRule -DisplayName ('ZW bench ' + $_) -Group $grp -Direction Outbound -Action Block -RemoteAddress $rng -Enabled True | Out-Null }
    Get-NetFirewallRule -Group $grp | Remove-NetFirewallRule
}
Measure-Ms 'COM     enumerate all rules (mode check)' { $p = New-Object -ComObject HNetCfg.FwPolicy2; foreach ($r in $p.Rules) { $null = $r.Grouping } } 3
Measure-Ms 'COM     create 2 rules + remove them' {
    $p = New-Object -ComObject HNetCfg.FwPolicy2
    foreach ($d in @(@('ZW bench a', 2), @('ZW bench b', 1))) {
        $r = New-Object -ComObject HNetCfg.FWRule
        $r.Name = $d[0]; $r.Grouping = $grp; $r.Direction = $d[1]; $r.Action = 0; $r.Protocol = 256; $r.Profiles = 2147483647
        $r.RemoteAddresses = ($rng -join ','); $r.Enabled = $true
        $p.Rules.Add($r)
    }
    foreach ($n in 'ZW bench a', 'ZW bench b') { $p.Rules.Remove($n) }
} 3
Measure-Ms 'cmdlet  Get-NetRoute (Test-Box today)' { Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Out-Null }
Measure-Ms 'cmdlet  Clear-DnsClientCache (switch today)' { Clear-DnsClientCache -ErrorAction SilentlyContinue }
'''
FILES['bench.yml'] = r'''name: bench
on:
  workflow_dispatch:
jobs:
  bench:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - name: Bench (Windows PowerShell 5.1)
        shell: powershell
        run: powershell -ExecutionPolicy Bypass -File tools\bench.ps1 | Tee-Object -FilePath bench.txt
      - name: Smoke test (starts the real app for about 2 minutes)
        shell: powershell
        continue-on-error: true
        run: powershell -ExecutionPolicy Bypass -File tools\smoke.ps1
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: bench
          path: |
            bench.txt
            smoke-screen.png
            smoke-log.txt
'''
FILES['check-csharp.ps1'] = r'''# tools/check-csharp.ps1 - compiles every C# block of ZerkiWatch.bat ($xxxCode = @' ... '@) with Windows PowerShell 5.1 (C# 5 compiler).
# Without it a C# error only shows up on a user's PC. Single-quoted pieces on purpose: in "..." the text \$(...) would be a PowerShell sub-expression.
# $refs = the extra assemblies the app passes to Add-TypeCached for each block (a block that is not listed is compiled with none).
$root = Split-Path -Parent $PSScriptRoot
$t = [IO.File]::ReadAllText((Join-Path $root 'ZerkiWatch.bat'))
$refs = @{ nativeCode = @(); hkCode = @('System.Windows.Forms'); themeCode = @('System.Windows.Forms', 'System.Drawing'); netCode = @('System.Core') }
$rx = '(?s)\$(\w+Code)\s*=\s*@' + "'" + '\r?\n(.*?)\r?\n' + "'" + '@'
$bad = 0
$cnt = 0
foreach ($m in [regex]::Matches($t, $rx)) {
    $cnt++
    $name = $m.Groups[1].Value
    $dll = Join-Path $env:TEMP ($name + '.dll')
    $r = @()
    if ($refs.ContainsKey($name)) { $r = $refs[$name] }
    try {
        if ($r.Count -gt 0) { Add-Type -TypeDefinition $m.Groups[2].Value -ReferencedAssemblies $r -OutputAssembly $dll -OutputType Library }
        else { Add-Type -TypeDefinition $m.Groups[2].Value -OutputAssembly $dll -OutputType Library }
        Write-Host ($name + ': compiled OK')
    } catch { Write-Host ($name + ': ' + $_.Exception.Message); $bad++ }
}
if ($cnt -lt 4) { Write-Host ('expected at least 4 C# blocks, found ' + $cnt); $bad++ }
if ($bad -gt 0) { exit 1 }
'''
FILES['dllcache.ps1'] = r'''# Compiled helper types are cached as a DLL (hash of the source): the C# compiler only runs the first time.
# The cache lives in %ProgramData%\ZerkiWatch\cache, a folder only SYSTEM and Administrators can write (this process is elevated and loads these DLLs).
# A DLL that is not owned by Administrators/SYSTEM is deleted and rebuilt. If no safe folder is available the code is compiled in memory.
$cacheState = @{ done = $false; dir = $null }
function Get-CacheDir {
    if ($cacheState.done) { return $cacheState.dir }
    $cacheState.done = $true
    $cdir = Join-Path $env:ProgramData 'ZerkiWatch\cache'
    try {
        $di = New-Object System.IO.DirectoryInfo($cdir)
        if (-not $di.Exists) { $di.Create() }
        $adm = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
        $sys = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-18')
        $acl = New-Object System.Security.AccessControl.DirectorySecurity
        $acl.SetOwner($adm)
        $acl.SetAccessRuleProtection($true, $false)
        $inh = [System.Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
        $prp = [System.Security.AccessControl.PropagationFlags]::None
        $alw = [System.Security.AccessControl.AccessControlType]::Allow
        foreach ($sid in @($adm, $sys)) {
            $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($sid, [System.Security.AccessControl.FileSystemRights]::FullControl, $inh, $prp, $alw)))
        }
        $di.SetAccessControl($acl)
        $cacheState.dir = $cdir
        return $cdir
    } catch { Write-Log ('Type cache folder unavailable, compiling in memory: ' + $_.Exception.Message); return $null }
}
function Test-AdminOwned([string]$path) {
    try {
        $own = ([System.IO.File]::GetAccessControl($path)).GetOwner([System.Security.Principal.SecurityIdentifier]).Value
        return (@('S-1-5-32-544', 'S-1-5-18') -contains $own)
    } catch { return $false }
}
function Add-TypeCached([string]$Code, [string[]]$Refs = @()) {
    try {
        $cdir = Get-CacheDir
        if ($cdir) {
            $sha = [System.Security.Cryptography.SHA256]::Create()
            $hs = ([BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Code)))).Replace('-', '').Substring(0, 16)
            $dll = Join-Path $cdir ('t' + $hs + '.dll')
            if ((Test-Path -LiteralPath $dll) -and (-not (Test-AdminOwned $dll))) { Write-Log ('Type cache: removed a DLL that is not owned by Administrators: ' + $dll); Remove-Item -LiteralPath $dll -Force }
            if (-not (Test-Path -LiteralPath $dll)) {
                if ($Refs.Count -gt 0) { Add-Type -TypeDefinition $Code -ReferencedAssemblies $Refs -OutputAssembly $dll -OutputType Library } else { Add-Type -TypeDefinition $Code -OutputAssembly $dll -OutputType Library }
                # owner = Administrators whatever the "default owner" policy of this PC says (the check below only trusts that owner)
                try { $fsec = New-Object System.Security.AccessControl.FileSecurity; $fsec.SetOwner((New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544'))); [System.IO.File]::SetAccessControl($dll, $fsec) } catch { }
            }
            if (Test-AdminOwned $dll) { Add-Type -Path $dll; return }
        }
    } catch { }
    # no safe cache: compile in memory (slower, still correct)
    Write-Log 'Type cache: compiling in memory'
    if ($Refs.Count -gt 0) { Add-Type -TypeDefinition $Code -ReferencedAssemblies $Refs } else { Add-Type -TypeDefinition $Code }
}
'''
FILES['fw.ps1'] = r'''# ---------- Fast firewall engine (COM HNetCfg.FwPolicy2: no CIM, no NetSecurity module) ----------
# The old cmdlet functions are kept under the names *Slow and used as a safety net when anything unexpected happens.
$FwRuleOut = 'ZerkiWatch - Block Internet (outbound)'
$FwRuleIn  = 'ZerkiWatch - Block Internet (inbound)'
function Get-FwPolicy { return (New-Object -ComObject HNetCfg.FwPolicy2) }
function Get-OurGroups { return (@($Group) + $LegacyGroups) }

# Same meaning as the old Get-Mode: LOCAL when one of our groups (current or legacy) holds 2 enabled rules. One enumeration, no CIM.
function Get-ModeFast {
    $pol = Get-FwPolicy
    $grps = Get-OurGroups
    $cnt = @{}
    foreach ($r in $pol.Rules) {
        $gname = [string]$r.Grouping
        if (($gname -ne '') -and ($grps -contains $gname) -and $r.Enabled) {
            if ($cnt.ContainsKey($gname)) { $cnt[$gname] = $cnt[$gname] + 1 } else { $cnt[$gname] = 1 }
        }
    }
    foreach ($v in $cnt.Values) { if ($v -ge 2) { return 'LOCAL' } }
    return 'INTERNET'
}
function Get-OurRuleCount {
    $pol = Get-FwPolicy
    $grps = Get-OurGroups
    $n = 0
    foreach ($r in $pol.Rules) { $gname = [string]$r.Grouping; if (($gname -ne '') -and ($grps -contains $gname)) { $n++ } }
    return $n
}
function Remove-RulesFast {
    $pol = Get-FwPolicy
    $grps = Get-OurGroups
    $names = @{}
    foreach ($r in $pol.Rules) {
        $gname = [string]$r.Grouping
        if (($gname -ne '') -and ($grps -contains $gname)) { $names[[string]$r.Name] = $true }
    }
    foreach ($nm in @($names.Keys)) { try { $pol.Rules.Remove($nm) } catch { } }
}
function Set-ModeLocalFast($remote) {
    $pol = Get-FwPolicy
    Remove-RulesFast
    $csv = (@($remote) -join ',')
    foreach ($def in @(@($FwRuleOut, 2), @($FwRuleIn, 1))) {
        $r = New-Object -ComObject HNetCfg.FWRule
        $r.Name = [string]$def[0]
        $r.Description = 'Created by ZerkiWatch. Blocks everything except the local network.'
        $r.Grouping = $Group
        $r.Direction = [int]$def[1]      # 1 = inbound, 2 = outbound
        $r.Action = 0                    # 0 = block
        $r.Protocol = 256                # any
        $r.Profiles = 2147483647         # all profiles
        $r.RemoteAddresses = $csv        # comma separated, a-b ranges allowed (IPv4 and IPv6)
        $r.Enabled = $true
        $pol.Rules.Add($r)
    }
    if ((Get-ModeFast) -ne 'LOCAL') { throw (T 'err.rules_inactive') }
}
function Set-ModeInternetFast {
    Remove-RulesFast
    if ((Get-OurRuleCount) -gt 0) { throw (T 'err.rules_left') }
}
# Profiles that are switched off. Any odd answer from COM -> the old cmdlet decides (never a false "firewall disabled" error).
function Get-DisabledProfiles {
    try {
        $pol = Get-FwPolicy
        $off = @()
        foreach ($pt in @(@(1, 'Domain'), @(2, 'Private'), @(4, 'Public'))) {
            $v = $pol.FirewallEnabled($pt[0])
            if ($v -isnot [bool]) { throw 'unexpected answer' }
            if (-not $v) { $off += [string]$pt[1] }
        }
        return , $off
    } catch { }
    return , @(Get-NetFirewallProfile | Where-Object { $_.Enabled -eq 'False' } | ForEach-Object { [string]$_.Name })
}
function Clear-DnsFast { try { $null = & cmd.exe /c 'ipconfig /flushdns >nul 2>&1' } catch { } }

# The ranges "everything except the local network" (code moved as it was from Set-ModeLocal; only the IPv6 CIM query became plain .NET)
function Get-LocalOnlyRanges {
    $v4Allowed = @('0.0.0.0/8', '10.0.0.0/8', '127.0.0.0/8', '169.254.0.0/16', '172.16.0.0/12', '192.168.0.0/16', '224.0.0.0/3') + $ExtraIPv4
    $v6Allowed = @('::/128', '::1/128', 'fc00::/7', 'fe80::/10', 'ff00::/8') + $ExtraIPv6
    $v6Dyn = New-Object System.Collections.ArrayList
    foreach ($ni in [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
        if ($ni.OperationalStatus -ne [System.Net.NetworkInformation.OperationalStatus]::Up) { continue }
        foreach ($ua in $ni.GetIPProperties().UnicastAddresses) {
            if ($ua.Address.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetworkV6) { continue }
            $t6 = $ua.Address.ToString()
            if (($t6 -match '^[23]') -and ($ua.PrefixLength -ge 64)) {
                $p6 = $t6 + '/' + $ua.PrefixLength
                if (-not $v6Dyn.Contains($p6)) { [void]$v6Dyn.Add($p6) }
            }
        }
    }
    $v6Allowed = $v6Allowed + @($v6Dyn.ToArray())
    $v4Iv = @(); foreach ($c in $v4Allowed) { $v4Iv += Get-Interval $c 32 }
    $v6Iv = @(); foreach ($c in $v6Allowed) { $v6Iv += Get-Interval $c 128 }
    $v4Block = ConvertTo-RangeStrings (Get-Complement $v4Iv 32) 4
    $v6Block = ConvertTo-RangeStrings (Get-Complement $v6Iv 128) 16
    return (@($v4Block) + @($v6Block))
}

# Dispatchers: fast COM path first, the old cmdlets as a safety net. The UI, the timers and the iPhone code keep calling the same names.
function Get-Mode {
    try { return (Get-ModeFast) } catch { }
    return (Get-ModeSlow)
}
function Set-ModeInternet {
    $done = $false
    try { Set-ModeInternetFast; $done = $true } catch { }
    if (-not $done) { Set-ModeInternetSlow }
    Clear-DnsFast
}
function Set-ModeLocal {
    $svc = Get-Service -Name 'mpssvc'
    if ($svc.Status -ne 'Running') { throw (T 'err.fw_stopped') }
    $off = Get-DisabledProfiles
    if ($off.Count -gt 0) { throw (Tf 'err.fw_disabled' @(($off -join ', '))) }
    $remote = $null
    try { $remote = @(Get-LocalOnlyRanges) } catch { $remote = $null }
    $done = $false
    if (($remote -ne $null) -and ($remote.Count -gt 0)) {
        try { Set-ModeLocalFast $remote; $done = $true } catch { try { Remove-RulesFast } catch { } }
    }
    if (-not $done) { Set-ModeLocalSlow }
    Clear-DnsFast
}
'''
FILES['hist.cs'] = r'''using System;
using System.Collections.Generic;
using System.Globalization;
public static class HistParse {
    // Same result as the PowerShell loop in Load-History: records [minuteIndex, dl, ul, cpu, ram, gpu, rx, tx] newer than cutoff.
    public static List<double[]> Parse(string[] lines, DateTime epoch, DateTime cutoff, List<string> keepLines) {
        List<double[]> res = new List<double[]>(lines.Length);
        CultureInfo inv = CultureInfo.InvariantCulture;
        foreach (string ln in lines) {
            string[] p = ln.Split(',');
            if (p.Length < 8) continue;
            DateTime dt;
            if (!DateTime.TryParseExact(p[0], "yyyyMMddHHmm", inv, DateTimeStyles.None, out dt)) continue;
            if (dt < cutoff) continue;
            double[] rec = new double[8];
            rec[0] = Math.Floor((dt - epoch).TotalMinutes);
            bool ok = true;
            for (int i = 1; i < 8; i++) { if (!double.TryParse(p[i], NumberStyles.Float, inv, out rec[i])) { ok = false; break; } }
            if (!ok) continue;
            res.Add(rec);
            keepLines.Add(ln);
        }
        return res;
    }
}
'''
FILES['lang_funcs.ps1'] = r'''# Languages are kept as raw text per language; only the active language + en + fr are parsed (T and the iPhone page read only those).
# The other embedded languages only get their "lang.name", so the language menus still list them. Set-Language restarts the app.
$LangRaw = @{}
function Unescape-Lang([string]$s) {
    if ($s.IndexOf('\') -lt 0) { return $s }
    $sb = New-Object System.Text.StringBuilder($s.Length)
    $n = $s.Length
    $i = 0
    while ($i -lt $n) {
        $c = $s[$i]
        if (($c -eq '\') -and (($i + 1) -lt $n)) {
            $d = $s[$i + 1]
            if ($d -eq 'n') { [void]$sb.Append("`n"); $i += 2; continue }
            if (($d -eq 'u') -and (($i + 5) -lt $n)) {
                $v = 0
                if ([int]::TryParse($s.Substring($i + 2, 4), [System.Globalization.NumberStyles]::AllowHexSpecifier, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$v)) { [void]$sb.Append([char]$v); $i += 6; continue }
            }
        }
        [void]$sb.Append($c)
        $i++
    }
    return $sb.ToString()
}
function ConvertFrom-LangEsc([string]$s) { return (Unescape-Lang $s) }
function Add-LangLines($lines, [string]$code) {
    if ($lines -is [string]) { $lines = $lines.Split("`n") }
    foreach ($ln in $lines) {
        $t = ([string]$ln).Trim()
        if ($t.Length -lt 2) { continue }
        $c0 = $t[0]
        if ($c0 -eq '#') { continue }
        if (($c0 -eq '[') -and ($t -match '^\[([A-Za-z\-]{2,10})\]$')) {
            $code = $Matches[1].ToLower()
            if (-not $LangDb.ContainsKey($code)) { $LangDb[$code] = @{} }
            continue
        }
        $i = $t.IndexOf('=')
        if (($i -lt 1) -or ($code -eq '')) { continue }
        if (-not $LangDb.ContainsKey($code)) { $LangDb[$code] = @{} }
        $LangDb[$code][$t.Substring(0, $i).Trim()] = Unescape-Lang ($t.Substring($i + 1))
    }
}
# Cuts the embedded text into one raw section per language (no parsing) and registers each code with its "lang.name"
function Split-LangData([string]$text) {
    $ms = [regex]::Matches($text, '(?m)^\[([A-Za-z\-]{2,10})\][ \t\r]*$')
    for ($k = 0; $k -lt $ms.Count; $k++) {
        $code = $ms[$k].Groups[1].Value.ToLower()
        $a = $ms[$k].Index
        $b = $text.Length
        if (($k + 1) -lt $ms.Count) { $b = $ms[$k + 1].Index }
        $sec = $text.Substring($a, $b - $a)
        if ($LangRaw.ContainsKey($code)) { $LangRaw[$code] = $LangRaw[$code] + "`n" + $sec } else { $LangRaw[$code] = $sec }
        if (-not $LangDb.ContainsKey($code)) { $LangDb[$code] = @{} }
        $p = $sec.IndexOf("`nlang.name=")
        if ($p -ge 0) {
            $e = $sec.IndexOf("`n", $p + 1)
            if ($e -lt 0) { $e = $sec.Length }
            $LangDb[$code]['lang.name'] = Unescape-Lang ($sec.Substring($p + 11, $e - $p - 11).Trim())
        }
    }
}
function Ensure-Lang([string]$code) {
    if (-not $LangRaw.ContainsKey($code)) { return }
    $txt = $LangRaw[$code]
    $LangRaw.Remove($code)
    Add-LangLines $txt.Split("`n") $code
}
function Ensure-AllLang { foreach ($c in @($LangRaw.Keys)) { Ensure-Lang $c } }
'''
FILES['lang_runtime.ps1'] = r'''function Get-TextHash([string]$s) {
    $norm = $s.Replace("`r`n", "`n").Trim()
    $sha = [System.Security.Cryptography.SHA256]::Create()
    return ([BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($norm)))).Replace('-', '').Substring(0, 16).ToLower()
}
Split-LangData $langData
Mark-Step 'languages split'
try {
    $selfPath0 = $env:SELF
    if (-not $selfPath0) { $selfPath0 = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName }
    foreach ($ld in @((Join-Path (Split-Path -Parent $selfPath0) 'lang'), (Join-Path $logDir 'lang'))) {
        if (-not [System.IO.Directory]::Exists($ld)) { continue }
        foreach ($lfPath in [System.IO.Directory]::GetFiles($ld, '*.txt')) {
            try {
                $lcode = [System.IO.Path]::GetFileNameWithoutExtension($lfPath).ToLower()
                $txt = [System.IO.File]::ReadAllText($lfPath, [System.Text.Encoding]::UTF8)
                if ($langHash.ContainsKey($lcode) -and ((Get-TextHash $txt) -eq $langHash[$lcode])) { continue }   # same as the embedded copy: nothing to load
                Ensure-AllLang                                                                                     # a real override: embedded first, the file on top (old order)
                Add-LangLines ($txt.Split("`n")) $lcode
            } catch { }
        }
    }
} catch { }
Mark-Step 'languages loaded'
'''
FILES['log.ps1'] = r'''# No Test-Path / Get-Item / Add-Content on every line: the rotation check runs once every 50 lines.
$logState = @{ n = 0 }
function Write-Log([string]$msg, [string]$key = '') {
    try {
        if ($key -ne '') {
            $n = [DateTime]::UtcNow
            if ($logLast.ContainsKey($key) -and (($n - $logLast[$key]).TotalSeconds -lt 60)) { return }
            $logLast[$key] = $n
        }
        if (($logState.n % 50) -eq 0) {
            if (-not [System.IO.Directory]::Exists($logDir)) { [void][System.IO.Directory]::CreateDirectory($logDir) }
            $fi = New-Object System.IO.FileInfo($logFile)
            if ($fi.Exists -and ($fi.Length -gt 400000)) { Move-Item -LiteralPath $logFile -Destination ($logFile + '.old') -Force }
        }
        $logState.n = $logState.n + 1
        $stamp = [DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture)
        [System.IO.File]::AppendAllText($logFile, ($stamp + '  ' + $msg + [Environment]::NewLine), [System.Text.Encoding]::ASCII)
    } catch { }
}
'''
FILES['mutex.ps1'] = r'''# OpenExisting throws (and PowerShell builds an error record) 3 times at EVERY normal launch: TryOpenExisting does not.
function Test-OldRun {
    foreach ($nm in @('Local\ModeReseauApp', 'Local\ModeReseauApp51', 'Local\ModeReseauApp54')) {
        $om = $null
        try { if ([System.Threading.Mutex]::TryOpenExisting($nm, [ref]$om)) { $om.Dispose(); return $true } } catch { }
    }
    return $false
}
'''
FILES['series.ps1'] = r'''# One PointF[] per series instead of one New-Object per point (about 155 us -> 2 us per point in the lab)
function Get-SeriesPoints($hist, [double]$x, [double]$y, [double]$w, [double]$h, [double]$mx, [bool]$close) {
    $cnt = $hist.Count
    $n = $cnt
    if ($close) { $n = $cnt + 2 }
    $pts = New-Object 'System.Drawing.PointF[]' $n
    $step = $w / 39.0
    for ($i = 0; $i -lt $cnt; $i++) {
        $pts[$i] = [System.Drawing.PointF]::new([single]($x + $w - ($cnt - 1 - $i) * $step), [single]($y + $h - ($hist[$i] / $mx) * $h))
    }
    if ($close) {
        $pts[$cnt] = [System.Drawing.PointF]::new([single]($x + $w), [single]($y + $h))
        $pts[$cnt + 1] = [System.Drawing.PointF]::new([single]($x + $w - ($cnt - 1) * $step), [single]($y + $h))
    }
    return , $pts
}
function Draw-Series($g, $hist, [single]$x, [single]$y, [single]$w, [single]$h, $color, [double]$mx, [bool]$fill) {
    $cnt = $hist.Count
    if ($cnt -lt 2) { return }
    if ($fill) {
        $poly = Get-SeriesPoints $hist $x $y $w $h $mx $true
        $fb = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(50, $color.R, $color.G, $color.B))
        $g.FillPolygon($fb, $poly)
        $fb.Dispose()
    }
    $pts = Get-SeriesPoints $hist $x $y $w $h $mx $false
    $lp = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(230, $color.R, $color.G, $color.B), [single]1.6)
    $lp.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $g.DrawLines($lp, $pts)
    $lp.Dispose()
}

'''
FILES['smoke.ps1'] = r'''# tools/smoke.ps1 - starts the REAL app on the CI runner, waits for the first refresh, fails on error lines, keeps log + screenshot
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$dir = Join-Path $env:APPDATA 'ZerkiWatch'
New-Item -ItemType Directory -Path $dir -Force | Out-Null
$log = Join-Path $dir 'log.txt'
if (Test-Path -LiteralPath $log) { Remove-Item -LiteralPath $log -Force }
# any config line hides the first-run wizard; Perf=1 turns on the PERF log lines (added by LOT 0)
Set-Content -LiteralPath (Join-Path $dir 'config.txt') -Value @('Perf=1', 'Wizard=1') -Encoding ASCII
Start-Process -FilePath 'cmd.exe' -ArgumentList ('/c ""' + (Join-Path $root 'ZerkiWatch.bat') + '""') -WindowStyle Hidden
$ok = $false
for ($i = 0; $i -lt 90; $i++) {
    Start-Sleep -Seconds 1
    if ((Test-Path -LiteralPath $log) -and ((Get-Content -LiteralPath $log -Raw) -match 'first refresh done')) { $ok = $true; break }
}
Start-Sleep -Seconds 65
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
try {
    $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp = New-Object System.Drawing.Bitmap($b.Width, $b.Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
    $bmp.Save((Join-Path $root 'smoke-screen.png'))
} catch { Write-Host ('screenshot failed: ' + $_.Exception.Message) }
$txt = ''
if (Test-Path -LiteralPath $log) { $txt = Get-Content -LiteralPath $log -Raw; Copy-Item -LiteralPath $log -Destination (Join-Path $root 'smoke-log.txt') }
Write-Host $txt
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like '*#PS*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
$errs = @($txt -split "`r?`n" | Where-Object { $_ -match 'FATAL|UI error|paint:|Update-Mon:|Update-Bar:|Remote:|Net job:' })
if ((-not $ok) -or ($errs.Count -gt 0)) { Write-Host ('SMOKE FAILED: started=' + $ok + ' errors=' + $errs.Count); exit 1 }
Write-Host 'SMOKE OK'
'''
FILES['svc.cs'] = r'''using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class SvcMap {
    [StructLayout(LayoutKind.Sequential)]
    struct ENUM_SERVICE_STATUS_PROCESS {
        public IntPtr lpServiceName;
        public IntPtr lpDisplayName;
        public int dwServiceType, dwCurrentState, dwControlsAccepted, dwWin32ExitCode, dwServiceSpecificExitCode, dwCheckPoint, dwWaitHint;
        public int dwProcessId;
        public int dwServiceFlags;
    }
    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)] static extern IntPtr OpenSCManager(string machine, string db, int access);
    [DllImport("advapi32.dll", SetLastError = true)] static extern bool CloseServiceHandle(IntPtr h);
    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool EnumServicesStatusEx(IntPtr scm, int infoLevel, int serviceType, int serviceState, IntPtr buf, int bufSize, out int bytesNeeded, out int servicesReturned, ref int resumeHandle, string groupName);
    // "pid|DisplayName" for every running Win32 service that owns a process (same lines the PowerShell code builds from WMI today)
    public static string[] Running() {
        List<string> res = new List<string>();
        IntPtr scm = OpenSCManager(null, null, 0x0004);
        if (scm == IntPtr.Zero) return res.ToArray();
        try {
            int need = 0, count = 0, resume = 0;
            EnumServicesStatusEx(scm, 0, 0x30, 0x1, IntPtr.Zero, 0, out need, out count, ref resume, null);
            if (need <= 0) return res.ToArray();
            int size = need + 8192;
            IntPtr buf = Marshal.AllocHGlobal(size);
            try {
                resume = 0;
                if (!EnumServicesStatusEx(scm, 0, 0x30, 0x1, buf, size, out need, out count, ref resume, null)) return res.ToArray();
                int stride = Marshal.SizeOf(typeof(ENUM_SERVICE_STATUS_PROCESS));
                for (int i = 0; i < count; i++) {
                    ENUM_SERVICE_STATUS_PROCESS e = (ENUM_SERVICE_STATUS_PROCESS)Marshal.PtrToStructure(new IntPtr(buf.ToInt64() + (long)i * stride), typeof(ENUM_SERVICE_STATUS_PROCESS));
                    if (e.dwProcessId <= 0) continue;
                    res.Add(e.dwProcessId.ToString() + "|" + Marshal.PtrToStringUni(e.lpDisplayName));
                }
            } finally { Marshal.FreeHGlobal(buf); }
        } finally { CloseServiceHandle(scm); }
        return res.ToArray();
    }
}
'''
FILES['svcmap.ps1'] = r'''function Update-SvcMap {
    $map = @{}
    foreach ($ln in [SvcMap]::Running()) {
        $p = ([string]$ln).Split('|', 2)
        if ($p.Count -lt 2) { continue }
        $spid = 0
        if (-not [int]::TryParse($p[0], [ref]$spid)) { continue }
        if (-not $map.ContainsKey($spid)) { $map[$spid] = New-Object 'System.Collections.Generic.List[string]' }
        $map[$spid].Add($p[1])
    }
    if ($map.Count -gt 0) { $S.SvcMap = $map }
    $S.SvcStamp = [DateTime]::UtcNow
}
'''
FILES['test-cache.ps1'] = r'''# tools/test-cache.ps1 - the helper-type cache must live in a folder that only SYSTEM and Administrators can write.
# Runs the REAL Get-CacheDir / Test-AdminOwned / Add-TypeCached of ZerkiWatch.bat on the CI runner (Windows PowerShell 5.1, elevated), in a temporary folder.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$t = [IO.File]::ReadAllText((Join-Path $root 'ZerkiWatch.bat'))
$a = $t.IndexOf('# Compiled helper types are cached as a DLL')
$b = $t.IndexOf("`n" + '$native = $false', $a)
if (($a -lt 0) -or ($b -lt 0)) { Write-Host 'cache code not found in ZerkiWatch.bat'; exit 1 }
$base = Join-Path ([IO.Path]::GetTempPath()) ('zwcache-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $base | Out-Null
$env:ProgramData = $base
Invoke-Expression $t.Substring($a, $b - $a)
$fail = 0
function Check([string]$what, [bool]$ok) { if ($ok) { Write-Host ('ok    ' + $what) } else { Write-Host ('FAIL  ' + $what); $script:fail++ } }
$cdir = Get-CacheDir
Check 'cache folder created' (($cdir -ne $null) -and (Test-Path -LiteralPath $cdir))
if ($cdir -ne $null) {
    $acl = (New-Object System.IO.DirectoryInfo($cdir)).GetAccessControl()
    $rules = @($acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]))
    $sids = @($rules | ForEach-Object { $_.IdentityReference.Value } | Sort-Object)
    Check 'inheritance from the parent is cut' $acl.AreAccessRulesProtected
    Check 'only Administrators and SYSTEM have access' (($sids -join ',') -eq 'S-1-5-18,S-1-5-32-544')
    Check 'owner is Administrators' ($acl.GetOwner([System.Security.Principal.SecurityIdentifier]).Value -eq 'S-1-5-32-544')
    Check 'no rule grants access to Users / Everyone / Authenticated Users' (@($sids | Where-Object { @('S-1-5-32-545', 'S-1-1-0', 'S-1-5-11') -contains $_ }).Count -eq 0)
}
# 1) a normal compile goes through the cache
Add-TypeCached 'public static class ZwCacheTest1 { public static int V() { return 41; } }'
Check 'type compiled and usable' ([ZwCacheTest1]::V() -eq 41)
$dlls = @(Get-ChildItem -LiteralPath $cdir -Filter 't*.dll')
Check 'a DLL was written to the cache' ($dlls.Count -ge 1)
Check 'that DLL is owned by Administrators/SYSTEM' ((Test-AdminOwned $dlls[0].FullName))
# 2) a DLL planted with another owner must be ignored and rebuilt
$code2 = 'public static class ZwCacheTest2 { public static int V() { return 7; } }'
$sha = [System.Security.Cryptography.SHA256]::Create()
$hs = ([BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($code2)))).Replace('-', '').Substring(0, 16)
$planted = Join-Path $cdir ('t' + $hs + '.dll')
[IO.File]::WriteAllBytes($planted, [byte[]](1, 2, 3, 4))
$planted_ok = $false
try {
    $fs = New-Object System.Security.AccessControl.FileSecurity
    $fs.SetOwner((New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-545')))
    [IO.File]::SetAccessControl($planted, $fs)
    $planted_ok = (-not (Test-AdminOwned $planted))
} catch { Write-Host ('note: cannot give the planted file another owner here (' + $_.Exception.Message + ')') }
if ($planted_ok) {
    Add-TypeCached $code2
    Check 'planted DLL (owner = Users) was not loaded: the real type works' ([ZwCacheTest2]::V() -eq 7)
    Check 'planted DLL was replaced by an Administrators-owned one' (Test-AdminOwned $planted)
} else { Write-Host 'skip  planted-DLL check (owner could not be changed on this runner)' }
Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
if ($fail -gt 0) { Write-Host ('CACHE TEST FAILED: ' + $fail); exit 1 }
Write-Host 'CACHE TEST OK'
'''
FILES['test-fw.ps1'] = r'''# tools/test-fw.ps1 - runs the REAL firewall functions of ZerkiWatch.bat on the CI runner (Windows PowerShell 5.1).
# Throw-away group + TEST-NET ranges (192.0.2.0/24, 198.51.100.0/24 are reserved for documentation): blocking them cuts nothing real.
# NEVER calls the real Set-ModeLocal (it would cut the runner's Internet). Prints timings. Exit 1 on any failure.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Numerics
$root = Split-Path -Parent $PSScriptRoot
$t = [IO.File]::ReadAllText((Join-Path $root 'ZerkiWatch.bat'))
$m = [regex]::Match($t, '(?s)\$ModeFnSrc\s*=\s*@' + "'" + '\r?\n(.*?)\r?\n' + "'" + '@')
if (-not $m.Success) { Write-Host 'ModeFnSrc not found'; exit 1 }
$fnSrc = $m.Groups[1].Value
$Group = 'ZW-CI-TEST'
$LegacyGroups = @('ZW-CI-TEST-OLD')
$ExtraIPv4 = @()
$ExtraIPv6 = @()
function T([string]$k) { return $k }
function Tf([string]$k, [object[]]$a) { return $k }
. ([scriptblock]::Create($fnSrc))
$FwRuleOut = 'ZW-CI-TEST out'
$FwRuleIn = 'ZW-CI-TEST in'
$fail = 0
function Check([string]$what, [bool]$ok) { if ($ok) { Write-Host ('ok    ' + $what) } else { Write-Host ('FAIL  ' + $what); $script:fail++ } }
function Time-It([string]$label, [scriptblock]$sb) { $sw = [Diagnostics.Stopwatch]::StartNew(); $r = & $sb; Write-Host ('{0,-46} {1,9:N1} ms' -f $label, $sw.Elapsed.TotalMilliseconds); return $r }
$rng = @('192.0.2.0-192.0.2.255', '198.51.100.0-198.51.100.255')
try {
    Remove-RulesFast
    Check 'start: INTERNET' ((Get-ModeFast) -eq 'INTERNET')
    $null = Time-It 'Set-ModeLocalFast (first call, 2 rules)' { Set-ModeLocalFast $rng }
    Check 'after local: Get-ModeFast = LOCAL' ((Get-ModeFast) -eq 'LOCAL')
    $cm = @(Get-NetFirewallRule -Group $Group -ErrorAction SilentlyContinue)
    Check 'NetSecurity cmdlets see 2 rules in the group' ($cm.Count -eq 2)
    Check 'both enabled and Block' (@($cm | Where-Object { ($_.Enabled -eq 'True') -and ($_.Action -eq 'Block') }).Count -eq 2)
    Check 'one outbound and one inbound' ((@($cm | Where-Object { $_.Direction -eq 'Outbound' }).Count -eq 1) -and (@($cm | Where-Object { $_.Direction -eq 'Inbound' }).Count -eq 1))
    Check 'profiles = Any' (@($cm | Where-Object { $_.Profile -eq 'Any' }).Count -eq 2)
    $af = @($cm | ForEach-Object { ($_ | Get-NetFirewallAddressFilter).RemoteAddress })
    Check 'remote ranges stored as given' ((($af | ForEach-Object { $_ }) -join ',') -match '192\.0\.2\.0')
    $null = Time-It 'Get-ModeFast (all rules enumerated)' { Get-ModeFast }
    $null = Time-It 'Set-ModeInternetFast' { Set-ModeInternetFast }
    Check 'after internet: Get-ModeFast = INTERNET' ((Get-ModeFast) -eq 'INTERNET')
    Check 'no rule left (cmdlets)' (@(Get-NetFirewallRule -Group $Group -ErrorAction SilentlyContinue).Count -eq 0)
    $null = Time-It 'Set-ModeLocalFast (second call)' { Set-ModeLocalFast $rng }
    $null = Time-It 'Set-ModeInternetFast (second call)' { Set-ModeInternetFast }
    # old group: two enabled rules created with the cmdlets must read as LOCAL and be removed by Remove-RulesFast
    1..2 | ForEach-Object { New-NetFirewallRule -DisplayName ('ZW-CI-TEST old ' + $_) -Group $LegacyGroups[0] -Direction Outbound -Action Block -RemoteAddress $rng[0] -Enabled True | Out-Null }
    Check 'legacy group with 2 enabled rules reads as LOCAL' ((Get-ModeFast) -eq 'LOCAL')
    Remove-RulesFast
    Check 'legacy rules removed by Remove-RulesFast' (@(Get-NetFirewallRule -Group $LegacyGroups[0] -ErrorAction SilentlyContinue).Count -eq 0)
    # the app runs this code in a background runspace
    $bg = @'
param($Group, $LegacyGroups, $ExtraIPv4, $ExtraIPv6, $FnSrc, $Rng)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Numerics
function T([string]$k) { return $k }
function Tf([string]$k, [object[]]$a) { return $k }
. ([scriptblock]::Create($FnSrc))
$FwRuleOut = 'ZW-CI-TEST out'
$FwRuleIn = 'ZW-CI-TEST in'
Set-ModeLocalFast $Rng
$m1 = Get-ModeFast
Set-ModeInternetFast
$m2 = Get-ModeFast
($m1 + ',' + $m2)
'@
    $ps = [powershell]::Create()
    [void]$ps.AddScript($bg).AddArgument($Group).AddArgument($LegacyGroups).AddArgument($ExtraIPv4).AddArgument($ExtraIPv6).AddArgument($fnSrc).AddArgument($rng)
    $h = $ps.BeginInvoke()
    $out = @($ps.EndInvoke($h))
    if ($ps.Streams.Error.Count -gt 0) { Write-Host ($ps.Streams.Error | Out-String) }
    Check 'works inside a background runspace (as in the app)' (($out.Count -gt 0) -and ([string]$out[0] -eq 'LOCAL,INTERNET'))
    $ps.Dispose()
    # FirewallEnabled(profile) must answer a boolean for the three profiles
    $pol = Get-FwPolicy
    foreach ($pt in @(1, 2, 4)) { Check ('FirewallEnabled(' + $pt + ') answers a boolean') ($pol.FirewallEnabled($pt) -is [bool]) }
    Check 'Get-DisabledProfiles runs' ($null -ne (Get-DisabledProfiles))
    # ranges: local addresses stay reachable, internet addresses are inside the blocked ranges
    $rg = @(Time-It 'Get-LocalOnlyRanges' { Get-LocalOnlyRanges })
    Check 'Get-LocalOnlyRanges returns IPv4 and IPv6 ranges' ($rg.Count -ge 8)
    function To-U32([string]$ip) { $b = [System.Net.IPAddress]::Parse($ip).GetAddressBytes(); return ([uint64]$b[0] * 16777216 + [uint64]$b[1] * 65536 + [uint64]$b[2] * 256 + [uint64]$b[3]) }
    function In-Ranges([string]$ip, $ranges) {
        $x = To-U32 $ip
        foreach ($r in $ranges) {
            if ($r -match ':') { continue }
            $p = $r.Split('-'); $a = To-U32 $p[0]; $b = $a; if ($p.Count -gt 1) { $b = To-U32 $p[1] }
            if (($x -ge $a) -and ($x -le $b)) { return $true }
        }
        return $false
    }
    foreach ($ip in @('10.1.2.3', '192.168.1.1', '127.0.0.1', '169.254.1.1', '172.16.0.1', '172.31.255.255', '224.0.0.251', '239.255.255.250')) { Check ('stays reachable: ' + $ip) (-not (In-Ranges $ip $rg)) }
    foreach ($ip in @('1.1.1.1', '8.8.8.8', '93.184.216.34', '172.15.255.255', '172.32.0.0', '192.169.0.1', '100.64.0.1')) { Check ('is blocked: ' + $ip) (In-Ranges $ip $rg) }
} finally {
    try { Remove-RulesFast } catch { }
    Get-NetFirewallRule -Group 'ZW-CI-TEST' -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
    Get-NetFirewallRule -Group 'ZW-CI-TEST-OLD' -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
}
if ($fail -gt 0) { Write-Host ('FIREWALL TEST FAILED: ' + $fail); exit 1 }
Write-Host 'FIREWALL TEST OK'
'''
FILES['tests.ps1'] = r'''# Worst case 2 s instead of 3 x 2 s: the three connections are tried at the same time, the first success wins
function Test-AnyTcp($Targets, [int]$TimeoutMs) {
    $clients = New-Object System.Collections.ArrayList
    try {
        foreach ($t in $Targets) {
            try {
                $addr = [System.Net.IPAddress]::Parse([string]$t[0])
                $c = New-Object System.Net.Sockets.TcpClient -ArgumentList $addr.AddressFamily
                $iar = $c.BeginConnect($addr, [int]$t[1], $null, $null)
                [void]$clients.Add(@($c, $iar))
            } catch { }
        }
        $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMs)
        $pending = New-Object System.Collections.ArrayList
        foreach ($p in $clients) { [void]$pending.Add($p) }
        while (($pending.Count -gt 0) -and ([DateTime]::UtcNow -lt $deadline)) {
            foreach ($p in @($pending.ToArray())) {
                if ($p[1].IsCompleted) {
                    [void]$pending.Remove($p)
                    try { $p[0].EndConnect($p[1]); return $true } catch { }
                }
            }
            Start-Sleep -Milliseconds 15
        }
        return $false
    } finally { foreach ($p in $clients) { try { $p[0].Close() } catch { } } }
}
function Test-Internet {
    return (Test-AnyTcp @(@('1.1.1.1', 443), @('8.8.8.8', 443), @('2606:4700:4700::1111', 443)) 2000)
}
# The router (box) test: default gateways come from .NET (no Get-NetRoute / CIM, which costs 0.3 - 1 s the first time); up to 3 are pinged at the same time
function Test-AnyPing($Targets, [int]$TimeoutMs) {
    $pings = New-Object System.Collections.ArrayList
    $tasks = New-Object System.Collections.ArrayList
    try {
        foreach ($ip in $Targets) {
            try {
                $p = New-Object System.Net.NetworkInformation.Ping
                [void]$pings.Add($p)
                [void]$tasks.Add($p.SendPingAsync([string]$ip, $TimeoutMs))
            } catch { }
        }
        $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMs + 500)
        while (($tasks.Count -gt 0) -and ([DateTime]::UtcNow -lt $deadline)) {
            foreach ($tk in @($tasks.ToArray())) {
                if ($tk.IsCompleted) {
                    [void]$tasks.Remove($tk)
                    try { if ((-not $tk.IsFaulted) -and (-not $tk.IsCanceled) -and ($tk.Result.Status -eq [System.Net.NetworkInformation.IPStatus]::Success)) { return $true } } catch { }
                }
            }
            Start-Sleep -Milliseconds 15
        }
        return $false
    } finally { foreach ($p in $pings) { try { $p.Dispose() } catch { } } }
}
function Get-GatewayList {
    $gws = New-Object System.Collections.ArrayList
    try {
        foreach ($ni in [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
            if ($ni.OperationalStatus -ne [System.Net.NetworkInformation.OperationalStatus]::Up) { continue }
            if ($ni.NetworkInterfaceType -eq [System.Net.NetworkInformation.NetworkInterfaceType]::Loopback) { continue }
            foreach ($ga in $ni.GetIPProperties().GatewayAddresses) {
                if ($ga.Address.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) { continue }
                $gs = $ga.Address.ToString()
                if (($gs -ne '0.0.0.0') -and (-not $gws.Contains($gs))) { [void]$gws.Add($gs) }
            }
        }
    } catch { }
    return , @($gws.ToArray())
}
function Test-Box {
    $gws = Get-GatewayList
    if ($gws.Count -eq 0) { return $false }
    return (Test-AnyPing @($gws | Select-Object -First 3) 2000)
}
'''
FILES['upd.ps1'] = r'''function Start-UpdateCheck {
    $S.UpdTask = $null
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add('User-Agent', 'ZerkiWatch')
        $S.UpdWc = $wc
        $S.UpdStart = [DateTime]::UtcNow
        $S.UpdTask = $wc.DownloadStringTaskAsync('https://api.github.com/repos/zerkino/ZerkiWatch/releases/latest')
    } catch { $S.UpdTask = $null }
}
# Call from a timer (500 ms). Returns $true when finished; the answer is in $S.UpdResult ($null = offline, else @{ Tag; Url; Newer }).
function Poll-UpdateCheck {
    if ($S.UpdTask -eq $null) { return $true }
    if (-not $S.UpdTask.IsCompleted) {
        if (([DateTime]::UtcNow - $S.UpdStart).TotalSeconds -gt 8) { try { $S.UpdWc.CancelAsync() } catch { } }
        return $false
    }
    $S.UpdResult = $null
    try {
        if ((-not $S.UpdTask.IsFaulted) -and (-not $S.UpdTask.IsCanceled)) {
            $r = ConvertFrom-Json $S.UpdTask.Result
            $tag = ([string]$r.tag_name).TrimStart('v', 'V')
            $S.UpdResult = @{ Tag = $tag; Url = [string]$r.html_url; Newer = ([Version]($tag -replace '[^0-9.].*$', '') -gt [Version]$APPVER) }
        }
    } catch { }
    $S.UpdTask = $null
    return $true
}
'''
LOTSRC[0] = r"""N = 0
MARK = 'function Perf-Add('
PERF_BLOCK = r'''$PerfS = @{ On = $false; At = [DateTime]::UtcNow }
$PerfAcc = @{}
function Perf-Add([string]$name, [long]$t0) {
    $ms = ([Diagnostics.Stopwatch]::GetTimestamp() - $t0) * 1000.0 / [Diagnostics.Stopwatch]::Frequency
    $a = $PerfAcc[$name]
    if ($a -eq $null) { $a = [double[]]@(0.0, 0.0, 0.0); $PerfAcc[$name] = $a }   # count, total ms, max ms
    $a[0] = $a[0] + 1
    $a[1] = $a[1] + $ms
    if ($ms -gt $a[2]) { $a[2] = $ms }
    if (([DateTime]::UtcNow - $PerfS.At).TotalSeconds -ge 30) { Perf-Flush }
}
function Perf-Flush {
    $PerfS.At = [DateTime]::UtcNow
    foreach ($k in @($PerfAcc.Keys | Sort-Object)) {
        $a = $PerfAcc[$k]
        if ($a[0] -gt 0) { Write-Log ('PERF ' + $k + ' n=' + [int]$a[0] + ' avg=' + ($a[1] / $a[0]).ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture) + ' ms max=' + $a[2].ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture) + ' ms') }
        $PerfAcc[$k] = [double[]]@(0.0, 0.0, 0.0)
    }
}
'''
T1 = "$pf0 = 0; if ($PerfS.On) { $pf0 = [Diagnostics.Stopwatch]::GetTimestamp() }; "
def wrap(stmt, name):
    return T1 + stmt + "; if ($PerfS.On) { Perf-Add '" + name + "' $pf0 }"

OPS = [
 # 1) PERF helpers (opt-in: "Perf=1" in config.txt)
 ('bat_edit', "$logLast = @{}\n", "$logLast = @{}\n" + PERF_BLOCK),
 # 2) read Perf= with the other early settings
 ('bat_edit',
  "            if ($ln0.StartsWith('Theme=')) { $ThemePref = $ln0.Substring(6).Trim().ToLower() }\n",
  "            if ($ln0.StartsWith('Theme=')) { $ThemePref = $ln0.Substring(6).Trim().ToLower() }\n"
  "            if ($ln0.StartsWith('Perf=')) { $PerfS.On = ($ln0.Substring(5).Trim() -eq '1') }\n"),
 # 3) Save-BarConfig rewrites config.txt from scratch: keep Perf=1
 ('bat_edit',
  "        if ($LangPref -ne '') { $lines = $lines + ('Lang=' + $LangPref) }\n",
  "        if ($LangPref -ne '') { $lines = $lines + ('Lang=' + $LangPref) }\n"
  "        if ($PerfS.On) { $lines = $lines + 'Perf=1' }\n"),
 # 4) more STARTUP marks (languages, history, per-app totals)
 ('bat_edit', "$LangCode = ''\n$ThemePref = 'dark'\n", "Mark-Step 'languages loaded'\n$LangCode = ''\n$ThemePref = 'dark'\n"),
 ('bat_edit', "\nLoad-History\n\n# ---------- Cumul par application", "\nLoad-History\nMark-Step 'history loaded'\n\n# ---------- Cumul par application"),
 ('bat_edit', "\nLoad-AppDays\n\n# ---------- Fenetre Historique ----------\n", "\nLoad-AppDays\nMark-Step 'app totals loaded'\n\n# ---------- Fenetre Historique ----------\n"),
 # 5) switch / network tests: time of each phase, logged as one NETJOB line (always on: rare event)
 ('bat_edit',
  "$res = @{ ok = $true; err = ''; net = $false; box = $false }\n"
  "if ($Target -ne '') {\n"
  "    try { if ($Target -eq 'LOCAL') { Set-ModeLocal } else { Set-ModeInternet } } catch { $res.ok = $false; $res.err = $_.Exception.Message }\n"
  "}\n"
  "if ($res.ok) {\n"
  "    try { $res.net = [bool](Test-Internet) } catch { }\n"
  "    try { $res.box = [bool](Test-Box) } catch { }\n"
  "}\n"
  "$res\n",
  "$res = @{ ok = $true; err = ''; net = $false; box = $false; msw = 0; mnet = 0; mbox = 0 }\n"
  "$swt = [System.Diagnostics.Stopwatch]::StartNew()\n"
  "if ($Target -ne '') {\n"
  "    try { if ($Target -eq 'LOCAL') { Set-ModeLocal } else { Set-ModeInternet } } catch { $res.ok = $false; $res.err = $_.Exception.Message }\n"
  "    $res.msw = [int]$swt.ElapsedMilliseconds\n"
  "}\n"
  "if ($res.ok) {\n"
  "    $swt.Restart()\n"
  "    try { $res.net = [bool](Test-Internet) } catch { }\n"
  "    $res.mnet = [int]$swt.ElapsedMilliseconds\n"
  "    $swt.Restart()\n"
  "    try { $res.box = [bool](Test-Box) } catch { }\n"
  "    $res.mbox = [int]$swt.ElapsedMilliseconds\n"
  "}\n"
  "$res\n"),
 ('bat_edit',
  "    if ($res -eq $null) { $res = @{ ok = $false; err = 'no result'; net = $false; box = $false } }\n    if ($res.ok) {\n",
  "    if ($res -eq $null) { $res = @{ ok = $false; err = 'no result'; net = $false; box = $false } }\n"
  "    try { Write-Log ('NETJOB ' + $(if ($target -ne '') { $target } else { 'tests' }) + ' total=' + [int]([DateTime]::UtcNow - $S.SwStart).TotalMilliseconds + ' ms (switch=' + $res.msw + ' net=' + $res.mnet + ' box=' + $res.mbox + ' ok=' + $res.ok + ')') } catch { }\n"
  "    if ($res.ok) {\n"),
 # 6) PERF probes (only measure when Perf=1)
 ('bat_edit',
  "$monTimer.Add_Tick({ try { Update-Mon } catch {",
  "$monTimer.Add_Tick({ " + T1 + "try { Update-Mon } catch {"),
 ('bat_edit',
  "'um' } })\n$monTimer.Start()\n",
  "'um' }; if ($PerfS.On) { Perf-Add 'update-mon' $pf0 } })\n$monTimer.Start()\n"),
 ('bat_edit',
  "    try { Update-Hist $drx $dtx $dt } catch { Write-Log ('Update-Hist: ' + $_.Exception.Message + ' (line ' + $_.InvocationInfo.ScriptLineNumber + ')') 'uh' }\n",
  "    " + wrap("try { Update-Hist $drx $dtx $dt } catch { Write-Log ('Update-Hist: ' + $_.Exception.Message + ' (line ' + $_.InvocationInfo.ScriptLineNumber + ')') 'uh' }", 'update-hist') + "\n"),
 ('bat_edit',
  "    if ($needProcs -and (($S.Tick % 2) -eq 0)) { try { Update-Procs } catch { } }\n",
  "    if ($needProcs -and (($S.Tick % 2) -eq 0)) { " + wrap("try { Update-Procs } catch { }", 'update-procs') + " }\n"),
 ('bat_edit',
  "    try { Update-Bar } catch { Write-Log ('Update-Bar: ' + $_.Exception.Message + ' (line ' + $_.InvocationInfo.ScriptLineNumber + ')') 'ub' }\n",
  "    " + wrap("try { Update-Bar } catch { Write-Log ('Update-Bar: ' + $_.Exception.Message + ' (line ' + $_.InvocationInfo.ScriptLineNumber + ')') 'ub' }", 'update-bar') + "\n"),
 ('bat_edit',
  "    try { Update-Widget } catch { Write-Log ('Update-Widget: ' + $_.Exception.Message + ' (line ' + $_.InvocationInfo.ScriptLineNumber + ')') 'uw' }\n",
  "    " + wrap("try { Update-Widget } catch { Write-Log ('Update-Widget: ' + $_.Exception.Message + ' (line ' + $_.InvocationInfo.ScriptLineNumber + ')') 'uw' }", 'update-widget') + "\n"),
 # paint handlers: window (right panel), floating bar and desktop widget
 ('bat_edit',
  "$pnlRight.Add_Paint({\n    param($sender, $pe)\n    try {\n",
  "$pnlRight.Add_Paint({\n    param($sender, $pe)\n    " + T1.rstrip() + "\n    try {\n"),
 ('bat_edit',
  "    } catch { Write-Log ('Window paint: ' + $_.Exception.Message + ' (line ' + $_.InvocationInfo.ScriptLineNumber + ')') 'pw' }\n})\n",
  "    } catch { Write-Log ('Window paint: ' + $_.Exception.Message + ' (line ' + $_.InvocationInfo.ScriptLineNumber + ')') 'pw' } finally { if ($PerfS.On) { Perf-Add 'paint-window' $pf0 } }\n})\n"),
 ('bat_edit',
  "$barForm.Add_Paint({ param($sender, $pe) Draw-Bar $pe.Graphics $BAR.K })\n",
  "$barForm.Add_Paint({ param($sender, $pe) " + wrap("Draw-Bar $pe.Graphics $BAR.K", 'paint-bar') + " })\n"),
 # flush the counters when the app closes
 ('bat_edit',
  "try { $netTimer.Stop(); $monTimer.Stop() } catch { }\nStop-Remote\n",
  "try { $netTimer.Stop(); $monTimer.Stop() } catch { }\ntry { if ($PerfS.On) { Perf-Flush } } catch { }\nStop-Remote\n"),
 # 7) CI: tools and workflows
 ('file', 'tools/bench.ps1', F('bench.ps1')),
 ('file', 'tools/smoke.ps1', F('smoke.ps1')),
 ('file', 'tools/check-csharp.ps1', F('check-csharp.ps1')),
 ('file', '.github/workflows/bench.yml', F('bench.yml')),
 ('file_append', '.github/workflows/check.yml',
  "      - name: C# blocks compile (Windows PowerShell 5.1)\n"
  "        shell: powershell\n"
  "        run: powershell -ExecutionPolicy Bypass -File tools\\check-csharp.ps1\n"),
]
"""
LOTSRC[1] = r'''N = 1
MARK = 'function Split-LangData('

HIST_COMPILE = ("$histCode = @'\n" + F('hist.cs').rstrip('\n') + "\n'@\n"
                "$S.HistNative = $false\n"
                "try { Add-TypeCached $histCode; $S.HistNative = $true } catch { }\n")

OLD_HIST_LOOP = (
"            foreach ($ln in [System.IO.File]::ReadAllLines($histFile)) {\n"
"                $total++\n"
"                $p = $ln.Split(',')\n"
"                if ($p.Count -lt 8) { continue }\n"
"                try {\n"
"                    $dt = [DateTime]::ParseExact($p[0], 'yyyyMMddHHmm', $invc)\n"
"                    if ($dt -lt $cut) { continue }\n"
"                    $rec = New-Object 'double[]' 8\n"
"                    $rec[0] = [double](Get-MinIdx $dt)\n"
"                    for ($i = 1; $i -lt 8; $i++) { $rec[$i] = [double]::Parse($p[$i], $invc) }\n"
"                    [void]$S.HistMem.Add($rec)\n"
"                    [void]$keep.Add($ln)\n"
"                } catch { }\n"
"            }\n")
NEW_HIST_LOOP = (
"            if ($S.HistNative) {\n"
"                $all = [System.IO.File]::ReadAllLines($histFile)\n"
"                $total = $all.Length\n"
"                $keepL = New-Object 'System.Collections.Generic.List[string]'\n"
"                $recs = [HistParse]::Parse($all, $histEpoch, $cut, $keepL)\n"
"                $S.HistMem.AddRange($recs)\n"
"                $keep.AddRange($keepL)\n"
"            } else {\n"
"                foreach ($ln in [System.IO.File]::ReadAllLines($histFile)) {\n"
"                    $total++\n"
"                    $p = $ln.Split(',')\n"
"                    if ($p.Count -lt 8) { continue }\n"
"                    try {\n"
"                        $dt = [DateTime]::ParseExact($p[0], 'yyyyMMddHHmm', $invc)\n"
"                        if ($dt -lt $cut) { continue }\n"
"                        $rec = New-Object 'double[]' 8\n"
"                        $rec[0] = [double](Get-MinIdx $dt)\n"
"                        for ($i = 1; $i -lt 8; $i++) { $rec[$i] = [double]::Parse($p[$i], $invc) }\n"
"                        [void]$S.HistMem.Add($rec)\n"
"                        [void]$keep.Add($ln)\n"
"                    } catch { }\n"
"                }\n"
"            }\n")

OPS = [
 # 1A) languages: raw text per language, parse only the active one + en + fr, skip lang\*.txt copies identical to the embedded text
 ('bat_between', "function ConvertFrom-LangEsc([string]$s) {\n", "# LANGDATA BEGIN\n", F('lang_funcs.ps1')),
 ('bat_langhash',),
 ('bat_between', "Add-LangLines ($langData -split \"`n\") ''\n", "$LangCode = ''\n", F('lang_runtime.ps1')),
 ('bat_edit',
  "if (-not $LangDb.ContainsKey($LangCode)) { $LangCode = 'fr' }\n",
  "if (-not $LangDb.ContainsKey($LangCode)) { $LangCode = 'fr' }\n"
  "Ensure-Lang $LangCode\nEnsure-Lang 'en'\nEnsure-Lang 'fr'\nMark-Step 'languages parsed'\n"),
 ('file_edit', 'tools/embed-lang.ps1',
  "$out = New-Object System.Collections.ArrayList\n"
  "foreach ($f in @(Get-ChildItem -LiteralPath (Join-Path $root 'lang') -Filter '*.txt' | Sort-Object Name)) {\n",
  "$out = New-Object System.Collections.ArrayList\n"
  "$hashPairs = New-Object System.Collections.ArrayList\n"
  "$sha = [System.Security.Cryptography.SHA256]::Create()\n"
  "foreach ($f in @(Get-ChildItem -LiteralPath (Join-Path $root 'lang') -Filter '*.txt' | Sort-Object Name)) {\n"
  "    # hash of the whole file (same formula as Get-TextHash in ZerkiWatch.bat): a lang\\*.txt identical to the embedded copy is not read at start-up\n"
  "    $norm = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8).Replace(\"`r`n\", \"`n\").Trim()\n"
  "    $hh = ([BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($norm)))).Replace('-', '').Substring(0, 16).ToLower()\n"
  "    [void]$hashPairs.Add(\"'\" + $f.BaseName.ToLower() + \"' = '\" + $hh + \"'\")\n"),
 ('file_edit', 'tools/embed-lang.ps1',
  "+ \"`n'@`n\" + $text.Substring($e)\n",
  "+ \"`n'@`n\" + \"`$langHash = @{ \" + ($hashPairs -join '; ') + \" }`n\" + $text.Substring($e)\n"),
 ('file_edit', 'tools/check-lang.ps1',
  "foreach ($c in ($langs.Keys | Sort-Object)) { Write-Host ('  ' + $c + ': ' + $langs[$c].Count + ' keys') }\n",
  "# the $langHash line (start-up skips lang\\*.txt files identical to the embedded copy) must match the files\n"
  "$hm = [regex]::Match($bat, '(?m)^\\$langHash = @\\{(.*)\\}\\s*$')\n"
  "if (-not $hm.Success) { Write-Host 'The $langHash line is missing in ZerkiWatch.bat. Run tools\\embed-lang.ps1'; $bad++ }\n"
  "else {\n"
  "    $sha = [System.Security.Cryptography.SHA256]::Create()\n"
  "    foreach ($f in @(Get-ChildItem -LiteralPath (Join-Path $root 'lang') -Filter '*.txt')) {\n"
  "        $norm = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8).Replace(\"`r`n\", \"`n\").Trim()\n"
  "        $hh = ([BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($norm)))).Replace('-', '').Substring(0, 16).ToLower()\n"
  "        if ($hm.Groups[1].Value -notmatch (\"'\" + $f.BaseName.ToLower() + \"' = '\" + $hh + \"'\")) { Write-Host ('$langHash is out of date for ' + $f.BaseName + '. Run tools\\embed-lang.ps1'); $bad++ }\n"
  "    }\n"
  "}\n"
  "foreach ($c in ($langs.Keys | Sort-Object)) { Write-Host ('  ' + $c + ': ' + $langs[$c].Count + ' keys') }\n"),
 # 1B) Write-Log without a file-system round trip per line
 ('bat_between', "function Write-Log([string]$msg, [string]$key = '') {\n", "function Mark-Step([string]$name) {\n", F('log.ps1')),
 # 1C) single-instance check without exceptions
 ('bat_between', "function Test-OldRun {\n", "Mark-Step 'libraries loaded, checking old version'\n", F('mutex.ps1')),
 # 1D) history: C# parser (the old loop stays as fallback)
 ('bat_edit', "\nLoad-History\n", "\n" + HIST_COMPILE + "Load-History\n"),
 ('bat_edit', OLD_HIST_LOOP, NEW_HIST_LOOP),
]
'''
LOTSRC[2] = r'''N = 2
MARK = 'function Get-ModeFast'

OLD_TESTS = (
"function Test-Internet {\n"
"    return ((Test-Tcp '1.1.1.1' 443 2000) -or (Test-Tcp '8.8.8.8' 443 2000) -or (Test-Tcp '2606:4700:4700::1111' 443 2000))\n"
"}\n"
"function Test-Box {\n"
"    $gw = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Sort-Object -Property RouteMetric | Select-Object -First 1\n"
"    if ($gw -and $gw.NextHop -and ($gw.NextHop -ne '0.0.0.0')) { return (Test-Ping $gw.NextHop) }\n"
"    return $false\n"
"}\n")

OPS = [
 # 1) the old cmdlet code becomes the safety net (*Slow)
 ('bat_edit', "function Remove-Rules {\n", "function Remove-RulesSlow {\n"),
 ('bat_edit', "function Get-Mode {\n", "function Get-ModeSlow {\n"),
 ('bat_edit', "function Set-ModeInternet {\n    Remove-Rules\n", "function Set-ModeInternetSlow {\n    Remove-RulesSlow\n"),
 ('bat_edit', "function Set-ModeLocal {\n", "function Set-ModeLocalSlow {\n"),
 ('bat_edit', "        Remove-Rules\n        $v4Allowed = ", "        Remove-RulesSlow\n        $v4Allowed = "),
 ('bat_edit', "    } catch {\n        Remove-Rules\n        throw\n    }\n", "    } catch {\n        Remove-RulesSlow\n        throw\n    }\n"),
 # 2) the COM engine + dispatchers (same public names as before)
 ('bat_edit', "\n# ---------- Tests ----------\nfunction Test-Tcp(", "\n" + F('fw.ps1') + "\n# ---------- Tests ----------\nfunction Test-Tcp("),
 # 3) network tests: three connections at once, no Get-NetRoute
 ('bat_edit', OLD_TESTS, F('tests.ps1')),
 # 4) the periodic "mode" check (every ~20 s) uses the same fast code instead of two Get-NetFirewallRule calls
 ('bat_between',
  "            $src = '$r = @(Get-NetFirewallRule -Group ''__G__''",
  "        } else {\n            $src = 'Get-CimInstance",
  "            $src = 'param($Group, $LegacyGroups, $FnSrc) function T([string]$k) { return $k }; function Tf([string]$k, [object[]]$a) { return $k }; . ([scriptblock]::Create($FnSrc)); Get-Mode'\n"),
 ('bat_edit',
  "        [void]$S.Bg.AddScript($src)\n        $S.BgKind = $kind\n",
  "        [void]$S.Bg.AddScript($src)\n        if ($kind -eq 'mode') { [void]$S.Bg.AddArgument($Group).AddArgument($LegacyGroups).AddArgument($ModeFnSrc) }\n        $S.BgKind = $kind\n"),
 # 5) CI: real firewall test on a throw-away group (TEST-NET ranges, never the real rules)
 ('file', 'tools/test-fw.ps1', F('test-fw.ps1')),
 ('file_append', '.github/workflows/check.yml',
  "      - name: Firewall engine (COM, throw-away rules)\n"
  "        shell: powershell\n"
  "        run: powershell -ExecutionPolicy Bypass -File tools\\test-fw.ps1\n"),
]
'''
LOTSRC[3] = r'''N = 3
MARK = 'function Get-SeriesPoints('

OLD_NETSEG = (
"        $step = $w2 / 39.0\n"
"        $pts = New-Object 'System.Collections.Generic.List[System.Drawing.PointF]'\n"
"        for ($i = 0; $i -lt $cnt; $i++) {\n"
"            $sx = $x0 + $w2 - ($cnt - 1 - $i) * $step\n"
"            $sy = $y0 + $h2 - ($hist[$i] / $mx) * $h2\n"
"            $pts.Add((New-Object System.Drawing.PointF([single]$sx, [single]$sy)))\n"
"        }\n"
"        $poly = New-Object 'System.Collections.Generic.List[System.Drawing.PointF]'\n"
"        $poly.AddRange($pts)\n"
"        $poly.Add((New-Object System.Drawing.PointF([single]($x0 + $w2), [single]($y0 + $h2))))\n"
"        $poly.Add((New-Object System.Drawing.PointF([single]($x0 + $w2 - ($cnt - 1) * $step), [single]($y0 + $h2))))\n"
"        $fb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(58, $accent.R, $accent.G, $accent.B))\n"
"        $g.FillPolygon($fb, $poly.ToArray())\n"
"        $fb.Dispose()\n"
"        $lp = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(215, $accent.R, $accent.G, $accent.B), [single]1.4)\n"
"        $lp.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round\n"
"        $g.DrawLines($lp, $pts.ToArray())\n"
"        $lp.Dispose()\n")
NEW_NETSEG = (
"        $poly = Get-SeriesPoints $hist $x0 $y0 $w2 $h2 $mx $true\n"
"        $pts = Get-SeriesPoints $hist $x0 $y0 $w2 $h2 $mx $false\n"
"        $fb = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(58, $accent.R, $accent.G, $accent.B))\n"
"        $g.FillPolygon($fb, $poly)\n"
"        $fb.Dispose()\n"
"        $lp = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(215, $accent.R, $accent.G, $accent.B), [single]1.4)\n"
"        $lp.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round\n"
"        $g.DrawLines($lp, $pts)\n"
"        $lp.Dispose()\n")

DIAL = (
"# Rectangle of the dial (design units 158,68 - 264x264). While a switch is running only this part is repainted (33 ms animation).\n"
"$S.DialRect = New-Object System.Drawing.Rectangle([int](158 * $DS), [int](68 * $DS), [int](264 * $DS), [int](264 * $DS))\n"
"function Invalidate-Dial {\n"
"    if ($S.Tab -eq 'perf') { return }\n"
"    $pnlRight.Invalidate($S.DialRect)\n"
"}\n")

OPS = [
 # 1) curves: arrays of points instead of one New-Object per point
 ('bat_between', "function Draw-Series($g, $hist, [single]$x, [single]$y, [single]$w, [single]$h, $color, [double]$mx, [bool]$fill) {\n",
  "function Draw-Arrow(", F('series.ps1')),
 ('bat_edit', OLD_NETSEG, NEW_NETSEG),
 # 2) dial animation: partial repaint
 ('bat_edit', "\nfunction Start-NetJob([string]$target) {\n", "\n" + DIAL + "\nfunction Start-NetJob([string]$target) {\n"),
 ('bat_edit',
  "    if (-not $S.SwH.IsCompleted) { try { $pnlRight.Invalidate() } catch { }; return }\n",
  "    if (-not $S.SwH.IsCompleted) { try { Invalidate-Dial } catch { }; return }\n"),
 ('bat_edit',
  "        $S.HitMain.Clear()\n",
  "        # a repaint limited to the dial (Invalidate-Dial) keeps the click zones of the previous full paint and skips everything outside the dial\n"
  "        $dialOnly = (($S.Tab -ne 'perf') -and ($S.DialRect -ne $null) -and $S.DialRect.Contains($pe.ClipRectangle))\n"
  "        if (-not $dialOnly) { $S.HitMain.Clear() }\n"),
 ('bat_edit',
  "        $g.DrawString((T 'ui.mbps_in'), $fSmall, $bMuted, $rc3, $sfCenter)\n        Add-Hit $S.HitMain 'dial' ",
  "        $g.DrawString((T 'ui.mbps_in'), $fSmall, $bMuted, $rc3, $sfCenter)\n        if ($dialOnly) { return }\n        Add-Hit $S.HitMain 'dial' "),
]
'''
LOTSRC[4] = r'''N = 4
MARK = 'function Update-SvcMap'

SVC_BLOCK = ("$svcCode = @'\n" + F('svc.cs').rstrip('\n') + "\n'@\n"
             "$S.SvcNative = $false\n"
             "try { Add-TypeCached $svcCode; $S.SvcNative = $true } catch { }\n"
             + F('svcmap.ps1') + "\n")

OLD_UPD = (
"if ($S.UpdCheck) {\n"
"    $updTimer = New-Object System.Windows.Forms.Timer\n"
"    $updTimer.Interval = 15000\n"
"    $updTimer.Add_Tick({\n"
"        $updTimer.Stop()\n"
"        try {\n"
"            $r = Get-LatestRelease\n"
"            if (($r -ne $null) -and $r.Newer) { $tray.ShowBalloonTip(6000, 'ZerkiWatch', (Tf 'about.newer' @($r.Tag)), [System.Windows.Forms.ToolTipIcon]::Info) }\n"
"        } catch { }\n"
"    })\n"
"    $updTimer.Start()\n"
"}\n")
NEW_UPD = (
"if ($S.UpdCheck) {\n"
"    # the check runs in the background (WebClient async) and is read by a 500 ms timer: no more freeze up to 6 s, 15 s after the start\n"
"    $updPoll = New-Object System.Windows.Forms.Timer\n"
"    $updPoll.Interval = 500\n"
"    $updPoll.Add_Tick({\n"
"        try {\n"
"            if (Poll-UpdateCheck) {\n"
"                $updPoll.Stop()\n"
"                $r = $S.UpdResult\n"
"                if (($r -ne $null) -and $r.Newer) { $tray.ShowBalloonTip(6000, 'ZerkiWatch', (Tf 'about.newer' @($r.Tag)), [System.Windows.Forms.ToolTipIcon]::Info) }\n"
"            }\n"
"        } catch { $updPoll.Stop() }\n"
"    })\n"
"    $updTimer = New-Object System.Windows.Forms.Timer\n"
"    $updTimer.Interval = 15000\n"
"    $updTimer.Add_Tick({\n"
"        $updTimer.Stop()\n"
"        try { Start-UpdateCheck; $updPoll.Start() } catch { }\n"
"    })\n"
"    $updTimer.Start()\n"
"}\n")

OPS = [
 # 4A) service -> process map from the Service Control Manager (a few ms) instead of a WMI query in a background runspace (0.5 - 2 s of CPU)
 ('bat_edit', "function Start-BgWork([string]$kind) {\n", SVC_BLOCK + "function Start-BgWork([string]$kind) {\n"),
 ('bat_edit',
  "{ $S.SvcAsk = [DateTime]::UtcNow; Start-BgWork 'svc' }",
  "{ $S.SvcAsk = [DateTime]::UtcNow; if ($S.SvcNative) { try { Update-SvcMap } catch { Start-BgWork 'svc' } } else { Start-BgWork 'svc' } }", 2),
 # 4B) update check without freezing the window
 ('bat_edit', "\nfunction Show-About {\n", "\n" + F('upd.ps1') + "\nfunction Show-About {\n"),
 ('bat_edit', OLD_UPD, NEW_UPD),

 # 4C) dead code and wasted work in the paint / tooltip code
 ('bat_between', "function Get-ServiceMap {\n", "function Get-AppLabel(", ""),
 ('bat_edit',
  "        $sepPen = New-Object System.Drawing.Pen((Get-Ov 34), [single]1)\n        $sepPen.Dispose()\n        $bp = New-Object System.Drawing.Pen($barBorder, [single]1)\n",
  "        $bp = New-Object System.Drawing.Pen($barBorder, [single]1)\n"),
 ('bat_edit',
  "function Update-BarTip {\n    $nl = \"`n\"\n",
  "function Update-BarTip {\n    if (($S.Tick % 3) -ne 0) { return }   # the text is only applied every 3rd tick: do not build it for nothing\n    $nl = \"`n\"\n"),
]
'''
LOTSRC[6] = r'''N = 6
MARK = ('tools/installer/ZerkiWatch.iss', 'AppUserModelID: "zerkino.ZerkiWatch"')
OPS = [
 # the two shortcuts get the same AppUserModelID as the running app ([MN]::SetAppId('zerkino.ZerkiWatch') in ZerkiWatch.bat):
 # a button pinned to the taskbar and the running window then share ONE taskbar button
 ('file_edit', 'tools/installer/ZerkiWatch.iss',
  'Name: "{autoprograms}\\ZerkiWatch"; Filename: "{app}\\ZerkiWatch.exe"; IconFilename: "{app}\\ZerkiWatch.ico"\n',
  'Name: "{autoprograms}\\ZerkiWatch"; Filename: "{app}\\ZerkiWatch.exe"; IconFilename: "{app}\\ZerkiWatch.ico"; AppUserModelID: "zerkino.ZerkiWatch"\n'),
 ('file_edit', 'tools/installer/ZerkiWatch.iss',
  'Name: "{autodesktop}\\ZerkiWatch"; Filename: "{app}\\ZerkiWatch.exe"; IconFilename: "{app}\\ZerkiWatch.ico"; Tasks: desktopicon\n',
  'Name: "{autodesktop}\\ZerkiWatch"; Filename: "{app}\\ZerkiWatch.exe"; IconFilename: "{app}\\ZerkiWatch.ico"; AppUserModelID: "zerkino.ZerkiWatch"; Tasks: desktopicon\n'),
]
'''
LOTSRC[7] = r'''N = 7
MARK = 'public static volatile int WindowMs'

OLD_LOOP = (
"                int rc = RunTool(\"logman.exe\", \"start \" + SessionName + \" -p \\\"Microsoft-Windows-Kernel-Network\\\" 0x30 0xFF -o \\\"\" + etl + \"\\\" -ets -bs 128 -nb 16 64 -max 64\");\n"
"                if (rc != 0)\n"
"                {\n"
"                    Status = \"trace failed (code \" + rc + \", administrator rights required)\";\n"
"                    Wait(6000);\n"
"                    continue;\n"
"                }\n"
"                Stopwatch sw = Stopwatch.StartNew();\n"
"                Wait(3000);\n"
"                RunTool(\"logman.exe\", \"stop \" + SessionName + \" -ets\");\n"
"                double secs = Math.Max(0.5, sw.Elapsed.TotalSeconds);\n"
"                if (!run) break;\n"
"                Parse(etl, secs);\n")
NEW_LOOP = (
"                Stopwatch busy = Stopwatch.StartNew();\n"
"                int rc = RunTool(\"logman.exe\", \"start \" + SessionName + \" -p \\\"Microsoft-Windows-Kernel-Network\\\" 0x30 0xFF -o \\\"\" + etl + \"\\\" -ets -bs 128 -nb 16 64 -max 64\");\n"
"                if (rc != 0)\n"
"                {\n"
"                    Status = \"trace failed (code \" + rc + \", administrator rights required)\";\n"
"                    Wait(6000);\n"
"                    continue;\n"
"                }\n"
"                Interlocked.Add(ref BusyMs, busy.ElapsedMilliseconds);\n"
"                Stopwatch sw = Stopwatch.StartNew();\n"
"                Wait(WindowMs);\n"
"                busy.Restart();\n"
"                RunTool(\"logman.exe\", \"stop \" + SessionName + \" -ets\");\n"
"                double secs = Math.Max(0.5, sw.Elapsed.TotalSeconds);\n"
"                if (!run) break;\n"
"                Parse(etl, secs);\n"
"                Interlocked.Add(ref BusyMs, busy.ElapsedMilliseconds);\n"
"                Interlocked.Increment(ref Cycles);\n")

OPS = [
 # 7A) counters: how much time the ETW cycle really costs (shown in the PERF lines of the log when Perf=1)
 ('bat_edit',
  "    public static volatile string Status = \"starting\";\n    public static volatile bool Paused;\n",
  "    public static volatile string Status = \"starting\";\n    public static volatile bool Paused;\n"
  "    public static volatile int WindowMs = 3000;   // length of one capture window (the PowerShell side lengthens it when nobody looks at the per-app lists)\n"
  "    public static long Cycles;                    // finished capture cycles\n"
  "    public static long BusyMs;                    // ms spent in logman start / stop and in the parse\n"),
 ('bat_edit', OLD_LOOP, NEW_LOOP),
 ('bat_edit',
  "        $PerfAcc[$k] = [double[]]@(0.0, 0.0, 0.0)\n    }\n}\n",
  "        $PerfAcc[$k] = [double[]]@(0.0, 0.0, 0.0)\n    }\n"
  "    try { if ($S.EtwOk) { Write-Log ('PERF etw cycles=' + [NetEtw]::Cycles + ' busy=' + [NetEtw]::BusyMs + ' ms (since start) window=' + [NetEtw]::WindowMs + ' ms') } } catch { }\n}\n"),
 # 7B) 6 s windows instead of 3 s when the window and the iPhone page are not looking (the totals "Cumul" keep running): half as many logman start/stop + parses
 ('bat_edit',
  "        try { if ([NetEtw]::Paused -ne $pz) { [NetEtw]::Paused = $pz } } catch { }\n",
  "        try { if ([NetEtw]::Paused -ne $pz) { [NetEtw]::Paused = $pz } } catch { }\n"
  "        $wm = 3000\n"
  "        if (($nowU - $S.NeedAt).TotalSeconds -gt 15) { $wm = 6000 }\n"
  "        try { if ([NetEtw]::WindowMs -ne $wm) { [NetEtw]::WindowMs = $wm } } catch { }\n"),
]
'''
LOTSRC[8] = r'''N = 8
MARK = 'function Test-AdminOwned('
OPS = [
 # the cache of compiled helper types moves from %APPDATA% (writable by any program of the user) to %ProgramData% (Administrators + SYSTEM only)
 ('bat_between',
  "# Compiled helper types are cached as a DLL (hash of the source): the C# compiler only runs the first time\nfunction Add-TypeCached(",
  "$native = $false\n",
  F('dllcache.ps1')),
 ('bat_edit',
  "try { Add-TypeCached $nativeCode; $native = $true } catch { $native = $false }\n",
  "try { Add-TypeCached $nativeCode; $native = $true } catch { $native = $false }\n"
  "# the old cache folder was writable by any program of the user: remove it (it is never read again)\n"
  "try { $oldCache = Join-Path $logDir 'cache'; if (Test-Path -LiteralPath $oldCache) { Remove-Item -LiteralPath $oldCache -Recurse -Force } } catch { }\n"),
 ('file', 'tools/test-cache.ps1', F('test-cache.ps1')),
 ('file_append', '.github/workflows/check.yml',
  "      - name: Compiled-type cache folder (ACL and owner)\n"
  "        shell: powershell\n"
  "        run: powershell -ExecutionPolicy Bypass -File tools\\test-cache.ps1\n"),
 ('file_edit', 'tools/installer/cleanup.ps1',
  "Unregister-ScheduledTask -TaskName 'ModeReseau' -Confirm:$false\n",
  "Unregister-ScheduledTask -TaskName 'ModeReseau' -Confirm:$false\n"
  "Remove-Item -LiteralPath (Join-Path $env:ProgramData 'ZerkiWatch') -Recurse -Force\n"),
]
'''
TESTSRC['cs5'] = r'''# Lab check (Roslyn from pwsh 7): every C# block of a ZerkiWatch.bat must use only C# 5 syntax (what Windows PowerShell 5.1 compiles).
# Reports syntax errors and "feature not available in C# 5" errors; missing-type errors (System.Windows.Forms is not here) are ignored.
param([string]$OldBat, [string]$NewBat, [string]$Root, [string]$Bat)
if (-not $Bat) { $Bat = $NewBat }
$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
Add-Type -Path (Join-Path $dir 'Microsoft.CodeAnalysis.dll')
Add-Type -Path (Join-Path $dir 'Microsoft.CodeAnalysis.CSharp.dll')
$t = [IO.File]::ReadAllText($Bat)
$rx = '(?s)\$(\w+Code)\s*=\s*@' + "'" + '\r?\n(.*?)\r?\n' + "'" + '@'
$opt = [Microsoft.CodeAnalysis.CSharp.CSharpParseOptions]::Default.WithLanguageVersion([Microsoft.CodeAnalysis.CSharp.LanguageVersion]::CSharp5)
$refs = [Microsoft.CodeAnalysis.MetadataReference[]]@([Microsoft.CodeAnalysis.MetadataReference]::CreateFromFile([object].Assembly.Location), [Microsoft.CodeAnalysis.MetadataReference]::CreateFromFile((Join-Path $dir 'System.Runtime.dll')))
$bad = 0; $n = 0
foreach ($m in [regex]::Matches($t, $rx)) {
    $n++
    $tree = [Microsoft.CodeAnalysis.CSharp.CSharpSyntaxTree]::ParseText($m.Groups[2].Value, $opt)
    $comp = [Microsoft.CodeAnalysis.CSharp.CSharpCompilation]::Create('x', [Microsoft.CodeAnalysis.SyntaxTree[]]@($tree), $refs, $null)
    $errs = @($comp.GetDiagnostics() | Where-Object { ($_.Severity -eq 'Error') -and (($_.Id -match '^CS1\d\d\d$') -or ($_.GetMessage() -match 'not available in C#|language version')) -and ($_.Id -ne 'CS5001') })
    if ($errs.Count -gt 0) { $bad++; foreach ($x in $errs) { Write-Host ($m.Groups[1].Value + ': ' + $x.Id + ' ' + $x.GetMessage() + ' @' + $x.Location.GetLineSpan().StartLinePosition) } }
    else { Write-Host ($m.Groups[1].Value + ': C# 5 syntax OK') }
}
if ($n -lt 4) { Write-Host "only $n C# blocks found"; $bad++ }
if ($bad -gt 0) { exit 1 }
'''
TESTSRC['dispatch'] = r'''# LOT 2: the dispatchers choose the fast COM path first and fall back to the old cmdlet code (*Slow) on any failure; the user-facing errors stay the same.
# Everything the real functions call is replaced by stubs that record what happened. No firewall is touched.
param([string]$OldBat, [string]$NewBat, [string]$Root)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Numerics
$t = [IO.File]::ReadAllText($NewBat)
$m = [regex]::Match($t, '(?s)\$ModeFnSrc\s*=\s*@' + "'" + '\r?\n(.*?)\r?\n' + "'" + '@')
if (-not $m.Success) { Write-Host 'ModeFnSrc not found'; exit 1 }
$Group = 'G'; $LegacyGroups = @('L'); $ExtraIPv4 = @(); $ExtraIPv6 = @()
function T([string]$k) { return $k }
function Tf([string]$k, [object[]]$a) { return ($k + ':' + ($a -join ',')) }
. ([scriptblock]::Create($m.Groups[1].Value))
$fail = 0
function Check([string]$what, [bool]$ok) { if ($ok) { Write-Host ('ok    ' + $what) } else { Write-Host ('FAIL  ' + $what); $script:fail++ } }
$calls = New-Object System.Collections.ArrayList
# the old (cmdlet) code must still exist under the *Slow names
foreach ($fn in @('Remove-RulesSlow', 'Get-ModeSlow', 'Set-ModeInternetSlow', 'Set-ModeLocalSlow', 'Get-ModeFast', 'Set-ModeLocalFast', 'Set-ModeInternetFast', 'Remove-RulesFast', 'Get-DisabledProfiles', 'Get-LocalOnlyRanges', 'Clear-DnsFast')) { Check ('function ' + $fn + ' exists') ($null -ne (Get-Command $fn -CommandType Function -ErrorAction SilentlyContinue)) }
Check 'Set-ModeInternetSlow calls Remove-RulesSlow (not the removed name)' ((Get-Command Set-ModeInternetSlow).ScriptBlock.ToString() -match 'Remove-RulesSlow')
Check 'Set-ModeLocalSlow calls Remove-RulesSlow (twice)' (([regex]::Matches((Get-Command Set-ModeLocalSlow).ScriptBlock.ToString(), 'Remove-RulesSlow')).Count -eq 2)
Check 'no call to the old name Remove-Rules is left' (-not ($m.Groups[1].Value -match 'Remove-Rules(?!Slow|Fast)\b'))
# ---- stubs ----
function Get-Service { param($Name) return [pscustomobject]@{ Status = $script:svcStatus } }
$script:svcStatus = 'Running'
function Clear-DnsFast { [void]$calls.Add('dns') }
function Remove-RulesFast { [void]$calls.Add('removeFast') }
function Set-ModeLocalSlow { [void]$calls.Add('localSlow') }
function Set-ModeInternetSlow { [void]$calls.Add('internetSlow') }
function Get-ModeSlow { [void]$calls.Add('modeSlow'); return 'SLOWANSWER' }
$script:off = @()
function Get-DisabledProfiles { return , $script:off }
$script:ranges = @('1.0.0.0-9.255.255.255')
function Get-LocalOnlyRanges { return $script:ranges }
$script:failFast = $false
function Set-ModeLocalFast($remote) { if ($script:failFast) { throw 'com failed' }; [void]$calls.Add('localFast:' + (@($remote) -join '|')) }
function Set-ModeInternetFast { if ($script:failFast) { throw 'com failed' }; [void]$calls.Add('internetFast') }
function Get-ModeFast { if ($script:failFast) { throw 'com failed' }; return 'FASTANSWER' }
function Run([scriptblock]$sb) { $calls.Clear(); $err = ''; try { & $sb } catch { $err = $_.Exception.Message }; return @{ calls = ($calls -join ','); err = $err } }
# Get-Mode
$script:failFast = $false
Check 'Get-Mode uses the fast answer' ((Get-Mode) -eq 'FASTANSWER')
$script:failFast = $true; $calls.Clear()
Check 'Get-Mode falls back to the old code when COM fails' (((Get-Mode) -eq 'SLOWANSWER') -and ($calls -contains 'modeSlow'))
# Set-ModeInternet
$script:failFast = $false
$r = Run { Set-ModeInternet }
Check ('Set-ModeInternet: fast path then DNS flush (' + $r.calls + ')') (($r.calls -eq 'internetFast,dns') -and ($r.err -eq ''))
$script:failFast = $true
$r = Run { Set-ModeInternet }
Check ('Set-ModeInternet: COM fails -> old code runs, DNS flushed (' + $r.calls + ')') (($r.calls -eq 'internetSlow,dns') -and ($r.err -eq ''))
# Set-ModeLocal
$script:failFast = $false
$r = Run { Set-ModeLocal }
Check ('Set-ModeLocal: fast path with the computed ranges (' + $r.calls + ')') (($r.calls -eq 'localFast:1.0.0.0-9.255.255.255,dns') -and ($r.err -eq ''))
$script:failFast = $true
$r = Run { Set-ModeLocal }
Check ('Set-ModeLocal: COM fails -> partial rules removed, old code runs (' + $r.calls + ')') (($r.calls -eq 'removeFast,localSlow,dns') -and ($r.err -eq ''))
$script:failFast = $false; $script:svcStatus = 'Stopped'
$r = Run { Set-ModeLocal }
Check ('Set-ModeLocal: firewall service stopped -> same error as before, nothing changed (' + $r.err + ')') (($r.err -eq 'err.fw_stopped') -and ($r.calls -eq ''))
$script:svcStatus = 'Running'; $script:off = @('Public', 'Private')
$r = Run { Set-ModeLocal }
Check ('Set-ModeLocal: profile disabled -> err.fw_disabled with the profile names (' + $r.err + ')') (($r.err -eq 'err.fw_disabled:Public, Private') -and ($r.calls -eq ''))
$script:off = @(); $script:ranges = @()
$r = Run { Set-ModeLocal }
Check ('Set-ModeLocal: no ranges computed -> the old code decides (' + $r.calls + ')') (($r.calls -eq 'localSlow,dns') -and ($r.err -eq ''))
function Get-LocalOnlyRanges { throw 'boom' }
$r = Run { Set-ModeLocal }
Check ('Set-ModeLocal: range computation throws -> the old code decides (' + $r.calls + ')') (($r.calls -eq 'localSlow,dns') -and ($r.err -eq ''))
if ($fail -gt 0) { Write-Host "DISPATCH TEST FAILED: $fail"; exit 1 }
Write-Host 'DISPATCH TEST OK'
'''
TESTSRC['hist'] = r'''# LOT 1: the C# history parser (HistParse) gives exactly the same records, kept lines and cut-off as the PowerShell loop it replaces; the C# block compiles.
param([string]$OldBat, [string]$NewBat, [string]$Root)
$ErrorActionPreference = 'Stop'
$t = [IO.File]::ReadAllText($NewBat)
$m = [regex]::Match($t, '(?s)\$histCode\s*=\s*@' + "'" + '\r?\n(.*?)\r?\n' + "'" + '@')
if (-not $m.Success) { Write-Host 'histCode block not found'; exit 1 }
Add-Type -TypeDefinition $m.Groups[1].Value
$invc = [System.Globalization.CultureInfo]::InvariantCulture
$histEpoch = [DateTime]'2020-01-01'
function Get-MinIdx([DateTime]$d) { return [long][math]::Floor(($d - $histEpoch).TotalMinutes) }
$rnd = New-Object System.Random(3)
$lines = New-Object System.Collections.ArrayList
$h0 = (Get-Date).AddDays(-9)
for ($k = 0; $k -lt 3000; $k++) {
    $ts = $h0.AddMinutes($k * 4).ToString('yyyyMMddHHmm', $invc)
    [void]$lines.Add($ts + ',' + ($rnd.NextDouble() * 900).ToString('0.000', $invc) + ',' + ($rnd.NextDouble() * 90).ToString('0.000', $invc) + ',' + ($rnd.NextDouble() * 100).ToString('0.0', $invc) + ',' + ($rnd.NextDouble() * 100).ToString('0.0', $invc) + ',' + ($rnd.NextDouble() * 100).ToString('0.0', $invc) + ',' + $rnd.Next(100000).ToString() + ',' + $rnd.Next(100000).ToString())
}
# damaged lines: too few fields, bad date, bad number, empty line, spaces around a number, exponent notation
[void]$lines.Add('2099'); [void]$lines.Add('notadate,1,2,3,4,5,6,7'); [void]$lines.Add((Get-Date).ToString('yyyyMMddHHmm', $invc) + ',x,2,3,4,5,6,7'); [void]$lines.Add('')
[void]$lines.Add((Get-Date).AddMinutes(-1).ToString('yyyyMMddHHmm', $invc) + ', 1.5 ,2,3,4,5,6,7')
[void]$lines.Add((Get-Date).AddMinutes(-2).ToString('yyyyMMddHHmm', $invc) + ',1E3,2,3,4,5,6,7')
[void]$lines.Add((Get-Date).AddMinutes(-3).ToString('yyyyMMddHHmm', $invc) + ',1,2,3,4,5,6,7,extra,fields')
$all = [string[]]$lines.ToArray()
$cut = (Get-Date).AddDays(-7)
$memOld = New-Object System.Collections.ArrayList; $keepOld = New-Object System.Collections.ArrayList
foreach ($ln in $all) {
    $p = $ln.Split(',')
    if ($p.Count -lt 8) { continue }
    try {
        $dt = [DateTime]::ParseExact($p[0], 'yyyyMMddHHmm', $invc)
        if ($dt -lt $cut) { continue }
        $rec = New-Object 'double[]' 8
        $rec[0] = [double](Get-MinIdx $dt)
        for ($i = 1; $i -lt 8; $i++) { $rec[$i] = [double]::Parse($p[$i], $invc) }
        [void]$memOld.Add($rec); [void]$keepOld.Add($ln)
    } catch { }
}
$keepL = New-Object 'System.Collections.Generic.List[string]'
$recs = [HistParse]::Parse($all, $histEpoch, $cut, $keepL)
$bad = 0
if (($memOld.Count -ne $recs.Count) -or ($keepOld.Count -ne $keepL.Count)) { $bad++; Write-Host ('count differs: old ' + $memOld.Count + '/' + $keepOld.Count + ' new ' + $recs.Count + '/' + $keepL.Count) }
for ($k = 0; $k -lt [math]::Min($memOld.Count, $recs.Count); $k++) {
    for ($i = 0; $i -lt 8; $i++) { if ($memOld[$k][$i] -ne $recs[$k][$i]) { $bad++ } }
    if ($keepOld[$k] -ne $keepL[$k]) { $bad++ }
}
Write-Host ('history parser: kept old=' + $memOld.Count + ' new=' + $recs.Count + ' of ' + $all.Length + ' lines ; differences=' + $bad)
$big = New-Object System.Collections.ArrayList; for ($k = 0; $k -lt 4; $k++) { $big.AddRange($all) }
$sw = [Diagnostics.Stopwatch]::StartNew()
$keep3 = New-Object 'System.Collections.Generic.List[string]'
$null = [HistParse]::Parse([string[]]$big.ToArray(), $histEpoch, $cut, $keep3)
Write-Host ('native parse of ' + $big.Count + ' lines: ' + [int]$sw.Elapsed.TotalMilliseconds + ' ms')
if ($bad -gt 0) { Write-Host 'HIST TEST FAILED'; exit 1 }
Write-Host 'HIST TEST OK'
'''
TESTSRC['lang_real'] = r'''# Language loading: old loader (base commit) versus new loader (patched ZerkiWatch.bat), on the REAL code of both files.
# usage: pwsh -File t_lang_real.ps1 <old ZerkiWatch.bat> <new ZerkiWatch.bat> <repo root (for the lang folder)>
param([string]$OldBat, [string]$NewBat, [string]$Root)
$ErrorActionPreference = 'Stop'
function Get-LangRegion([string]$bat) {
    $t = [IO.File]::ReadAllText($bat)
    $a = $t.IndexOf('$LangDb = @{}')
    $b = $t.IndexOf("`n" + '$LangCode = ' + "''", $a)
    if (($a -lt 0) -or ($b -lt 0)) { throw ('language region not found in ' + $bat) }
    return $t.Substring($a, $b - $a)
}
function Mark-Step([string]$n) { }
function Run-Flow([string]$region, [string]$extRoot, [bool]$ensure) {
    $script:LangDb = $null
    $env:SELF = (Join-Path $extRoot 'ZerkiWatch.bat')
    $logDir = Join-Path ([IO.Path]::GetTempPath()) 'zw-no-such-dir'
    $sw = [Diagnostics.Stopwatch]::StartNew()
    Invoke-Expression $region
    if ($ensure) { foreach ($c in @('de', 'en', 'fr')) { Ensure-Lang $c } }
    $ms = $sw.Elapsed.TotalMilliseconds
    return @{ Db = $LangDb; Ms = $ms; Raw = $(if (Test-Path variable:LangRaw) { $LangRaw } else { @{} }) }
}
$oldRegion = Get-LangRegion $OldBat
$newRegion = Get-LangRegion $NewBat
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('zwlang' + [Guid]::NewGuid().ToString('N'))
$dirA = Join-Path $tmp 'A'; $dirB = Join-Path $tmp 'B'; $dirC = Join-Path $tmp 'C'
foreach ($d in @($dirA, $dirB, $dirC)) { New-Item -ItemType Directory -Path (Join-Path $d 'lang') -Force | Out-Null }
Copy-Item (Join-Path $Root 'lang/*.txt') (Join-Path $dirA 'lang')        # A: the shipped files (identical to the embedded copy)
Copy-Item (Join-Path $Root 'lang/*.txt') (Join-Path $dirB 'lang')        # B: CRLF + BOM copies, one edited value, one new language
foreach ($f in Get-ChildItem (Join-Path $dirB 'lang') -Filter *.txt) {
    $x = [IO.File]::ReadAllText($f.FullName).Replace("`r`n", "`n").Replace("`n", "`r`n")
    [IO.File]::WriteAllText($f.FullName, $x, (New-Object System.Text.UTF8Encoding($true)))
}
$frp = Join-Path $dirB 'lang/fr.txt'
$fr = [IO.File]::ReadAllText($frp)
if (-not $fr.Contains('Vous ' + [char]0xea + 'tes ' + [char]0xe0 + ' jour.')) { throw 'test string not found in fr.txt (update this test)' }
[IO.File]::WriteAllText($frp, $fr.Replace('Vous ' + [char]0xea + 'tes ' + [char]0xe0 + ' jour.', 'Tout est a jour, Big Boss.'), (New-Object System.Text.UTF8Encoding($true)))
[IO.File]::WriteAllText((Join-Path $dirB 'lang/xx.txt'), "[xx]`nlang.name=Test\nLang`nabout.btn=Caf" + [char]0xe9 + "`n", (New-Object System.Text.UTF8Encoding($false)))
# C: no lang folder at all
Remove-Item (Join-Path $dirC 'lang') -Recurse -Force
$bad = 0
foreach ($sc in @(@('A: shipped lang files, identical', $dirA), @('B: CRLF/BOM copies + edited fr.txt + new xx.txt', $dirB), @('C: no lang folder', $dirC))) {
    $o = Run-Flow $oldRegion $sc[1] $false
    $n = Run-Flow $newRegion $sc[1] $true
    $diff = 0
    foreach ($lc in $o.Db.Keys) {
        if (-not $n.Db.ContainsKey($lc)) { $diff++; "  missing language $lc"; continue }
        if (-not $n.Raw.ContainsKey($lc)) {        # parsed language: every key must be identical
            if ($n.Db[$lc].Count -ne $o.Db[$lc].Count) { $diff++; "  key count differs for $lc : " + $n.Db[$lc].Count + ' vs ' + $o.Db[$lc].Count }
            foreach ($k in $o.Db[$lc].Keys) { if ((-not $n.Db[$lc].ContainsKey($k)) -or ($n.Db[$lc][$k] -cne $o.Db[$lc][$k])) { $diff++; if ($diff -lt 6) { "  DIFF [$lc] $k" } } }
        } else {                                   # still raw: only the menu name is available, and it must be the same
            if ($n.Db[$lc]['lang.name'] -cne $o.Db[$lc]['lang.name']) { $diff++; "  lang.name differs for $lc" }
        }
    }
    foreach ($lc in $n.Db.Keys) { if (-not $o.Db.ContainsKey($lc)) { $diff++; "  extra language $lc" } }
    $bad += $diff
    '{0}: differences={1} ; old {2:N0} ms ; new {3:N0} ms ; languages kept raw: {4}' -f $sc[0], $diff, $o.Ms, $n.Ms, ((@($n.Raw.Keys) | Sort-Object) -join ',')
}
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
if ($bad -gt 0) { "LANG EQUIVALENCE FAILED: $bad"; exit 1 }
'LANG EQUIVALENCE OK'
'''
TESTSRC['log'] = r'''# LOT 1: the new Write-Log writes the same kind of lines, throttles repeated keys, rotates the file, and never throws.
param([string]$OldBat, [string]$NewBat, [string]$Root)
$ErrorActionPreference = 'Stop'
$t = [IO.File]::ReadAllText($NewBat)
$a = $t.IndexOf('$logState = @{ n = 0 }')
$b = $t.IndexOf('function Mark-Step', $a)
if (($a -lt 0) -or ($b -lt 0)) { Write-Host 'new Write-Log not found'; exit 1 }
$logDir = Join-Path ([IO.Path]::GetTempPath()) ('zwlog' + [Guid]::NewGuid().ToString('N'))
$logFile = Join-Path $logDir 'log.txt'
$logLast = @{}
Invoke-Expression $t.Substring($a, $b - $a)
$fail = 0
function Check([string]$what, [bool]$ok) { if ($ok) { Write-Host ('ok    ' + $what) } else { Write-Host ('FAIL  ' + $what); $script:fail++ } }
Write-Log 'first line'
Check 'folder and file created on the first call' (Test-Path -LiteralPath $logFile)
Write-Log 'key line' 'k1'; Write-Log 'key line again' 'k1'
for ($i = 0; $i -lt 120; $i++) { Write-Log ('line ' + $i) }
$lines = [IO.File]::ReadAllLines($logFile)
Check 'throttled key: second call with the same key within 60 s is dropped' ((@($lines | Where-Object { $_ -like '*key line*' })).Count -eq 1)
Check 'every other line is there (1 + 1 + 120)' ($lines.Count -eq 122)
Check 'format: "yyyy-MM-dd HH:mm:ss  message"' ($lines[0] -match '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}  first line$')
# rotation: the check runs when the counter is a multiple of 50
$logState.n = 50
[IO.File]::WriteAllText($logFile, ('x' * 400100))
Write-Log 'after big file'
Check 'file over 400000 bytes is moved to log.txt.old' ((Test-Path -LiteralPath ($logFile + '.old')) -and ((Get-Item -LiteralPath $logFile).Length -lt 1000))
# never throws, even when the folder is unusable
$logFile = Join-Path (Join-Path $logDir 'nonexistent-sub') (Join-Path 'a' 'log.txt')
$logDir = Join-Path $logDir 'nonexistent-sub'
$threw = $false
try { $logState.n = 0; Write-Log 'x' } catch { $threw = $true }
Check 'Write-Log does not throw when the folder is missing (it creates it)' (-not $threw)
Remove-Item (Split-Path -Parent $logDir) -Recurse -Force -ErrorAction SilentlyContinue
if ($fail -gt 0) { Write-Host "LOG TEST FAILED: $fail"; exit 1 }
Write-Host 'LOG TEST OK'
'''
TESTSRC['mutex'] = r'''# LOT 1: Test-OldRun answers false when no old version runs and true when an old mutex is held, without exceptions.
param([string]$OldBat, [string]$NewBat, [string]$Root)
$ErrorActionPreference = 'Stop'
$t = [IO.File]::ReadAllText($NewBat)
$a = $t.IndexOf('function Test-OldRun {')
$b = $t.IndexOf("Mark-Step 'libraries loaded, checking old version'", $a)
if (($a -lt 0) -or ($b -lt 0)) { Write-Host 'Test-OldRun not found'; exit 1 }
Invoke-Expression $t.Substring($a, $b - $a)
$fail = 0
function Check([string]$what, [bool]$ok) { if ($ok) { Write-Host ('ok    ' + $what) } else { Write-Host ('FAIL  ' + $what); $script:fail++ } }
Check 'no old version running -> false' ((Test-OldRun) -eq $false)
$m = New-Object System.Threading.Mutex($true, 'Local\ModeReseauApp51')
Check 'old mutex held -> true' ((Test-OldRun) -eq $true)
$m.ReleaseMutex(); $m.Dispose()
Check 'released -> false again' ((Test-OldRun) -eq $false)
$errBefore = $Error.Count
$null = Test-OldRun
Check 'no error record is produced (OpenExisting used to build 3 per launch)' ($Error.Count -eq $errBefore)
if ($fail -gt 0) { Write-Host "MUTEX TEST FAILED: $fail"; exit 1 }
Write-Host 'MUTEX TEST OK'
'''
TESTSRC['net'] = r'''# LOT 2: Test-AnyTcp / Test-AnyPing / Test-Box (parallel tests, no CIM): right answers and right timing. Uses loopback and TEST-NET addresses (never routed).
param([string]$OldBat, [string]$NewBat, [string]$Root)
$ErrorActionPreference = 'Stop'
$t = [IO.File]::ReadAllText($NewBat)
$m = [regex]::Match($t, '(?s)\$ModeFnSrc\s*=\s*@' + "'" + '\r?\n(.*?)\r?\n' + "'" + '@')
if (-not $m.Success) { Write-Host 'ModeFnSrc not found'; exit 1 }
function T([string]$k) { return $k }
function Tf([string]$k, [object[]]$a) { return $k }
$Group = 'G'; $LegacyGroups = @('L'); $ExtraIPv4 = @(); $ExtraIPv6 = @()
. ([scriptblock]::Create($m.Groups[1].Value))
$fail = 0
function Check([string]$what, [bool]$ok) { if ($ok) { Write-Host ('ok    ' + $what) } else { Write-Host ('FAIL  ' + $what); $script:fail++ } }
function Timed([scriptblock]$sb) { $sw = [Diagnostics.Stopwatch]::StartNew(); $r = & $sb; return @($r, $sw.Elapsed.TotalMilliseconds) }
$lst = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 0); $lst.Start(); $port = ([System.Net.IPEndPoint]$lst.LocalEndpoint).Port
$r = Timed { Test-AnyTcp @(@('203.0.113.9', 81), @('198.51.100.9', 81), @('127.0.0.1', $port)) 2000 }
Check ('AnyTcp: 2 dead + 1 live -> true quickly (' + [int]$r[1] + ' ms)') (($r[0] -eq $true) -and ($r[1] -lt 1500))
$lst.Stop()
$r = Timed { Test-AnyTcp @(@('203.0.113.9', 81), @('198.51.100.9', 81)) 2000 }
Check ('AnyTcp: all dead -> false after about 2 s, not 4 s (' + [int]$r[1] + ' ms)') (($r[0] -eq $false) -and ($r[1] -gt 1500) -and ($r[1] -lt 3500))
$r = Timed { Test-AnyTcp @(,@('127.0.0.1', 1)) 2000 }
Check ('AnyTcp: refused connection -> false quickly (' + [int]$r[1] + ' ms)') (($r[0] -eq $false) -and ($r[1] -lt 1500))
$r = Timed { Test-AnyPing @('127.0.0.1') 2000 }
Check ('AnyPing: loopback -> true (' + [int]$r[1] + ' ms)') (($r[0] -eq $true) -and ($r[1] -lt 1500))
$r = Timed { Test-AnyPing @('203.0.113.9', '127.0.0.1') 2000 }
Check ('AnyPing: one dead + one live -> true quickly (' + [int]$r[1] + ' ms)') (($r[0] -eq $true) -and ($r[1] -lt 1500))
$r = Timed { Test-AnyPing @('203.0.113.9', '198.51.100.9') 2000 }
Check ('AnyPing: all dead -> false after about 2 s (' + [int]$r[1] + ' ms)') (($r[0] -eq $false) -and ($r[1] -lt 3500))
$g = Get-GatewayList
Check ('Get-GatewayList returns an array (count ' + @($g).Count + ')') ($null -ne $g)
$r = Timed { Test-Box }
Check ('Test-Box answers a boolean without error (' + $r[0] + ', ' + [int]$r[1] + ' ms)') ($r[0] -is [bool])
if ($fail -gt 0) { Write-Host "NET TEST FAILED: $fail"; exit 1 }
Write-Host 'NET TEST OK'
'''
TESTSRC['perf'] = r'''# LOT 0: the PERF helpers (opt-in counters) work: count / average / maximum, one log line per name, flush resets.
param([string]$OldBat, [string]$NewBat, [string]$Root)
$ErrorActionPreference = 'Stop'
$t = [IO.File]::ReadAllText($NewBat)
$a = $t.IndexOf('$PerfS = @{ On = $false')
$b = $t.IndexOf('function Write-Log', $a)
if (($a -lt 0) -or ($b -lt 0)) { Write-Host 'PERF block not found'; exit 1 }
$logLines = New-Object System.Collections.ArrayList
function Write-Log([string]$m, [string]$k = '') { [void]$logLines.Add($m) }
Invoke-Expression $t.Substring($a, $b - $a)
$fail = 0
function Check([string]$what, [bool]$ok) { if ($ok) { Write-Host ('ok    ' + $what) } else { Write-Host ('FAIL  ' + $what); $script:fail++ } }
$PerfS.On = $true
for ($i = 0; $i -lt 5; $i++) { $pt = 0; if ($PerfS.On) { $pt = [Diagnostics.Stopwatch]::GetTimestamp() }; Start-Sleep -Milliseconds 20; if ($PerfS.On) { Perf-Add 'demo' $pt } }
Perf-Flush
Check 'one PERF line for "demo"' ((@($logLines | Where-Object { $_ -like 'PERF demo n=5 avg=*' })).Count -eq 1)
Write-Host ('      ' + ($logLines -join ' | '))
Check 'average is at least the sleep (20 ms)' ($logLines[0] -match 'avg=(\d+\.\d) ms' -and [double]$Matches[1] -ge 15)
$logLines.Clear()
Perf-Flush
Check 'a second flush writes nothing (counters were reset)' ($logLines.Count -eq 0)
# Perf=1 must survive Save-BarConfig and be read at start
Check 'Save-BarConfig keeps Perf=1' ($t.Contains("if (`$PerfS.On) { `$lines = `$lines + 'Perf=1' }"))
Check 'config parser reads Perf=' ($t.Contains("if (`$ln0.StartsWith('Perf=')) { `$PerfS.On = (`$ln0.Substring(5).Trim() -eq '1') }"))
if ($fail -gt 0) { Write-Host "PERF TEST FAILED: $fail"; exit 1 }
Write-Host 'PERF TEST OK'
'''
TESTSRC['ranges'] = r'''# LOT 2: Get-LocalOnlyRanges (new) returns exactly the ranges the old Set-ModeLocal computed (IPv4 + fixed IPv6; the dynamic IPv6 part only differs in how addresses are listed).
param([string]$OldBat, [string]$NewBat, [string]$Root)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Numerics
function Load-Fn([string]$batPath) {
    $t = [IO.File]::ReadAllText($batPath)
    $m = [regex]::Match($t, '(?s)\$ModeFnSrc\s*=\s*@' + "'" + '\r?\n(.*?)\r?\n' + "'" + '@')
    if (-not $m.Success) { throw ('ModeFnSrc not found in ' + $batPath) }
    return $m.Groups[1].Value
}
$ExtraIPv4 = @(); $ExtraIPv6 = @(); $Group = 'G'; $LegacyGroups = @('L')
function T([string]$k) { return $k }
function Tf([string]$k, [object[]]$a) { return $k }
. ([scriptblock]::Create((Load-Fn $OldBat)))
# the old range code, as it was inside Set-ModeLocal (IPv6 dynamic part left out: it needs the CIM cmdlet Get-NetIPAddress)
$v4Allowed = @('0.0.0.0/8', '10.0.0.0/8', '127.0.0.0/8', '169.254.0.0/16', '172.16.0.0/12', '192.168.0.0/16', '224.0.0.0/3') + $ExtraIPv4
$v6Allowed = @('::/128', '::1/128', 'fc00::/7', 'fe80::/10', 'ff00::/8') + $ExtraIPv6
$v4Iv = @(); foreach ($c in $v4Allowed) { $v4Iv += Get-Interval $c 32 }
$v6Iv = @(); foreach ($c in $v6Allowed) { $v6Iv += Get-Interval $c 128 }
$old = @(@(ConvertTo-RangeStrings (Get-Complement $v4Iv 32) 4) + @(ConvertTo-RangeStrings (Get-Complement $v6Iv 128) 16))
. ([scriptblock]::Create((Load-Fn $NewBat)))
$sw = [Diagnostics.Stopwatch]::StartNew()
$new = @(Get-LocalOnlyRanges)
$ms = $sw.Elapsed.TotalMilliseconds
$hasGlobal6 = (@([System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() | ForEach-Object { $_.GetIPProperties().UnicastAddresses } | Where-Object { $_.Address.AddressFamily -eq 'InterNetworkV6' -and $_.Address.ToString() -match '^[23]' }).Count -gt 0)
Write-Host ('old ranges: ' + $old.Count + ' ; new ranges: ' + $new.Count + ' ; Get-LocalOnlyRanges ' + [int]$ms + ' ms ; global IPv6 on this host: ' + $hasGlobal6)
$same = (($old -join ',') -ceq ($new -join ','))
if ($hasGlobal6) { Write-Host 'note: this host has a global IPv6 address, the new list legitimately contains extra ranges: comparing the IPv4 part only'; $same = ((($old | Where-Object { $_ -notmatch ':' }) -join ',') -ceq (($new | Where-Object { $_ -notmatch ':' }) -join ',')) }
Write-Host ('identical: ' + $same)
Write-Host ('first ranges: ' + (($new | Select-Object -First 4) -join '  '))
if (-not $same) { Write-Host 'RANGES TEST FAILED'; exit 1 }
Write-Host 'RANGES TEST OK'
'''
TESTSRC['series'] = r'''# LOT 3: Get-SeriesPoints gives exactly the points the old per-point New-Object code produced (same X/Y, same closing points), as a PointF[].
param([string]$OldBat, [string]$NewBat, [string]$Root)
$ErrorActionPreference = 'Stop'
$t = [IO.File]::ReadAllText($NewBat)
$a = $t.IndexOf('function Get-SeriesPoints'); $b = $t.IndexOf('function Draw-Series', $a)
if (($a -lt 0) -or ($b -lt 0)) { Write-Host 'Get-SeriesPoints not found'; exit 1 }
Invoke-Expression $t.Substring($a, $b - $a)
$rnd = New-Object System.Random(7)
$bad = 0
foreach ($cnt in @(2, 5, 17, 39, 40)) {
    $hist = New-Object 'System.Collections.Generic.List[double]'
    for ($i = 0; $i -lt $cnt; $i++) { [void]$hist.Add($rnd.NextDouble() * 100) }
    $mx = 100.0; $x = 12.5; $y = 31.0; $w = 74.0; $h = 11.0
    $step = $w / 39.0
    $pts = New-Object 'System.Collections.Generic.List[System.Drawing.PointF]'
    for ($i = 0; $i -lt $cnt; $i++) { $sx = $x + $w - ($cnt - 1 - $i) * $step; $sy = $y + $h - ($hist[$i] / $mx) * $h; $pts.Add((New-Object System.Drawing.PointF([single]$sx, [single]$sy))) }
    $poly = New-Object 'System.Collections.Generic.List[System.Drawing.PointF]'; $poly.AddRange($pts)
    $poly.Add((New-Object System.Drawing.PointF([single]($x + $w), [single]($y + $h)))); $poly.Add((New-Object System.Drawing.PointF([single]($x + $w - ($cnt - 1) * $step), [single]($y + $h))))
    $oldPts = $pts.ToArray(); $oldPoly = $poly.ToArray()
    $newPts = Get-SeriesPoints $hist $x $y $w $h $mx $false
    $newPoly = Get-SeriesPoints $hist $x $y $w $h $mx $true
    if ($newPts.GetType().Name -ne 'PointF[]') { $bad++; Write-Host ('wrong type ' + $newPts.GetType().FullName) }
    if (($newPts.Length -ne $oldPts.Length) -or ($newPoly.Length -ne $oldPoly.Length)) { $bad++; Write-Host ('length differs for ' + $cnt) }
    for ($i = 0; $i -lt $oldPts.Length; $i++) { if (($oldPts[$i].X -ne $newPts[$i].X) -or ($oldPts[$i].Y -ne $newPts[$i].Y)) { $bad++ } }
    for ($i = 0; $i -lt $oldPoly.Length; $i++) { if (($oldPoly[$i].X -ne $newPoly[$i].X) -or ($oldPoly[$i].Y -ne $newPoly[$i].Y)) { $bad++ } }
}
Write-Host ('series points: differences = ' + $bad)
# the dial rectangle logic: a repaint limited to the dial is recognised, a full repaint is not
$DS = 1.5
$dial = New-Object System.Drawing.Rectangle([int](158 * $DS), [int](68 * $DS), [int](264 * $DS), [int](264 * $DS))
$inside = New-Object System.Drawing.Rectangle(($dial.X + 5), ($dial.Y + 5), 50, 50)
$full = New-Object System.Drawing.Rectangle(0, 0, [int](1100 * $DS), [int](580 * $DS))
if ((-not $dial.Contains($dial)) -or (-not $dial.Contains($inside)) -or $dial.Contains($full)) { $bad++; Write-Host 'dial clip logic is wrong' } else { Write-Host 'dial clip logic ok (dial and inside -> partial, whole window -> full)' }
if ($bad -gt 0) { Write-Host 'SERIES TEST FAILED'; exit 1 }
Write-Host 'SERIES TEST OK'
'''


if __name__ == '__main__':
    sys.exit(main())
