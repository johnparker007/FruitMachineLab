# Direct native primitive natural execution

Status: **bounded natural fresh-boot MAME 0.281 observation of the exact
compiled direct native primitive; one capture, attempt 1, no rerun. Supervisor accepted the bounded entry/result/return proof with the explicit DP limitation: DP=0 is deduced, not directly measured.** Base commit `6a5ee4d3b5f2264507fd591db610237ce096b4a8`. This
proof follows the reviewed static builder in `il-native-primitive-build-45` and
the corrected task44 ABI. Native C# gameplay remains frozen. No fourth composite
capture was made.

Evidence: `evidence/mpu4/integrity/il-native-primitive-natural.json`.
Private raw run and logs:
`artifacts/deepseek/il-native-primitive-natural-46/run-01/`. The offline audit
task `il-native-primitive-audit-47` re-analysed a byte-preserving copy at
`artifacts/deepseek/il-native-primitive-audit-47/verify-run-01/`; the original
raw run was not edited or rerun.

## Boundary

| Item | Value |
| --- | --- |
| Boundary id | `natural-fresh-boot-native-primitive-1012-observation` |
| Attempt | 1 |
| Token cell | `1010-1011 = 1012` |
| Native handler | `1012-101A = ECC4C38000EDC40EFC` |
| Caller | `9F14-9F15 = 1010` |
| Successor | `9F16-9F17 = 75A9` |
| Entry | `PC=1012`, `X=1012`, `Y=9F16` |
| Control top (parent) | `9F3F` |
| Constants | `U=066E`, `S=0798`, input `0000` |

The pointer cell is explicitly **not** a `00F8` definition header. The handler
contains `LDD ,U`; `ADDD #$8000`; `STD ,U`; `JMP $00FC`, with no
`PSHS`/`PULS` and no `792F` return token. Entry therefore creates no new save
frame and leaves `S=0798`.

## Exact inputs

| Item | SHA256 |
| --- | --- |
| Original ROM `a6ls.p1` | `EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C` |
| Repaired native image | `67E9390B8CD5EB941E1928F5E38129DF265207536002B6304C2A3B413E9B3AA8` |
| Source map | `9BC2112CA0E4B427804BA2FB27F64F52338055F161E631999FD584B4FCD2A8E0` |
| Build report (run copy) | `C0151C9D3828DC207F04B1AA89E59484BFBD102F59F45723358343DF33C6CC87` |
| MAME 0.281 executable | `0FCE5A88DF4F9D9B1FBF1405812C00848036E615993780978D967DA34204CB7A` |
| Tracked replay `actions.csv` | `4A051DA15264842697879EFF396B34A789F5D80623F9A2E749C244E6A80E721D` |
| Tracked `input.lua` | `23099F8888AF8DB353253E0DF97638320DC59CA9A47371723A380E0C4EE85C94` |
| Capture wrapper used for the raw capture | `09119E7BC282BF3150E4426C4DD2C74EC1CAB8673AF30DC871B3803EC57BB5E8` |
| Capture/analysis wrapper after the DP audit | `430440230F7AA4F35A637AAB76BFCFB602FD16A112F08A4DF30AF7587A7410DC` |
| Read-only observer Lua (captured and current) | `5FCE90BD5F6FD18B95C1B57CEED84B606211CFCC94B109C4FD840AE3CAC7487A` |
| Offline verifier used for task46 | `83E0E9F965CC086C03FC467C176F711BDD33B9F988602BA290BF52AB20A54997` |
| Offline verifier after the DP audit | `F935A4E80DBC6A9B5FD878EEBC8D86E1E00403EAB2C10AA9D41B62F99E692BC3` |
| Natural evidence after the DP audit | `20C4470C1C657F14772C4BB48F43DE016D9D85040A9286AFD34A85875DB75A8E` |

The build remains the task45 positive output exactly: 18 changed offsets
(`1010-101A`, `9F14-9F15`, `FFD1-FFD5`), integrity fields
`E93F3C61B5`, original `9ED7`/`9ED9` and guards preserved.

The raw run was captured with wrapper `0911...` above and the unchanged
observer Lua. The audit extended only the offline analyzer and checker, then
re-analysed a byte-preserving copy. The evidence records
`toolChangedAfterCapture=true`, `luaChangedAfterCapture=false`,
`rawArtifactModified=false` and `rerunPerformed=false`; no MAME or Lua process
was started during the audit.

## Capture conditions

