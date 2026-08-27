using System.Diagnostics;
using System.Text.RegularExpressions;
using LanScope.Core.Models;

namespace LanScope.Core.Services;

public static partial class WifiScanner
{
    [GeneratedRegex(@"^\s*SSID\s+\d+\s*:\s*(?<value>.*)$", RegexOptions.IgnoreCase)]
    private static partial Regex SsidRegex();
    [GeneratedRegex(@"^\s*BSSID\s+\d+\s*:\s*(?<value>[0-9a-f:-]+)", RegexOptions.IgnoreCase)]
    private static partial Regex BssidRegex();
    [GeneratedRegex(@"(?:Signal|Сигнал)\s*:\s*(?<value>\d+)%", RegexOptions.IgnoreCase)]
    private static partial Regex SignalRegex();
    [GeneratedRegex(@"(?:Channel|Канал)\s*:\s*(?<value>\d+)", RegexOptions.IgnoreCase)]
    private static partial Regex ChannelRegex();
    [GeneratedRegex(@"(?:Authentication|Аутентификация|Проверка подлинности)\s*:\s*(?<value>.+)$", RegexOptions.IgnoreCase)]
    private static partial Regex SecurityRegex();
    [GeneratedRegex(@"(?:Radio type|Тип радио|Тип радиосигнала)\s*:\s*(?<value>.+)$", RegexOptions.IgnoreCase)]
    private static partial Regex RadioRegex();

    public static async Task<IReadOnlyList<WifiNetwork>> ScanAsync(CancellationToken cancellationToken)
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = "netsh.exe",
            Arguments = "wlan show networks mode=bssid",
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        using var process = Process.Start(startInfo) ?? throw new InvalidOperationException("Could not start netsh.");
        var outputTask = process.StandardOutput.ReadToEndAsync(cancellationToken);
        var errorTask = process.StandardError.ReadToEndAsync(cancellationToken);
        await process.WaitForExitAsync(cancellationToken);
        var output = await outputTask;
        var error = await errorTask;
        if (process.ExitCode != 0) throw new InvalidOperationException(string.IsNullOrWhiteSpace(error) ? "Windows Wi-Fi scan failed." : error.Trim());

        return Parse(output);
    }

    public static IReadOnlyList<WifiNetwork> Parse(string output)
    {
        var result = new List<WifiNetwork>();
        string currentSsid = "";
        string currentSecurity = "Unknown";
        WifiNetwork? current = null;

        foreach (var line in output.Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries))
        {
            var ssid = SsidRegex().Match(line);
            if (ssid.Success)
            {
                currentSsid = ssid.Groups["value"].Value.Trim();
                currentSecurity = "Unknown";
                current = null;
                continue;
            }

            var security = SecurityRegex().Match(line);
            if (security.Success)
            {
                currentSecurity = security.Groups["value"].Value.Trim();
                if (current is not null) current.Security = currentSecurity;
                continue;
            }

            var bssid = BssidRegex().Match(line);
            if (bssid.Success)
            {
                current = new WifiNetwork
                {
                    Ssid = currentSsid,
                    Bssid = bssid.Groups["value"].Value.ToUpperInvariant(),
                    Security = currentSecurity,
                    LastSeen = DateTimeOffset.Now
                };
                result.Add(current);
                continue;
            }

            if (current is null) continue;

            var signal = SignalRegex().Match(line);
            if (signal.Success && int.TryParse(signal.Groups["value"].Value, out var signalValue))
            {
                current.SignalPercent = signalValue;
                continue;
            }

            var channel = ChannelRegex().Match(line);
            if (channel.Success && int.TryParse(channel.Groups["value"].Value, out var channelValue))
            {
                current.Channel = channelValue;
                current.Band = channelValue <= 14 ? "2.4 GHz" : channelValue >= 1 && channelValue <= 233 ? "5 / 6 GHz" : "Unknown";
                continue;
            }

            var radio = RadioRegex().Match(line);
            if (radio.Success) current.RadioType = radio.Groups["value"].Value.Trim();
        }

        return result
            .GroupBy(x => x.Bssid, StringComparer.OrdinalIgnoreCase)
            .Select(x => x.OrderByDescending(y => y.SignalPercent).First())
            .OrderByDescending(x => x.SignalPercent)
            .ToList();
    }
}
