#!/usr/bin/env python3
"""Validate the capture-61 IRQ prefix boundary run and curate its fixture.

Positive evidence must be valid or this process exits non-zero, even when every
negative control passes. The negative controls mutate only in-memory copies.
"""
import argparse
import copy
import csv
import hashlib
import json
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RUN = ROOT / "artifacts/deepseek/capture-61/natural-irq-prefix"
OUT = ROOT / "artifacts/deepseek/capture-61"
FIXTURE = ROOT / "evidence/mpu4/collection/irq-prefix-capture61.json"
SOURCE = ROOT / "artifacts/deepseek/gate-28/natural-service"
MAME = Path(r"E:\Arcade\MAME0266\mame281.exe")
ROMS = Path(r"E:\Arcade\MAME0266\roms")
TIMER_ROOT = Path(r"C:\projects\GitRepos\mame")

INPUT_SHA = "7C664323A5725E9FB294CB201B17B855564AF2E4A500560ED499F1EE45179D0D"
REPLAY_SHA = "4A051DA15264842697879EFF396B34A789F5D80623F9A2E749C244E6A80E721D"
MAME_SHA = "0FCE5A88DF4F9D9B1FBF1405812C00848036E615993780978D967DA34204CB7A"
ROM_SHA1 = "402D1518BB78FDC489B06C2AABC771E5CE151847"
ROM_SHA256 = "EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C"
ZIP_SHA = "E2553AFA6B8E9DEF55BD920E4BED77A4324696C1E358B73BE70BFD2C58179989"
TIMER_SOURCES = {
    "src/devices/machine/6840ptm.cpp": "BF485C444CA2A22FA0659F7BF5E8C15B80F34203B86718BA52FD71D2C28EC55C",
    "src/devices/machine/6840ptm.h": "36649A534EDE34CA10483A9DEBBABE18446635466BE59C63168AA38B7FB59770",
    "src/mame/barcrest/mpu4.cpp": "E37D7E55078E40C058AF91E9C745A5E10239B19BA01CEC570FEB66587A4EABDB",
    "src/mame/barcrest/mpu4.h": "0BFF1FB38135E215F96C7ACEB6089916CC7F6F982342FCBDDF4CA4C0C4CD3DFA",
}
FILES = {
    "fc": "fc4d.bin", "outer": "fe70.bin", "nested": "fe70_nested.bin",
    "return": "ff13.bin", "fec3": "fec3.bin", "fece": "fece.bin",
}
ANCHOR_TAGS = (
    "FC", "OUTER_FE70", "NESTED_FE70", "NESTED_RETURN", "GUARD_2851",
    "GUARD_1400_RTS", "FEC3_ENTRY", "FECE_SUFFIX",
)
BAD_TAG_PREFIXES = ("UNSUPPORTED", "OVERFLOW")


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


def ints(text):
    return int(text, 16)


def parse_events(text):
    events = []
    for line in text.splitlines():
        m = re.match(r"^([A-Z0-9_]+)\s+(.*)$", line)
        if not m:
            continue
        tag, rest = m.group(1), m.group(2)
        if tag in ANCHOR_TAGS or tag == "SW" or tag.startswith(BAD_TAG_PREFIXES):
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
            "cyc": int(m.group(1), 16), "a": m.group(2).upper(), "b": m.group(3).upper(),
            "x": m.group(4).upper(), "y": m.group(5).upper(), "u": m.group(6).upper(),
            "s": m.group(7).upper(), "cc": m.group(8).upper(), "op": m.group(9).upper(),
            "pc": m.group(10).upper(), "text": m.group(11).strip(),
        })
    return rows


def parse_ptm(path):
    with open(path, newline="", encoding="ascii") as f:
        return list(csv.DictReader(f))


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
        "-cfg_directory", str(run / "cfg"), "-nvram_directory", str(run / "nvram"),
        "-input_directory", str(run / "inp"), "-snapshot_directory", str(run / "snap"),
        "-comment_directory", str(run / "comments"), "-state_directory", str(run / "state"),
        "-diff_directory", str(run / "diff"), "-autoboot_delay", "0",
        "-autoboot_script", str(run / "input.lua"), "-debug", "-debugger", "windows",
        "-debugscript", str(run / "debugger.cmd"), "-debuglog", "-video", "none",
        "-sound", "none", "-window", "-skip_gameinfo", "-nothrottle",
        "-seconds_to_run", "430",
    ]


