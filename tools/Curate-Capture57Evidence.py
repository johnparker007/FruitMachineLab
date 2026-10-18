#!/usr/bin/env python3
"""Curate and validate the capture-57 corrected IRQ suffix attempt.

Attempt 1 (capture 56) is preserved unchanged. This script validates the one
authorized capture-57 run, writes a compact accepted fixture only when every
positive check and every negative control passes, and exits non-zero whenever
positive evidence is invalid, even if the negative controls pass.
"""
import argparse
import copy
import hashlib
import json
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RUN = ROOT / "artifacts/deepseek/capture-57/natural-irq-suffix"
OUT = ROOT / "artifacts/deepseek/capture-57"
FIXTURE = ROOT / "evidence/mpu4/collection/irq-suffix-capture57.json"
ATTEMPT1 = ROOT / "evidence/mpu4/collection/irq-suffix-capture56-attempt1.json"
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
BOUNDARY_FILES = {
    "fc": "fc4d.bin",
    "fec3": "fec3.bin",
    "fec6": "fec6.bin",
    "fec9": "fec9.bin",
    "sv": "sv.bin",
    "fecc": "fecc.bin",
    "fece": "fece.bin",
}
ANCHOR_TAGS = (
    "FC", "TRACE_ENTRY", "FEC6_RET", "FEC9_RET", "SV_ENTRY",
    "FECC_RET", "FECC_OTHER", "FECE_END", "FECE_OTHER", "OVERFLOW_stack",
)
SW_TAG = "SW"


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
        m = re.match(r"^(" + "|".join(ANCHOR_TAGS + (SW_TAG,)) + r")\s+(.*)$", line)
        if not m:
            continue
        tag, rest = m.group(1), m.group(2)
        kv = {k: v for k, v in re.findall(r"(\w+)=([0-9A-Fa-f]+)", rest)}
        events.append({"tag": tag, **kv})
    return events


def parse_trace(path):
    rows = []
    pat = re.compile(
        r"^cyc=([0-9A-F]+) A=([0-9A-F]+) B=([0-9A-F]+) X=([0-9A-F]+) Y=([0-9A-F]+) "
        r"U=([0-9A-F]+) S=([0-9A-F]+) CC=([0-9A-F]+) OP=([0-9A-F]+)\s+([0-9A-F]{4}): (.*)$",
        re.IGNORECASE,
    )
    for line in path.read_text(encoding="ascii", errors="replace").splitlines():
        m = pat.match(line)
        if not m:
            continue
        rows.append({
            "cyc": int(m.group(1), 16),
            "a": m.group(2).upper(),
            "b": m.group(3).upper(),
            "x": m.group(4).upper(),
            "y": m.group(5).upper(),
            "u": m.group(6).upper(),
            "s": m.group(7).upper(),
            "cc": m.group(8).upper(),
            "op": m.group(9).upper(),
            "pc": m.group(10).upper(),
            "text": m.group(11).strip(),
        })
    return rows


def apply_input_patch(text):
    text = text.replace("local setup_callbacks_to_skip=36", "local setup_callbacks_to_skip=0")
    return re.sub(
        r"\r?\n if setup_callbacks_to_skip>0 then\r?\n  assert\(m\.time:as_double\(\)<0\.001,'Unexpected running frame during debugger setup'\)\r?\n  setup_callbacks_to_skip=setup_callbacks_to_skip-1\r?\n  return\r?\n end",
        "",
        text,
    )


def expected_arguments(run):
    return [
        "m4addr", "-noreadconfig", "-rompath", str(ROMS),
        "-cfg_directory", str(run / "cfg"),
        "-nvram_directory", str(run / "nvram"),
        "-input_directory", str(run / "inp"),
        "-snapshot_directory", str(run / "snap"),
        "-comment_directory", str(run / "comments"),
        "-state_directory", str(run / "state"),
        "-diff_directory", str(run / "diff"),
        "-autoboot_delay", "0",
        "-autoboot_script", str(run / "input.lua"),
        "-debug", "-debugger", "windows",
        "-debugscript", str(run / "debugger.cmd"),
        "-debuglog", "-video", "none", "-sound", "none", "-window",
        "-skip_gameinfo", "-nothrottle", "-seconds_to_run", "430",
    ]


