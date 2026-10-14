using System.IO;
using System.Windows;
using FruitMachineLab.Adders;
namespace FruitMachineLab.Diagnostics;
public partial class MainWindow : Window
{
    public MainWindow() { InitializeComponent(); RootPath.Text=RepositoryLocation.Find(Directory.GetCurrentDirectory(),AppContext.BaseDirectory); }
    private async void Replay(object sender,RoutedEventArgs args)
    {
        var button=(System.Windows.Controls.Button)sender;
        button.IsEnabled=false;Status.Text="Verifying recovered scripts and recorded state…";
        string repository=RootPath.Text;
        try {
            var result=await Task.Run(()=> {
                string evidence=Path.Combine(repository,"evidence","mpu4");
                SkillCashSoundVerification.VerifyFeature(evidence);
                SkillCashLampFrameVerification.Verify(evidence);
                return SkillCashFeatureReplay.Run(evidence);
            });
            Events.ItemsSource=result.Events;
            Status.Text=$"Verified continuous feature replay: level {result.Level}, final pending {result.Pending}, current win {result.CurrentWin} ROM units; {result.Instructions:N0} VM dispatches. Lamp frame buffers and sound timing match MAME. Physical display, lamp scanning and audio synthesis remain incomplete.";
        } catch(Exception error) { Events.ItemsSource=null; Status.Text=error.Message; }
        finally {button.IsEnabled=true;}
    }
}