def build():
    prov = read_json(RUN / "provenance.json")
    args = read_json(RUN / "arguments.json")
    exit_code = int((RUN / "exit-code.txt").read_text(encoding="ascii").strip())
    debugger_text = (RUN / "debugger.cmd").read_text(encoding="ascii")
    debug_log = (RUN / "debug.log").read_text(encoding="utf-8", errors="replace")
    events = parse_events(debug_log)
    trace = parse_trace(RUN / "routine.trace")
    ptm = parse_ptm(RUN / "ptm-state.csv")
    trace_lines = int((RUN / "trace-lines.txt").read_text(encoding="ascii").strip())
    with zipfile.ZipFile(ROMS / "m4addr.zip") as z:
        rom = z.read("a6ls.p1")

    by_tag = {}
    for e in events:
        by_tag.setdefault(e["tag"], []).append(e)

    def event(tag):
        return by_tag.get(tag, [None])[0]

    def boundary(name, tag):
        e = event(tag)
        row = {"source": "trace-and-full-2KB" if e else "missing", "tag": tag}
        if e:
            row.update({k: e.get(k, "") for k in (
                "pc", "cyc", "s", "u", "x", "y", "a", "b", "dp", "cc",
                "twoC", "m44", "m6b", "m29", "w1400", "q719b", "q719c",
                "r2", "r0", "s0", "s2", "s4")})
        p = RUN / FILES[name]
        if p.exists():
            data = p.read_bytes()
            row.update({"file": FILES[name], "fileBytes": len(data),
                        "fileSha256": sha_bytes(data)})
            if len(data) >= 0x800:
                for off, key in ((0x2c, "twoC"), (0x44, "m44"), (0x6b, "m6b"),
                                 (0x29, "m29"), (0x719b, "q719b"), (0x719c, "q719c")):
                    if off < len(data):
                        row[key + "File"] = f"{data[off]:02X}"
                s = int(row.get("s", "0"), 16)
                if 0 <= s - 2 < len(data) - 1:
                    row["wordAtS"] = f"{(data[s] << 8) | data[s + 1]:04X}"
                if 0 <= s - 4 < len(data) - 1:
                    row["wordAtSMinus2"] = f"{(data[s - 2] << 8) | data[s - 1]:04X}"
        return row

    def boundary_word(name, offset):
        p = RUN / FILES[name]
        if not p.exists():
            return None
        data = p.read_bytes()
        e = event(ANCHOR_TAG[name])
        if not e:
            return None
        addr = int(e["s"], 16) + offset
        if addr < 0 or addr + 1 >= len(data):
            return None
        return f"{(data[addr] << 8) | data[addr + 1]:04X}"

    ANCHOR_TAG = {"fc": "FC", "outer": "OUTER_FE70", "nested": "NESTED_FE70",
                  "return": "NESTED_RETURN", "fec3": "FEC3_ENTRY", "fece": "FECE_SUFFIX"}
    boundaries = {name: boundary(name, tag) for name, tag in ANCHOR_TAG.items()}
    for name, off in (("outer", 0), ("nested", 0), ("return", 0), ("fec3", -2)):
        b = boundaries[name]
        b["matchedWord"] = boundary_word(name, off)
        b["matchedWordOffset"] = off

    ptm_rows = {r["event"]: r for r in ptm}
    trace_out = []
    prev = None
    for r in trace:
        trace_out.append({
            "pc": r["pc"], "cyc": f"{r['cyc']:016X}",
            "interval": None if prev is None else f"{r['cyc'] - prev:08X}",
            "a": r["a"], "b": r["b"], "x": r["x"], "y": r["y"],
            "u": r["u"], "s": r["s"], "cc": r["cc"], "op": r["op"], "text": r["text"],
        })
        prev = r["cyc"]

    return {
        "schema": "fruitmachinelab.mpu4.irq-prefix-capture61/v1",
        "classification": (
            "trace-backed fresh IRQ prefix boundary from one controlled original-reset "
            "physical-input replay occurrence: full 2KB outer FE70 before its first "
            "instruction, nested timer3 entry/return, guard 1400 RTS, FEC3 snapshot, "
            "actual PTM saved-item state and bounded FE70->FEC3 instruction trace"
        ),
        "run": str(RUN.relative_to(ROOT)).replace("\\", "/"),
        "selectionRule": (
            "fresh first FC4D window; outer FE70 is the first FE70 after it; nested FE70 "
            "is the next FE70; FF13 is the nested return; guard RTS at 288E must be "
            "taken; FEC3 entry requires S=outerS, w@s=outer return word and "
            "w@(s-2)=FEC3; no old absolute cycles or historical fitting"
        ),
        "provenance": prov,
        "arguments": args,
        "exitCode": exit_code,
        "debuggerText": debugger_text,
        "boundaries": boundaries,
        "ptm": {"rows": ptm, "byEvent": ptm_rows},
        "trace": {
            "count": len(trace), "traceLines": trace_lines,
            "first": trace_out[0] if trace_out else None,
            "last": trace_out[-1] if trace_out else None,
            "rows": trace_out,
        },
        "rom": {
            "entry": "a6ls.p1", "bytes": len(rom), "sha1": sha_bytes(rom, "sha1"),
            "sha256": sha_bytes(rom), "zipSha256": sha(ROMS / "m4addr.zip"),
        },
        "limits": [
            "One matched occurrence only; this proves a captured prefix boundary, not the whole IRQ or autonomous cadence.",
            "m_counter is MAME's saved reload/frozen counter field, not a continuously decremented register; remaining timer ticks are not exposed and are not inferred.",
            "No RAM/register/PTM/ACK/end-state/input injection, no reseeding, no historical cycle fitting.",
            "No active 6403, 4167, non-19B8 C6, SWI, 7CCF, Live, audio, hardware or gate-3 claim.",
        ],
    }


