# Integrate59 IRQ suffix flags and frame preflight correction

## Scope

Correction of the accepted integrate58 suffix composition. The execution boundary
is unchanged: one machine seeded only from the captured `FEC3` full 2 KB and
registers runs `FEC3 JSR 6B4D`, `FEC6 JSR 58BB`, `FEC9 JSR 5CD0`, the native
`5CD0` zero-guard service and `FECC CLR <$2C`, then stops at `FECE`. No
intermediate reseeding, return-frame reload, host RAM patch or IRQ cadence was
added. All five intermediate full 2 KB anchors and all supported cycle splits
remain compared exactly.

## Native 5CD0 flags

`5CD0` has no CPU register or flag file. `AddersIrqSuffixNativeState` therefore
no longer carries a byte `CC` copied from the pre-service CPU state. It carries
`AddersIrqSuffixFlags(KnownMask,Value)`, matching the finish-component practice:

- every native `5CD0` post-service flag is explicitly unknown
  (`KnownMask=00`, `Value=00`) at `FECC`;
- `FECC CLR <$2C` exposes only `N/Z/V/C` (`KnownMask=0F`, `Value=04`, i.e.
  N=0, Z=1, V=0, C=0) at `FECE`;
- `H/I/F/E` are not claimed, and the full captured `FECE` `CC` is not compared.
  The captured condition nibble is checked only against the known mask.

No upper `CC` bits are inherited from `atFec9.CC`, and no comparison treats
copied flags as generated native output.

## Closed frame preflight

The optional caller-supplied `expectedEntryS` argument was removed. It made the
guard tautological and allowed unsupported low `S` values to reach a push and
wrap. `AddersIrq6B4DZeroStateExecution` now accepts only two independent captured
FEC3 pre-JSR placements:

- `0786`, the 6B4D component capture;
- `078D`, the capture57 suffix entry.

The suffix wrapper accepts only `078D` and requires the derived `FEC9` frame
`078D` and `5CD0` entry `078B`. Unsupported values are rejected before any write.
Positive checks exercise both `0786` and `078D` on the 6B4D path. Negative
controls cover `S=0001`, `S=0002` and `S=078C`, and verify the complete memory
image is unchanged after rejection.

## Negative-control staging

Fixture negatives use the semantic validator without raw-file hash short-circuit.
Each mutation must fail at its intended rule and with its expected message:

- wrong entry frame -> closed frame preflight;
- changed `FEC6` image -> full 2 KB comparison, not an earlier hash;
- reseeded `FEC3` image -> entry-pin comparison;
- changed trace row 0 -> 6B4D trace-row comparison.

Unexpected exception types are not caught, and checks were not weakened. The
fixture files themselves are unchanged.

## Commands and exits

- `dotnet build FruitMachineLab.Headless.sln -v:minimal` -> exit 0, 0 warnings,
  0 errors.
- Focused `... -- "C:\projects\GitRepos\FruitMachineLab" "IRQ capture57"` ->
  exit 0, 2 groups.
- Full headless suite -> exit 0, **415 groups** (unchanged baseline).
- Manifest entry for this document was recomputed from actual bytes; prior
  entries were retained in appended order.

## Limits and next task

One capture57 occurrence only. There is no nested IRQ after `FECE`, no autonomous
timer cadence, no `58BB` active/pulse path, no nonzero `6B4D`/`5330` branch, no
whole-IRQ or Live integration and no audio or hardware claim. Native `5CD0`
register and flag coverage remains explicitly partial. The next task should
extend only a separately captured branch or foreground/IRQ ownership boundary;
do not infer unobserved semantics from this zero-guard suffix.
