using System.IO;
using System.Windows;
using FruitMachineLab.Adders;
namespace FruitMachineLab.Diagnostics;
public partial class MainWindow : Window
{
    private sealed record AlphaRow(int Frame,string Site,string ReferenceClock,ushort Pending,ushort CurrentWin,string Text);
    private sealed record ScanRow(int Scan,string ReferenceClock,byte Phase,ushort Column,string LampLow,string LampHigh,string Digit,string Selectors);
    public MainWindow() { InitializeComponent(); RootPath.Text=RepositoryLocation.Find(Directory.GetCurrentDirectory(),AppContext.BaseDirectory); }
    private async void Replay(object sender,RoutedEventArgs args)
    {
        var button=(System.Windows.Controls.Button)sender;
        button.IsEnabled=false;Status.Text="Verifying recovered scripts and recorded state…";
        string repository=RootPath.Text;
        try {
            var verified=await Task.Run(()=> {
                string evidence=Path.Combine(repository,"evidence","mpu4");
                SkillCashSoundVerification.VerifyFeature(evidence);
                SkillCashLampFrameVerification.Verify(evidence);
                var scans=SkillCashOutputScanVerification.Verify(evidence);
                return (Feature:SkillCashFeatureReplay.Run(evidence),Scans:scans);
            });
            var result=verified.Feature;
            Events.ItemsSource=result.Events;
            AlphaTimeline.ItemsSource=result.AlphaFrames.Select((frame,index)=>new AlphaRow(index+1,frame.Site.ToString("X4"),frame.Clock.ToString("X4"),frame.Pending,frame.CurrentWin,frame.State.Text)).ToArray();
            AlphaTimeline.SelectedIndex=result.AlphaFrames.Count-1;
            ScanTimeline.ItemsSource=verified.Scans.Frames.Select(frame=>new ScanRow(frame.Ordinal+1,frame.ReferenceClock.ToString("X4"),frame.State.Phase,frame.State.Column,
                frame.State.Ports[..2],frame.State.Ports.Substring(2,2),frame.State.Ports.Substring(4,2),frame.State.Ports[6..])).ToArray();
            Status.Text=$"Verified level {result.Level}, final pending {result.Pending}, current win {result.CurrentWin} ROM units; {result.Instructions:N0} VM dispatches and {verified.Scans.Scans:N0} output scans. Alpha software state/serial bytes, lamp frame buffers and sound timing match MAME.";
        } catch(Exception error) { Events.ItemsSource=null;AlphaTimeline.ItemsSource=null;ScanTimeline.ItemsSource=null;AlphaPreview.Text=""; Status.Text=error.Message; }
        finally {button.IsEnabled=true;}
    }
    private void AlphaSelected(object sender,System.Windows.Controls.SelectionChangedEventArgs args)
    {
        if(AlphaTimeline.SelectedItem is AlphaRow row)AlphaPreview.Text=row.Text;
    }
}
