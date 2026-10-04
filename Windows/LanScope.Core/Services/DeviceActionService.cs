using System.Diagnostics;
using LanScope.Core.Models;

namespace LanScope.Core.Services;

public static class DeviceActionService
{
    public static void OpenBrowser(Device device)
    {
        var scheme = device.OpenPorts.Contains(443) ? "https" : "http";
        var port = device.OpenPorts.Contains(8080) && !device.OpenPorts.Contains(80) && !device.OpenPorts.Contains(443) ? ":8080" : "";
        OpenShell($"{scheme}://{device.IpAddress}{port}");
    }

    public static void OpenSsh(Device device)
    {
        try { Process.Start(new ProcessStartInfo("wt.exe", $"-w 0 new-tab ssh {device.IpAddress}") { UseShellExecute = true }); }
        catch { Process.Start(new ProcessStartInfo("cmd.exe", $"/k ssh {device.IpAddress}") { UseShellExecute = true }); }
    }

    public static void OpenSmb(Device device) => Process.Start(new ProcessStartInfo("explorer.exe", $@"\\{device.IpAddress}") { UseShellExecute = true });
    public static void OpenRdp(Device device) => Process.Start(new ProcessStartInfo("mstsc.exe", $"/v:{device.IpAddress}") { UseShellExecute = true });
    private static void OpenShell(string target) => Process.Start(new ProcessStartInfo(target) { UseShellExecute = true });
}
