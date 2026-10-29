#!/usr/bin/env python3
"""Apply smali recipes to an apktool decode, finding classes in any smali dir.

Recipe lines (tab separated, '#' comments):
  return     <class> <method> <value>
  null       <class> <method>
  replace    <class> <method> <old> <new>
  replaceall <class> <old> <new>
  body       <class> <method> <file>      (method body from file, without .method/.end)
  add        <class> <file>               (new smali file for <class>, into the last smali dir)
  rmfile     <path>                       (file relative to the decode root)
  replacefile <path> <old> <new>          (plain text replace in any decoded file, once)
  append     <class> <file>               (append smali text, e.g. new methods or fields)
  cscbool    <class> <key> <0x0|0x1>      (SemCscFeature.getBoolean(key, ...) -> constant, all uses)
  putfile    <src> <path>                 (copy src, relative to the recipe, into the decode)

<class> is the descriptor path, e.g. com/android/server/RescueParty.
<method> is a substring of the .method line, e.g. isDisabled()Z.
In <old>/<new>, \\n is a newline and \\t a tab. Every op must change something.
"""
import os
import re
import sys


def smali_dirs(work):
    return sorted((d for d in os.listdir(work) if re.fullmatch(r"smali(_classes\d+)?", d)),
                  key=lambda d: int(d[13:] or 1) if d != "smali" else 1)


def find_class(work, cls):
    for d in smali_dirs(work):
        p = os.path.join(work, d, cls + ".smali")
        if os.path.exists(p):
            return p
    return None


def unescape(s):
    return s.replace("\\n", "\n").replace("\\t", "\t")


def method_span(lines, method):
    hits = [i for i, l in enumerate(lines) if l.startswith(".method") and method in l]
    if len(hits) != 1:
        raise ValueError(f"method '{method}' matched {len(hits)} times")
    start = hits[0]
    end = next(i for i in range(start, len(lines)) if lines[i].startswith(".end method"))
    return start, end


def return_body(decl, method, value):
    ret = method.split(")", 1)[1]
    static = " static " in decl
    has_args = "()" not in method
    if ret == "V":
        return ["    .locals 0", "", "    return-void"]
    v = {"true": "0x1", "false": "0x0"}.get(value, value)
    if ret == "J":
        return ["    .locals 2", "", f"    const-wide v0, {v}", "", "    return-wide v0"]
    reg, loc = ("p0", 0) if (not static or has_args) else ("v0", 1)
    if ret in ("Z", "B", "S", "C", "I", "F"):
        n = int(v, 0) if ret != "F" else None
        op = "const/4" if n is not None and -8 <= n <= 7 else "const"
        return [f"    .locals {loc}", "", f"    {op} {reg}, {v}", "", f"    return {reg}"]
    if ret == "Ljava/lang/String;":
        return [f"    .locals {loc}", "", f'    const-string {reg}, "{value}"', "", f"    return-object {reg}"]
    if value == "null":
        return [f"    .locals {loc}", "", f"    const/4 {reg}, 0x0", "", f"    return-object {reg}"]
    raise ValueError(f"unsupported return type {ret}")


def apply(work, op, args, base):
    if op == "rmfile":
        p = os.path.join(work, args[0])
        if not os.path.exists(p):
            raise ValueError(f"{args[0]} not found")
        os.remove(p)
        return
    if op == "replacefile":
        p = os.path.join(work, args[0])
        text = open(p).read()
        old, rep = unescape(args[1]), unescape(args[2])
        if text.count(old) != 1:
            raise ValueError(f"'{args[1][:40]}' found {text.count(old)} times in {args[0]}")
        open(p, "w").write(text.replace(old, rep))
        return
    if op == "putfile":
        dst = os.path.join(work, args[1])
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(os.path.join(base, args[0]), "rb") as f, open(dst, "wb") as o:
            o.write(f.read())
        return
    if op == "add":
        cls, src = args
        dst = os.path.join(work, smali_dirs(work)[-1], cls + ".smali")
        if find_class(work, cls):
            raise ValueError(f"{cls} already exists")
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(os.path.join(base, src)) as f, open(dst, "w") as o:
            o.write(f.read())
        return
    cls = args[0]
    path = find_class(work, cls)
    if not path:
        raise ValueError(f"class {cls} not found")
    text = open(path).read()
    new = text
    if op == "replaceall":
        old, rep = unescape(args[1]), unescape(args[2])
        new = text.replace(old, rep)
    elif op == "cscbool":
        pat = re.compile(
            r"invoke-static \{\}, Lcom/samsung/android/feature/SemCscFeature;->getInstance\(\)"
            r"Lcom/samsung/android/feature/SemCscFeature;\n\n\s+move-result-object (\w+)\n\n"
            r"\s+const-string (\w+), \"" + re.escape(args[1]) + r"\"\n\n"
            r"(?:\s+(const/4 \w+, 0x[01])\n\n)?"
            r"\s+invoke-virtual \{[^}]*\}, Lcom/samsung/android/feature/SemCscFeature;->getBoolean\(Ljava/lang/String;Z?\)Z\n\n"
            r"\s+move-result (\w+)")
        new = pat.sub(lambda m: (f"{m.group(3)}\n\n    " if m.group(3) else "") + f"const/4 {m.group(4)}, {args[2]}", text)
    elif op == "append":
        with open(os.path.join(base, args[1])) as f:
            new = text.rstrip("\n") + "\n\n" + f.read().rstrip("\n") + "\n"
    else:
        lines = text.split("\n")
        s, e = method_span(lines, args[1])
        if op == "return":
            lines[s + 1:e] = return_body(lines[s], args[1], args[2])
        elif op == "null":
            lines[s + 1:e] = return_body(lines[s], args[1].rsplit(")", 1)[0] + ")V", "")
        elif op == "body":
            with open(os.path.join(base, args[2])) as f:
                lines[s + 1:e] = f.read().rstrip("\n").split("\n")
        elif op == "replace":
            old, rep = unescape(args[2]), unescape(args[3])
            seg = "\n".join(lines[s:e + 1])
            if old not in seg:
                raise ValueError(f"'{args[2]}' not found in {args[1]}")
            lines[s:e + 1] = seg.replace(old, rep).split("\n")
        else:
            raise ValueError(f"unknown op {op}")
        new = "\n".join(lines)
    if new == text:
        raise ValueError("no change")
    open(path, "w").write(new)


def main(work, recipe):
    base = os.path.dirname(os.path.abspath(recipe))
    bad = 0
    for n, line in enumerate(open(recipe), 1):
        line = line.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        op, *args = line.split("\t")
        try:
            apply(work, op, args, base)
        except (ValueError, StopIteration) as e:
            bad += 1
            print(f"{recipe}:{n}: {op} {' '.join(args[:2])}: {e}")
    if bad:
        sys.exit(f"{bad} op(s) failed")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("usage: smali_patch.py <decoded_dir> <recipe>")
    main(*sys.argv[1:])
