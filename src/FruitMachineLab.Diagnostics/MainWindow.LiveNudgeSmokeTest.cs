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
                byte[] before=[liveSession.Machine.Memory[0x169],liveSession.Machine.Memory[0x16B],liveSession.Machine.Memory[0x16D]];
                ResumeLive();buttons[reel].Focus();await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);NudgeSmokeKey(buttons[reel],true);await Task.Delay(100);NudgeSmokeKey(buttons[reel],false);
                if(liveSession.Fault?.StartsWith("BOARD nudge request accepted")!=true || liveSession.Panel.PhysicalBlack2!=0 || liveSession.Machine.Memory[0xBE]!=3)throw new InvalidOperationException($"Nudge request boundary failed: {Status.Text}; vm={liveSession.VmAddress:X4}, physical={liveSession.Panel.PhysicalBlack2:X2}, sampled={liveSession.Machine.Memory[3]:X2}, fault={liveSession.Fault}, ready={liveSession.AwaitingNudgeInput}");
                for(int n=0;n<3;n++)if(liveSession.Machine.Memory[0x169+2*n]!=unchecked((byte)(before[n]+(n==reel ? 1 : 0))))throw new InvalidOperationException("Wrong reel request changed");
                RenderLive();await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);SaveWindowImage(Path.Combine(directory,$"nudge-{reel+1}-accepted.png"));
            }
            if(!await LoadLive(startExecution:false) || liveSession!.Instructions!=0 || liveSession.Fault is not null)throw new InvalidOperationException("Restart retained nudge state");
            File.WriteAllText(Path.Combine(directory,"result.txt"),"PASS: all three momentary nudge keyboard handlers; actual recovered input scan, only selected reel request incremented, mouse-capture failure/loss release, VM/memory/time pause, unchanged count/accounting before motion, rendered prompt/request boundaries and clean restart. Main-reel motion remains explicitly bounded.\n");Application.Current.Shutdown(0);
        }catch(Exception error){File.WriteAllText(Path.Combine(directory,"result.txt"),error.ToString());Application.Current.Shutdown(1);}
    }
}
