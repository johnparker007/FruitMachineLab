using System.IO;
using System.Windows;
using System.Windows.Input;
using System.Windows.Threading;
namespace FruitMachineLab.Diagnostics;

public partial class MainWindow
{
    private async Task LiveBoardCycleSmokeTest(string directory)
    {
        Directory.CreateDirectory(directory);
        try {
            ContinueBoardExecution.IsChecked=true;LiveEntryMode.SelectedIndex=2;
            // Accelerated synthetic player timing finds the demonstrated 32→36
            // return. No state/outcome injection; all rolls execute normally.
            bool returned=false;
            foreach(int delay in new[]{0,50,100,200,400,800,1200,2000}) {
                if(!await LoadLive(startExecution:false))throw new InvalidOperationException(Status.Text);
                liveSession!.Resume();bool motorStarted=false;
                try{for(int n=0;n<30000 && liveSession.BoardPrompts<2;n++){if(!motorStarted && liveSession.Instructions>250+delay)liveSession.SetStart(true);liveSession.AdvanceCycles(512);motorStarted|=liveSession.Snapshot().DiceRequest?.Busy==true;if(motorStarted)liveSession.SetStart(false);}}
                catch(NotSupportedException error){if(!error.Message.StartsWith("BOARD result type"))throw;}
                liveSession.Pause();
                if(liveSession.BoardPrompts==2){liveSession.Resume();for(int n=0;n<1000 && !liveSession.AwaitingBoardSelection;n++)liveSession.AdvanceCycles(512);liveSession.Pause();returned=true;break;}
            }
            if(!returned || !liveSession!.AwaitingBoardSelection || liveSession.Machine.Memory[0xC9]!=36)throw new InvalidOperationException("No returned board prompt");
            PauseLive();ulong cycle=liveSession.Cycle;var frozen=liveSession.Machine.Memory.ToArray();
            RenderLive();await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);SaveWindowImage(Path.Combine(directory,"returned-prompt.png"));await Task.Delay(120);
            if(cycle!=liveSession.Cycle || !frozen.SequenceEqual(liveSession.Machine.Memory))throw new InvalidOperationException("Pause advanced returned prompt");
            ResumeLive();PhysicalStartDown(PhysicalStart,new MouseButtonEventArgs(Mouse.PrimaryDevice,Environment.TickCount,MouseButton.Left){RoutedEvent=UIElement.PreviewMouseLeftButtonDownEvent});await Task.Delay(100);
            PhysicalStartUp(PhysicalStart,new MouseButtonEventArgs(Mouse.PrimaryDevice,Environment.TickCount,MouseButton.Left){RoutedEvent=UIElement.PreviewMouseLeftButtonUpEvent});
            var timeout=System.Diagnostics.Stopwatch.StartNew();bool motor=false;int initialVisited=liveSession.Snapshot().Board!.Visited.Count;
            while(liveSession.Fault is null && liveSession.BoardPrompts<3 && timeout.Elapsed.TotalSeconds<10){motor|=liveSession.Snapshot().DiceRequest?.Busy==true;await Task.Delay(10);}
            if(!motor || liveSession.Panel.StartPressed || liveSession.Snapshot().Board!.Visited.Count<=initialVisited || (liveSession.Fault is not null && !liveSession.Fault.StartsWith("BOARD result type")))throw new InvalidOperationException("Returned START did not drive the recovered board: "+Status.Text);
            PauseLive();RenderLive();await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);SaveWindowImage(Path.Combine(directory,"next-advance.png"));
            if(!await LoadLive(startExecution:false) || liveSession!.BoardPrompts!=0 || liveSession.Fault is not null)throw new InvalidOperationException("Restart retained continuation state");
            File.WriteAllText(Path.Combine(directory,"result.txt"),"PASS: accelerated physical-input driver returned from 32 to 36; actual pause/resume, real-time physical mouse START press/release, new generated motor/board advance, explicit result boundary or repeated prompt, rendering and restart.\n");Application.Current.Shutdown(0);
        }catch(Exception error){File.WriteAllText(Path.Combine(directory,"result.txt"),error.ToString());Application.Current.Shutdown(1);}
    }
}
