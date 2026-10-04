using System.Text;
using System.Text.Json;

namespace LanScope.Core.Services;

public static class OuiDatabaseUpdater
{
    private static readonly Uri SourceUri = new("https://standards-oui.ieee.org/oui/oui.csv");

    public static async Task<int> UpdateAsync(string destinationPath, CancellationToken cancellationToken)
    {
        using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(45) };
        var csv = await client.GetStringAsync(SourceUri, cancellationToken);
        var vendors = new SortedDictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (var line in csv.Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries).Skip(1))
        {
            var fields = ParseCsvLine(line);
            if (fields.Count < 3) continue;
            var assignment = fields[1].Replace("-", "").Replace(":", "").ToUpperInvariant();
            if (assignment.Length != 6 || !assignment.All(Uri.IsHexDigit)) continue;
            var organization = fields[2].Trim();
            if (!string.IsNullOrWhiteSpace(organization)) vendors[assignment] = organization;
        }
        if (vendors.Count == 0) throw new InvalidDataException("IEEE OUI file did not contain vendor records.");

        Directory.CreateDirectory(Path.GetDirectoryName(destinationPath)!);
        var temp = destinationPath + ".tmp";
        await File.WriteAllTextAsync(temp, JsonSerializer.Serialize(vendors, new JsonSerializerOptions { WriteIndented = true }), new UTF8Encoding(false), cancellationToken);
        File.Move(temp, destinationPath, true);
        return vendors.Count;
    }

    private static List<string> ParseCsvLine(string line)
    {
        var result = new List<string>();
        var field = new StringBuilder();
        var quoted = false;
        for (var i = 0; i < line.Length; i++)
        {
            var character = line[i];
            if (character == '"')
            {
                if (quoted && i + 1 < line.Length && line[i + 1] == '"') { field.Append('"'); i++; }
                else quoted = !quoted;
            }
            else if (character == ',' && !quoted) { result.Add(field.ToString()); field.Clear(); }
            else field.Append(character);
        }
        result.Add(field.ToString());
        return result;
    }
}