def validate(doc):
    checks = []

    def add(cid, ok, detail):
        checks.append({"id": cid, "pass": bool(ok), "detail": detail})

    prov = doc.get("provenance", {})
    run = ROOT / doc.get("run", "")
    b = doc.get("boundaries", {})
    t = doc.get("trace", {})
    rows = t.get("rows", [])
    ptm = doc.get("ptm", {}).get("byEvent", {})
    rom = doc.get("rom", {})

    add("source-hashes",
        sha(SOURCE / "input.lua") == INPUT_SHA
        and sha(SOURCE / "replay-actions.csv") == REPLAY_SHA
        and prov.get("source_input_lua_sha256") == INPUT_SHA
        and prov.get("source_replay_actions_sha256") == REPLAY_SHA,
        "pinned campaign input/replay hashes")

    patched = apply_input_patch((SOURCE / "input.lua").read_text(encoding="utf-8", newline=""))
    derived = (run / "input.lua").read_text(encoding="utf-8", newline="")
    tail = derived[len(patched):]
    add("input-derivation",
        derived.startswith(patched)
        and sha(run / "input.lua") == prov.get("derived_input_lua_sha256")
        and tail.lstrip("\r\n").startswith("-- Capture61 read-only PTM saved-item observer")
        and "install_write_tap" not in tail and "set_value" not in tail
        and "write_u8" not in tail and "write_u16" not in tail,
        "only declared startup patch plus read-only PTM observer; no appended injection")

    add("mame-hash", MAME.exists() and sha(MAME) == MAME_SHA and prov.get("mame_sha256") == MAME_SHA,
        "pinned MAME 0.281 sha256")
    add("rom", rom.get("bytes") == 65536 and rom.get("sha1") == ROM_SHA1
        and rom.get("sha256") == ROM_SHA256 and rom.get("zipSha256") == ZIP_SHA,
        "actual ROM entry, ROM sha1/sha256 and zip sha256")
    add("arguments-isolation", doc.get("arguments") == expected_arguments(run),
        "exact isolated MAME argument array; no state/playback/record input")
    add("debugger-hash", (run / "debugger.cmd").exists()
        and sha(run / "debugger.cmd") == prov.get("debugger_sha256"), "debugger.cmd sha256")

    lines = [l.strip() for l in doc.get("debuggerText", "").splitlines() if l.strip()]
    allowed = all(re.match(r"^(temp[0-9]=0|bpset |wpset |go$|quit$)", l) for l in lines)
    forbidden = any(re.search(r"(^|[;\s])(set|write|load|restore|playback|record|fill|paste|rompatch)([;\s]|$)", l, re.I)
                    for l in lines)
    counts = {k: sum(1 for l in lines if l.startswith(k)) for k in (
        "bpset 0xfc,", "bpset 0xfe70,", "bpset 0xff13,", "bpset 0x2851,",
        "bpset 0x288e,", "bpset 0xfec3,", "bpset 0xfece,", "bpset 0x288f,",
        "bpset 0x6407,", "bpset 0x439a,", "bpset 0x4167,", "bpset 0x7ccf,", "wpset ")}
    structure = allowed and not forbidden and counts == {
        "bpset 0xfc,": 1, "bpset 0xfe70,": 2, "bpset 0xff13,": 1,
        "bpset 0x2851,": 1, "bpset 0x288e,": 1, "bpset 0xfec3,": 2,
        "bpset 0xfece,": 1, "bpset 0x288f,": 1, "bpset 0x6407,": 1,
        "bpset 0x439a,": 1, "bpset 0x4167,": 1, "bpset 0x7ccf,": 1, "wpset ": 2}
    saves = sum(1 for l in lines if "save " in l)
    watch_guarded = all("temp6==1" in l and "temp7==0" in l
                        for l in lines if l.startswith("wpset "))
    add("debugger-structure", structure and saves == 6 and watch_guarded,
        "breakpoints/watchpoint/2KB saves/trace only; no memory/state injection; watch only after FEC3")
    add("exit-code", doc.get("exitCode") == 0, "MAME exit 0")
    add("trace-count", 0 < t.get("count", 0) <= t.get("traceLines", 0)
        <= int(prov.get("instruction_cap", 0)) and t.get("count") == len(rows),
        "bounded trace; parsed rows, raw lines and instruction cap agree")
    add("fixed-caps", prov.get("event_cap") == 256 and prov.get("instruction_cap") == 16384
        and prov.get("hard_timeout_seconds") == 600 and prov.get("seconds_to_run") == 430
        and "temp4<256" in doc.get("debuggerText", "") and len(rows) <= 16384,
        "fixed event/instruction/wall caps recorded before launch")

    add("timer-source-hashes",
        all((TIMER_ROOT / rel).exists() and sha(TIMER_ROOT / rel) == h
            and prov.get("timer_source_sha256", {}).get(rel) == h
            for rel, h in TIMER_SOURCES.items())
        and prov.get("timer_source_root") == str(TIMER_ROOT),
        "actual local MAME source hashes for saved-item names/semantics")

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
            opcode_ok = intervals_ok = False
            continue
        opcode_ok = opcode_ok and 0 <= pc < len(rom_bytes) and rom_bytes[pc:pc + 4] == op
        if prev is not None:
            intervals_ok = intervals_ok and cy > prev
        prev = cy
    add("trace-opcode", opcode_ok, "every trace row PC/opcode matches actual ROM bytes")
    add("trace-interval", intervals_ok, "trace cycles are strictly increasing")

    bad = [e for e in parse_events((run / "debug.log").read_text(encoding="utf-8", errors="replace"))
           if e["tag"].startswith(BAD_TAG_PREFIXES)]
    add("no-unsupported-stop", not bad, "no SWI2/active6403/non-19B8 C6/4167/7CCF/overflow stop")

    names = ["fc", "outer", "nested", "return", "fec3", "fece"]
    add("boundary-set", all(n in b and b[n].get("tag") for n in names),
        "FC, outer/nested FE70, FF13 return, FEC3 and FECE anchors present")

    file_ok = True
    for n in names:
        p = run / b[n].get("file", "")
        file_ok = file_ok and p.exists() and p.stat().st_size == 2048
        file_ok = file_ok and b[n].get("fileBytes") == 2048
        file_ok = file_ok and b[n].get("fileSha256") == sha_bytes(p.read_bytes()) if p.exists() else False
    add("boundary-files", file_ok, "full 2KB files at every boundary")

    try:
        outer_s = ints(b["outer"]["s"])
        outer_ret = ints(b["outer"]["r0"])
        nested_s = ints(b["nested"]["s"])
        return_s = ints(b["return"]["s"])
        fec3_s = ints(b["fec3"]["s"])
        fec3_ret = ints(b["fec3"]["r0"])
    except (KeyError, ValueError):
        outer_s = outer_ret = nested_s = return_s = fec3_s = fec3_ret = -1
    cyc = {n: ints(b[n]["cyc"]) for n in names}
    stack_ok = (
        b["outer"].get("matchedWord") == b["outer"].get("r0")
        and b["nested"].get("matchedWord") == b["nested"].get("r0")
        and b["return"].get("matchedWord") == b["return"].get("r0")
        and b["fec3"].get("matchedWord") == "FEC3"
        and b["fec3"].get("r2") == "FEC3"
        and nested_s < outer_s and return_s == nested_s and fec3_s == outer_s
        and fec3_ret == outer_ret
        and cyc["fc"] < cyc["outer"] < cyc["nested"] < cyc["return"]
        < cyc["fec3"] < cyc["fece"]
    )
    add("matched-stack-depth-return-cycle", stack_ok,
        "fresh stack/depth/return-word/cycle identity, not PC alone; no old cycle comparison")

    def hx(name, key):
        return ints(b[name].get(key, "X"))

    add("selected-host-state",
        hx("outer", "m44") == 0 and hx("outer", "m6b") == 0
        and (hx("outer", "m29") & 3) != 0 and hx("outer", "w1400") != 0
        and hx("fec3", "twoC") == 0xFF and hx("fec3", "m44") == 0
        and hx("fec3", "m6b") == 0 and (hx("fec3", "m29") & 3) != 0
        and hx("fec3", "w1400") != 0
        and b["outer"].get("twoCFile") == b["outer"].get("twoC")
        and b["fec3"].get("twoCFile") == "FF"
        and b["fec3"].get("m44File") == "00" and b["fec3"].get("m6bFile") == "00"
        and b["fec3"].get("q719b") is not None,
        "2C/44/6B/29/1400/719B/719C actual state; FEC3 has 2C=FF, 44=00, 6B=00, 29&3!=0, 1400!=0")

    add("guard-1400-rts",
        "GUARD_1400_RTS" in [e["tag"] for e in parse_events((run / "debug.log").read_text(encoding="utf-8", errors="replace"))]
        and any(r["pc"] == "288E" and int(r["cyc"], 16) < cyc["fec3"] for r in rows)
        and hx("fec3", "w1400") != 0,
        "static 2851..288E tail actually takes the 1400 nonzero RTS path")

    ptm_order = ["outer", "nested", "nested_return", "fec3"]
    ptm_ok = all(k in ptm for k in ptm_order)
    if ptm_ok:
        times = [int(ptm[k]["seconds"]) * 10**18 + int(ptm[k]["attoseconds"]) for k in ptm_order]
        ptm_ok = all(times[i] < times[i + 1] for i in range(3))
        ptm_ok = ptm_ok and ptm["outer"]["pc"] == "FE71" and ints(ptm["outer"]["s"]) == outer_s
        ptm_ok = ptm_ok and ptm["outer"]["cc"] == b["outer"]["cc"]
        ptm_ok = ptm_ok and ptm["nested"]["pc"] == "FE71" and ints(ptm["nested"]["s"]) == nested_s
        ptm_ok = ptm_ok and ptm["nested"]["cc"] == b["nested"]["cc"]
        ptm_ok = ptm_ok and ptm["nested_return"]["pc"] == "FF14" and ints(ptm["nested_return"]["s"]) == return_s
        ptm_ok = ptm_ok and ptm["nested_return"]["cc"] == b["return"]["cc"]
        ptm_ok = ptm_ok and ptm["fec3"]["pc"] == "FEC4" and ints(ptm["fec3"]["s"]) == fec3_s
        ptm_ok = ptm_ok and ptm["fec3"]["cc"] == b["fec3"]["cc"]
        for k in ptm_order:
            for field in ("output3", "control3", "latch3", "counter3", "status", "irq"):
                ptm_ok = ptm_ok and int(ptm[k][field]) >= 0
        ptm_ok = ptm_ok and (int(ptm["nested"]["status"]) & 0x04) != 0
        ptm_ok = ptm_ok and int(ptm["nested"]["enabled3"]) == 1
        ptm_ok = ptm_ok and int(ptm["nested_return"]["enabled3"]) == 0
        ptm_ok = ptm_ok and int(ptm["fec3"]["control3"]) == 0
    add("ptm-timer3-state", ptm_ok,
        "actual PTM saved-item state sampled for the same outer/nested/return/FEC3 occurrence; timer3 pending at nested, disabled on return")

    pcs = [r["pc"] for r in rows]
    def index(pc, start=0):
        for i in range(start, len(pcs)):
            if pcs[i] == pc:
                return i
        return -1
    i_nested = index("FE70")
    i_ff13 = index("FF13")
    i_ret = index("1AA2", i_ff13 + 1)
    i_2851 = index("2851")
    i_288e = index("288E")
    i_fec3 = index("FEC3")
    if i_nested >= 0 and i_ff13 >= 0 and i_fec3 >= 0:
        nested_row, ff13_row, fec3_row = rows[i_nested], rows[i_ff13], rows[i_fec3]
        nested_ok = (int(nested_row["cyc"], 16) == cyc["nested"]
                     and ints(nested_row["s"]) == nested_s
                     and int(ff13_row["cyc"], 16) == cyc["return"]
                     and ints(ff13_row["s"]) == return_s
                     and i_ret > i_ff13
                     and int(rows[i_ret]["cyc"], 16) > int(ff13_row["cyc"], 16)
                     and i_2851 > i_ff13 and i_288e > i_2851 and i_fec3 == len(rows) - 1
                     and int(fec3_row["cyc"], 16) == cyc["fec3"]
                     and ints(fec3_row["s"]) == fec3_s
                     and fec3_row["op"][:8] == "BD6B4DBD")
    else:
        nested_ok = False
    add("trace-nested-entry-return", nested_ok,
        "trace explicitly contains nested FE70 and FF13, resumes at 1AA2, takes 2851/288E, and stops on FEC3")

    add("trace-selected-path",
        all(p in pcs for p in ("438C", "439A", "19B8", "1A87", "FEC3"))
        and not any(p in pcs for p in ("288F", "6407", "4167", "7CCF")),
        "trace contains the selected 438C/439A/19B8/1A87 path and no unsupported branches")

    sw = [e for e in parse_events((run / "debug.log").read_text(encoding="utf-8", errors="replace")) if e["tag"] == "SW"]
    add("suffix-watch-bounds", len(sw) <= int(prov.get("event_cap", 0))
        and all(ints(e["cyc"]) >= cyc["fec3"] for e in sw),
        "optional suffix write observation after FEC3 within event cap")

    return checks


