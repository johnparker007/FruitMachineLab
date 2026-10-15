using System.IO;
using System.Windows;
using System.Windows.Input;
using System.Windows.Threading;
namespace FruitMachineLab.Diagnostics;

public partial class MainWindow
{
    private async Task LiveRollSmokeTest(string directory)
    {
        Directory.CreateDirectory(directory);
        try {
            LiveEntryMode.SelectedIndex=2;if(!await LoadLive(startExecution:false))throw new InvalidOperationException(Status.Text);
            byte position=liveSession!.Machine.Memory[0x16E];ResumeLive();await Task.Delay(150);
            PhysicalStartDown(PhysicalStart,new MouseButtonEventArgs(Mouse.PrimaryDevice,Environment.TickCount,MouseButton.Left){RoutedEvent=UIElement.PreviewMouseLeftButtonDownEvent});
            await Task.Delay(100);PhysicalStartUp(PhysicalStart,new MouseButtonEventArgs(Mouse.PrimaryDevice,Environment.TickCount,MouseButton.Left){RoutedEvent=UIElement.PreviewMouseLeftButtonUpEvent});
            var timeout=System.Diagnostics.Stopwatch.StartNew();while(liveSession.Fault is null && !liveSession.Completed && timeout.Elapsed.TotalSeconds<10)await Task.Delay(10);
            var state=liveSession.Snapshot();
            if(liveSession.Fault?.StartsWith("ROLL requested")!=true || state.DiceRequest is not { } request || request.PhysicalPosition!=position || !state.Alpha.Contains("ROLLING") || liveSession.Panel.StartPressed || liveSession.Panel.TakePressed || liveSession.Completed)throw new InvalidOperationException("Roll request did not stop at the declared physical motion boundary: "+state.Execution);
            RenderLive();await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);SaveWindowImage(Path.Combine(directory,"roll-request.png"));
            if(!await LoadLive(startExecution:false) || liveSession!.Instructions!=0 || liveSession.Fault is not null || liveSession.Snapshot().DiceRequest is not null)throw new InvalidOperationException("Restart retained roll fault/request state");
            File.WriteAllText(Path.Combine(directory,"result.txt"),$"PASS: physical Start generated dice symbol {request.Symbol}, signed stop offset {request.StopOffset}; unchanged physical position, explicit 61F6 stop, released inputs, rendered output and clean restart. No physical motion or full-board play is claimed.\n");Application.Current.Shutdown(0);
        }catch(Exception error){File.WriteAllText(Path.Combine(directory,"result.txt"),error.ToString());Application.Current.Shutdown(1);}
    }
}
