using System.Diagnostics;
using System.Globalization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;
using FruitMachineLab.Adders;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Diagnostics;

public partial class MainWindow
{
    private OutputPlayback? playback;
    private PlaybackTransport? transport;
    private readonly Stopwatch wallClock=new();
    private TimeSpan previousWallTime;
    private DispatcherTimer? playbackTimer;
    private bool updatingPosition;
    private readonly List<(int Lamp,Border Tile)> lampTiles=new();
    private readonly Brush[] lampPalette=Enumerable.Range(0,101).Select(n=> {
        double t=n/100.0;var brush=new SolidColorBrush(Color.FromRgb((byte)(35+220*t),(byte)(39+155*t),(byte)(45+15*t)));brush.Freeze();return (Brush)brush;
    }).ToArray();
    private void InitializePlayback()
    {
        playbackTimer=new DispatcherTimer(DispatcherPriority.Render){Interval=TimeSpan.FromMilliseconds(16)};
        playbackTimer.Tick+=(_,_)=>{AdvanceWallTime();RenderPlayback();if(transport?.IsPlaying!=true)playbackTimer.Stop();};
        Closed+=(_,_)=>{playbackTimer.Stop();wallClock.Stop();};
        var args=Environment.GetCommandLineArgs();
        if(args.Length==3 && args[1]=="--playback-smoke-test")Loaded+=async(_,_)=>await PlaybackSmokeTest(args[2]);
    }
    private void ClearPlayback()
    {
        playbackTimer?.Stop();wallClock.Reset();playback=null;transport=null;
        PlayButton.IsEnabled=PauseButton.IsEnabled=RestartButton.IsEnabled=PlaybackPosition.IsEnabled=false;
        lampTiles.Clear();FeatureLamps.Children.Clear();AllLamps.Children.Clear();LiveAlpha.Text="                ";
        LiveAccounting.Text="Recorded input path • no player input required";PlaybackTime.Text="Preparing verified feature…";
        updatingPosition=true;PlaybackPosition.Value=0;updatingPosition=false;
    }
    private void SetPlayback(SkillCashPlaybackResult result)
    {
        playback=result.Output;transport=new(playback.DurationSeconds);
        PlayButton.IsEnabled=PauseButton.IsEnabled=RestartButton.IsEnabled=PlaybackPosition.IsEnabled=true;
        PlaybackPosition.Maximum=playback.DurationSeconds;
        foreach(int number in new[]{47,39,31,23,15,7,83,41})AddLamp(FeatureLamps,result.Lamps[number],true);
        foreach(var lamp in result.Lamps)AddLamp(AllLamps,lamp,false);
        SetSpeed();StartPlayback();
    }
    private void AddLamp(Panel panel,PlaybackLamp lamp,bool featured)
    {
        var label=new TextBlock{Text=$"{lamp.Caption}\n#{lamp.Number} / {lamp.LogicalId:X2}",TextWrapping=TextWrapping.Wrap,TextAlignment=TextAlignment.Center,
            Foreground=Brushes.White,FontSize=featured ? 14 : 11,Margin=new Thickness(4),VerticalAlignment=VerticalAlignment.Center};
        var tile=new Border{Child=label,CornerRadius=new CornerRadius(6),Background=lampPalette[0],Margin=new Thickness(3),MinHeight=featured ? 62 : 48,
            ToolTip=$"MAME lamp {lamp.Number}; ROM command {lamp.LogicalId:X2}. Caption from recovered mapping."};
        panel.Children.Add(tile);lampTiles.Add((lamp.Number,tile));
    }
    private void AdvanceWallTime()
    {
        var now=wallClock.Elapsed;transport?.Advance(now-previousWallTime);previousWallTime=now;
    }
    private void StartPlayback()
    {
        if(transport is null)return;transport.Play();wallClock.Restart();previousWallTime=TimeSpan.Zero;playbackTimer?.Start();RenderPlayback();
    }
    private void PlayPlayback(object sender,RoutedEventArgs args)=>StartPlayback();
    private void PausePlayback(object sender,RoutedEventArgs args)
    {
        AdvanceWallTime();transport?.Pause();playbackTimer?.Stop();RenderPlayback();
    }
    private void RestartPlayback(object sender,RoutedEventArgs args){transport?.Seek(0);StartPlayback();}
    private void SpeedChanged(object sender,SelectionChangedEventArgs args){if(transport is null)return;AdvanceWallTime();SetSpeed();RenderPlayback();}
    private void SetSpeed()
    {
        if(transport is not null && PlaybackSpeed.SelectedItem is ComboBoxItem choice)transport.Speed=double.Parse((string)choice.Tag,CultureInfo.InvariantCulture);
    }
    private void SeekPlayback(object sender,RoutedPropertyChangedEventArgs<double> args)
    {
        if(updatingPosition || transport is null)return;AdvanceWallTime();transport.Seek(args.NewValue);RenderPlayback();
    }
    private void RenderPlayback()
    {
        if(playback is null || transport is null)return;
        ulong cycle=transport.PositionSeconds>=transport.DurationSeconds ? playback.DurationCycles : (ulong)(transport.PositionSeconds*OutputPlayback.CpuCyclesPerSecond);
        var sample=playback.Sample(cycle);
        foreach(var tile in lampTiles) {
            // Eight-way scan normalization is a visualization gain, not a bulb model.
            int intensity=(int)Math.Round(Math.Clamp(sample.LampDuty[tile.Lamp]*8,0,1)*100);tile.Tile.Background=lampPalette[intensity];
            ((TextBlock)tile.Tile.Child).Foreground=intensity>=35 ? Brushes.Black : Brushes.White;
        }
        LiveAlpha.Text=sample.Alpha;
        LiveAccounting.Text=$"Pending {sample.Pending} • current win {sample.CurrentWin} ROM units • recorded inputs";
        PlaybackTime.Text=$"{(transport.IsPlaying ? "Playing" : transport.PositionSeconds>=transport.DurationSeconds ? "Finished" : "Paused")}  {transport.PositionSeconds:0.00} / {transport.DurationSeconds:0.00} s";
        updatingPosition=true;PlaybackPosition.Value=transport.PositionSeconds;updatingPosition=false;
        PlayButton.IsEnabled=!transport.IsPlaying;PauseButton.IsEnabled=transport.IsPlaying;
    }
}
