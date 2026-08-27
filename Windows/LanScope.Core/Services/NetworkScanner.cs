using System.Collections.Concurrent;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using LanScope.Core.Models;

namespace LanScope.Core.Services;

public sealed class NetworkScanner
{
    private readonly VendorLookup _vendorLookup;

    public NetworkScanner(VendorLookup vendorLookup) => _vendorLookup = vendorLookup;
    public int VendorDatabaseCount => _vendorLookup.Count;

    public async Task<IReadOnlyList<Device>> ScanAsync(
        ScannerConfig config,
        IProgress<ScanProgress>? progress,
        CancellationToken cancellationToken)
    {
        config.Normalize();
        var hosts = IPRangeParser.Parse(config.IpRange);
        var found = new ConcurrentBag<Device>();
        using var gate = new SemaphoreSlim(config.ConcurrencyLimit);
        var completed = 0;

        var tasks = hosts.Select(async host =>
        {
            await gate.WaitAsync(cancellationToken);
            try
            {
                var device = await ScanHostAsync(host, config, cancellationToken);
                if (device is not null) found.Add(device);
                var done = Interlocked.Increment(ref completed);
                progress?.Report(new ScanProgress(done, hosts.Count, device));
            }
            finally
            {
                gate.Release();
            }
        });

        await Task.WhenAll(tasks);
        cancellationToken.ThrowIfCancellationRequested();

        var arpEntries = await ArpResolver.ReadAsync(cancellationToken);
        var result = found.OrderBy(x => IPRangeParser.ToUInt32(IPAddress.Parse(x.IpAddress))).ToList();
        foreach (var device in result)
        {
            if (arpEntries.TryGetValue(device.IpAddress, out var mac)) device.MacAddress = mac;
            device.Vendor = config.VendorLookupEnabled ? _vendorLookup.Find(device.MacAddress) : "Disabled";
        }
        return result;
    }

    private static async Task<Device?> ScanHostAsync(string host, ScannerConfig config, CancellationToken token)
    {
        var timeout = TimeSpan.FromSeconds(config.TimeoutSeconds);
        var pingTask = PingAsync(host, timeout, token);
        var portTasks = config.Ports.Select(port => IsPortOpenAsync(host, port, timeout, token)).ToArray();

        var pingSucceeded = await pingTask;
        var portStates = await Task.WhenAll(portTasks);
        var openPorts = config.Ports.Zip(portStates).Where(x => x.Second).Select(x => x.First).Order().ToList();
        if (!pingSucceeded && openPorts.Count == 0) return null;

        var hostname = await ResolveHostnameAsync(host, timeout, token);
        return new Device
        {
            IpAddress = host,
            Hostname = hostname ?? "",
            Status = DeviceStatus.Online,
            OpenPorts = openPorts,
            Services = openPorts.Select(ServiceCatalog.ForPort).ToList(),
            LastSeen = DateTimeOffset.Now
        };
    }

    private static async Task<bool> PingAsync(string host, TimeSpan timeout, CancellationToken token)
    {
        try
        {
            using var ping = new Ping();
            var reply = await ping.SendPingAsync(host, (int)timeout.TotalMilliseconds).WaitAsync(timeout + TimeSpan.FromMilliseconds(100), token);
            return reply.Status == IPStatus.Success;
        }
        catch
        {
            return false;
        }
    }

    private static async Task<bool> IsPortOpenAsync(string host, int port, TimeSpan timeout, CancellationToken token)
    {
        try
        {
            using var client = new TcpClient();
            await client.ConnectAsync(host, port, token).AsTask().WaitAsync(timeout, token);
            return true;
        }
        catch
        {
            return false;
        }
    }

    private static async Task<string?> ResolveHostnameAsync(string host, TimeSpan timeout, CancellationToken token)
    {
        try
        {
            var entry = await Dns.GetHostEntryAsync(IPAddress.Parse(host)).WaitAsync(timeout, token);
            return string.Equals(entry.HostName, host, StringComparison.OrdinalIgnoreCase) ? null : entry.HostName;
        }
        catch
        {
            return null;
        }
    }
}
