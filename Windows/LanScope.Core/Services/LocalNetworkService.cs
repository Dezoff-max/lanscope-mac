using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;

namespace LanScope.Core.Services;

public static class LocalNetworkService
{
    public static string? SuggestedRange()
    {
        var candidate = NetworkInterface.GetAllNetworkInterfaces()
            .Where(x => x.OperationalStatus == OperationalStatus.Up &&
                        x.NetworkInterfaceType is not NetworkInterfaceType.Loopback and not NetworkInterfaceType.Tunnel)
            .SelectMany(networkInterface => networkInterface.GetIPProperties().UnicastAddresses
                .Where(address => address.Address.AddressFamily == AddressFamily.InterNetwork &&
                                  !IPAddress.IsLoopback(address.Address) && address.IPv4Mask is not null)
                .Select(address => new
                {
                    Address = address,
                    Score = InterfaceScore(networkInterface)
                }))
            .OrderByDescending(x => x.Score)
            .Select(x => x.Address)
            .FirstOrDefault();

        if (candidate?.IPv4Mask is null) return null;

        var address = IPRangeParser.ToUInt32(candidate.Address);
        var mask = IPRangeParser.ToUInt32(candidate.IPv4Mask);
        var network = address & mask;
        var broadcast = network | ~mask;
        var usable = (ulong)broadcast - network - 1;

        if (usable is > 0 and <= 512)
            return $"{IPRangeParser.FromUInt32(network + 1)}-{IPRangeParser.FromUInt32(broadcast - 1)}";

        var bytes = candidate.Address.GetAddressBytes();
        return $"{bytes[0]}.{bytes[1]}.{bytes[2]}.1-254";
    }

    private static int InterfaceScore(NetworkInterface networkInterface)
    {
        var properties = networkInterface.GetIPProperties();
        var description = $"{networkInterface.Name} {networkInterface.Description}".ToLowerInvariant();
        var isVirtual = new[] { "virtual", "hyper-v", "wsl", "docker", "vmware", "vethernet", "loopback", "bluetooth" }
            .Any(description.Contains);
        var score = properties.GatewayAddresses.Any(x => x.Address.AddressFamily == AddressFamily.InterNetwork) ? 100 : 0;
        score += networkInterface.NetworkInterfaceType switch
        {
            NetworkInterfaceType.Wireless80211 => 40,
            NetworkInterfaceType.Ethernet => 30,
            NetworkInterfaceType.GigabitEthernet => 30,
            _ => 0
        };
        if (isVirtual) score -= 80;
        return score;
    }
}
