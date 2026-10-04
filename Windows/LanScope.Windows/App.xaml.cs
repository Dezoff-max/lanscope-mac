using System.Windows;
using System.Windows.Media;
using LanScope.Core.Models;
using Microsoft.Win32;

namespace LanScope.Windows;

public partial class App : Application
{
    public static void ApplyTheme(AppTheme theme)
    {
        var dark = theme == AppTheme.Dark || (theme == AppTheme.System && IsSystemDark());
        SetBrush("AppBackgroundBrush", dark ? "#0F172A" : "#F5F7FA");
        SetBrush("PanelBrush", dark ? "#182235" : "#FFFFFF");
        SetBrush("PanelAltBrush", dark ? "#202C42" : "#F1F4F8");
        SetBrush("TextBrush", dark ? "#EEF3FA" : "#18202D");
        SetBrush("MutedTextBrush", dark ? "#AAB6C8" : "#647084");
        SetBrush("BorderBrush", dark ? "#334155" : "#DDE3EC");
        SetBrush("AccentSoftBrush", dark ? "#1E3A5F" : "#DBEAFE");
    }

    private static void SetBrush(string key, string color) =>
        Current.Resources[key] = new SolidColorBrush((Color)ColorConverter.ConvertFromString(color));

    private static bool IsSystemDark()
    {
        try
        {
            var value = Registry.GetValue(
                @"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize",
                "AppsUseLightTheme", 1);
            return value is int number && number == 0;
        }
        catch { return false; }
    }
}
