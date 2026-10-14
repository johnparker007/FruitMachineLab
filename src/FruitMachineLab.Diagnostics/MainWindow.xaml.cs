using System.IO;
using System.Windows;
using FruitMachineLab.Adders;
namespace FruitMachineLab.Diagnostics;
public partial class MainWindow : Window
{
    private sealed record AlphaRow(int Frame,string Site,string ReferenceClock,ushort Pending,ushort CurrentWin,string Text);
    private sealed record ScanRow(int Event,ulong CapturedCycleOffset,string Kind,byte Phase,ushort Column,string LampLow,string LampHigh,string Digit,string Selectors);
    public MainWindow() { InitializeComponent(); RootPath.Text=RepositoryLocation.Find(Directory.GetCurrentDirectory(),AppContext.BaseDirectory); InitializePlayback();InitializeLive(); }
    private async void Replay(object sender,RoutedEventArgs args)=>await LoadFeature();
    private async Task<bool> LoadFeature()
    {
        var button=LoadReplay;
        button.IsEnabled=false;BeginLiveButton.IsEnabled=RestartLiveButton.IsEnabled=false;PauseLive();ClearPlayback();Status.Text="Verifying recovered scripts and preparing playback…";
        string repository=RootPath.Text;
        try {
            var verified=await Task.Run(()=> {
                string evidence=Path.Combine(repository,"evidence","mpu4");
                return SkillCashPlayback.Load(evidence);
            });
            var result=verified.Verification.Feature;
            Events.ItemsSource=result.Events;
            AlphaTimeline.ItemsSource=result.AlphaFrames.Select((frame,index)=>new AlphaRow(index+1,frame.Site.ToString("X4"),frame.Clock.ToString("X4"),frame.Pending,frame.CurrentWin,frame.State.Text)).ToArray();
            AlphaTimeline.SelectedIndex=result.AlphaFrames.Count-1;
            ScanTimeline.ItemsSource=verified.Verification.Outputs.Select(frame=>new ScanRow(frame.Sequence+1,frame.CycleOffset,frame.Kind,frame.Phase,frame.Column,
                frame.Ports[..2],frame.Ports.Substring(2,2),frame.Ports.Substring(4,2),frame.Ports[6..])).ToArray();
            Views.SelectedIndex=1;SetPlayback(verified);
            Status.Text=$"Verified {result.Instructions:N0} VM dispatches, {verified.Verification.Scans:N0} scans and {verified.Verification.Callbacks:N0} callbacks. Playing the recorded path; 1× follows captured machine time.";
            return true;
        } catch(Exception error) { Events.ItemsSource=null;AlphaTimeline.ItemsSource=null;ScanTimeline.ItemsSource=null;AlphaPreview.Text=""; Status.Text=error.Message;PlaybackTime.Text="Playback unavailable";return false; }
        finally {button.IsEnabled=BeginLiveButton.IsEnabled=true;RestartLiveButton.IsEnabled=liveSession is not null;}
    }
    private void AlphaSelected(object sender,System.Windows.Controls.SelectionChangedEventArgs args)
    {
        if(AlphaTimeline.SelectedItem is AlphaRow row)AlphaPreview.Text=row.Text;
    }
}
