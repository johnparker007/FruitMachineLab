using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Threading;
using FruitMachineLab.Adders;
namespace FruitMachineLab.Diagnostics;

public partial class MainWindow
{
    private SkillCashLiveSession? liveSession;
    private readonly Stopwatch liveWallClock=new();
    private TimeSpan liveLastWallTime;
    private DispatcherTimer? liveTimer;
    private readonly List<(int Lamp,Border Tile)> liveTiles=new();
    private void InitializeLive()
    {
        liveTimer=new DispatcherTimer(DispatcherPriority.Render){Interval=TimeSpan.FromMilliseconds(16)};
        liveTimer.Tick+=(_,_)=>{AdvanceLive();RenderLive();if(liveSession?.Paused!=false)liveTimer.Stop();};
        Deactivated+=(_,_)=>{AdvanceLive();ReleasePhysicalStart();ReleasePhysicalTake();RenderLive();};Closed+=(_,_)=>{PauseLive();liveWallClock.Stop();};
        var args=Environment.GetCommandLineArgs();
        if(args.Length==3 && args[1]=="--live-smoke-test")Loaded+=async(_,_)=>await LiveSmokeTest(args[2]);
        if(args.Length==3 && args[1]=="--live-jackpot-smoke-test")Loaded+=async(_,_)=>await LiveSmokeTest(args[2],true);
        if(args.Length==3 && args[1]=="--live-roll-smoke-test")Loaded+=async(_,_)=>await LiveRollSmokeTest(args[2]);
    }
    private async void BeginLive(object sender,RoutedEventArgs args)=>await LoadLive();
    private async Task<bool> LoadLive(bool startExecution=true)
    {
        PauseLive();transport?.Pause();playbackTimer?.Stop();
        BeginLiveButton.IsEnabled=RestartLiveButton.IsEnabled=LoadReplay.IsEnabled=false;string path=RootPath.Text;int entry=LiveEntryMode.SelectedIndex;
        try {
            Status.Text="Loading feature-entry state and recovered scripts…";
            liveSession=await Task.Run(()=>new SkillCashLiveSession(Path.Combine(path,"evidence","mpu4"),entry>=1,entry==2));
            liveTiles.Clear();SessionFeatureLamps.Children.Clear();SessionAllLamps.Children.Clear();SessionSelectionLamps.Children.Clear();
            foreach(byte id in liveSession.Machine.Memory[0x726F..0x7281])AddLamp(SessionSelectionLamps,liveSession.Lamps.Single(lamp=>lamp.LogicalId==id),false,liveTiles);
            foreach(int number in new[]{47,39,31,23,15,7,83,41})AddLamp(SessionFeatureLamps,liveSession.Lamps[number],true,liveTiles);
            foreach(var lamp in liveSession.Lamps)AddLamp(SessionAllLamps,lamp,false,liveTiles);
            Views.SelectedIndex=0;if(startExecution)ResumeLive();else RenderLive();
            Status.Text=liveSession.StartsAtBoardSelection ? "Board square 32: press and release TAKE FEATURE, then use START for the three Skill Cash selections. START at the board prompt reaches the unresolved dice-motion boundary." : "Live feature running. Press and release START to stop each selection. No recorded player events are applied.";return true;
        } catch(Exception error){Status.Text=error.Message;SessionDiagnostic.Text="Live feature unavailable: "+error.Message;liveSession=null;return false;}
        finally {BeginLiveButton.IsEnabled=LoadReplay.IsEnabled=true;RestartLiveButton.IsEnabled=liveSession is not null;}
    }
    private void AdvanceLive()
    {
        if(liveSession is null)return;var now=liveWallClock.Elapsed;var elapsed=now-liveLastWallTime;liveLastWallTime=now;
        try{liveSession.Advance(elapsed);}catch(Exception error){Status.Text="Live execution stopped: "+error.Message;ReleasePhysicalStart();ReleasePhysicalTake();liveTimer?.Stop();}
    }
    private void ResumeLive()
    {
        liveSession?.Resume();liveWallClock.Restart();liveLastWallTime=TimeSpan.Zero;
        if(liveSession?.Paused==false)liveTimer?.Start();RenderLive();
    }
    private void PauseLive()
    {
        AdvanceLive();liveSession?.Pause();liveTimer?.Stop();ReleasePhysicalStart();ReleasePhysicalTake();RenderLive();
    }
    private void PauseLiveClick(object sender,RoutedEventArgs args)=>PauseLive();
    private void ResumeLiveClick(object sender,RoutedEventArgs args)=>ResumeLive();
    private void ViewChanged(object sender,SelectionChangedEventArgs args)
    {
        if(!ReferenceEquals(args.OriginalSource,Views))return;
        if(Views.SelectedIndex!=0)PauseLive();
        if(Views.SelectedIndex!=1 && transport is not null){AdvanceWallTime();transport.Pause();playbackTimer?.Stop();RenderPlayback();}
    }
    private void PressPhysicalStart()
    {
        if(liveSession?.Paused!=false)return;AdvanceLive();liveSession.SetStart(true);PhysicalStart.Background=Brushes.Gold;RenderLive();
    }
    private void ReleasePhysicalStart()
    {
        liveSession?.SetStart(false);if(PhysicalStart is null)return;
        PhysicalStart.ClearValue(Control.BackgroundProperty);if(Mouse.Captured==PhysicalStart)PhysicalStart.ReleaseMouseCapture();
    }
    private void PhysicalStartDown(object sender,MouseButtonEventArgs args){PhysicalStart.Focus();PhysicalStart.CaptureMouse();PressPhysicalStart();args.Handled=true;}
    private void PhysicalStartUp(object sender,MouseButtonEventArgs args){AdvanceLive();ReleasePhysicalStart();RenderLive();args.Handled=true;}
    private void PhysicalStartCaptureLost(object sender,MouseEventArgs args){AdvanceLive();ReleasePhysicalStart();RenderLive();}
    private void PhysicalStartFocusLost(object sender,KeyboardFocusChangedEventArgs args){AdvanceLive();ReleasePhysicalStart();RenderLive();}
    private void PhysicalStartKeyDown(object sender,KeyEventArgs args){if(args.Key is Key.Space or Key.Enter){if(!args.IsRepeat)PressPhysicalStart();args.Handled=true;}}
    private void PhysicalStartKeyUp(object sender,KeyEventArgs args){if(args.Key is Key.Space or Key.Enter){AdvanceLive();ReleasePhysicalStart();RenderLive();args.Handled=true;}}
    private void ReleasePhysicalTake()
    {
        liveSession?.SetTake(false);if(PhysicalTake is null)return;PhysicalTake.ClearValue(Control.BackgroundProperty);
        if(Mouse.Captured==PhysicalTake)PhysicalTake.ReleaseMouseCapture();
    }
    private void PressPhysicalTake(){if(liveSession?.Paused!=false)return;AdvanceLive();liveSession.SetTake(true);PhysicalTake.Background=Brushes.Gold;RenderLive();}
    private void PhysicalTakeDown(object sender,MouseButtonEventArgs args){PhysicalTake.Focus();PhysicalTake.CaptureMouse();PressPhysicalTake();args.Handled=true;}
    private void PhysicalTakeUp(object sender,MouseButtonEventArgs args){AdvanceLive();ReleasePhysicalTake();RenderLive();args.Handled=true;}
    private void PhysicalTakeCaptureLost(object sender,MouseEventArgs args){AdvanceLive();ReleasePhysicalTake();RenderLive();}
    private void PhysicalTakeFocusLost(object sender,KeyboardFocusChangedEventArgs args){AdvanceLive();ReleasePhysicalTake();RenderLive();}
    private void PhysicalTakeKeyDown(object sender,KeyEventArgs args){if(args.Key is Key.Space or Key.Enter){if(!args.IsRepeat)PressPhysicalTake();args.Handled=true;}}
    private void PhysicalTakeKeyUp(object sender,KeyEventArgs args){if(args.Key is Key.Space or Key.Enter){AdvanceLive();ReleasePhysicalTake();RenderLive();args.Handled=true;}}
    private void RenderLive()
    {
        if(liveSession is null)return;var state=liveSession.Snapshot();
        SessionAlpha.Text=state.Alpha;
        SessionDiagnostic.Text=$"{state.Execution}\nVirtual {state.Cycle/SkillCashLiveSession.CyclesPerSecond:0.000} s · VM {state.VmAddress:X4} · dispatches {state.Instructions:N0}\nBLACK2 physical {state.PhysicalBlack2:X2} / sampled {state.SampledBlack2:X2} · latch {state.PanelLatch:X4} · choice {state.Choice}";
        SessionAccounting.Text=$"Pending {state.Pending} • current win {state.CurrentWin} ROM units • accepted selections {string.Join(", ",state.Selections)}";
        SessionDice.Text=state.DiceRequest is { } dice ? $"Prepared dice request: symbol {dice.Symbol}, stop offset {dice.StopOffset}, physical position {dice.PhysicalPosition}. Motor motion has not started." : "";
        foreach(var tile in liveTiles) {
            int intensity=(int)Math.Round(Math.Clamp(state.LampDuty[tile.Lamp]*8,0,1)*100);tile.Tile.Background=lampPalette[intensity];((TextBlock)tile.Tile.Child).Foreground=intensity>=35 ? Brushes.Black : Brushes.White;
        }
        bool running=!liveSession.Paused && !liveSession.Completed && liveSession.Fault is null;
        PhysicalStart.IsEnabled=PauseLiveButton.IsEnabled=running;ResumeLiveButton.IsEnabled=!running && !liveSession.Completed && liveSession.Fault is null;
        PhysicalTake.IsEnabled=running && liveSession.AwaitingBoardSelection;
        if(!running){ReleasePhysicalStart();ReleasePhysicalTake();}
    }
}
