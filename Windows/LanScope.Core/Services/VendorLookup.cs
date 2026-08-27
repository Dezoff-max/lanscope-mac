using System.Text.Json;

namespace LanScope.Core.Services;

public sealed class VendorLookup
{
    private readonly string _databasePath;
    private Dictionary<string, string> _vendors = new(StringComparer.OrdinalIgnoreCase);

    public VendorLookup(string databasePath)
    {
        _databasePath = databasePath;
        Reload();
    }

    public int Count => _vendors.Count;

    public int Reload()
    {
        try
        {
            if (!File.Exists(_databasePath)) return _vendors.Count;
            _vendors = JsonSerializer.Deserialize<Dictionary<string, string>>(File.ReadAllText(_databasePath))
                       ?? new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        }
        catch
        {
            _vendors = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        }
        return _vendors.Count;
    }

    public string Find(string? macAddress)
    {
        if (string.IsNullOrWhiteSpace(macAddress)) return "Unknown";
        var normalized = macAddress.Replace(":", "").Replace("-", "").ToUpperInvariant();
        if (normalized.Length < 6) return "Unknown";
        if (_vendors.TryGetValue(normalized[..6], out var vendor)) return vendor;
        if (byte.TryParse(normalized[..2], System.Globalization.NumberStyles.HexNumber, null, out var first) && (first & 0x02) != 0)
            return "Locally Administered";
        return "Unknown";
    }
}