def run_controls(doc):
    controls = []

    def check(name, mutate, expected):
        trial = copy.deepcopy(doc)
        mutate(trial)
        failed = [c["id"] for c in validate(trial) if not c["pass"]]
        controls.append({"name": name, "expectedFailure": expected,
                         "passed": expected in failed, "failedIds": failed})

    check("wrong-outer-s", lambda d: d["boundaries"]["outer"].__setitem__("s", "078C"), "matched-stack-depth-return-cycle")
    check("wrong-nested-depth", lambda d: d["boundaries"]["nested"].__setitem__("s", d["boundaries"]["outer"]["s"]), "matched-stack-depth-return-cycle")
    check("wrong-return-s", lambda d: d["boundaries"]["return"].__setitem__("s", "0778"), "matched-stack-depth-return-cycle")
    check("wrong-fec3-return-word", lambda d: d["boundaries"]["fec3"].__setitem__("r2", "FEC6"), "matched-stack-depth-return-cycle")
    check("wrong-fec3-2c", lambda d: d["boundaries"]["fec3"].__setitem__("twoC", "00"), "selected-host-state")
    check("wrong-fec3-1400", lambda d: d["boundaries"]["fec3"].__setitem__("w1400", "0000"), "selected-host-state")
    check("missing-outer-file", lambda d: d["boundaries"]["outer"].__setitem__("file", "missing.bin"), "boundary-files")
    check("missing-fec3-file", lambda d: d["boundaries"]["fec3"].__setitem__("file", "missing.bin"), "boundary-files")
    check("missing-ptm-outer", lambda d: d["ptm"]["byEvent"].pop("outer"), "ptm-timer3-state")
    check("wrong-ptm-outer-s", lambda d: d["ptm"]["byEvent"]["outer"].__setitem__("s", "078C"), "ptm-timer3-state")
    check("nested-no-timer3-flag", lambda d: d["ptm"]["byEvent"]["nested"].__setitem__("status", "128"), "ptm-timer3-state")
    check("return-still-enabled", lambda d: d["ptm"]["byEvent"]["nested_return"].__setitem__("enabled3", "1"), "ptm-timer3-state")
    check("trace-missing-ff13", lambda d: d["trace"].__setitem__("rows", [r for r in d["trace"]["rows"] if r["pc"] != "FF13"]), "trace-nested-entry-return")
    check("trace-missing-fec3", lambda d: d["trace"].__setitem__("rows", [r for r in d["trace"]["rows"] if r["pc"] != "FEC3"]), "trace-nested-entry-return")
    check("trace-opcode", lambda d: d["trace"]["rows"][0].__setitem__("op", "FFFFFFFF"), "trace-opcode")
    check("trace-nonmonotonic", lambda d: d["trace"]["rows"][1].__setitem__("cyc", d["trace"]["rows"][0]["cyc"]), "trace-interval")
    check("injected-debugger", lambda d: d.__setitem__("debuggerText", d["debuggerText"] + "\nset 0x44=1"), "debugger-structure")
    check("arguments", lambda d: d["arguments"].append("-state"), "arguments-isolation")
    check("exit", lambda d: d.__setitem__("exitCode", 1), "exit-code")
    check("source", lambda d: d["provenance"].__setitem__("source_input_lua_sha256", "00"), "source-hashes")
    check("timer-source", lambda d: d["provenance"]["timer_source_sha256"].__setitem__("src/devices/machine/6840ptm.cpp", "00"), "timer-source-hashes")
    check("fixed-caps", lambda d: d["provenance"].__setitem__("event_cap", 1024), "fixed-caps")
    return controls


