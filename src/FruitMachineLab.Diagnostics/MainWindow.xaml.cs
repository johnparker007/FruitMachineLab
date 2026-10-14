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
            var result=await Task.Run(()=>SkillCashReplay.Run(Path.Combine(repository,"evidence","mpu4")));
            Events.ItemsSource=result.Events;
            Status.Text=$"Verified level {result.Level}, pending award {result.PendingAward} ROM units. Complete feature execution is still pending.";
        } catch(Exception error) { Events.ItemsSource=null; Status.Text=error.Message; }
        finally {button.IsEnabled=true;}
    }
}
