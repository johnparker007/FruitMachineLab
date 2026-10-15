using System.IO;
using System.Windows;
using System.Windows.Input;
using System.Windows.Threading;
namespace FruitMachineLab.Diagnostics;

public partial class MainWindow
{
    private async Task LiveAvailabilitySmokeTest(string directory)
    {
        Directory.CreateDirectory(directory);
        try {
            ContinueBoardExecution.IsChecked=true;LiveEntryMode.SelectedIndex=3;
            foreach(bool take in new[]{false,true}) {
                if(!await LoadLive(startExecution:false))throw new InvalidOperationException(Status.Text);
                ResumeLive();var timeout=System.Diagnostics.Stopwatch.StartNew();
                while(!liveSession!.AwaitingBoardSelection && liveSession.Fault is null && timeout.Elapsed.TotalSeconds<8)await Task.Delay(15);
                if(liveSession.Fault is not null || !liveSession.AwaitingBoardSelection || liveSession.Machine.Memory[0xC8]!=16 || liveSession.Machine.Memory[0xC9]!=22 || !PhysicalTake.IsEnabled)throw new InvalidOperationException("Availability prompt failed: "+Status.Text);
                PauseLive();ulong cycle=liveSession.Cycle;var memory=liveSession.Machine.Memory.ToArray();
                RenderLive();await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);SaveWindowImage(Path.Combine(directory,take ? "take-prompt.png" : "start-prompt.png"));await Task.Delay(120);
                if(cycle!=liveSession.Cycle || !memory.SequenceEqual(liveSession.Machine.Memory))throw new InvalidOperationException("Availability prompt changed while paused");
                ResumeLive();var button=take ? PhysicalTake : PhysicalStart;
                var down=new MouseButtonEventArgs(Mouse.PrimaryDevice,Environment.TickCount,MouseButton.Left){RoutedEvent=UIElement.PreviewMouseLeftButtonDownEvent};
                if(take)PhysicalTakeDown(button,down);else PhysicalStartDown(button,down);
                await Task.Delay(100);
                var up=new MouseButtonEventArgs(Mouse.PrimaryDevice,Environment.TickCount,MouseButton.Left){RoutedEvent=UIElement.PreviewMouseLeftButtonUpEvent};
                if(take)PhysicalTakeUp(button,up);else PhysicalStartUp(button,up);
                if(take){
                    var ready=System.Diagnostics.Stopwatch.StartNew();
                    while(!liveSession.AwaitingNudgeInput && liveSession.Fault is null && ready.Elapsed.TotalSeconds<5)await Task.Delay(10);
                    if(!liveSession.AwaitingNudgeInput || liveSession.Fault is not null)throw new InvalidOperationException("Nudge prompt unavailable: "+Status.Text);
                    NudgeSmokeKey(Nudge1,true);await Task.Delay(100);NudgeSmokeKey(Nudge1,false);
                }
                timeout.Restart();bool motor=false;
                while(liveSession.Fault is null && liveSession.BoardPrompts<2 && !(take && liveSession.AwaitingNudgeInput && liveSession.Machine.Memory[0xBE]==2 && !liveSession.NudgeMoving) && timeout.Elapsed.TotalSeconds<10){motor|=liveSession.Snapshot().DiceRequest?.Busy==true;await Task.Delay(10);}
                if(liveSession.Panel.StartPressed || liveSession.Panel.TakePressed || (liveSession.Fault is not null && !liveSession.Fault.StartsWith("BOARD result type") && !liveSession.Fault.StartsWith("BOARD nudge motion completed")))throw new InvalidOperationException("Unexpected availability exit: "+Status.Text);
                if(take && ((liveSession.Fault is not null || !liveSession.AwaitingNudgeInput) || motor || liveSession.Machine.Memory[0xC9]!=22 || liveSession.Machine.Memory[0xBE]!=2))throw new InvalidOperationException("TAKE bypassed the verified nudge completion boundary");
                if(!take && (!motor || liveSession.Snapshot().Board!.Visited.Count<3))throw new InvalidOperationException("START failed to roll from the nudge prompt");
                PauseLive();RenderLive();await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);SaveWindowImage(Path.Combine(directory,take ? "take-boundary.png" : "start-advance.png"));
            }
            if(!await LoadLive(startExecution:false) || liveSession!.Instructions!=0 || liveSession.Fault is not null)throw new InvalidOperationException("Restart retained availability state");
            File.WriteAllText(Path.Combine(directory,"result.txt"),"PASS: real-time ladder to computed nudge availability; actual pause/resume; mouse START generated a new roll/advance; mouse TAKE reached verified first-nudge completion boundary without invented nudges; released inputs, rendered output and restart.\n");Application.Current.Shutdown(0);
        }catch(Exception error){File.WriteAllText(Path.Combine(directory,"result.txt"),error.ToString());Application.Current.Shutdown(1);}
    }
}
