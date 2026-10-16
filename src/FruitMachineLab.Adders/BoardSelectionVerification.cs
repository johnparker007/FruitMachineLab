using System.Buffers.Binary;
using System.Security.Cryptography;
using System.Text.Json;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public record BoardSelectionVerificationResult(int Instructions,int Lamps,int Sounds,int AlphaBytes,int Conditions,bool AlphaExact=true,int ReferenceAlphaBytes=0,string LampSequence="",string AlphaShadow="");
public static class BoardSelectionVerification
{
    public static BoardSelectionVerificationResult Verify(string evidence,bool diceRequests=false,bool diceMotion=false,bool boardMovement=false,bool nudgePotProbe=false,string? boardLink=null,bool continuation=false,bool availability=false,bool nudgeEntry=false,bool nudgePrompt=false,bool nudgeRequest=false,bool nudgeMotion=false,bool nudgeReturn=false,bool nudgeSequence=false,bool nudgeResult=false,bool nudgeExit=false,bool nudgeWinTransfer=false,bool nudgeTail=false,bool nudgeAccounting=false,bool nudgeBankReturn=false,bool nudgeCycleInit=false,bool nudgeIc8=false,bool nudgeBackground=false,bool nudgeStatus=false,bool nudgeServices=false,bool nudgePreplay=false,bool nudgeEligibility=false,bool nudgeStart=false,bool nudgeStake=false,bool nudgeTone=false,bool nudgeSpinFlags=false,bool nudgeSpinGates=false,bool nudgeFinalSelection=false,bool nudgeSpinPreparation=false,bool nudgePaidSpin=false)
    {
        if(nudgePaidSpin)nudgeSpinPreparation=true;
        if(nudgeSpinPreparation)nudgeFinalSelection=true;
        if(nudgeFinalSelection)nudgeSpinGates=true;
        if(nudgeSpinGates)nudgeSpinFlags=true;
        if(nudgeSpinFlags)nudgeTone=true;
        if(nudgeTone)nudgeStake=true;
        if(nudgeStake)nudgeStart=true;
        if(nudgeStart)nudgeEligibility=true;
        if(nudgeEligibility)nudgePreplay=true;
        if(nudgePreplay)nudgeServices=true;
        if(nudgeServices)nudgeStatus=true;
        if(nudgeStatus)nudgeBackground=true;
        if(nudgeBackground)nudgeIc8=true;
        if(nudgeIc8)nudgeCycleInit=true;
        if(nudgeCycleInit)nudgeBankReturn=true;
        if(nudgeBankReturn)nudgeAccounting=true;
        if(nudgeAccounting)nudgeTail=true;
        if(nudgeTail)nudgeWinTransfer=true;
        if(nudgeWinTransfer)nudgeExit=true;
        if(nudgeExit)nudgeResult=true;
        if(nudgeResult)nudgeSequence=true;
        if(nudgeSequence)nudgeReturn=true;
        if(nudgeReturn)nudgeMotion=true;
        if(nudgeMotion)nudgeRequest=true;
        if(nudgeRequest)nudgePrompt=true;
        if(nudgePrompt)nudgeEntry=true;
        if(diceMotion)diceRequests=true;
        if(nudgePotProbe)boardMovement=true;
        if(boardLink is not null)boardMovement=true;
        using var capture=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash",nudgePaidSpin ? "nudge-paid-spin.json" : nudgeSpinPreparation ? "nudge-spin-preparation.json" : nudgeFinalSelection ? "nudge-final-selection.json" : nudgeSpinGates ? "nudge-spin-gates.json" : nudgeSpinFlags ? "nudge-spin-flags.json" : nudgeTone ? "nudge-tone.json" : nudgeStake ? "nudge-stake.json" : nudgeStart ? "nudge-start.json" : nudgeEligibility ? "nudge-eligibility.json" : nudgePreplay ? "nudge-preplay.json" : nudgeServices ? "nudge-services.json" : nudgeStatus ? "nudge-status.json" : nudgeBackground ? "nudge-background.json" : nudgeIc8 ? "nudge-ic8.json" : nudgeCycleInit ? "nudge-cycle-init.json" : nudgeBankReturn ? "nudge-bank-return.json" : nudgeAccounting ? "nudge-accounting.json" : nudgeTail ? "nudge-tail.json" : nudgeWinTransfer ? "nudge-win-transfer.json" : nudgeExit ? "nudge-exit.json" : nudgeResult ? "nudge-result.json" : nudgeSequence ? "nudge-sequence.json" : nudgeReturn ? "nudge-return.json" : nudgeMotion ? "nudge-motion-vm.json" : nudgeRequest ? "nudge-request.json" : nudgePrompt ? "nudge-prompt.json" : nudgeEntry ? "nudge-entry.json" : availability ? "ladder-availability.json" : boardLink is not null ? boardLink+"-link"+(continuation ? "-next" : "")+".json" : nudgePotProbe ? "nudge-pot-probe.json" : boardMovement ? (continuation ? "board-movement-next.json" : "board-movement.json") : diceMotion ? "dice-motion-vm.json" : diceRequests ? "dice-requests.json" : "board-selection.json")));var root=capture.RootElement;
        if(nudgeTail){
            using var entryReference=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash",nudgePaidSpin ? "nudge-spin-preparation.json" : nudgeSpinPreparation ? "nudge-final-selection.json" : nudgeFinalSelection ? "nudge-spin-gates.json" : nudgeSpinGates ? "nudge-spin-flags.json" : nudgeSpinFlags ? "nudge-tone.json" : nudgeTone ? "nudge-stake.json" : nudgeStake ? "nudge-start.json" : nudgeEligibility ? "nudge-preplay.json" : nudgePreplay ? "nudge-services.json" : nudgeServices ? "nudge-status.json" : nudgeStatus ? "nudge-background.json" : nudgeBackground ? "nudge-ic8.json" : nudgeIc8 ? "nudge-cycle-init.json" : nudgeCycleInit ? "nudge-bank-return.json" : nudgeBankReturn ? "nudge-accounting.json" : nudgeAccounting ? "nudge-tail.json" : "nudge-win-transfer.json")));
            using var sidecar=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash",nudgePaidSpin ? "nudge-paid-spin-verification.json" : nudgeSpinPreparation ? "nudge-spin-preparation-verification.json" : nudgeFinalSelection ? "nudge-final-selection-verification.json" : nudgeSpinGates ? "nudge-spin-gates-verification.json" : nudgeSpinFlags ? "nudge-spin-flags-verification.json" : nudgeTone ? "nudge-tone-verification.json" : nudgeStake ? "nudge-stake-verification.json" : nudgeStart ? "nudge-start-verification.json" : nudgeEligibility ? "nudge-eligibility-verification.json" : nudgePreplay ? "nudge-preplay-verification.json" : nudgeServices ? "nudge-services-verification.json" : nudgeStatus ? "nudge-status-verification.json" : nudgeBackground ? "nudge-background-verification.json" : nudgeIc8 ? "nudge-ic8-verification.json" : nudgeCycleInit ? "nudge-cycle-init-verification.json" : nudgeBankReturn ? "nudge-bank-return-verification.json" : nudgeAccounting ? "nudge-accounting-verification.json" : "nudge-tail-verification.json")));
            foreach(var field in root.GetProperty("initial").EnumerateObject())if(field.Name is not ("cycle" or "io" or "io_control" or "aux") && entryReference.RootElement.GetProperty("terminal").GetProperty(field.Name).GetString()!=field.Value.GetString())throw new InvalidDataException("Tail entry differs from verified transfer boundary");
            if(!sidecar.RootElement.GetProperty("tail_window").GetBoolean() || sidecar.RootElement.GetProperty("process_exit_code").GetString()!.Trim()!="0")throw new InvalidDataException("Incomplete tail campaign");
        }
        if(nudgeWinTransfer && !nudgeTail){
            using var provenance=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","nudge-win-transfer-verification.json")));
            var terminal=root.GetProperty("terminal");
            if(!provenance.RootElement.GetProperty("observed_prefix").GetBoolean() || root.GetProperty("terminal_ram_hex").ValueKind!=JsonValueKind.Null || terminal.GetProperty("y").GetString()!="AFC2" || terminal.GetProperty("pending").GetString()!="0000" || terminal.GetProperty("win").GetString()!="0010")throw new InvalidDataException("Transfer prefix provenance/boundary differs");
        }
        if(boardMovement) {
            int lifted=root.GetProperty("lifted_dispatches").GetInt32();
            if((!nudgeResult && lifted!=(nudgePotProbe ? 48 : 0)) || root.GetProperty("raw_instructions").GetInt32()!=root.GetProperty("instructions").GetInt32()+lifted)throw new InvalidDataException("Unexpected board/probe dispatch normalization");
        }
        // C63C writes the low byte; C640 clears the high byte. Only bytes
        // preceding those first writes may be excluded as undefined residue.
        string[] undefinedWords=["C726","C728","C72A","C72C","C72E","C730","C732","C637","C63A","C63C"];
        var frameMasks=undefinedWords.ToDictionary(site=>site,_=>0);frameMasks.Add("C63E",255);frameMasks.Add("C640",255);
        if(diceRequests || boardMovement)frameMasks.Clear();
        var declared=root.GetProperty("undefined_frame_masks").EnumerateObject().ToArray();
        if(declared.Length!=frameMasks.Count || declared.Any(item=>!frameMasks.TryGetValue(item.Name,out int mask) || item.Value.GetInt32()!=mask))throw new InvalidDataException("Invalid uninitialized-frame comparison exclusions");
        var ordinalMasks=nudgeEntry ? root.GetProperty("ordinal_frame_masks").EnumerateArray().ToDictionary(r=>r[0].GetInt32(),r=>r[1].GetInt32()) : new Dictionary<int,int>();int nudgeMask=65535;ushort lastNudgeSite=0;
        var m=new SkillCashLiveSession(evidence).Machine;ushort clock=boardLink is not null ? BoardLinkState.Apply(m,evidence,boardLink,continuation,availability,nudgeEntry,nudgePrompt,nudgeRequest,nudgeMotion,nudgeReturn,nudgeSequence,nudgeResult,nudgeExit,nudgeWinTransfer,nudgeTail,nudgeAccounting,nudgeBankReturn,nudgeCycleInit,nudgeIc8,nudgeBackground,nudgeStatus,nudgeServices,nudgePreplay,nudgeEligibility,nudgeStart,nudgeStake,nudgeTone,nudgeSpinFlags,nudgeSpinGates,nudgeFinalSelection,nudgeSpinPreparation,nudgePaidSpin) : boardMovement ? BoardMovementState.Apply(m,evidence,nudgePotProbe,continuation) : BoardSelectionState.Apply(m,evidence,diceRequests);
        if(nudgeIc8)m.Memory[0xF02]=(byte)Convert.ToUInt16(root.GetProperty("initial").GetProperty("io").GetString(),16);
        if(nudgeStatus)m.Memory[0xC02]=Convert.ToByte(root.GetProperty("initial").GetProperty("aux").GetString(),16);
        var motion=!nudgeTail && (diceMotion || nudgeMotion) ? new DiceMotionReference(m,evidence,nudgeMotion,nudgeSequence,nudgeResult) : null;
        using var vmHash=IncrementalHash.CreateHash(HashAlgorithmName.SHA256);using var lampHash=IncrementalHash.CreateHash(HashAlgorithmName.SHA256);using var soundHash=IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
        static void Hash(IncrementalHash hash,ReadOnlySpan<ushort> values){Span<byte> bytes=stackalloc byte[values.Length*2];for(int n=0;n<values.Length;n++)BinaryPrimitives.WriteUInt16BigEndian(bytes.Slice(n*2,2),values[n]);hash.AppendData(bytes);}
        var logicalLamps=new List<byte>();var serial=new List<byte>();var alpha=new Mpu4Alpha(m,serial.Add);int lamps=0,sounds=0;
        var scheduler=new Mpu4ChoiceStreamScheduler(m,clock,item=>{
            if(item.Kind!="command")return;ushort[] values=[item.Cursor,item.Value,item.Clock,item.Choice,item.Rate,item.Tempo,item.Gate,item.Flags,item.Pitch,item.Transpose];
            if(root.TryGetProperty("sound_observations",out var soundRows)) {
                if(sounds>=soundRows.GetArrayLength())throw new InvalidDataException("Extra roll sound observation");
                var expected=soundRows[sounds].EnumerateArray().Select(value=>value.GetUInt16()).ToArray();
                for(int n=0;n<values.Length;n++)if(values[n]!=expected[n])throw new InvalidDataException($"Roll sound {sounds} field {n}: {values[n]:X4} != {expected[n]:X4}");
            }
            sounds++;Hash(soundHash,values);
        });
        scheduler.RestoreQueuedNativeTasks(boardLink is null ? null : at=>BoardLinkState.ResolveSoundContinuation(m,at));
        var response=JsonSerializer.Deserialize<LampFrameCapture>(File.ReadAllText(Path.Combine(evidence,"skill-cash","lamp-frames.json")),new JsonSerializerOptions{PropertyNameCaseInsensitive=true})!;
        var frames=new Mpu4LampFrames(m,response.Responses.Select(x=>(byte)x).ToArray());
        var requests=new Mpu4LampRequests(m,request=>{logicalLamps.Add(request.Id);logicalLamps.Add((byte)(request.Pattern&15));byte column=frames.Apply(request.Id,request.Pattern);lampHash.AppendData(new byte[]{request.Id,(byte)(request.Pattern&15),column});lampHash.AppendData(frames.Snapshot());lamps++;});
        int[][] Rows(string name)=>root.GetProperty(name).EnumerateArray().Select(row=>row.EnumerateArray().Select(x=>x.GetInt32()).ToArray()).ToArray();
        var inputs=Rows("inputs");var conditions=Rows("conditions");var reads=Rows("before_reads");var anchors=Rows("anchors").ToDictionary(row=>row[0]);int point=0,condition=0,phase=0,ordinal=0;
        var native=Rows("native");int nativePoint=0;
        var availabilityRows=availability || nudgeEntry ? Rows("availability") : [];int availabilityPoint=0;
        var byteReads=boardMovement ? Rows("byte_reads") : [];int byteReadPoint=0;
        var catalog=new RecoveredScriptCatalog(Path.Combine(evidence,"VM-SCRIPTS"));
        RecoveredScript Resolve(ushort at)=>catalog.Owner(at);
        void Advance(ushort target){ushort delta=Cell.Subtract(target,scheduler.Clock);if(delta>32767)throw new InvalidDataException("Board sound clock reversed");if(delta!=0){m.WriteWord(0x2F,Cell.Add(m.ReadWord(0x2F),delta));m.Memory[0x2C]=0;m.WriteWord(0x35,(ushort)Math.Max(0,m.ReadWord(0x35)-delta));}scheduler.AdvanceTicks(delta);}
        if(nudgePaidSpin)motion=new(m,evidence,paidSpin:true,advanceClock:Advance,queueSound:stream=>{
            if(nativePoint>=native.Length)throw new InvalidDataException("Extra motor stop sound");var row=native[nativePoint++];
            if(row[0]!=ordinal || row[1]!=1 || row[2]!=scheduler.Clock || row[3]!=stream)throw new InvalidDataException("Motor stop sound phase differs");scheduler.Queue(stream);
        });
        int liftedObserved=0,chrPoint=0;
        var executor=new ScriptExecutor(m){ResolveScript=Resolve,ResolveWord=SkillCashData.ResolveWord,
            InputConditionCell=value=>{
                if(condition>=conditions.Length)throw new InvalidDataException("Extra board input condition");var row=conditions[condition++];
                if(row[0]!=ordinal || row[1]!=value)throw new InvalidDataException($"Board input condition ordinal {ordinal}, expected {row[0]}");
                int[] ports=[0,1,2,3,6,7];for(int n=0;n<ports.Length;n++)m.Memory[ports[n]]=(byte)row[n+2];
                return Mpu4InputConditions.Evaluate(m,(byte)value);
            },
            OperationBoundary=(i,state)=>{
                if(nudgeResult && i.Operation=="vm_return_to_caller_stream" && state.ReadWord(state.Control!.Pointer)==0x76BD)liftedObserved++;
                if(byteReadPoint<byteReads.Length && byteReads[byteReadPoint][0]==ordinal){
                    if(i.Operation!="vm_fetch_unsigned_byte" || state.Data.Peek()!=0x33)throw new InvalidDataException("Invalid board IRQ-byte read phase");
                    ushort ticks=(ushort)byteReads[byteReadPoint++][1];state.WriteWord(0x2D,Cell.Add(state.ReadWord(0x2D),ticks));state.Memory[0x33]=unchecked((byte)(state.Memory[0x33]+ticks));
                }
                // Capture-backed IRQ completion can precede the byte fetch
                // inside B25F, rather than the next VM dispatch boundary.
                if(motion is not null && i.Operation=="vm_fetch_unsigned_byte" && state.Data.Peek()==0x6B)motion.BeforeDispatch(ordinal+1);
                if(phase<reads.Length && reads[phase][0]==ordinal){if(i.Token!=0x790D || state.Data.Peek()!=0x2D)throw new InvalidDataException("Invalid board timer read phase");ushort ticks=(ushort)reads[phase++][1];state.WriteWord(0x2D,Cell.Add(state.ReadWord(0x2D),ticks));state.Memory[0x33]=unchecked((byte)(state.Memory[0x33]+ticks));}
            },
            WordHandler=(i,state)=>{
                if(i.Native==0x5A14){
                    if(!nudgeTone)throw new InvalidDataException("Missing timed-tone evidence");
                    var phases=root.GetProperty("tone_phases");
                    if(nativePoint>=native.Length)throw new InvalidDataException("Missing tone queue");var queue=native[nativePoint++];
                    if(queue[0]!=ordinal || queue[1]!=1 || queue[3]!=0x59EB)throw new InvalidDataException("Tone queue phase differs");
                    Advance((ushort)queue[2]);AddersTimedTone.Begin(state,scheduler);
                    Advance(phases[3].GetProperty("clock").GetUInt16());AddersTimedTone.End(state,scheduler);return true;
                }
                if(nudgeResult && i.Token==0x856F)liftedObserved+=4;
                if(nudgeMotion && i.Native==0x2BEB && motion is not null)motion.BeforeDispatch(ordinal+1);
                if((diceMotion || nudgeMotion) && (i.Native==0x61F6 || (nudgePaidSpin && i.Native==0x61D5)))return true; // Native phases applied before the following dispatch.
                if(i.Native is 0x5C18 or 0x5B77){if(nativePoint>=native.Length)throw new InvalidDataException("Extra native scheduler call");var row=native[nativePoint++];if(row[0]!=ordinal || row[1]!=(i.Native==0x5C18 ? 1 : 2) || (i.Native==0x5C18 && row[3]!=state.Data.Peek()))throw new InvalidDataException($"Native board scheduler phase differs at {ordinal}/{i.Site:X4}, expected {row[0]}/{row[1]} stream {row[3]:X4}, stack {(state.Data.Count>0 ? state.Data.Peek() : 0):X4}");Advance((ushort)row[2]);}
                if(i.Native==0x5CCB){if(point>=inputs.Length || inputs[point][0]!=ordinal+1)throw new InvalidDataException("Missing board scheduler wait boundary");Advance((ushort)inputs[point][4]);}
                int[]? av=null;
                if(i.Native is 0x29F4 or 0x29EC && (availability || nudgeEntry)){
                    if(availabilityPoint>=availabilityRows.Length)throw new InvalidDataException("Extra native availability call");av=availabilityRows[availabilityPoint++];
                    if(av[0]!=ordinal || av[1]!=state.DataPointer || av[2]!=state.Data.Peek())throw new InvalidDataException("Native availability entry differs");
                }
                if(nudgeServices && i.Native==0x68F1){
                    var rows=root.GetProperty("characteriser");AddersBackgroundServices.VerifyCharacteriser(state,x=>AddersBackgroundServices.Mame6809CompatibilityResponse(state,x),(at,call,response)=>{
                        var row=rows[chrPoint++];if(row[0].GetUInt16()!=at+1 || row[1].GetByte()!=call || row[2].GetByte()!=response || row[3].GetByte()!=state.Memory[at+1])throw new InvalidDataException("Characteriser reference response differs");
                    });return true;
                }
                bool handled=AddersNativeWords.Handle(i,state,requests,scheduler,alpha);
                if(av is not null){ushort[] values=[state.Data.Peek(),state.Memory[0xC8],state.Memory[0xA8],state.Memory[0xDD],state.Memory[0xDE],state.ReadWord(0x160),state.ReadWord(0x162),state.ReadWord(0x164)];for(int n=0;n<values.Length;n++)if(values[n]!=av[n+3])throw new InvalidDataException($"Native availability call {availabilityPoint} field {n} differs: {values[n]:X4} != {av[n+3]:X4}");}
                return handled;
            }
        };
        ushort entry=diceRequests || boardMovement ? Convert.ToUInt16(root.GetProperty("initial").GetProperty("y").GetString(),16) : (ushort)0xDD38;
        executor.BeginResumed(Resolve(entry),entry,catalog.Owner,0xBEEF,root.GetProperty("instructions").GetInt32()+1);
        while(!executor.Completed) {
            motion?.BeforeDispatch(ordinal);
            if(point<inputs.Length && inputs[point][0]==ordinal){var row=inputs[point++];m.WriteWord(0x2D,(ushort)row[1]);m.Memory[0x33]=(byte)row[2];m.WriteWord(0x90,(ushort)row[3]);Advance((ushort)row[4]);}
            var i=executor.NextInstruction!;var cells=m.Data.ToArray();
            // The debugger reads four physical cells even when U approaches the
            // host stack base. Preserve the captured memory beyond active cells.
            ushort CellAt(int index)=>index<cells.Length ? cells[index] : m.ReadWord(Cell.Add(m.DataPointer,(ushort)(index*2)));
            ushort[] signature=[i.Site,i.Token,CellAt(0),CellAt(1),CellAt(2),CellAt(3),m.DataPointer,m.Control!.Pointer,m.LocalFrame,m.Control.LoopFrame,m.ReadWord(m.LocalFrame),m.ReadWord(0x2D),m.Memory[0x33],m.ReadWord(0x324),m.Memory[0x4F],m.Memory[0x4E],m.ReadWord(0x90),m.ReadWord(0xBA),m.ReadWord(0x2FA),m.Memory[0x2C],m.Memory[0x322],m.Memory[0x323],m.ReadWord(0x327),m.ReadWord(0xA0),scheduler.Clock];
            if(boardMovement)signature=[..signature,m.Memory[0xC9],m.Memory[0xBF]];
            if(nudgeEntry){
                if(lastNudgeSite==0xB730)nudgeMask=0;
                if(lastNudgeSite==0xB2D0)nudgeMask|=0xFF00;
                if(lastNudgeSite==0xB2E2)nudgeMask|=0xFF;
                if(nudgeMask!=65535){if(!ordinalMasks.TryGetValue(ordinal,out int ordinalMask) || ordinalMask!=nudgeMask)throw new InvalidDataException("Uninitialized nudge frame mask differs");signature[10]&=(ushort)nudgeMask;ordinalMasks.Remove(ordinal);}
                lastNudgeSite=i.Site;
            }
            if(frameMasks.TryGetValue(i.Site.ToString("X4"),out int mask))signature[10]&=(ushort)mask;
            if(anchors.TryGetValue(ordinal,out var expected))for(int n=0;n<signature.Length;n++)if(signature[n]!=expected[n+1])throw new InvalidDataException($"Board ordinal {ordinal}, {i.Site:X4}, field {n}: {signature[n]:X4} != {expected[n+1]:X4}");
            if(nudgeIc8 && m.Memory[0xF02]!=root.GetProperty("io_rows")[ordinal][1].GetByte())throw new InvalidDataException("IC8 output latch differs");
            Hash(vmHash,signature);if((diceRequests && i.Site==(diceMotion ? 0xB28F : 0xB283)) || (boardMovement && (!nudgeReturn || ordinal==root.GetProperty("instructions").GetInt32()-1) && i.Site==Convert.ToUInt16(root.GetProperty("terminal").GetProperty("y").GetString(),16))){ordinal++;break;}executor.Step();ordinal++;
        }
        void Match(string key,string actual){if(root.GetProperty(key).GetString()!=actual)throw new InvalidDataException($"Board {key} differs: {actual}");}
        Match("expected_vm_sha256",Convert.ToHexString(vmHash.GetHashAndReset()));Match("expected_lamp_sha256",Convert.ToHexString(lampHash.GetHashAndReset()));Match("expected_sound_sha256",Convert.ToHexString(soundHash.GetHashAndReset()));
        string actualAlpha=Convert.ToHexString(serial.ToArray()),expectedAlpha=root.GetProperty("serial_hex").GetString()!;
        bool alphaExact=actualAlpha==expectedAlpha;
        if(!alphaExact) {
            // Explicitly bounded timing discrepancy: the reference adapter
            // advances alpha delay at VM/native boundaries, not every CPU read.
            // Preserve the raw evidence and reject anything beyond one missing
            // FF brightness restoration. Character/cursor/reset bytes must all match.
            int restore=actualAlpha.LastIndexOf("E0C0",StringComparison.Ordinal);
            if(!diceMotion || expectedAlpha.Length-actualAlpha.Length!=2 || restore<0 || actualAlpha.Insert(restore+2,"FF")!=expectedAlpha)Match("serial_hex",actualAlpha);
        }
        if(ordinal!=root.GetProperty("instructions").GetInt32() || lamps!=root.GetProperty("lamp_requests").GetInt32() || sounds!=root.GetProperty("sound_commands").GetInt32() || condition!=conditions.Length || point!=inputs.Length || phase!=reads.Length || nativePoint!=native.Length)throw new InvalidDataException("Incomplete board selection replay");
        if(nudgeResult && (!nudgeWinTransfer || nudgeTail)){
            byte[] terminal=Convert.FromHexString(root.GetProperty("terminal_ram_hex").GetString()!);
            if(terminal.Length!=0x800 || !m.Memory.AsSpan(0x2F0,0x33).SequenceEqual(terminal.AsSpan(0x2F0,0x33)) || m.ReadWord(0xBA)!=(ushort)((terminal[0xBA]<<8)|terminal[0xBB]) || m.ReadWord(0x2FA)!=(ushort)((terminal[0x2FA]<<8)|terminal[0x2FB]))throw new InvalidDataException("Pending award/NVRAM boundary bytes differ");
            if(nudgePaidSpin && !m.Memory.AsSpan(0x100,64).SequenceEqual(terminal.AsSpan(0x100,64)))throw new InvalidDataException("Paid-spin lamp frame RAM differs: "+string.Join(",",Enumerable.Range(0x100,64).Where(a=>m.Memory[a]!=terminal[a]).Select(a=>$"{a:X4}:{m.Memory[a]:X2}/{terminal[a]:X2}")));
            if(nudgeSpinGates && !m.Memory.AsSpan(0x150,80).SequenceEqual(terminal.AsSpan(0x150,80)))throw new InvalidDataException("Pre-spin reel requests/records differ");
            if(nudgeServices && (chrPoint!=root.GetProperty("characteriser").GetArrayLength() || m.Memory[0x38]!=terminal[0x38] || m.Memory[0x2C]!=terminal[0x2C]))throw new InvalidDataException("Background guard state differs");
            if(nudgeAccounting && (!m.Memory.AsSpan(0x43A,30).SequenceEqual(terminal.AsSpan(0x43A,30)) || !m.Memory.AsSpan(0x7C9,31).SequenceEqual(terminal.AsSpan(0x7C9,31))))throw new InvalidDataException("Award statistics bytes differ");
        }
        if(nudgeResult && liftedObserved!=root.GetProperty("lifted_dispatches").GetInt32())throw new InvalidDataException("Typed-list/local-release normalization differs");
        if(motion is not null && !motion.Complete)throw new InvalidDataException("Incomplete full-VM motion phases");
        if(ordinalMasks.Count!=0)throw new InvalidDataException("Unused nudge local masks");
        if(availabilityPoint!=availabilityRows.Length)throw new InvalidDataException("Incomplete availability observations");
        if(byteReadPoint!=byteReads.Length)throw new InvalidDataException("Incomplete board IRQ-byte phases");
        return new(ordinal,lamps,sounds,serial.Count,condition,alphaExact,expectedAlpha.Length/2,Convert.ToHexString(logicalLamps.ToArray()),alpha.Snapshot().Shadow);
    }
}
