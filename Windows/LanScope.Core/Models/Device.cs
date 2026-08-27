using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Text.Json.Serialization;

namespace LanScope.Core.Models;

public sealed class Device : INotifyPropertyChanged
{
    private bool _isFavorite;

    public Guid Id { get; set; } = Guid.NewGuid();
    public string IpAddress { get; set; } = "";
    public string Hostname { get; set; } = "";
    public string? MacAddress { get; set; }
    public string Vendor { get; set; } = "Unknown";
    public DeviceStatus Status { get; set; } = DeviceStatus.Online;
    public List<int> OpenPorts { get; set; } = [];
    public List<NetworkService> Services { get; set; } = [];
    public DateTimeOffset LastSeen { get; set; } = DateTimeOffset.Now;

    public bool IsFavorite
    {
        get => _isFavorite;
        set
        {
            if (_isFavorite == value) return;
            _isFavorite = value;
            OnPropertyChanged();
            OnPropertyChanged(nameof(FavoriteGlyph));
        }
    }

    [JsonIgnore] public string DisplayName => string.IsNullOrWhiteSpace(Hostname) ? IpAddress : Hostname;
    [JsonIgnore] public string OpenPortsDisplay => OpenPorts.Count == 0 ? "-" : string.Join(", ", OpenPorts);
    [JsonIgnore] public string ServicesDisplay => Services.Count == 0 ? "-" : string.Join(", ", Services.Select(x => x.Name));
    [JsonIgnore] public string StatusDisplay => Status.ToString();
    [JsonIgnore] public string FavoriteGlyph => IsFavorite ? "★" : "▣";
    [JsonIgnore] public bool HasWebService => OpenPorts.Any(x => x is 80 or 443 or 8080);
    [JsonIgnore] public bool HasSsh => OpenPorts.Contains(22);
    [JsonIgnore] public bool HasSmb => OpenPorts.Contains(445);
    [JsonIgnore] public bool HasRdp => OpenPorts.Contains(3389);

    public bool Matches(Device other) =>
        (!string.IsNullOrWhiteSpace(MacAddress) &&
         !string.IsNullOrWhiteSpace(other.MacAddress) &&
         string.Equals(MacAddress, other.MacAddress, StringComparison.OrdinalIgnoreCase)) ||
        string.Equals(IpAddress, other.IpAddress, StringComparison.OrdinalIgnoreCase);

    public event PropertyChangedEventHandler? PropertyChanged;
    private void OnPropertyChanged([CallerMemberName] string? name = null) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
}

public enum DeviceStatus
{
    Online,
    Offline,
    Unknown
}

public sealed record NetworkService(int Port, string Name, string? Scheme = null)
{
    [JsonIgnore] public string DisplayName => $"{Name} :{Port}";
}
