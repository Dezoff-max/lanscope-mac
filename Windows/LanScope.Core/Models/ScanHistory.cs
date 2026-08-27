namespace LanScope.Core.Models;

public sealed class ScanHistory
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public DateTimeOffset StartedAt { get; set; }
    public DateTimeOffset FinishedAt { get; set; }
    public string IpRange { get; set; } = "";
    public int TotalHosts { get; set; }
    public int FoundDevices { get; set; }
    public List<Device> Devices { get; set; } = [];
    public double DurationSeconds => Math.Max(0, (FinishedAt - StartedAt).TotalSeconds);
    public string Summary => $"{StartedAt:g}  ·  {FoundDevices} found";
}
