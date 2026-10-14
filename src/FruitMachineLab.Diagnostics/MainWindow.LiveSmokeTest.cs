using System.IO;
using System.Windows;
using System.Windows.Input;
using System.Windows.Threading;
namespace FruitMachineLab.Diagnostics;

public partial class MainWindow
{
    private async Task LiveSmokeTest(string directory)
    {
        Directory.CreateDirectory(directory);
        try {
            if(!await LoadLive())throw new InvalidOperationException(Status.Text);
            if(liveSession!.Instructions!=0 || liveSession.AlphaOperations!=0)throw new InvalidOperationException("Live load pre-executed the feature");
            await Task.Delay(200);PauseLive();
            ulong cycle=liveSession.Cycle;int instructions=liveSession.Instructions;var memory=liveSession.Machine.Memory.ToArray();
            await Task.Delay(100);
            if(liveSession.Cycle!=cycle || liveSession.Instructions!=instructions || !memory.SequenceEqual(liveSession.Machine.Memory))throw new InvalidOperationException("Paused live VM advanced");
            ResumeLive();await Task.Delay(50);
            if(liveSession.Cycle<=cycle || liveSession.Instructions<=instructions)throw new InvalidOperationException("Resume did not continue live execution");
            PhysicalStartDown(PhysicalStart,new MouseButtonEventArgs(Mouse.PrimaryDevice,Environment.TickCount,MouseButton.Left){RoutedEvent=UIElement.PreviewMouseLeftButtonDownEvent});
            if(!liveSession.Panel.StartPressed)throw new InvalidOperationException("Physical mouse-down did not press Start");
            PhysicalStartCaptureLost(PhysicalStart,new MouseEventArgs(Mouse.PrimaryDevice,Environment.TickCount));
            if(liveSession.Panel.StartPressed)throw new InvalidOperationException("Lost capture left Start held");
            PressPhysicalStart();PhysicalStartFocusLost(PhysicalStart,new KeyboardFocusChangedEventArgs(Keyboard.PrimaryDevice,Environment.TickCount,PhysicalStart,null));
            if(liveSession.Panel.StartPressed)throw new InvalidOperationException("Lost keyboard focus left Start held");
            // Restart after this synthetic focus/capture exercise. The remaining
            // run supplies only physical Start events while the actual timer runs.
            if(!await LoadLive())throw new InvalidOperationException(Status.Text);
            ushort[] choices=[3,2,1];int stage=0;bool pressed=false;
            var timeout=System.Diagnostics.Stopwatch.StartNew();
            while(!liveSession!.Completed && liveSession.Fault is null && timeout.Elapsed.TotalSeconds<30) {
                if(stage<choices.Length && !pressed && liveSession.Machine.Memory[0x4F]==choices[stage]) {
                    PhysicalStartDown(PhysicalStart,new MouseButtonEventArgs(Mouse.PrimaryDevice,Environment.TickCount,MouseButton.Left){RoutedEvent=UIElement.PreviewMouseLeftButtonDownEvent});pressed=true;
                }
                if(pressed && liveSession.Selections.Count>stage) {
                    PhysicalStartUp(PhysicalStart,new MouseButtonEventArgs(Mouse.PrimaryDevice,Environment.TickCount,MouseButton.Left){RoutedEvent=UIElement.PreviewMouseLeftButtonUpEvent});pressed=false;stage++;
                }
                if(stage==1 && !File.Exists(Path.Combine(directory,"live.png"))) {
                    await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);SaveWindowImage(Path.Combine(directory,"live.png"));
                    Width=800;Height=650;await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);SaveWindowImage(Path.Combine(directory,"live-small.png"));
                    Width=1100;Height=850;
                }
                await Task.Delay(5);
            }
            if(!liveSession.Completed || liveSession.Fault is not null || liveSession.Selections.Count!=3 || liveSession.Machine.ReadWord(0x2FA)!=10 || liveSession.Panel.StartPressed)
                throw new InvalidOperationException("Live WPF run failed: "+liveSession.Snapshot().Execution+" choices "+string.Join(',',liveSession.Selections));
            RenderLive();await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);SaveWindowImage(Path.Combine(directory,"live-completed.png"));
            if(!await LoadLive() || liveSession!.Instructions!=0)throw new InvalidOperationException("Restart did not restore feature-entry state");
            PauseLive();File.WriteAllText(Path.Combine(directory,"result.txt"),"PASS: no precomputed execution, actual pause/resume, physical mouse press/release, capture-loss release, live player selections, award completion, restart, WPF renders.\n");
            Application.Current.Shutdown(0);
        } catch(Exception error){File.WriteAllText(Path.Combine(directory,"result.txt"),error.ToString());Application.Current.Shutdown(1);}
    }
}