def manifest(include_result=True):
    entries = [
        "tools/Capture-IrqPrefix61.ps1",
        "tools/Curate-Capture61Evidence.py",
        "evidence/mpu4/collection/irq-prefix-capture61.json",
        "artifacts/deepseek/capture-61/validation.json",
        "artifacts/deepseek/capture-61/negative-controls.json",
    ]
    if include_result and (OUT / "result.md").exists():
        entries.append("artifacts/deepseek/capture-61/result.md")
    if (ROOT / "docs/recovery/CAPTURE61-IRQ-PREFIX-BOUNDARY-PASS.md").exists():
        entries.append("docs/recovery/CAPTURE61-IRQ-PREFIX-BOUNDARY-PASS.md")
    entries += [
        "artifacts/deepseek/capture-61/natural-irq-prefix/fc4d.bin",
        "artifacts/deepseek/capture-61/natural-irq-prefix/fe70.bin",
        "artifacts/deepseek/capture-61/natural-irq-prefix/fe70_nested.bin",
        "artifacts/deepseek/capture-61/natural-irq-prefix/ff13.bin",
        "artifacts/deepseek/capture-61/natural-irq-prefix/fec3.bin",
        "artifacts/deepseek/capture-61/natural-irq-prefix/fece.bin",
        "artifacts/deepseek/capture-61/natural-irq-prefix/debug.log",
        "artifacts/deepseek/capture-61/natural-irq-prefix/routine.trace",
        "artifacts/deepseek/capture-61/natural-irq-prefix/ptm-state.csv",
        "artifacts/deepseek/capture-61/natural-irq-prefix/debugger.cmd",
        "artifacts/deepseek/capture-61/natural-irq-prefix/arguments.json",
        "artifacts/deepseek/capture-61/natural-irq-prefix/provenance.json",
        "artifacts/deepseek/capture-61/natural-irq-prefix/exit-code.txt",
        "artifacts/deepseek/capture-61/natural-irq-prefix/trace-lines.txt",
        "artifacts/deepseek/capture-61/natural-irq-prefix/input.lua",
        "artifacts/deepseek/capture-61/natural-irq-prefix/replay-actions.csv",
        "artifacts/deepseek/capture-61/natural-irq-prefix/console.txt",
        "artifacts/deepseek/capture-61/natural-irq-prefix/stderr.txt",
    ]
    rows = []
    for rel in entries:
        p = ROOT / rel
        if not p.exists():
            rows.append({"path": rel, "bytes": None, "sha256": None, "exists": False})
            continue
        rows.append({"path": rel, "bytes": p.stat().st_size, "sha256": sha(p), "exists": True})
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
    ap.add_argument("--prove-fail-closed", action="store_true")
    args = ap.parse_args()

    doc = build()
    if args.prove_fail_closed:
        trial = copy.deepcopy(doc)
        trial["boundaries"]["fec3"]["r2"] = "FEC6"
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
        "outerCycle": doc["boundaries"]["outer"].get("cyc"),
        "fec3Cycle": doc["boundaries"]["fec3"].get("cyc"),
        "outerS": doc["boundaries"]["outer"].get("s"),
        "fec3S": doc["boundaries"]["fec3"].get("s"),
    }, indent=2))
    return 0 if all_pass else 1


if __name__ == "__main__":
    sys.exit(main())


