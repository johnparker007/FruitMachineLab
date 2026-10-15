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
                while(liveSession.Fault is null && !(liveSession.AwaitingNudgeInput && liveSession.Machine.Memory[0xBE]==2 && !liveSession.NudgeMoving) && timeout.Elapsed.TotalSeconds<5){
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
                        Nudge1.Focus();NudgeSmokeKey(Nudge1,true);await Task.Delay(25);NudgeSmokeKey(Nudge1,false);timeout.Restart();
                        while(liveSession.Fault is null && !(liveSession.AwaitingNudgeInput && liveSession.Machine.Memory[0xBE]==remaining-1 && !liveSession.NudgeMoving) && timeout.Elapsed.TotalSeconds<(remaining==1 ? 45 : 5)){
                            if(remaining==1 && !pausedImprovement && liveSession.Machine.Memory[0xBE]==3 && liveSession.MotorBusy){
                                PauseLive();var frozen=liveSession.Machine.Memory.ToArray();ulong at=liveSession.Cycle;await Task.Delay(100);
                                if(at!=liveSession.Cycle || !frozen.SequenceEqual(liveSession.Machine.Memory))throw new InvalidOperationException("Automatic improvement advanced while paused");
                                RenderLive();await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);SaveWindowImage(Path.Combine(directory,"improvement-paused.png"));ResumeLive();pausedImprovement=true;
                            }
                            if(remaining==1 && !pausedTransfer && liveSession.Machine.ReadWord(0xBA) is >0 and <16 && liveSession.Machine.ReadWord(0x2FA)>0){PauseLive();var frozen=liveSession.Machine.Memory.ToArray();ulong at=liveSession.Cycle;await Task.Delay(100);if(at!=liveSession.Cycle || !frozen.SequenceEqual(liveSession.Machine.Memory))throw new InvalidOperationException("Meter transfer advanced while paused");RenderLive();await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);SaveWindowImage(Path.Combine(directory,"meter-transfer-paused.png"));ResumeLive();pausedTransfer=true;}
                            await Task.Delay(10);
                        }
                        if(remaining==2 && (liveSession.Fault is not null || liveSession.Machine.Memory[0xBE]!=1))throw new InvalidOperationException("Second nudge failed: "+Status.Text);
                    }
                    if(liveSession.Fault?.StartsWith("BOARD nudge award committed to bank")!=true || liveSession.Machine.Memory[0xBE]!=0 || liveSession.Machine.Memory[0xBF]!=0 || liveSession.Machine.ReadWord(0xBA)!=0 || liveSession.Machine.ReadWord(0x2FA)!=0 || liveSession.Snapshot().CashBank!=16 || !pausedImprovement || !pausedTransfer || liveSession.Panel.PhysicalBlack2!=0)throw new InvalidOperationException("Sequence did not exhaust cleanly: "+Status.Text);
                    RenderLive();await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);SaveWindowImage(Path.Combine(directory,"nudge-improvement-result.png"));
                }
            }
            if(!await LoadLive(startExecution:false) || liveSession!.Instructions!=0 || liveSession.Fault is not null)throw new InvalidOperationException("Restart retained nudge state");
            File.WriteAllText(Path.Combine(directory,"result.txt"),"PASS: all three momentary nudge keyboard handlers; actual recovered input scan, only selected main reel moved six positions and remaining/pot became two, mouse-capture failure/loss release, VM/memory/time pause, native cleanup and unchanged award accounting, rendered prompt/request boundaries and clean restart. Returns to the next prompt with preserved lamp-native save bytes; repeated Nudge1 exhausts the pot; recovered automatic improvement executes, actual auto-motor pause/resume freezes execution, board-exit return and pending-to-current-win animation execute, seven-flash tail, statistics/scaled counters and cash-bank16 commit with pending/current-win0; bank-limit service and collection remain explicit.\n");Application.Current.Shutdown(0);
        }catch(Exception error){File.WriteAllText(Path.Combine(directory,"result.txt"),error.ToString());Application.Current.Shutdown(1);}
    }
}
