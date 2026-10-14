using System.IO;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
namespace FruitMachineLab.Diagnostics;

public partial class MainWindow
{
    // Opt-in local WPF smoke mode. Runs the real load/control/render path, saves
    // rendered window pixels, and exits with status; normal launches are unchanged.
    private async Task PlaybackSmokeTest(string directory)
    {
        try {
            if(!await LoadFeature())throw new InvalidOperationException(Status.Text);
            await Task.Delay(250);
            if(transport is null || transport.PositionSeconds<=0 || !transport.IsPlaying)throw new InvalidOperationException("Playback timer did not advance");
            PausePlayback(this,new RoutedEventArgs());double paused=transport.PositionSeconds;
            await Task.Delay(80);if(transport.PositionSeconds!=paused)throw new InvalidOperationException("Paused position advanced");
            PlaybackPosition.Value=4;
            if(transport.PositionSeconds!=4)throw new InvalidOperationException("Seek control did not update transport");
            PlaybackSpeed.SelectedIndex=3;if(transport.Speed!=2)throw new InvalidOperationException("Speed control did not update transport");
            RestartPlayback(this,new RoutedEventArgs());await Task.Delay(120);PausePlayback(this,new RoutedEventArgs());
            if(transport.PositionSeconds<0.15)throw new InvalidOperationException("Restart/speed playback did not advance");
            PlaybackSpeed.SelectedIndex=2;RestartPlayback(this,new RoutedEventArgs());
            var realtime=System.Diagnostics.Stopwatch.StartNew();
            while(transport.IsPlaying && realtime.Elapsed.TotalSeconds<20)await Task.Delay(50);
            realtime.Stop();
            if(transport.IsPlaying || transport.PositionSeconds!=playback!.DurationSeconds || Math.Abs(realtime.Elapsed.TotalSeconds-playback.DurationSeconds)>0.5)
                throw new InvalidOperationException("Complete 1× playback did not finish at captured duration");
            Directory.CreateDirectory(directory);
            // Choose a lit award-strip sample from actual calculated latch output.
            double position=Enumerable.Range(1,200).Select(n=>playback!.DurationSeconds*n/200)
                .First(seconds=>playback!.Sample((ulong)(seconds*FruitMachineLab.Runtime.OutputPlayback.CpuCyclesPerSecond)).LampDuty[47]>0.03);
            PlaybackPosition.Value=position;
            await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);
            SaveWindowImage(Path.Combine(directory,"playback.png"));
            Width=800;Height=650;await Dispatcher.InvokeAsync(()=>{},DispatcherPriority.ApplicationIdle);
            SaveWindowImage(Path.Combine(directory,"playback-small.png"));
            PlaybackPosition.Value=playback!.DurationSeconds;PlayPlayback(this,new RoutedEventArgs());
            if(!transport.IsPlaying || transport.PositionSeconds!=0)throw new InvalidOperationException("Play did not restart completed feature");
            File.WriteAllText(Path.Combine(directory,"result.txt"),$"PASS: verified load, timer advance, pause, seek, speed, restart, complete 1× playback ({realtime.Elapsed.TotalSeconds:0.000} s wall time / {playback.DurationSeconds:0.000} s captured), end restart and two WPF renders.\n");
            Application.Current.Shutdown(0);
        } catch(Exception error) {
            Directory.CreateDirectory(directory);File.WriteAllText(Path.Combine(directory,"result.txt"),error.ToString());Application.Current.Shutdown(1);
        }
    }
    private void SaveWindowImage(string path)
    {
        UpdateLayout();var bitmap=new RenderTargetBitmap((int)ActualWidth,(int)ActualHeight,96,96,PixelFormats.Pbgra32);bitmap.Render(this);
        var png=new PngBitmapEncoder();png.Frames.Add(BitmapFrame.Create(bitmap));using var file=File.Create(path);png.Save(file);
    }
}
