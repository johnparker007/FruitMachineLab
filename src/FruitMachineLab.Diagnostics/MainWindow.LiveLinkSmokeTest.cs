using System.IO;
using System.Windows;
using System.Windows.Threading;
namespace FruitMachineLab.Diagnostics;

public partial class MainWindow
{
    private async Task LiveLinkSmokeTest(string directory)
    {
        ContinueBoardExecution.IsChecked=false;
        Directory.CreateDirectory(directory);
        try {
            foreach(string kind in new[]{"ladder","snake"}) {
                LiveEntryMode.SelectedIndex=kind=="ladder" ? 3 : 4;
                if(!await LoadLive(startExecution:false))throw new InvalidOperationException(Status.Text);
                ResumeLive();await Task.Delay(250);PauseLive();
                var frozen=liveSession!.Machine.Memory.ToArray();ulong cycle=liveSession.Cycle;int instructions=liveSession.Instructions;
                if(instructions==0 || liveSession.Fault is not null)throw new InvalidOperationException("Animation did not start: "+Status.Text);
                RenderLive();await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);SaveWindowImage(Path.Combine(directory,kind+"-paused.png"));
                await Task.Delay(120);
                if(cycle!=liveSession.Cycle || instructions!=liveSession.Instructions || !frozen.SequenceEqual(liveSession.Machine.Memory))throw new InvalidOperationException("Pause advanced live link execution");
                ResumeLive();var timeout=System.Diagnostics.Stopwatch.StartNew();
                while(liveSession.Fault is null && timeout.Elapsed.TotalSeconds<8)await Task.Delay(15);
                var board=liveSession.Snapshot().Board;
                if(liveSession.Fault?.StartsWith("BOARD "+kind+" completed")!=true || board?.Square!=(kind=="ladder" ? 22 : 7) || board.NudgePot!=(kind=="ladder" ? 3 : 1) || liveSession.Panel.StartPressed || liveSession.Panel.TakePressed || PhysicalTake.IsEnabled)throw new InvalidOperationException("Unexpected live link result: "+Status.Text);
                RenderLive();await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);SaveWindowImage(Path.Combine(directory,kind+"-completed.png"));
                if(!await LoadLive(startExecution:false) || liveSession!.Instructions!=0 || liveSession.Fault is not null)throw new InvalidOperationException("Restart retained link state");
            }
            File.WriteAllText(Path.Combine(directory,"result.txt"),"PASS: both natural link entries execute live; actual VM/memory/time pause and resume; ladder 2 to 22/pot3, snake41 to 7/pot1; rendered lamps/alpha, released inputs, disabled Take during animation and clean restart. Following board result remains explicit.\n");Application.Current.Shutdown(0);
        }catch(Exception error){File.WriteAllText(Path.Combine(directory,"result.txt"),error.ToString());Application.Current.Shutdown(1);}
    }
}
