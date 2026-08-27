namespace LanScope.Core.Models;

public sealed class WifiNetwork
{
    public string Ssid { get; set; } = "";
    public string Bssid { get; set; } = "-";
    public int SignalPercent { get; set; }
    public int? Channel { get; set; }
    public string Band { get; set; } = "Unknown";
    public string Security { get; set; } = "Unknown";
    public string RadioType { get; set; } = "-";
    public DateTimeOffset LastSeen { get; set; } = DateTimeOffset.Now;

    public string DisplaySsid => string.IsNullOrWhiteSpace(Ssid) ? "Hidden Network" : Ssid;
    public string SignalDisplay => $"{SignalPercent}%";
    public string ChannelDisplay => Channel?.ToString() ?? "-";
    public string SignalQuality => SignalPercent switch
    {
        >= 80 => "Excellent",
        >= 60 => "Good",
        >= 40 => "Fair",
        _ => "Weak"
    };
}
