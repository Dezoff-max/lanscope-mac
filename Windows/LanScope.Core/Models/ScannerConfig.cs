namespace LanScope.Core.Models;

public sealed class ScannerConfig
{
    public string IpRange { get; set; } = "192.168.1.1-254";
    public List<int> Ports { get; set; } = [22, 80, 443, 445, 548, 3389, 5900, 8080];
    public double TimeoutSeconds { get; set; } = 0.8;
    public int ConcurrencyLimit { get; set; } = 64;
    public bool VendorLookupEnabled { get; set; } = true;
    public AppTheme Theme { get; set; } = AppTheme.System;

    public ScannerConfig Normalize()
    {
        IpRange = IpRange.Trim();
        Ports = Ports.Where(x => x is >= 1 and <= 65535).Distinct().Order().ToList();
        if (Ports.Count == 0) Ports = [22, 80, 443, 445, 548, 3389, 5900, 8080];
        TimeoutSeconds = Math.Clamp(TimeoutSeconds, 0.2, 10.0);
        ConcurrencyLimit = Math.Clamp(ConcurrencyLimit, 1, 512);
        return this;
    }
}

public enum AppTheme
{
    System,
    Light,
    Dark
}
