#!/usr/bin/env python3
"""Curate and validate the capture-56 IRQ suffix attempt without recapturing."""
import argparse
import hashlib
import json
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RUN = ROOT / "artifacts/deepseek/capture-56/natural-irq-suffix"
FIXTURE = ROOT / "evidence/mpu4/collection/irq-suffix-capture56-attempt1.json"
OUT = ROOT / "artifacts/deepseek/capture-56"
SOURCE = ROOT / "artifacts/deepseek/gate-28/natural-service"
MAME = Path(r"E:\Arcade\MAME0266\mame281.exe")
ROMS = Path(r"E:\Arcade\MAME0266\roms")
INPUT_SHA = "7C664323A5725E9FB294CB201B17B855564AF2E4A500560ED499F1EE45179D0D"
REPLAY_SHA = "4A051DA15264842697879EFF396B34A789F5D80623F9A2E749C244E6A80E721D"
MAME_SHA = "0FCE5A88DF4F9D9B1FBF1405812C00848036E615993780978D967DA34204CB7A"
ROM_SHA1 = "402D1518BB78FDC489B06C2AABC771E5CE151847"
ROM_SHA256 = "EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C"
ZIP_SHA = "E2553AFA6B8E9DEF55BD920E4BED77A4324696C1E358B73BE70BFD2C58179989"
ROM_BOUNDARIES = {
    "fec3": (0xFEC3, "BD6B4D"),
    "fec6": (0xFEC6, "BD58BB"),
    "fec9": (0xFEC9, "BD5CD0"),
    "fecc": (0xFECC, "0F2C"),
    "fece": (0xFECE, "2038"),
    "6b4d": (0x6B4D, "0D83"),
    "58bb": (0x58BB, "B671"),
    "5cd0": (0x5CD0, "9644"),
}
BOUNDARY_FILES = {"fc": "fc4d.bin", "fec3": "fec3.bin", "fec6": "fec6.bin", "fec9": "fec9.bin", "sv": "sv.bin"}


def sha(path, alg="sha256"):
    h = hashlib.new(alg)
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest().upper()


def sha_bytes(data, alg="sha256"):
    return hashlib.new(alg, data).hexdigest().upper()


def read_json(path):
    with open(path, encoding="utf-8-sig") as f:
        return json.load(f)


def write_json(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, indent=2) + "\n", encoding="utf-8")


def u16(data, addr):
    return (data[addr] << 8) | data[addr + 1]


def parse_events(text):
    events = []
    for line in text.splitlines():
        m = re.match(r"^(FC|TRACE_ENTRY|FEC6_RET|FEC6_OTHER|FEC9_RET|SV_ENTRY|FECC_RET|FECE_END|OVERFLOW_stack|SW)\s+(.*)$", line)
        if not m:
            continue
        tag, rest = m.group(1), m.group(2)
        kv = {k: v for k, v in re.findall(r"(\w+)=([0-9A-Fa-f]+)", rest)}
        events.append({"tag": tag, **kv})
    return events


def parse_trace(path):
    rows = []
    for line in path.read_text(encoding="ascii", errors="replace").splitlines():
        m = re.match(
            r"^cyc=([0-9A-F]+) A=([0-9A-F]+) B=([0-9A-F]+) X=([0-9A-F]+) Y=([0-9A-F]+) "
            r"U=([0-9A-F]+) S=([0-9A-F]+) CC=([0-9A-F]+) ([0-9A-F]{4}): (.*)$",
            line,
        )
        if not m:
            continue
        rows.append({
            "cyc": int(m.group(1), 16), "a": m.group(2), "b": m.group(3), "x": m.group(4),
            "y": m.group(5), "u": m.group(6), "s": m.group(7), "cc": m.group(8),
            "pc": m.group(9), "text": m.group(10).strip(),
        })
    return rows


def apply_input_patch(text):
    text = text.replace("local setup_callbacks_to_skip=36", "local setup_callbacks_to_skip=0")
    return re.sub(
        r"\r?\n if setup_callbacks_to_skip>0 then\r?\n  assert\(m\.time:as_double\(\)<0\.001,'Unexpected running frame during debugger setup'\)\r?\n  setup_callbacks_to_skip=setup_callbacks_to_skip-1\r?\n  return\r?\n end",
        "",
        text,
    )


