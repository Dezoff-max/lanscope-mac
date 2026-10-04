using LanScope.Core.Models;

namespace LanScope.Core.Services;

public static class ServiceCatalog
{
    private static readonly IReadOnlyDictionary<int, NetworkService> Services =
        new Dictionary<int, NetworkService>
        {
            [22] = new(22, "SSH", "ssh"),
            [80] = new(80, "HTTP", "http"),
            [443] = new(443, "HTTPS", "https"),
            [445] = new(445, "SMB", "smb"),
            [548] = new(548, "AFP", "afp"),
            [3389] = new(3389, "RDP", "rdp"),
            [5900] = new(5900, "VNC", "vnc"),
            [8080] = new(8080, "HTTP-alt", "http")
        };

    public static NetworkService ForPort(int port) =>
        Services.TryGetValue(port, out var service) ? service : new NetworkService(port, $"TCP {port}");
}
