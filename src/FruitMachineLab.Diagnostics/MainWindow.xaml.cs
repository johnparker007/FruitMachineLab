using System.IO;
using System.Windows;
using FruitMachineLab.Adders;
namespace FruitMachineLab.Diagnostics;
public partial class MainWindow : Window
{
    public MainWindow() { InitializeComponent(); RootPath.Text=Directory.GetCurrentDirectory(); }
    private void Replay(object sender,RoutedEventArgs args)
    {
        try {
            var result=SkillCashReplay.Run(Path.Combine(RootPath.Text,"evidence","mpu4"));
            Events.ItemsSource=result.Events;
            Status.Text=$"Verified level {result.Level}, pending award {result.PendingAward} ROM units. Complete feature execution is still pending.";
        } catch(Exception error) { Events.ItemsSource=null; Status.Text=error.Message; }
    }
}