def build():
    prov = read_json(RUN / "provenance.json")
    args = read_json(RUN / "arguments.json")
    exit_code = int((RUN / "exit-code.txt").read_text(encoding="ascii").strip())
    debugger_text = (RUN / "debugger.cmd").read_text(encoding="ascii")
    debug_log = (RUN / "debug.log").read_text(encoding="utf-8", errors="replace")
    events = parse_events(debug_log)
    trace = parse_trace(RUN / "routine.trace")
    with zipfile.ZipFile(ROMS / "m4addr.zip") as z:
        rom = z.read("a6ls.p1")

    by_tag = {}
    for e in events:
        by_tag.setdefault(e["tag"], []).append(e)

    def event(tag):
        return by_tag.get(tag, [None])[0]

    fec3 = event("TRACE_ENTRY")
    fec6 = event("FEC6_RET")
    fec9 = event("FEC9_RET")
    sv = event("SV_ENTRY")
    if not all([fec3, fec6, fec9, sv]):
        raise SystemExit("missing required boundary events")

    entry_s = int(fec3["s"], 16)
    fecc_rows = [r for r in trace if r["pc"] == "FECC" and int(r["s"], 16) == entry_s]
    fece_rows = [r for r in trace if r["pc"] == "FECE" and int(r["s"], 16) == entry_s]
    if not fecc_rows or not fece_rows:
        raise SystemExit("missing matched FECC/FECE trace rows")
    fecc_trace, fece_trace = fecc_rows[0], fece_rows[0]

    boundaries = {}
    for name, tag in [("fc", "FC"), ("fec3", "TRACE_ENTRY"), ("fec6", "FEC6_RET"), ("fec9", "FEC9_RET"), ("sv", "SV_ENTRY")]:
        e = event(tag)
        row = {"source": "trace-and-full-2KB", "pc": e["pc"], "cyc": e["cyc"], "s": e["s"], "u": e.get("u", ""),
               "x": e.get("x", ""), "y": e.get("y", ""), "a": e.get("a", ""), "b": e.get("b", ""),
               "dp": e.get("dp", ""), "cc": e.get("cc", ""), "q719b": e.get("q719b", "")}
        f = BOUNDARY_FILES.get(name)
        if f:
            p = RUN / f
            if p.exists():
                data = p.read_bytes()
                row.update({"file": f, "fileBytes": len(data), "fileSha256": sha_bytes(data)})
        boundaries[name] = row

    boundaries["fecc"] = {"source": "trace-only; full 2KB not saved", "pc": "FECC", "cyc": f"{fecc_trace['cyc']:016X}",
                          "s": fecc_trace["s"], "u": fecc_trace["u"], "x": fecc_trace["x"], "y": fecc_trace["y"],
                          "a": fecc_trace["a"], "b": fecc_trace["b"], "cc": fecc_trace["cc"],
                          "q719b": "00", "text": fecc_trace["text"]}
    boundaries["fece"] = {"source": "trace-only; full 2KB not saved", "pc": "FECE", "cyc": f"{fece_trace['cyc']:016X}",
                          "s": fece_trace["s"], "u": fece_trace["u"], "x": fece_trace["x"], "y": fece_trace["y"],
                          "a": fece_trace["a"], "b": fece_trace["b"], "cc": fece_trace["cc"],
                          "q719b": "00", "text": fece_trace["text"]}

    for name, (addr, _) in ROM_BOUNDARIES.items():
        if name in boundaries:
            boundaries[name]["romAddress"] = f"{addr:04X}"
            boundaries[name]["romBytes"] = rom[addr:addr + 8].hex().upper()
        else:
            boundaries[name] = {"source": "rom-only", "romAddress": f"{addr:04X}", "romBytes": rom[addr:addr + 8].hex().upper()}

    for name, row, off in [("fec6", "fec6", -2), ("fec9", "fec9", -2), ("sv", "sv", 0)]:
        p = RUN / BOUNDARY_FILES[name]
        if p.exists():
            data = p.read_bytes()
            s = int(boundaries[row]["s"], 16)
            word = u16(data, s + off)
            boundaries[row]["returnWord"] = f"{word:04X}"
            boundaries[row]["stackWordAddress"] = f"{s + off:04X}"

    sw = [e for e in events if e["tag"] == "SW" and int(e["cyc"], 16) <= fece_trace["cyc"] and int(e["s"], 16) >= entry_s - 2]
    kept_tags = {"FC", "TRACE_ENTRY", "FEC6_RET", "FEC9_RET", "SV_ENTRY", "FEC6_OTHER", "FECC_RET", "FECE_END", "OVERFLOW_stack"}
    kept_events = [e for e in events if e["tag"] in kept_tags]
    trace_first = trace[0]
    trace_last = trace[-1]
    return {
        "schema": "fruitmachinelab.mpu4.irq-suffix-capture56/v1",
        "classification": "trace-backed instruction suffix from one controlled replay occurrence; FECC/FECE full 2KB not saved, so this attempt is incomplete",
        "attempt": 1,
        "run": str(RUN.relative_to(ROOT)).replace("\\", "/"),
        "selectionRule": "FEC3 JSR 6B4D opcode BD6B4D; FEC6/FEC9/SV matched by S and return word; FECC/FECE matched by S depth and trace order; no first-FECC flag",
        "entryS": f"{entry_s:04X}",
        "provenance": prov,
        "arguments": args,
        "exitCode": exit_code,
        "debuggerText": debugger_text,
        "events": kept_events,
        "boundaries": boundaries,
        "trace": {
            "count": len(trace),
            "first": {"pc": trace_first["pc"], "cyc": f"{trace_first['cyc']:016X}"},
            "last": {"pc": trace_last["pc"], "cyc": f"{trace_last['cyc']:016X}"},
            "fecc": {"pc": fecc_trace["pc"], "cyc": f"{fecc_trace['cyc']:016X}", "s": fecc_trace["s"], "text": fecc_trace["text"]},
            "fece": {"pc": fece_trace["pc"], "cyc": f"{fece_trace['cyc']:016X}", "s": fece_trace["s"], "text": fece_trace["text"]},
        },
        "stackWrites": sw,
        "missing": ["fecc.bin", "fece.bin", "FECC_RET", "FECE_END"],
        "limits": [
            "The first matched suffix FEC3->6B4D->FEC6->58BB->FEC9->5CD0->FECC->FECE is present in the trace.",
            "Full 2KB was saved at FEC3, FEC6, FEC9 and 5CD0; it was not saved at FECC/FECE because the FECC breakpoint required the 6B4D return word instead of the 5CD0 return word, and the stack watchpoint cap later quit the run.",
            "No state was patched and no second MAME run was made; missing FECC/FECE 2KB is reported, not reconstructed.",
            "No 58BB/5CD0 semantics beyond the observed instructions, no whole-IRQ/timer cadence, no Live or audio claim.",
        ],
        "rom": {"entry": "a6ls.p1", "bytes": len(rom), "sha1": sha_bytes(rom, "sha1"), "sha256": sha_bytes(rom),
                "zipSha256": sha(ROMS / "m4addr.zip")},
    }