def build():
    prov = read_json(RUN / "provenance.json")
    args = read_json(RUN / "arguments.json")
    exit_code = int((RUN / "exit-code.txt").read_text(encoding="ascii").strip())
    debugger_text = (RUN / "debugger.cmd").read_text(encoding="ascii")
    debug_log = (RUN / "debug.log").read_text(encoding="utf-8", errors="replace")
    events = parse_events(debug_log)
    trace = parse_trace(RUN / "routine.trace")
    trace_lines = int((RUN / "trace-lines.txt").read_text(encoding="ascii").strip())
    with zipfile.ZipFile(ROMS / "m4addr.zip") as z:
        rom = z.read("a6ls.p1")

    by_tag = {}
    for e in events:
        by_tag.setdefault(e["tag"], []).append(e)

    def event(tag):
        return by_tag.get(tag, [None])[0]

    fec3 = event("TRACE_ENTRY")
    if not fec3:
        raise SystemExit("missing required TRACE_ENTRY event")
    entry_s = int(fec3["s"], 16)
    entry_cycle = int(fec3["cyc"], 16)
    trace_first = trace[0] if trace else None
    trace_last = trace[-1] if trace else None
    fecc_res = event("FECC_RET")
    fece_res = event("FECE_END")
    sv_res = event("SV_ENTRY")
    sv_s = int(sv_res["s"], 16) if sv_res else None
    sv_cycle = int(sv_res["cyc"], 16) if sv_res else None

    boundaries = {}
    for name, tag in [
        ("fc", "FC"), ("fec3", "TRACE_ENTRY"), ("fec6", "FEC6_RET"),
        ("fec9", "FEC9_RET"), ("sv", "SV_ENTRY"),
        ("fecc", "FECC_RET"), ("fece", "FECE_END"),
    ]:
        e = event(tag)
        row = {
            "source": "trace-and-full-2KB" if e else "missing",
            "tag": tag,
        }
        if e:
            row.update({
                "pc": e.get("pc", ""), "cyc": e.get("cyc", ""), "s": e.get("s", ""),
                "u": e.get("u", ""), "x": e.get("x", ""), "y": e.get("y", ""),
                "a": e.get("a", ""), "b": e.get("b", ""), "dp": e.get("dp", ""),
                "cc": e.get("cc", ""), "q719b": e.get("q719b", ""),
                "guard83": e.get("guard83", ""), "host44": e.get("host44", ""),
                "host45": e.get("host45", ""), "host46": e.get("host46", ""),
                "ret2": e.get("ret2", ""), "ret0": e.get("ret0", ""),
            })
        f = BOUNDARY_FILES[name]
        p = RUN / f
        if p.exists():
            data = p.read_bytes()
            row.update({"file": f, "fileBytes": len(data), "fileSha256": sha_bytes(data)})
            if len(data) >= 0x800:
                row["host44File"] = f"{data[0x44]:02X}"
                row["guard83File"] = f"{data[0x83]:02X}"
                row["byte44"] = f"{data[0x44]:02X}"
                row["byte83"] = f"{data[0x83]:02X}"
        boundaries[name] = row

    for name, offset in [("fec6", -2), ("fec9", -2), ("fecc", -2)]:
        b = boundaries.get(name, {})
        p = RUN / BOUNDARY_FILES[name]
        if p.exists() and b.get("s"):
            data = p.read_bytes()
            addr = int(b["s"], 16) + offset
            b["returnWord"] = f"{u16(data, addr):04X}"
            b["stackWordAddress"] = f"{addr:04X}"
            b["returnWordSource"] = "full-2KB"
    b = boundaries.get("sv", {})
    p = RUN / BOUNDARY_FILES["sv"]
    if p.exists() and b.get("s"):
        data = p.read_bytes()
        addr = int(b["s"], 16)
        b["returnWord"] = f"{u16(data, addr):04X}"
        b["stackWordAddress"] = f"{addr:04X}"
        b["returnWordSource"] = "full-2KB"
    b = boundaries.get("fece", {})
    p = RUN / BOUNDARY_FILES["fece"]
    if p.exists() and b.get("s"):
        data = p.read_bytes()
        addr = int(b["s"], 16)
        b["stackTopWord"] = f"{u16(data, addr):04X}"
        b["stackTopWordAddress"] = f"{addr:04X}"
        b["returnWordSource"] = "full-2KB"

    for name, (addr, _) in ROM_BOUNDARIES.items():
        if name not in boundaries:
            boundaries[name] = {"source": "rom-only"}
        boundaries[name]["romAddress"] = f"{addr:04X}"
        boundaries[name]["romBytes"] = rom[addr:addr + 8].hex().upper()

    # Full trace with register/cycle/opcode/interval rows.
    trace_out = []
    prev = entry_cycle
    for r in trace:
        trace_out.append({
            "pc": r["pc"], "cyc": f"{r['cyc']:016X}", "interval": f"{r['cyc'] - prev:08X}",
            "a": r["a"], "b": r["b"], "x": r["x"], "y": r["y"],
            "u": r["u"], "s": r["s"], "cc": r["cc"], "op": r["op"], "text": r["text"],
        })
        prev = r["cyc"]

    sw = []
    for e in events:
        if e["tag"] != SW_TAG:
            continue
        sw.append({k: e.get(k, "") for k in (
            "pc", "cyc", "s", "u", "a", "b", "dp", "cc", "wpaddr", "old", "new",
            "opm4", "opm3", "opm2", "opm1", "op0", "op1", "op2", "op3",
        )})

    host44 = boundaries.get("sv", {}).get("host44", "")
    if host44 == "00":
        path_class = (
            "5CD0 guard 44=00 at service entry; the observed execution is the "
            "zero-guard service body through 5CD4..5D38 and the FECC continuation, "
            "not a nonzero guard return and not a synthesized active path"
        )
    else:
        path_class = (
            f"5CD0 guard 44={host44} at service entry; the observed FECC is the "
            "guard-return path via BNE 5D3A, not a synthesized active service path"
        )

    return {
        "schema": "fruitmachinelab.mpu4.irq-suffix-capture57/v1",
        "classification": (
            "trace-backed matched IRQ suffix from one controlled original-reset replay "
            "occurrence with full 2KB anchors at FEC3, FEC6, FEC9, 5CD0, matched FECC "
            "and FECE; attempt 2 corrects the attempt-1 FECC stack-word guard"
        ),
        "attempt": 2,
        "run": str(RUN.relative_to(ROOT)).replace("\\", "/"),
        "selectionRule": (
            "FEC3 JSR opcode BD6B4D; FEC6/FEC9 matched by selected entry S and return word; "
            "5CD0 entry requires S=entryS-2 and stack word FECC; matched FECC requires "
            "S=5CD0entryS+2, stack word FECC and cycle after 5CD0 entry; FECE requires "
            "entryS and the corresponding cycle after matched FECC; no PC-only selection "
            "and no first-FECC flag"
        ),
        "pathClass": path_class,
        "entryS": f"{entry_s:04X}",
        "entryCycle": f"{entry_cycle:016X}",
        "serviceEntryS": f"{sv_s:04X}" if sv_s is not None else "",
        "host44AtService": host44,
        "provenance": prov,
        "arguments": args,
        "exitCode": exit_code,
        "debuggerText": debugger_text,
        "boundaries": boundaries,
        "trace": {
            "count": len(trace),
            "traceLines": trace_lines,
            "first": {"pc": trace_first["pc"], "cyc": f"{trace_first['cyc']:016X}",
                      "op": trace_first["op"]} if trace_first else None,
            "last": {"pc": trace_last["pc"], "cyc": f"{trace_last['cyc']:016X}",
                     "op": trace_last["op"], "s": trace_last["s"]} if trace_last else None,
            "rows": trace_out,
        },
        "stackWrites": sw,
        "rom": {
            "entry": "a6ls.p1", "bytes": len(rom), "sha1": sha_bytes(rom, "sha1"),
            "sha256": sha_bytes(rom), "zipSha256": sha(ROMS / "m4addr.zip"),
        },
        "limits": [
            "One matched occurrence only; nested IRQs after FECE are outside this fixture.",
            "No whole-IRQ or autonomous timer cadence claim; no 58BB/5CD0 semantics beyond the observed instruction path.",
            "No state/playback/end-state injection, no expected-state fit, no Live or audio claim.",
            "Attempt 1 (capture 56) remains explicitly incomplete and unchanged; capture 57 is the final authorized attempt on this suffix boundary.",
        ],
    }


