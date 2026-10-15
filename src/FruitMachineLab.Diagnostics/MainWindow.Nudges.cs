using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
namespace FruitMachineLab.Diagnostics;

public partial class MainWindow
{
    private void ReleaseNudges()
    {
        foreach(var button in new[]{Nudge1,Nudge2,Nudge3}) {
            if(button is null)continue;liveSession?.SetNudge(int.Parse((string)button.Tag),false);
            if(Mouse.Captured==button)button.ReleaseMouseCapture();
        }
    }
    private void NudgeDown(object sender,MouseButtonEventArgs e)
    {
        var button=(Button)sender;AdvanceLive();button.Focus();liveSession?.SetNudge(int.Parse((string)button.Tag),true);if(!button.CaptureMouse())ReleaseNudges();RenderLive();e.Handled=true;
    }
    private void NudgeUp(object sender,MouseButtonEventArgs e){AdvanceLive();ReleaseNudges();RenderLive();e.Handled=true;}
    private void NudgeCaptureLost(object sender,MouseEventArgs e){ReleaseNudges();}
    private void NudgeFocusLost(object sender,KeyboardFocusChangedEventArgs e){AdvanceLive();ReleaseNudges();RenderLive();}
    private void NudgeKeyDown(object sender,KeyEventArgs e){if(e.Key is Key.Space or Key.Enter){if(!e.IsRepeat){AdvanceLive();liveSession?.SetNudge(int.Parse((string)((Button)sender).Tag),true);RenderLive();}e.Handled=true;}}
    private void NudgeKeyUp(object sender,KeyEventArgs e){if(e.Key is Key.Space or Key.Enter){AdvanceLive();ReleaseNudges();RenderLive();e.Handled=true;}}
}
