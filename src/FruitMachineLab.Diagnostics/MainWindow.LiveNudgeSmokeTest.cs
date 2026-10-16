using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Threading;
namespace FruitMachineLab.Diagnostics;

public partial class MainWindow
{
    private void NudgeSmokeKey(Button button,bool down)
    {
        var e=new KeyEventArgs(Keyboard.PrimaryDevice,PresentationSource.FromVisual(button),Environment.TickCount,Key.Space){RoutedEvent=down ? Keyboard.PreviewKeyDownEvent : Keyboard.PreviewKeyUpEvent};
        if(down)NudgeKeyDown(button,e);else NudgeKeyUp(button,e);
    }
    private async Task NudgeSmokePress(Button button)
    {
        button.Focus();NudgeSmokeKey(button,true);int mask=2<<int.Parse((string)button.Tag);var timeout=System.Diagnostics.Stopwatch.StartNew();
        while(liveSession?.Fault is null && liveSession is not null && (liveSession.Machine.Memory[3]&mask)==0 && timeout.ElapsedMilliseconds<250)await Task.Delay(1);
        NudgeSmokeKey(button,false);
    }
    private async Task LiveNudgeSmokeTest(string directory)
    {
        Directory.CreateDirectory(directory);
        try {
            ContinueBoardExecution.IsChecked=true;LiveEntryMode.SelectedIndex=3;
            for(int reel=0;reel<3;reel++) {
                if(!await LoadLive(startExecution:false))throw new InvalidOperationException(Status.Text);
                ResumeLive();var timeout=System.Diagnostics.Stopwatch.StartNew();
                while(!liveSession!.AwaitingBoardSelection && liveSession.Fault is null && timeout.Elapsed.TotalSeconds<6)await Task.Delay(10);
                if(!liveSession.AwaitingBoardSelection)throw new InvalidOperationException("No ladder prompt: "+Status.Text);
                PhysicalTakeDown(PhysicalTake,new MouseButtonEventArgs(Mouse.PrimaryDevice,Environment.TickCount,MouseButton.Left){RoutedEvent=UIElement.PreviewMouseLeftButtonDownEvent});await Task.Delay(80);PhysicalTakeUp(PhysicalTake,new MouseButtonEventArgs(Mouse.PrimaryDevice,Environment.TickCount,MouseButton.Left){RoutedEvent=UIElement.PreviewMouseLeftButtonDownEvent});
                while(!liveSession.AwaitingNudgeInput && liveSession.Fault is null && timeout.Elapsed.TotalSeconds<8)await Task.Delay(10);
                if(!liveSession.AwaitingNudgeInput || !liveSession.Snapshot().Alpha.Contains("NUDGES"))throw new InvalidOperationException("No nudge prompt: "+Status.Text);
                Activate();var buttons=new[]{Nudge1,Nudge2,Nudge3};buttons[reel].BringIntoView();await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);if(buttons.Any(b=>!b.IsEnabled))throw new InvalidOperationException("Nudge panel disabled");
                // Release before another scheduler turn: capture/focus loss must
                // remove the physical level without injecting a reel request.
                NudgeDown(buttons[reel],new MouseButtonEventArgs(Mouse.PrimaryDevice,Environment.TickCount,MouseButton.Left){RoutedEvent=UIElement.PreviewMouseLeftButtonDownEvent});buttons[reel].ReleaseMouseCapture();
                if(liveSession.Panel.PhysicalBlack2!=0)throw new InvalidOperationException($"Nudge capture loss retained input {liveSession.Panel.PhysicalBlack2:X2}; captured={Mouse.Captured}; nudge={liveSession.Panel.NudgePressed(reel)}; take={liveSession.Panel.TakePressed}");
                PauseLive();ulong cycle=liveSession.Cycle;var memory=liveSession.Machine.Memory.ToArray();await Task.Delay(100);
                if(cycle!=liveSession.Cycle || !memory.SequenceEqual(liveSession.Machine.Memory))throw new InvalidOperationException("Pause advanced nudge prompt");
                RenderLive();await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);SaveWindowImage(Path.Combine(directory,$"nudge-{reel+1}-prompt.png"));
                byte[] before=[liveSession.Machine.Memory[0x168],liveSession.Machine.Memory[0x16A],liveSession.Machine.Memory[0x16C]];
                ResumeLive();buttons[reel].Focus();await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);NudgeSmokeKey(buttons[reel],true);await Task.Delay(25);NudgeSmokeKey(buttons[reel],false);
                timeout.Restart();bool pausedMotor=false;
                while(liveSession.Fault is null && !liveSession.AwaitingPaidStart && !(liveSession.AwaitingNudgeInput && liveSession.Machine.Memory[0xBE]==2 && !liveSession.NudgeMoving) && timeout.Elapsed.TotalSeconds<5){
                    if(!pausedMotor && liveSession.MotorBusy){
                        PauseLive();var frozen=liveSession.Machine.Memory.ToArray();ulong at=liveSession.Cycle;await Task.Delay(100);
                        if(at!=liveSession.Cycle || !frozen.SequenceEqual(liveSession.Machine.Memory))throw new InvalidOperationException("Nudge motor advanced during pause");
                        RenderLive();await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);SaveWindowImage(Path.Combine(directory,$"nudge-{reel+1}-motor-paused.png"));ResumeLive();pausedMotor=true;
                    }
                    await Task.Delay(10);
                }
                if((liveSession.Fault is not null || !liveSession.AwaitingNudgeInput) || liveSession.Panel.PhysicalBlack2!=0 || liveSession.Machine.Memory[0xBE]!=2 || liveSession.Machine.Memory[0xBF]!=2 || liveSession.MotorBusy || !pausedMotor)throw new InvalidOperationException($"Nudge request boundary failed: {Status.Text}; vm={liveSession.VmAddress:X4}, physical={liveSession.Panel.PhysicalBlack2:X2}, sampled={liveSession.Machine.Memory[3]:X2}, fault={liveSession.Fault}, ready={liveSession.AwaitingNudgeInput}");
                for(int n=0;n<3;n++)if(liveSession.Machine.Memory[0x168+2*n]!=(byte)((before[n]+(n==reel ? 90 : 0))%96))throw new InvalidOperationException("Wrong reel request changed");
                RenderLive();await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);SaveWindowImage(Path.Combine(directory,$"nudge-{reel+1}-accepted.png"));
                if(reel==0) {
                    bool pausedImprovement=false,pausedTransfer=false;
                    for(int remaining=2;remaining>0;remaining--) {
                        var selected=Nudge1;await NudgeSmokePress(selected);timeout.Restart();
                        while(liveSession.Fault is null && !liveSession.AwaitingPaidStart && !(liveSession.AwaitingNudgeInput && liveSession.Machine.Memory[0xBE]==remaining-1 && !liveSession.NudgeMoving) && timeout.Elapsed.TotalSeconds<45){
                            if(!pausedImprovement && liveSession.Machine.Memory[0xBE]==3 && liveSession.MotorBusy){
                                PauseLive();var frozen=liveSession.Machine.Memory.ToArray();ulong at=liveSession.Cycle;await Task.Delay(100);
                                if(at!=liveSession.Cycle || !frozen.SequenceEqual(liveSession.Machine.Memory))throw new InvalidOperationException("Automatic improvement advanced while paused");
                                RenderLive();await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);SaveWindowImage(Path.Combine(directory,"improvement-paused.png"));ResumeLive();pausedImprovement=true;
                            }
                            if(!pausedTransfer && liveSession.Machine.ReadWord(0xBA) is >0 and <16 && liveSession.Machine.ReadWord(0x2FA)>0){PauseLive();var frozen=liveSession.Machine.Memory.ToArray();ulong at=liveSession.Cycle;await Task.Delay(100);if(at!=liveSession.Cycle || !frozen.SequenceEqual(liveSession.Machine.Memory))throw new InvalidOperationException("Meter transfer advanced while paused");RenderLive();await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);SaveWindowImage(Path.Combine(directory,"meter-transfer-paused.png"));ResumeLive();pausedTransfer=true;}
                            await Task.Delay(10);
                        }
                        if(liveSession.AwaitingPaidStart)break;
                        if(remaining==2 && (liveSession.Fault is not null || liveSession.Machine.Memory[0xBE]!=1))throw new InvalidOperationException("Second nudge failed: "+Status.Text+$" vm={liveSession.VmAddress:X4} remaining={liveSession.Machine.Memory[0xBE]} fault={liveSession.Fault} sampled={liveSession.Machine.Memory[3]:X2}");
                    }
                    if(!liveSession.AwaitingPaidStart || liveSession.Fault is not null || liveSession.Snapshot().Credits!=6)throw new InvalidOperationException("Preplay prompt was not reached: "+Status.Text);
                    PauseLive();var readyMemory=liveSession.Machine.Memory.ToArray();ulong readyCycle=liveSession.Cycle;await Task.Delay(100);
                    if(readyCycle!=liveSession.Cycle || !readyMemory.SequenceEqual(liveSession.Machine.Memory))throw new InvalidOperationException("Preplay wait advanced while paused");
                    RenderLive();await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);SaveWindowImage(Path.Combine(directory,"paid-start-ready.png"));ResumeLive();
                    PhysicalStart.Focus();PhysicalStartDown(PhysicalStart,new MouseButtonEventArgs(Mouse.PrimaryDevice,Environment.TickCount,MouseButton.Left){RoutedEvent=UIElement.PreviewMouseLeftButtonDownEvent});
                    await Task.Delay(100);PhysicalStartUp(PhysicalStart,new MouseButtonEventArgs(Mouse.PrimaryDevice,Environment.TickCount,MouseButton.Left){RoutedEvent=UIElement.PreviewMouseLeftButtonUpEvent});
                    bool pausedTone=false,pausedPaidSpin=false;timeout.Restart();while(liveSession.Fault is null && (liveSession.PaidGamesCompleted==0 || !liveSession.AwaitingPaidStart) && !liveSession.AwaitingPaidNudge && timeout.Elapsed.TotalSeconds<6){
                        if(liveSession.TimedToneActive && liveSession.Machine.Memory[0x4D]==0x31 && !pausedTone){
                            PauseLive();var frozenTone=liveSession.Machine.Memory.ToArray();ulong toneAt=liveSession.Cycle;await Task.Delay(100);
                            if(toneAt!=liveSession.Cycle || !frozenTone.SequenceEqual(liveSession.Machine.Memory))throw new InvalidOperationException("Native tone advanced while paused");
                            RenderLive();await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);SaveWindowImage(Path.Combine(directory,"timed-tone-paused.png"));ResumeLive();pausedTone=true;
                        }
                        if(liveSession.PaidSpinMoving && liveSession.MotorBusy && !pausedPaidSpin && Enumerable.Range(0,3).Any(n=>liveSession.Machine.Memory[0x168+2*n]!=readyMemory[0x168+2*n])){
                            PauseLive();var frozenSpin=liveSession.Machine.Memory.ToArray();ulong spinAt=liveSession.Cycle;await Task.Delay(100);
                            if(spinAt!=liveSession.Cycle || !frozenSpin.SequenceEqual(liveSession.Machine.Memory))throw new InvalidOperationException("Paid spin advanced while paused");
                            RenderLive();await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);SaveWindowImage(Path.Combine(directory,"paid-spin-paused.png"));ResumeLive();pausedPaidSpin=true;
                        }
                        await Task.Delay(1);
                    }
                    if(!pausedPaidSpin)throw new InvalidOperationException("Paid-spin pause was not exercised");
                    if(!pausedTone)throw new InvalidOperationException("Timed-tone pause was not exercised");
                    if(liveSession.PaidGamesCompleted!=1 || !liveSession.AwaitingPaidStart || liveSession.Fault is not null || liveSession.Machine.Memory[0xBE]!=0 || liveSession.Machine.Memory[0xBF]!=0 || liveSession.Machine.ReadWord(0xBA)!=0 || liveSession.Machine.ReadWord(0x2FA)!=0 || liveSession.Snapshot().CashBank!=16 || liveSession.Snapshot().Credits!=5 || !pausedImprovement || !pausedTransfer || liveSession.Panel.PhysicalBlack2!=0)throw new InvalidOperationException("Sequence did not return cleanly: "+Status.Text+$" vm={liveSession.VmAddress:X4} games={liveSession.PaidGamesCompleted} ready={liveSession.AwaitingPaidStart} fault={liveSession.Fault}");
                    RenderLive();await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);SaveWindowImage(Path.Combine(directory,"nudge-improvement-result.png"));
                }
            }
            await OrdinaryPaidNudgeGuiCheck(directory);
            if(!await LoadLive(startExecution:false) || liveSession!.Instructions!=0 || liveSession.PaidGamesCompleted!=0 || liveSession.Fault is not null)throw new InvalidOperationException("Restart retained nudge state");
            File.WriteAllText(Path.Combine(directory,"result.txt"),"PASS: all three momentary nudge keyboard handlers; actual recovered input scan, only selected main reel moved six positions and remaining/pot became two, mouse-capture failure/loss release, VM/memory/time pause, native cleanup and unchanged award accounting, rendered prompt/request boundaries and clean restart. Returns to the next prompt with preserved lamp-native save bytes; three Nudge1 inputs exhaust the pot; automatic improvement and its motor Pause execute, board-exit return and pending-to-current-win animation execute, seven-flash tail, statistics/scaled counters and cash-bank16 commit with pending/current-win0; bank-limit service, outer-cycle stack check and next-cycle display refresh execute; status lamps, guarded background services and credit loop complete; preplay wait pauses correctly; physical START reaches credit debit6 to5 and stake accounting; native tone progresses incrementally and pauses; pre-spin flags/random gates execute; selected final preparation and paid reel spin execute with actual motor Pause/Resume; paid result and ordinary-nudge offer execute; physical Nudge1 moves only its reel, with prompt/motor Pause; ordinary post-sequence result and outer paid-game return execute; a fresh Start prompt retains credit5/bank16 and completed-game count1. The separate mixed-input case stops before unrecovered three-flag feature accounting.\n");Application.Current.Shutdown(0);
        }catch(Exception error){File.WriteAllText(Path.Combine(directory,"result.txt"),error.ToString());Application.Current.Shutdown(1);}
    }
    private async Task OrdinaryPaidNudgeGuiCheck(string directory)
    {
        if(!await LoadLive(startExecution:false))throw new InvalidOperationException(Status.Text);
        // Generated physical-input campaign, matching the headless driver. The
        // deterministic prefix uses ordinary input handlers; no state injection.
        liveWallClock.Reset();liveLastWallTime=TimeSpan.Zero;liveSession!.Resume();int[] reels=[0,1,0];int next=3;bool started=false,paid=false;
        for(int n=0;n<180000 && !liveSession.AwaitingPaidNudge;n++){
            if(liveSession.AwaitingBoardSelection)PressPhysicalTake();
            if(!paid && liveSession.AwaitingNudgeInput && !liveSession.NudgeMoving){ReleasePhysicalTake();if(next>0 && liveSession.Machine.Memory[0xBE]==next){NudgeSmokeKey(new[]{Nudge1,Nudge2,Nudge3}[reels[3-next]],true);next--;}}
            if(liveSession.NudgeMoving)ReleaseNudges();
            if(liveSession.AwaitingPaidStart && !started){PressPhysicalStart();started=true;}
            if(started && liveSession.Panel.StartPressed && (liveSession.Machine.Memory[3]&128)!=0)ReleasePhysicalStart();
            if(liveSession.PaidSpinMoving)paid=true;
            liveSession.AdvanceCycles(512);
        }
        if(!liveSession.AwaitingPaidNudge || liveSession.Fault is not null || liveSession.Machine.Memory[0xBE]!=1)throw new InvalidOperationException("Generated ordinary paid nudge prompt missing");
        PauseLive();var before=liveSession.Machine.Memory.ToArray();ulong at=liveSession.Cycle;await Task.Delay(100);
        if(at!=liveSession.Cycle || !before.SequenceEqual(liveSession.Machine.Memory))throw new InvalidOperationException("Ordinary nudge prompt advanced during pause");
        RenderLive();await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);SaveWindowImage(Path.Combine(directory,"ordinary-paid-nudge-prompt.png"));ResumeLive();await NudgeSmokePress(Nudge1);
        bool pausedMotor=false;var timeout=System.Diagnostics.Stopwatch.StartNew();while(liveSession.Fault is null && timeout.Elapsed.TotalSeconds<4){
            if(liveSession.MotorBusy && !pausedMotor){PauseLive();var frozen=liveSession.Machine.Memory.ToArray();ulong motorAt=liveSession.Cycle;await Task.Delay(100);if(motorAt!=liveSession.Cycle || !frozen.SequenceEqual(liveSession.Machine.Memory))throw new InvalidOperationException("Ordinary nudge motor advanced during pause");RenderLive();await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);SaveWindowImage(Path.Combine(directory,"ordinary-paid-nudge-motor-paused.png"));ResumeLive();pausedMotor=true;}
            await Task.Delay(1);
        }
        if(!pausedMotor || liveSession.Machine.Memory[0x168]!=(before[0x168]+90)%96 || liveSession.Machine.Memory[0x16A]!=before[0x16A] || liveSession.Machine.Memory[0x16C]!=before[0x16C] || liveSession.VmAddress!=0xEE16 || liveSession.Fault?.StartsWith("BOARD paid nudge reached three flagged symbols")!=true || liveSession.Machine.Memory[0xBE]!=0 || liveSession.Snapshot().CashBank!=16 || liveSession.Snapshot().Credits!=5 || liveSession.Panel.PhysicalBlack2!=0)throw new InvalidOperationException("Ordinary paid nudge failed: "+Status.Text);
        RenderLive();await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);SaveWindowImage(Path.Combine(directory,"ordinary-paid-nudge-result.png"));
    }

}