def validate(doc):
    checks = []

    def add(cid, ok, detail):
        checks.append({"id": cid, "pass": bool(ok), "detail": detail})

    prov = doc.get("provenance", {})
    run = ROOT / doc.get("run", "")
    boundaries = doc.get("boundaries", {})
    trace = doc.get("trace", {})
    rows = trace.get("rows", [])
    rom = doc.get("rom", {})

    add(
        "source-hashes",
        sha(SOURCE / "input.lua") == INPUT_SHA
        and sha(SOURCE / "replay-actions.csv") == REPLAY_SHA
        and prov.get("source_input_lua_sha256") == INPUT_SHA
        and prov.get("source_replay_actions_sha256") == REPLAY_SHA,
        "source input/replay hashes",
    )
    with open(SOURCE / "input.lua", encoding="utf-8", newline="") as f:
        derived = apply_input_patch(f.read())
    add(
        "input-derivation",
        (run / "input.lua").exists()
        and sha(run / "input.lua") == prov.get("derived_input_lua_sha256")
        and sha_bytes(derived.encode("utf-8")) == prov.get("derived_input_lua_sha256"),
        "derived input.lua matches the declared skip-guard/assertion patch",
    )
    add(
        "mame-hash",
        MAME.exists() and sha(MAME) == MAME_SHA and prov.get("mame_sha256") == MAME_SHA,
        "MAME 0.281 sha256",
    )
    add(
        "rom",
        rom.get("bytes") == 65536 and rom.get("sha1") == ROM_SHA1
        and rom.get("sha256") == ROM_SHA256 and rom.get("zipSha256") == ZIP_SHA,
        "actual ROM entry, ROM sha1/sha256 and zip sha256",
    )
    add(
        "arguments-isolation",
        doc.get("arguments") == expected_arguments(run),
        "exact isolated MAME argument array; no state/playback/record input",
    )
    add(
        "debugger-hash",
        (run / "debugger.cmd").exists()
        and sha(run / "debugger.cmd") == prov.get("debugger_sha256"),
        "debugger.cmd sha256",
    )

    lines = [l.strip() for l in doc.get("debuggerText", "").splitlines() if l.strip()]
    allowed = all(re.match(r"^(temp[0-9]=0|bpset |wpset |go$|quit$)", l) for l in lines)
    forbidden = any(
        re.search(r"(^|[;\s])(set|write|load|restore|playback|record|fill|paste|rompatch)([;\s]|$)", l, re.I)
        for l in lines
    )
    counts = {
        "fc": sum(1 for l in lines if l.startswith("bpset 0xfc,")),
        "fec3": sum(1 for l in lines if l.startswith("bpset 0xfec3,")),
        "fec6": sum(1 for l in lines if l.startswith("bpset 0xfec6,")),
        "fec9": sum(1 for l in lines if l.startswith("bpset 0xfec9,")),
        "5cd0": sum(1 for l in lines if l.startswith("bpset 0x5cd0,")),
        "fecc": sum(1 for l in lines if l.startswith("bpset 0xfecc,")),
        "fece": sum(1 for l in lines if l.startswith("bpset 0xfece,")),
        "wpset": sum(1 for l in lines if l.startswith("wpset ")),
    }
    structure = (
        allowed and not forbidden
        and counts == {"fc": 1, "fec3": 1, "fec6": 1, "fec9": 1, "5cd0": 1,
                       "fecc": 2, "fece": 2, "wpset": 2}
    )
    add(
        "debugger-structure",
        structure,
        "only breakpoints/watchpoints/trace/save/quit actions; no memory/state injection",
    )
    add("exit-code", doc.get("exitCode") == 0, "MAME exit 0")
    add(
        "trace-count",
        0 < trace.get("count", 0) <= trace.get("traceLines", 0) <= int(prov.get("instruction_cap", 0))
        and trace.get("count") == len(rows),
        "bounded instruction trace; parsed rows, raw trace lines and instruction cap agree",
    )

    def cyc(name):
        return int(boundaries.get(name, {}).get("cyc", "FFFFFFFFFFFFFFFF"), 16)

    def sval(name):
        return int(boundaries.get(name, {}).get("s", "FFFF"), 16)

    fec3 = boundaries.get("fec3", {})
    occ_ok = (
        trace.get("first") is not None
        and trace["first"].get("pc") == "6B4D"
        and trace["first"].get("cyc") is not None
        and int(trace["first"]["cyc"], 16) == cyc("fec3") + 8
        and trace["first"].get("op", "")[:4] == "0D83"
        and cyc("fec3") < cyc("fec6") < cyc("fec9") < cyc("sv") < cyc("fecc") < cyc("fece")
    )
    add("trace-occurrence", occ_ok, "first selected 6B4D is 8 cycles after FEC3; boundary order holds")

    with zipfile.ZipFile(ROMS / "m4addr.zip") as z:
        rom_bytes = z.read("a6ls.p1")
    opcode_ok = bool(rows)
    intervals_ok = bool(rows)
    prev = None
    for r in rows:
        try:
            pc = int(r.get("pc", ""), 16)
            op = bytes.fromhex(r.get("op", ""))
            cy = int(r.get("cyc", ""), 16)
        except ValueError:
            opcode_ok = False
            intervals_ok = False
            continue
        opcode_ok = opcode_ok and 0 <= pc < len(rom_bytes) and rom_bytes[pc:pc + 4] == op
        if prev is not None:
            intervals_ok = intervals_ok and cy > prev
        prev = cy
    add("trace-opcode", opcode_ok, "every trace row PC/opcode matches actual ROM bytes")
    add("trace-interval", intervals_ok, "trace cycles are strictly increasing (positive intervals)")

    add(
        "boundary-set",
        all(k in boundaries for k in BOUNDARY_FILES),
        "FC, FEC3, FEC6, FEC9, 5CD0, matched FECC and FECE boundaries present",
    )

    file_ok = True
    file_detail = []
    for k, fname in BOUNDARY_FILES.items():
        b = boundaries.get(k, {})
        p = run / b.get("file", "")
        ok = p.exists() and p.stat().st_size == 2048 and b.get("fileBytes") == 2048
        ok = ok and b.get("fileSha256") == sha_bytes(p.read_bytes()) if p.exists() else False
        if not ok:
            file_detail.append(k)
        file_ok = file_ok and ok
    add("boundary-files", file_ok, "full 2KB files for FC/FEC3/FEC6/FEC9/5CD0/FECC/FECE"
        + ("" if file_ok else f"; missing/tampered: {','.join(file_detail)}"))

    rom_ok = True
    for k, (_, expected) in ROM_BOUNDARIES.items():
        rom_ok = rom_ok and boundaries.get(k, {}).get("romBytes", "")[:len(expected)] == expected
    add("boundary-rom", rom_ok, "actual ROM bytes at every boundary and service instruction")

    def file_word(name, offset):
        p = run / BOUNDARY_FILES[name]
        if not p.exists():
            return None
        data = p.read_bytes()
        addr = sval(name) + offset
        if addr < 0 or addr + 1 >= len(data):
            return None
        return f"{u16(data, addr):04X}"

    entry_s = int(doc.get("entryS", "FFFF"), 16)
    sv_s = sval("sv")
    stack_ok = (
        sval("fec6") == entry_s
        and boundaries.get("fec6", {}).get("returnWord") == "FEC6"
        and file_word("fec6", -2) == "FEC6"
        and sval("fec9") == entry_s
        and boundaries.get("fec9", {}).get("returnWord") == "FEC9"
        and file_word("fec9", -2) == "FEC9"
        and sv_s == entry_s - 2
        and boundaries.get("sv", {}).get("returnWord") == "FECC"
        and file_word("sv", 0) == "FECC"
        and sval("fecc") == sv_s + 2 == entry_s
        and boundaries.get("fecc", {}).get("returnWord") == "FECC"
        and file_word("fecc", -2) == "FECC"
        and sval("fece") == entry_s
        and cyc("fece") - cyc("fecc") == 6
        and cyc("fecc") > cyc("sv")
    )
    add(
        "boundary-stack-match",
        stack_ok,
        "entryS/return-word/depth/cycle matching; FECC uses S=5CD0entryS+2 and word FECC, not PC alone",
    )

    host_ok = True
    for k in BOUNDARY_FILES:
        b = boundaries.get(k, {})
        host_ok = host_ok and re.fullmatch(r"[0-9A-F]{2}", b.get("host44", "")) is not None
        host_ok = host_ok and re.fullmatch(r"[0-9A-F]{2}", b.get("guard83", "")) is not None
        host_ok = host_ok and re.fullmatch(r"[0-9A-F]{2}", b.get("q719b", "")) is not None
        if b.get("byte44") is not None:
            host_ok = host_ok and b.get("host44") == b.get("byte44")
        if b.get("byte83") is not None:
            host_ok = host_ok and b.get("guard83") == b.get("byte83")
    host_ok = host_ok and host44_consistent(doc)
    add(
        "actual-host44-serviceguard-719b",
        host_ok,
        "actual host44/serviceguard(83)/719B recorded and host44/83 agree with full 2KB anchors",
    )

    nested_ok = (
        doc.get("host44AtService") == boundaries.get("sv", {}).get("host44")
        and boundaries.get("fec6", {}).get("s") == doc.get("entryS")
        and boundaries.get("fec9", {}).get("s") == doc.get("entryS")
        and boundaries.get("fecc", {}).get("s") == doc.get("entryS")
        and boundaries.get("fece", {}).get("s") == doc.get("entryS")
        and boundaries.get("sv", {}).get("s") == f"{sv_s:04X}"
        and boundaries.get("fecc", {}).get("returnWord") != "FEC6"
    )
    add("nested-separation", nested_ok, "selected S/depth chain; FECC cannot satisfy the attempt-1 FEC6 word")

    sw = doc.get("stackWrites", [])
    watch_ok = len(sw) <= int(prov.get("event_cap", 0))
    for e in sw:
        try:
            watch_ok = watch_ok and cyc("fec3") <= int(e["cyc"], 16) <= cyc("fece")
            watch_ok = watch_ok and entry_s - 6 <= int(e["s"], 16) <= entry_s
        except (KeyError, ValueError):
            watch_ok = False
    watch_ok = watch_ok and not any(e.get("tag") == "OVERFLOW_stack" for e in sw)
    watch_ok = watch_ok and "s>=temp4-6 && s<=temp4" in doc.get("debuggerText", "")
    add("watch-bounds", watch_ok, "watch limited to selected interval/depth and event cap")

    caps_ok = (
        prov.get("event_cap") == 64
        and prov.get("instruction_cap") == 4096
        and prov.get("hard_timeout_seconds") == 600
        and prov.get("seconds_to_run") == 430
        and "temp5<64" in doc.get("debuggerText", "")
        and len(rows) <= 4096
    )
    add("fixed-caps", caps_ok, "fixed event/instruction/wall caps recorded before launch")

    rule = doc.get("selectionRule", "")
    selection_ok = (
        "return word" in rule
        and "S=5CD0entryS+2" in rule
        and "stack word FECC" in rule
        and "cycle after 5CD0 entry" in rule
        and "no PC-only selection" in rule
        and "no first-FECC flag" in rule
        and "s==temp8+2" in doc.get("debuggerText", "")
        and "w@(s-2)==0xfecc" in doc.get("debuggerText", "")
        and "totalcycles>temp9" in doc.get("debuggerText", "")
    )
    add("selection-rule", selection_ok, "selection explicitly uses entryS/return word/depth/cycle, not PC alone")

    add(
        "no-first-fecc-flag",
        "no first-FECC flag" in rule and "first" not in json.dumps(doc.get("boundaries", {})).lower().replace("first-fecc", ""),
        "selection uses S/word/depth/cycle, not a first-FECC flag",
    )

    last = trace.get("last") or {}
    add(
        "trace-stop",
        last.get("pc") == "FECE"
        and last.get("cyc") == boundaries.get("fece", {}).get("cyc")
        and last.get("s") == boundaries.get("fece", {}).get("s")
        and not any(e.get("tag") in ("FECC_OTHER", "FECE_OTHER", "OVERFLOW_stack") for e in parse_events((run / "debug.log").read_text(encoding="utf-8", errors="replace"))),
        "trace stops at the matched FECE; no mismatch/overflow stop",
    )

    add(
        "service-path-classification",
        bool(doc.get("pathClass"))
        and (boundaries.get("sv", {}).get("host44") == doc.get("host44AtService"))
        and (
            (boundaries.get("sv", {}).get("host44") == "00" and "zero-guard service body" in doc.get("pathClass", ""))
            or (boundaries.get("sv", {}).get("host44") != "00" and "guard-return path" in doc.get("pathClass", ""))
        ),
        "5CD0 guard 44 is reported as observed, not synthesized",
    )

    attempt1 = ATTEMPT1.exists() and read_json(ATTEMPT1)
    add(
        "preserved-attempt1",
        bool(attempt1)
        and attempt1.get("attempt") == 1
        and "incomplete" in attempt1.get("classification", "").lower(),
        "capture-56 attempt-1 fixture remains present and explicitly incomplete",
    )

    return checks