- One fresh isolated run directory with absent/empty `cfg`, `nvram`, `inp`,
  `snap`, `comments`, `state` and `diff`; `-noreadconfig`; no read or write of
  existing MAME settings.
- `-debugger imgui`, `-video bgfx`, installed BGFX assets, native debugger
  `bpset` boundaries and the periodic stopped-state driver. No instruction
  hook.
- Existing tracked physical coin/start replay and `input.lua` only. No input
  injection beyond that replay.
- No save-state load/save, PC/register/RAM/ROM write, seeding, synthetic
  invocation or additional input.
- MAME wall `7.093 s`, exit code `0`, not timed out. The isolated run ROM hash
  remained `67E9...`; the state directory was empty.

## Observed phases

All listed `PC`, `X`, `Y`, `U`, `S`, `D`, `CC`, token and stack values are live
native observations, not the source map's static predictions. `DP` is not in
this table and was not sampled by the captured observer; see the DP deduction
below. The map is used only for image binding and boundary addresses. Stack
columns are the data-stack top (`DStk0`) and control-stack top (`CStk0`).

| # | Phase | PC | X | Y | U | S | D | Top | Token (at) | CStk0 | CC |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | caller-prefetch | `00FC` | `0000` | `9F14` | `066E` | `0798` | `0000` | `0000` | `1010` (`9F14`) | `9F3F` | `C4` |
| 1 | direct-handler-entry | `1012` | `1012` | `9F16` | `066E` | `0798` | `0000` | `0000` | `1012` (`1010`) | `9F3F` | `C0` |
| 2 | after-ldd | `1014` | `1012` | `9F16` | `066E` | `0798` | `0000` | `0000` | `1012` (`1010`) | `9F3F` | `C4` |
| 3 | after-addd | `1017` | `1012` | `9F16` | `066E` | `0798` | `8000` | `0000` | `1012` (`1010`) | `9F3F` | `C8` |
| 4 | after-std | `1019` | `1012` | `9F16` | `066E` | `0798` | `8000` | `8000` | `1012` (`1010`) | `9F3F` | `C8` |
| 5 | post-handler-prefetch | `00FC` | `1012` | `9F16` | `066E` | `0798` | `8000` | `8000` | `75A9` (`9F16`) | `9F3F` | `C8` |
| 6 | 75ab-entry | `75AB` | `75AB` | `9F18` | `066E` | `0798` | `8000` | `8000` | `75A9` (`9F16`) | `9F3F` | `C0` |
| 7 | negative-arm | `75B6` | `75AB` | `9F18` | `066E` | `0798` | `8000` | `8000` | `75A9` (`9F16`) | `9F3F` | `C8` |
| 8 | post-75a9 | `00FC` | `75AB` | `9F18` | `066E` | `0798` | `FFFF` | `FFFF` | `7B7D` (`9F18`) | `9F3F` | `C8` |
| 9 | after-swap-drop | `00FC` | `7B3F` | `9F1C` | `0670` | `0798` | `FFFF` | `FFFF` | `792F` (`9F1C`) | `9F3F` | `C0` |
| 10 | return-handler | `7931` | `7931` | `9F1E` | `0670` | `0798` | `FFFF` | `FFFF` | `792F` (`9F1C`) | `9F3F` | `C0` |
| 11 | 9f12-post-return | `00FC` | `7931` | `9F3F` | `0670` | `079A` | `FFFF` | `FFFF` | `792F` (`9F3F`) | `AB44` | `C0` |

Exact transitions that matter:

- The primitive turns input `0000` into `8000` in place. `LDD` leaves the top
  cell `0000`; `ADDD` sets `D=8000` while the top is still `0000`; `STD` makes
  the top `8000`.
- `U` and `S` are unchanged from caller to post-handler. `Y` advances from the
  caller token address `9F14` to `9F16` during dispatch (`Y=C+2`, the next stream
  address), then is unchanged by the primitive handler: entry and post-handler
  are both `Y=9F16`. The control top stays `9F3F` and is not the old composite
  saved cursor `9F16`.
- The successor `75A9` reaches `75AB`, takes the negative arm `75B6`, and
  writes `FFFF`.
- The swap/drop changes `U` to `0670`; the `7931` return saves/restores
  control top `9F3F`; `PULS Y` raises `S` from `0798` to `079A` and restores
  `Y=9F3F`, `token=792F`.
- Net deltas are `U=+0002`, `S=+0002`. `H` was not asserted; CC is recorded
  only as a diagnostic byte.

### DP: static deduction, not a direct measurement