def payload(cycle):
    return int(cycle, 16)


def validate(doc):
    checks = []
    def add(cid, ok, detail):
        checks.append({"id": cid, "pass": bool(ok), "detail": detail})

    prov = doc["provenance"]
    run = ROOT / doc["run"]
    add("source-hashes", sha(SOURCE / "input.lua") == INPUT_SHA and sha(SOURCE / "replay-actions.csv") == REPLAY_SHA
        and prov.get("source_input_lua_sha256") == INPUT_SHA and prov.get("source_replay_actions_sha256") == REPLAY_SHA,
        "source input/replay hashes")
    with open(SOURCE / "input.lua", encoding="utf-8", newline="") as f:
        derived = apply_input_patch(f.read())
    add("input-derivation", sha(run / "input.lua") == prov.get("derived_input_lua_sha256")
        and sha_bytes(derived.encode("utf-8")) == prov.get("derived_input_lua_sha256"),
        "derived input.lua hash")
    add("mame-hash", MAME.exists() and sha(MAME) == MAME_SHA and prov.get("mame_sha256") == MAME_SHA,
        "MAME 0.281 sha256")
    rom = doc["rom"]
    add("rom", rom["bytes"] == 65536 and rom["sha1"] == ROM_SHA1 and rom["sha256"] == ROM_SHA256 and rom["zipSha256"] == ZIP_SHA,
        "actual ROM entry and zip")
    args = doc["arguments"]
    joined = " ".join(args)
    add("arguments-isolation", args[:2] == ["m4addr", "-noreadconfig"]
        and all(str(p).startswith(str(run)) for p in args if str(p).startswith("C:\\projects\\GitRepos\\FruitMachineLab\\artifacts"))
        and "-state" not in args and "-playback" not in args and "-record" not in args and "-input" not in args,
        "exact isolated argument array; no state/playback/record input")
    add("debugger-hash", sha(run / "debugger.cmd") == prov.get("debugger_sha256"), "debugger.cmd hash")
    lines = [l.strip() for l in doc["debuggerText"].splitlines() if l.strip()]
    allowed = all(re.match(r"^(temp[0-9]=0|bpset |wpset |go$|quit$)", l) for l in lines)
    forbidden = any(re.search(r"\b(set|write|load|restore|state|playback|record)\b", l, re.I) for l in lines)
    add("debugger-structure", allowed and not forbidden, "only breakpoints/watchpoints/trace/save/quit actions")
    add("exit-code", doc["exitCode"] == 0, "MAME exit 0")
    add("trace-count", 0 < doc["trace"]["count"] <= int(prov.get("instruction_cap", 0)), "bounded instruction trace")
    fec3 = doc["boundaries"]["fec3"]
    occ_ok = doc["trace"]["first"]["pc"] == "6B4D" and payload(doc["trace"]["first"]["cyc"]) == payload(fec3["cyc"]) + 8
    occ_ok = occ_ok and all(payload(doc["boundaries"][k]["cyc"]) > payload(doc["boundaries"]["fec3"]["cyc"]) for k in ["fec6", "fec9", "sv"])
    occ_ok = occ_ok and payload(doc["boundaries"]["fecc"]["cyc"]) >= payload(doc["boundaries"]["sv"]["cyc"])
    occ_ok = occ_ok and payload(doc["boundaries"]["fece"]["cyc"]) > payload(doc["boundaries"]["fecc"]["cyc"])
    add("trace-occurrence", occ_ok, "trace begins 8 cycles after FEC3 and follows the captured boundary cycle order")
    add("boundary-set", all(k in doc["boundaries"] for k in ["fc", "fec3", "fec6", "fec9", "sv", "fecc", "fece"]),
        "all seven boundaries present (five full-2KB, two trace-only)")
    file_ok = True
    for k in ["fc", "fec3", "fec6", "fec9", "sv", "fecc", "fece"]:
        b = doc["boundaries"][k]
        if b.get("source") == "trace-only; full 2KB not saved":
            file_ok = False
            continue
        p = run / b.get("file", "")
        file_ok = file_ok and p.exists() and p.stat().st_size == 2048 and sha(p) == b.get("fileSha256")
    add("boundary-files", file_ok, "full 2KB files for FEC3/FEC6/FEC9/5CD0/FECC/FECE")
    stack_ok = True
    for k, expected in [("fec6", "FEC6"), ("fec9", "FEC9"), ("sv", "FECC")]:
        b = doc["boundaries"][k]
        stack_ok = stack_ok and b.get("returnWord") == expected and b.get("stackWordAddress") is not None
    for k in ["fecc", "fece"]:
        stack_ok = stack_ok and doc["boundaries"][k].get("source") != "trace-only; full 2KB not saved"
    add("boundary-stack-match", stack_ok, "return words FEC6/FEC9 and 5CD0 entry FECC; matched S/depth")
    rom_ok = True
    for k, (_, expected) in ROM_BOUNDARIES.items():
        b = doc["boundaries"].get(k, {})
        rom_ok = rom_ok and b.get("romBytes", "")[:len(expected)] == expected
    add("boundary-rom", rom_ok, "actual ROM bytes at every boundary")
    b719 = True
    for k in ["fc", "fec3", "fec6", "fec9", "sv"]:
        b719 = b719 and doc["boundaries"][k].get("q719b") == "00"
    b719 = b719 and doc["boundaries"]["fecc"].get("q719b") == "00" and doc["boundaries"]["fece"].get("q719b") == "00"
    add("actual-719b", b719, "719B observed as 00 at each boundary; not injected")
    add("nested-separation", doc["entryS"] == doc["boundaries"]["fec6"]["s"] == doc["boundaries"]["fec9"]["s"]
        and int(doc["boundaries"]["sv"]["s"], 16) == int(doc["entryS"], 16) - 2
        and doc["boundaries"]["fecc"]["s"] == doc["entryS"] and doc["boundaries"]["fece"]["s"] == doc["entryS"],
        "S/depth pairing; nested IRQs cannot satisfy entryS")
    add("trace-stop", doc["trace"]["last"]["pc"] == "FECE", "trace stops at matched FECE")
    add("no-first-fecc-flag", "first-FECC" in doc["selectionRule"] and "no first-FECC flag" in doc["selectionRule"],
        "selection uses S/word/depth, not a first-FECC flag")
    return checks