def host44_consistent(doc):
    b = doc.get("boundaries", {}).get("sv", {})
    return bool(b.get("host44")) and b.get("host44") == doc.get("host44AtService")


def run_controls(doc):
    controls = []

    def check(name, mutate, expected):
        trial = copy.deepcopy(doc)
        mutate(trial)
        failed = [c["id"] for c in validate(trial) if not c["pass"]]
        controls.append({
            "name": name, "expectedFailure": expected,
            "passed": expected in failed, "failedIds": failed,
        })

    check("wrong-s", lambda d: d["boundaries"]["fec6"].__setitem__("s", f"{int(d['entryS'], 16) + 2:04X}"), "boundary-stack-match")
    check("wrong-return", lambda d: d["boundaries"]["fec6"].__setitem__("returnWord", "FEC9"), "boundary-stack-match")
    check("missing-boundary-file", lambda d: d["boundaries"]["fec9"].__setitem__("file", "missing.bin"), "boundary-files")
    check("missing-fecc-file", lambda d: d["boundaries"]["fecc"].__setitem__("file", "missing.bin"), "boundary-files")
    check("wrong-fecc-stack-word", lambda d: d["boundaries"]["fecc"].__setitem__("returnWord", "FEC6"), "boundary-stack-match")
    check("wrong-fecc-s", lambda d: d["boundaries"]["fecc"].__setitem__("s", d["boundaries"]["sv"]["s"]), "boundary-stack-match")
    check("wrong-fece-return", lambda d: d["boundaries"]["fece"].__setitem__("s", d["boundaries"]["sv"]["s"]), "boundary-stack-match")
    check("wrong-fece-cycle", lambda d: d["boundaries"]["fece"].__setitem__("cyc", d["boundaries"]["fecc"]["cyc"]), "boundary-stack-match")
    check("opcode", lambda d: d["boundaries"]["fec3"].__setitem__("romBytes", "BD6B4E"), "boundary-rom")
    check("trace-opcode", lambda d: d["trace"]["rows"][0].__setitem__("op", "FFFFFFFF"), "trace-opcode")
    check("host44", lambda d: d["boundaries"]["fecc"].__setitem__("host44", "01"), "actual-host44-serviceguard-719b")
    check("guard83", lambda d: d["boundaries"]["sv"].__setitem__("guard83", "00"), "actual-host44-serviceguard-719b")
    check("719b", lambda d: d["boundaries"]["sv"].__setitem__("q719b", "ZZ"), "actual-host44-serviceguard-719b")
    check("exit", lambda d: d.__setitem__("exitCode", 1), "exit-code")
    check("source", lambda d: d["provenance"].__setitem__("source_input_lua_sha256", "00"), "source-hashes")
    check("tampered-debugger", lambda d: d.__setitem__("debuggerText", d["debuggerText"] + "\nset 0x44=1"), "debugger-structure")
    check("trace-overflow", lambda d: d["trace"].__setitem__("count", int(d["provenance"]["instruction_cap"]) + 1), "trace-count")
    check("watch-s", lambda d: d["stackWrites"][0].__setitem__("s", f"{int(d['entryS'], 16) + 2:04X}"), "watch-bounds")
    check("watch-overflow", lambda d: d["stackWrites"].append({"tag": "OVERFLOW_stack", "cyc": d["boundaries"]["fece"]["cyc"], "s": d["entryS"]}), "watch-bounds")
    check("trace-stop", lambda d: d["trace"]["last"].__setitem__("pc", "FECC"), "trace-stop")
    check("pc-only-fecc", lambda d: d.__setitem__("selectionRule", "FECC selected by PC only"), "selection-rule")
    check("arguments", lambda d: d["arguments"].append("-state"), "arguments-isolation")
    check("fixed-caps", lambda d: d["provenance"].__setitem__("event_cap", 1024), "fixed-caps")
    return controls


