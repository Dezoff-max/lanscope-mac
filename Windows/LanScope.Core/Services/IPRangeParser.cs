using System.Net;

namespace LanScope.Core.Services;

public static class IPRangeParser
{
    public const int MaximumHosts = 4096;

    public static IReadOnlyList<string> Parse(string input)
    {
        var value = input.Trim();
        if (string.IsNullOrWhiteSpace(value))
            throw new FormatException("Enter an IPv4 address, range, or CIDR block.");

        if (value.Contains('/')) return ParseCidr(value);
        if (value.Contains('-')) return ParseRange(value);

        var address = ParseIPv4(value);
        return [address.ToString()];
    }

    private static IReadOnlyList<string> ParseRange(string value)
    {
        var parts = value.Split('-', 2, StringSplitOptions.TrimEntries);
        if (parts.Length != 2) throw new FormatException("Invalid IP range.");

        var start = ParseIPv4(parts[0]);
        IPAddress end;
        if (byte.TryParse(parts[1], out var lastOctet))
        {
            var bytes = start.GetAddressBytes();
            bytes[3] = lastOctet;
            end = new IPAddress(bytes);
        }
        else
        {
            end = ParseIPv4(parts[1]);
        }

        return Expand(ToUInt32(start), ToUInt32(end));
    }

    private static IReadOnlyList<string> ParseCidr(string value)
    {
        var parts = value.Split('/', 2, StringSplitOptions.TrimEntries);
        if (parts.Length != 2 || !int.TryParse(parts[1], out var prefix) || prefix is < 0 or > 32)
            throw new FormatException("CIDR prefix must be between 0 and 32.");

        var address = ToUInt32(ParseIPv4(parts[0]));
        var mask = prefix == 0 ? 0u : uint.MaxValue << (32 - prefix);
        var network = address & mask;
        var broadcast = network | ~mask;
        var blockSize = (ulong)broadcast - network + 1;

        if (blockSize > MaximumHosts + 2UL)
            throw new FormatException($"Range is too large. The limit is {MaximumHosts} hosts.");

        if (blockSize > 2) return Expand(network + 1, broadcast - 1);
        return Expand(network, broadcast);
    }

    private static IReadOnlyList<string> Expand(uint start, uint end)
    {
        if (end < start) throw new FormatException("Range end must not be below its start.");
        var count = (ulong)end - start + 1;
        if (count > MaximumHosts)
            throw new FormatException($"Range is too large. The limit is {MaximumHosts} hosts.");

        var result = new List<string>((int)count);
        for (var current = start; ; current++)
        {
            result.Add(FromUInt32(current).ToString());
            if (current == end) break;
        }
        return result;
    }

    private static IPAddress ParseIPv4(string value)
    {
        if (!IPAddress.TryParse(value, out var address) || address.AddressFamily != System.Net.Sockets.AddressFamily.InterNetwork)
            throw new FormatException($"'{value}' is not a valid IPv4 address.");
        return address;
    }

    public static uint ToUInt32(IPAddress address)
    {
        var bytes = address.GetAddressBytes();
        return ((uint)bytes[0] << 24) | ((uint)bytes[1] << 16) | ((uint)bytes[2] << 8) | bytes[3];
    }

    public static IPAddress FromUInt32(uint value) => new([
        (byte)(value >> 24),
        (byte)(value >> 16),
        (byte)(value >> 8),
        (byte)value
    ]);
}
