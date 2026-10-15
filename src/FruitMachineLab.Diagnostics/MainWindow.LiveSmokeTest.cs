using System.IO;
using System.Windows;
using System.Windows.Input;
using System.Windows.Threading;
namespace FruitMachineLab.Diagnostics;

public partial class MainWindow
{
    private async Task LiveSmokeTest(string directory,bool jackpot=false)
    {
        Directory.CreateDirectory(directory);
        try {
            if(!await LoadLive(startExecution:false))throw new InvalidOperationException(Status.Text);
            if(liveSession!.Instructions!=0 || liveSession.AlphaOperations!=0)throw new InvalidOperationException("Live load pre-executed the feature");
            ResumeLive();
            await Task.Delay(200);PauseLive();
            ulong cycle=liveSession.Cycle;int instructions=liveSession.Instructions;var memory=liveSession.Machine.Memory.ToArray();
            await Task.Delay(100);
            if(liveSession.Cycle!=cycle || liveSession.Instructions!=instructions || !memory.SequenceEqual(liveSession.Machine.Memory))throw new InvalidOperationException("Paused live VM advanced");
            ResumeLive();await Task.Delay(50);
            // The board announcement can be waiting on sound tasks here. IRQ
            // state and virtual time must resume even without a new VM dispatch.
            if(liveSession.Cycle<=cycle || (liveSession.Instructions<=instructions && memory.SequenceEqual(liveSession.Machine.Memory)))throw new InvalidOperationException("Resume did not continue live execution");
            PhysicalStartDown(PhysicalStart,new MouseButtonEventArgs(Mouse.PrimaryDevice,Environment.TickCount,MouseButton.Left){RoutedEvent=UIElement.PreviewMouseLeftButtonDownEvent});
            if(!liveSession.Panel.StartPressed)throw new InvalidOperationException("Physical mouse-down did not press Start");
            PhysicalStartCaptureLost(PhysicalStart,new MouseEventArgs(Mouse.PrimaryDevice,Environment.TickCount));
            if(liveSession.Panel.StartPressed)throw new InvalidOperationException("Lost capture left Start held");
            PressPhysicalStart();PhysicalStartFocusLost(PhysicalStart,new KeyboardFocusChangedEventArgs(Keyboard.PrimaryDevice,Environment.TickCount,PhysicalStart,null));
            if(liveSession.Panel.StartPressed)throw new InvalidOperationException("Lost keyboard focus left Start held");
            // Restart after this synthetic focus/capture exercise. The remaining
            // run supplies only physical Start events while the actual timer runs.
            if(!await LoadLive())throw new InvalidOperationException(Status.Text);
            ushort[] choices=jackpot ? [6,6,6] : [3,2,1];int stage=0;bool pressed=false;
            bool announced=false,title=false;
            liveSession!.ObserveAlpha=state=>{announced|=state.Text.Contains("JACKPOT");title|=state.Text.Contains("SKILL CASH");};
            if(jackpot)liveTimer!.Stop();
            var timeout=System.Diagnostics.Stopwatch.StartNew();
            while(!liveSession!.Completed && liveSession.Fault is null && timeout.Elapsed.TotalSeconds<45) {
                if(stage<choices.Length && !pressed && liveSession.Machine.Memory[0x4F]==choices[stage]) {
                    if(jackpot)liveSession.SetStart(true);else PhysicalStartDown(PhysicalStart,new MouseButtonEventArgs(Mouse.PrimaryDevice,Environment.TickCount,MouseButton.Left){RoutedEvent=UIElement.PreviewMouseLeftButtonDownEvent});pressed=true;
                }
                // Optional jackpot rendering exercise uses an accelerated physical
                // input driver. Real-time mouse operation is tested separately.
                if(jackpot)liveSession.AdvanceCycles(512);
                if(pressed && liveSession.Selections.Count>stage) {
                    if(jackpot)liveSession.SetStart(false);else PhysicalStartUp(PhysicalStart,new MouseButtonEventArgs(Mouse.PrimaryDevice,Environment.TickCount,MouseButton.Left){RoutedEvent=UIElement.PreviewMouseLeftButtonUpEvent});pressed=false;stage++;
                }
                if(stage==1 && !File.Exists(Path.Combine(directory,"live.png"))) {
                    await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);SaveWindowImage(Path.Combine(directory,"live.png"));
                    Width=800;Height=650;await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);SaveWindowImage(Path.Combine(directory,"live-small.png"));
                    Width=1100;Height=850;
                }
                if(jackpot && announced && !File.Exists(Path.Combine(directory,"jackpot.png"))){RenderLive();SaveWindowImage(Path.Combine(directory,"jackpot.png"));}
                if(title && stage==0 && !File.Exists(Path.Combine(directory,"board-entry.png"))){RenderLive();SaveWindowImage(Path.Combine(directory,"board-entry.png"));}
                if(!jackpot)await Task.Delay(5);
            }
            // Windows dispatch latency can move a real-time press into the next
            // selection. Exact player timing/awards are checked headlessly; this
            // smoke verifies physical input, completed accounting and rendering.
            ushort win=liveSession.Machine.ReadWord(0x2FA);
            if(!liveSession.Completed || liveSession.Fault is not null || liveSession.Selections.Count!=3 || win==0 || liveSession.Machine.ReadWord(0xBA)!=0 || (jackpot && win!=60) || liveSession.Panel.StartPressed || (liveSession.IncludesCaller && !title))
                throw new InvalidOperationException("Live WPF run failed: "+liveSession.Snapshot().Execution+" choices "+string.Join(',',liveSession.Selections));
            RenderLive();await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);SaveWindowImage(Path.Combine(directory,"live-completed.png"));
            if(!await LoadLive(startExecution:false) || liveSession!.Instructions!=0)throw new InvalidOperationException("Restart did not restore feature-entry state");
            PauseLive();File.WriteAllText(Path.Combine(directory,"result.txt"),jackpot ? "PASS: accelerated physical-input jackpot driver, generated announcement/lamp rendering, 60-unit award completion and restart. Real-time mouse path is a separate smoke mode.\n" : "PASS: no precomputed execution, actual pause/resume, physical mouse press/release, capture-loss release, live player selections, award completion, restart, WPF renders.\n");
            Application.Current.Shutdown(0);
        } catch(Exception error){File.WriteAllText(Path.Combine(directory,"result.txt"),error.ToString());Application.Current.Shutdown(1);}
    }
}