def manifest(include_result=True):
    entries = [
        "tools/Curate-Capture57Evidence.py",
        "evidence/mpu4/collection/irq-suffix-capture57.json",
        "evidence/mpu4/collection/irq-suffix-capture56-attempt1.json",
        "artifacts/deepseek/capture-57/validation.json",
        "artifacts/deepseek/capture-57/negative-controls.json",
    ]
    if include_result and (OUT / "result.md").exists():
        entries.append("artifacts/deepseek/capture-57/result.md")
    if (OUT / "worker-report.md").exists():
        entries.append("artifacts/deepseek/capture-57/worker-report.md")
    entries += [
        "artifacts/deepseek/capture-57/natural-irq-suffix/fc4d.bin",
        "artifacts/deepseek/capture-57/natural-irq-suffix/fec3.bin",
        "artifacts/deepseek/capture-57/natural-irq-suffix/fec6.bin",
        "artifacts/deepseek/capture-57/natural-irq-suffix/fec9.bin",
        "artifacts/deepseek/capture-57/natural-irq-suffix/sv.bin",
        "artifacts/deepseek/capture-57/natural-irq-suffix/fecc.bin",
        "artifacts/deepseek/capture-57/natural-irq-suffix/fece.bin",
        "artifacts/deepseek/capture-57/natural-irq-suffix/debug.log",
        "artifacts/deepseek/capture-57/natural-irq-suffix/routine.trace",
        "artifacts/deepseek/capture-57/natural-irq-suffix/debugger.cmd",
        "artifacts/deepseek/capture-57/natural-irq-suffix/arguments.json",
        "artifacts/deepseek/capture-57/natural-irq-suffix/provenance.json",
        "artifacts/deepseek/capture-57/natural-irq-suffix/exit-code.txt",
        "artifacts/deepseek/capture-57/natural-irq-suffix/trace-lines.txt",
        "artifacts/deepseek/capture-57/natural-irq-suffix/input.lua",
        "artifacts/deepseek/capture-57/natural-irq-suffix/replay-actions.csv",
        "artifacts/deepseek/capture-57/natural-irq-suffix/console.txt",
        "artifacts/deepseek/capture-57/natural-irq-suffix/stderr.txt",
    ]
    rows = []
    for rel in entries:
        p = ROOT / rel
        if not p.exists():
            rows.append({"path": rel, "bytes": None, "sha256": None, "exists": False})
            continue
        rows.append({
            "path": rel, "bytes": p.stat().st_size, "sha256": sha(p), "exists": True,
        })
    write_json(OUT / "manifest.json", rows)
    check = {"pass": True, "entries": []}
    for row in rows:
        p = ROOT / row["path"]
        ok = row["exists"] and p.exists() and p.stat().st_size == row["bytes"] and sha(p) == row["sha256"]
        check["entries"].append({"path": row["path"], "pass": ok})
        check["pass"] = check["pass"] and ok
    write_json(OUT / "manifest-check.json", check)
    return check


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--prove-fail-closed", action="store_true")
    ap.add_argument("--finalize", action="store_true")
    args = ap.parse_args()

    doc = build()
    if args.prove_fail_closed:
        trial = copy.deepcopy(doc)
        trial["boundaries"]["fecc"]["returnWord"] = "FEC6"
        checks = validate(trial)
        controls = run_controls(trial)
        failed = [c["id"] for c in checks if not c["pass"]]
        print(json.dumps({
            "validationPass": all(c["pass"] for c in checks),
            "failed": failed,
            "controlsPass": all(c["passed"] for c in controls),
            "note": "deliberate invalid positive evidence; process must exit non-zero",
        }, indent=2))
        return 1 if failed else 0

    checks = validate(doc)
    controls = run_controls(doc)
    validation_pass = all(c["pass"] for c in checks)
    controls_pass = all(c["passed"] for c in controls)

    write_json(OUT / "validation.json", {"pass": validation_pass, "checks": checks})
    write_json(OUT / "negative-controls.json", {"pass": controls_pass, "cases": controls})
    if validation_pass and controls_pass:
        write_json(FIXTURE, doc)
    mcheck = manifest(include_result=True)
    all_pass = validation_pass and controls_pass and mcheck["pass"]
    print(json.dumps({
        "validationPass": validation_pass,
        "failed": [c["id"] for c in checks if not c["pass"]],
        "controlsPass": controls_pass,
        "failedControls": [c["name"] for c in controls if not c["passed"]],
        "manifestPass": mcheck["pass"],
        "fixtureWritten": validation_pass and controls_pass,
        "traceCount": doc["trace"]["count"],
        "entryS": doc["entryS"],
        "serviceEntryS": doc["serviceEntryS"],
        "host44AtService": doc["host44AtService"],
        "traceLast": doc["trace"]["last"],
    }, indent=2))
    return 0 if all_pass else 1


if __name__ == "__main__":
    sys.exit(main())
