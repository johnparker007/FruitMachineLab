using System.IO;
using System.Windows;
using System.Windows.Input;
using System.Windows.Threading;
namespace FruitMachineLab.Diagnostics;

public partial class MainWindow
{
    private async Task LiveRollSmokeTest(string directory)
    {
        ContinueBoardExecution.IsChecked=false;
        Directory.CreateDirectory(directory);
        try {
            LiveEntryMode.SelectedIndex=2;if(!await LoadLive(startExecution:false))throw new InvalidOperationException(Status.Text);
            byte position=liveSession!.Machine.Memory[0x16E];ResumeLive();await Task.Delay(150);
            PhysicalStartDown(PhysicalStart,new MouseButtonEventArgs(Mouse.PrimaryDevice,Environment.TickCount,MouseButton.Left){RoutedEvent=UIElement.PreviewMouseLeftButtonDownEvent});
            await Task.Delay(100);PhysicalStartUp(PhysicalStart,new MouseButtonEventArgs(Mouse.PrimaryDevice,Environment.TickCount,MouseButton.Left){RoutedEvent=UIElement.PreviewMouseLeftButtonUpEvent});
            var timeout=System.Diagnostics.Stopwatch.StartNew();bool sawMotion=false,sawRolling=false,checkedPause=false,checkedBoardPause=false;
            while(liveSession.Fault is null && !liveSession.Completed && timeout.Elapsed.TotalSeconds<10) {
                var moving=liveSession.Snapshot();sawMotion|=moving.DiceRequest?.Busy==true;sawRolling|=moving.Alpha.Contains("ROLLING");
                if(!checkedPause && moving.DiceRequest is {Busy:true} && moving.DiceRequest.PhysicalPosition!=position) {
                    PauseLive();var frozen=liveSession.Machine.Memory.ToArray();ulong cycle=liveSession.Cycle;int instructions=liveSession.Instructions;
                    RenderLive();await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);SaveWindowImage(Path.Combine(directory,"roll-paused.png"));
                    await Task.Delay(120);
                    if(cycle!=liveSession.Cycle || instructions!=liveSession.Instructions || !frozen.SequenceEqual(liveSession.Machine.Memory))throw new InvalidOperationException("Pause advanced the motor or VM");
                    ResumeLive();checkedPause=true;
                }
                if(!checkedBoardPause && moving.Board is { } board && board.Square>32 && liveSession.Fault is null) {
                    PauseLive();var frozen=liveSession.Machine.Memory.ToArray();ulong cycle=liveSession.Cycle;int instructions=liveSession.Instructions;
                    RenderLive();await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);SaveWindowImage(Path.Combine(directory,"board-paused.png"));
                    await Task.Delay(120);
                    if(cycle!=liveSession.Cycle || instructions!=liveSession.Instructions || !frozen.SequenceEqual(liveSession.Machine.Memory))throw new InvalidOperationException("Pause advanced board movement");
                    ResumeLive();checkedBoardPause=true;
                }
                await Task.Delay(10);
            }
            var state=liveSession.Snapshot();
            if(liveSession.Fault?.StartsWith("BOARD advance completed")!=true || state.DiceRequest is not { } request || request.PhysicalPosition==position || request.Busy || request.Symbol!=request.DisplayedSymbol || !sawMotion || !sawRolling || !checkedPause || !checkedBoardPause || state.Board is null || state.Board.Square!=32+request.Symbol || state.Board.Visited.Count!=request.Symbol+1 || liveSession.Panel.StartPressed || liveSession.Panel.TakePressed || liveSession.Completed)throw new InvalidOperationException("Roll did not complete at the declared next-dispatch boundary: "+state.Execution);
            RenderLive();await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);SaveWindowImage(Path.Combine(directory,"roll-completed.png"));
            if(!await LoadLive(startExecution:false) || liveSession!.Instructions!=0 || liveSession.Fault is not null || liveSession.Snapshot().DiceRequest is not null)throw new InvalidOperationException("Restart retained roll fault/request state");
            File.WriteAllText(Path.Combine(directory,"result.txt"),$"PASS: physical Start generated dice symbol {request.Symbol}, signed stop offset {request.StopOffset}; incremental physical position, actual motor/VM pause/resume, completed symbol, incremental board advance with mid-movement pause, next-dispatch stop, released inputs, rendered output and clean restart. Board square {state.Board!.Square}, nudge pot {state.Board.NudgePot}. Further board dispatch and whole-game play remain outside this milestone.\n");Application.Current.Shutdown(0);
        }catch(Exception error){File.WriteAllText(Path.Combine(directory,"result.txt"),error.ToString());Application.Current.Shutdown(1);}
    }
}
