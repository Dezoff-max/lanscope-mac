using System.Diagnostics;
using System.Text.RegularExpressions;

namespace LanScope.Core.Services;

public static partial class ArpResolver
{
    [GeneratedRegex(@"(?<ip>\d{1,3}(?:\.\d{1,3}){3})\s+(?<mac>[0-9a-fA-F]{2}(?:[:-][0-9a-fA-F]{2}){5})", RegexOptions.Compiled)]
    private static partial Regex ArpLineRegex();

    public static async Task<IReadOnlyDictionary<string, string>> ReadAsync(CancellationToken cancellationToken)
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = "arp.exe",
            Arguments = "-a",
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        try
        {
            using var process = Process.Start(startInfo);
            if (process is null) return new Dictionary<string, string>();
            var outputTask = process.StandardOutput.ReadToEndAsync(cancellationToken);
            await process.WaitForExitAsync(cancellationToken);
            var output = await outputTask;
            var result = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            foreach (Match match in ArpLineRegex().Matches(output))
            {
                var mac = match.Groups["mac"].Value.Replace('-', ':').ToUpperInvariant();
                if (mac != "FF:FF:FF:FF:FF:FF") result[match.Groups["ip"].Value] = mac;
            }
            return result;
        }
        catch
        {
            return new Dictionary<string, string>();
        }
    }
}
