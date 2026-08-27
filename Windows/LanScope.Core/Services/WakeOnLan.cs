using System.Net;
using System.Net.Sockets;

namespace LanScope.Core.Services;

public static class WakeOnLan
{
    public static async Task SendAsync(string macAddress, CancellationToken cancellationToken = default)
    {
        var parts = macAddress.Replace('-', ':').Split(':');
        if (parts.Length != 6) throw new FormatException("Invalid MAC address.");
        var mac = parts.Select(x => Convert.ToByte(x, 16)).ToArray();
        var packet = Enumerable.Repeat((byte)0xFF, 6).Concat(Enumerable.Range(0, 16).SelectMany(_ => mac)).ToArray();
        using var client = new UdpClient { EnableBroadcast = true };
        await client.SendAsync(packet, new IPEndPoint(IPAddress.Broadcast, 9), cancellationToken);
    }
}