def run_controls(doc):
    controls = []
    def check(name, mutate, expected):
        copy = json.loads(json.dumps(doc))
        mutate(copy)
        failed = [c["id"] for c in validate(copy) if not c["pass"]]
        controls.append({"name": name, "expectedFailure": expected, "passed": expected in failed,
                         "failedIds": failed})
    check("wrong-s", lambda d: d["boundaries"]["fec6"].__setitem__("s", "0788"), "boundary-stack-match")
    check("wrong-occurrence", lambda d: d["boundaries"]["fec3"].__setitem__("cyc", "0000000000000000"), "trace-occurrence")
    check("missing-boundary", lambda d: d["boundaries"]["fec9"].__setitem__("file", "missing.bin"), "boundary-files")
    check("delta", lambda d: d["boundaries"]["fec6"].__setitem__("returnWord", "FEC9"), "boundary-stack-match")
    check("opcode", lambda d: d["boundaries"]["fec3"].__setitem__("romBytes", "BD6B4E"), "boundary-rom")
    check("exit", lambda d: d.__setitem__("exitCode", 1), "exit-code")
    check("source", lambda d: d["provenance"].__setitem__("source_input_lua_sha256", "00"), "source-hashes")
    check("tampered-debugger", lambda d: d.__setitem__("debuggerText", d["debuggerText"] + "\nset 0x44=1"), "debugger-structure")
    check("trace-overflow", lambda d: d["trace"].__setitem__("count", int(d["provenance"]["instruction_cap"]) + 1), "trace-count")
    return controls