The captured Lua observer did not sample the 6809 `DP` register, so this run
contains **no live `DP` observation**. The supervisor-required `DP=0` is
supported only as a static deduction for this call:

- the built handler is `ECC4C38000EDC40EFC`; its final instruction is `0E FC`
  (`JMP` direct-page with 8-bit target `FC`);
- the live post-handler breakpoint recorded `PC=00FC`;
- a direct-page `JMP` targets `DP:00FC`, so an observed `PC=00FC` implies `DP=0`;
- `LDD ,U`, `ADDD #$8000`, `STD ,U` and `JMP` do not write `DP`, so the same
  `DP=0` holds at handler entry `1012`.

This is a **static deduction from exact handler bytes plus a live `PC`**, not a
live `DP` measurement. Direct `DP` observation remains unfulfilled for this
capture and requires a separately scoped future observation; it is not claimed
here. The analyzer records `registerEvidence.dp.directObservation=false` and
rejects any event field that would claim a sampled `DP`.

## Verification

| Check | Actual result |
| --- | --- |
| Offline positive fixture and negative controls (audit) | exit `0`, **185 checks, 0 failures** |
| Natural capture | exit `0`; MAME exit `0`; not timed out; **12/12 phases** |
| Offline verification of the preserved run (audit) | exit `0`; strict JSON pass; **12/12 phases**; `dpStatus=deduced_zero_not_directly_measured` |
| Event log (captured and copied) | `70510702CDA40F69D7B7DDB760963B2B01D34192544017F3C83924861B0885AE` |
| Natural evidence after audit (raw file) | `20C4470C1C657F14772C4BB48F43DE016D9D85040A9286AFD34A85875DB75A8E` |
| Natural evidence after audit (canonical LF / manifest identity) | `C5CBB2C155E04F6E5116CD8860B2BB329B029BD36D048DB046478096DB7F195B` |
| Preserved task46 observation | `CB765150B2500F0079FB4EF307019CA12FF4A7857E4BEFB478FE6F85B5B2B513` |
| Audited copy observation | `239D5F57478D6DA9A9604E1EF827747E987809164F019C703264E30538B94F2D` |

Input provenance: coin rows exactly `2100-2103`; real 60 Hz start rows
`2221-2225`; twelve ordered debug-stop callback rows `2226-2237` matched the
twelve recorded phase stop times; no extra activity and no later fixture action.
Strict JSON, duplicate-key, event order, completion marker, image/map/build/
config/observer/replay hashes and the unchanged isolated ROM were all checked.
The audit also checked the MAME invocation record for `-noreadconfig`, isolated
config/NVRAM/state directories, the isolated first ROM path, the run-local
observer and the absence of playback, save-state, autosave and debug-script
switches; and required all four bounded data/control stack words plus live `A/B`
consistency with `D`. The checker rejected wrong image/map/target/composite
`00F8`, wrong phase PC/Y/X/U/S/top/D, inconsistent A/B/D, missing or invented
saved cursors, missing bounded stack words, fabricated `DP`, side-effect files,
duplicate JSON keys, missing/reordered/extra/partial phases, forged run records,
forged replay/input or mutated ROM, state files, malformed/nonmonotonic/
duplicate/off-window input, and invented stop context.

## Verification applicability

- The natural result applies only to the exact original revision and exact
  built image hashes above. It does not transfer to the composite image, other
  ROM revisions, other games or physical MPU4 hardware.
- The positive offline fixture is synthetic and explicitly classified as
  `synthetic_fixture_complete_not_evidence`; it only exercises the checker.
- The two-failure rule for this concrete boundary was not consumed: attempt 1
  completed. No automatic rerun, retry under another name, save-state load or
  additional MAME launch was made.

## Limitations

- MAME success is not physical MPU4 hardware compatibility.
- `DP` was not directly sampled by the captured observer. `DP=0` for this call
  is a static deduction from the exact `0EFC` direct `JMP` and the live
  `PC=00FC`, not a live measurement. Direct `DP` observation remains unfulfilled
  for this capture and needs a separately scoped future observation.
- Only the single direct native primitive reached from the naturally observed
  `9F14` caller site is claimed.
- The broader purpose of the `9F12` caller and all downstream consumers remains
  unresolved.
- The intentional `0000 -> 8000 -> FFFF` behaviour change is not original
  `9ED9` preservation, paid-window behaviour or a full-game proof.
- `H` is not defined, output or asserted. No relocation, banking, general
  dictionary decoding or arbitrary editor support is claimed.
- No fourth composite capture was made; the prior composite history remains
  preserved and unchanged.