def manifest():
    entries = [
        "tools/Curate-Capture56Evidence.py",
        "evidence/mpu4/collection/irq-suffix-capture56-attempt1.json",
        "artifacts/deepseek/capture-56/validation.json",
        "artifacts/deepseek/capture-56/negative-controls.json",
        "artifacts/deepseek/capture-56/result.md",
        "artifacts/deepseek/capture-56/natural-irq-suffix/fc4d.bin",
        "artifacts/deepseek/capture-56/natural-irq-suffix/fec3.bin",
        "artifacts/deepseek/capture-56/natural-irq-suffix/fec6.bin",
        "artifacts/deepseek/capture-56/natural-irq-suffix/fec9.bin",
        "artifacts/deepseek/capture-56/natural-irq-suffix/sv.bin",
        "artifacts/deepseek/capture-56/natural-irq-suffix/debug.log",
        "artifacts/deepseek/capture-56/natural-irq-suffix/routine.trace",
        "artifacts/deepseek/capture-56/natural-irq-suffix/debugger.cmd",
        "artifacts/deepseek/capture-56/natural-irq-suffix/arguments.json",
        "artifacts/deepseek/capture-56/natural-irq-suffix/provenance.json",
        "artifacts/deepseek/capture-56/natural-irq-suffix/exit-code.txt",
        "artifacts/deepseek/capture-56/natural-irq-suffix/trace-lines.txt",
    ]
    rows = []
    for rel in entries:
        p = ROOT / rel
        rows.append({"path": rel, "bytes": p.stat().st_size, "sha256": sha(p)})
    write_json(OUT / "manifest.json", rows)
    check = {"pass": True, "entries": []}
    for row in rows:
        p = ROOT / row["path"]
        ok = p.exists() and p.stat().st_size == row["bytes"] and sha(p) == row["sha256"]
        check["entries"].append({"path": row["path"], "pass": ok})
        check["pass"] = check["pass"] and ok
    write_json(OUT / "manifest-check.json", check)
    return check


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    doc = build()
    checks = validate(doc)
    controls = run_controls(doc)
    write_json(FIXTURE, doc)
    write_json(OUT / "validation.json", {"pass": all(c["pass"] for c in checks), "checks": checks})
    write_json(OUT / "negative-controls.json", {"pass": all(c["passed"] for c in controls), "cases": controls})
    mcheck = manifest()
    print(json.dumps({
        "validationPass": all(c["pass"] for c in checks),
        "failed": [c["id"] for c in checks if not c["pass"]],
        "controlsPass": all(c["passed"] for c in controls),
        "manifestPass": mcheck["pass"],
        "traceCount": doc["trace"]["count"],
        "traceLast": doc["trace"]["last"],
    }, indent=2))
    if args.self_test and not (all(c["passed"] for c in controls) and mcheck["pass"]):
        sys.exit(1)


if __name__ == "__main__":
    main()
