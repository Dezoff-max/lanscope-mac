using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using LanScope.Core.Models;

namespace LanScope.Core.Services;

public static class ExportService
{
    public static string ToCsv(IEnumerable<Device> devices)
    {
        var rows = new List<string>
        {
            CsvRow(["Status", "Name", "IP Address", "MAC Address", "Vendor", "Open Ports", "Services", "Last Seen"])
        };
        rows.AddRange(devices.Select(device => CsvRow([
            device.StatusDisplay,
            device.DisplayName,
            device.IpAddress,
            device.MacAddress ?? "",
            device.Vendor,
            device.OpenPortsDisplay,
            device.ServicesDisplay,
            device.LastSeen.ToString("O")
        ])));
        return string.Join(Environment.NewLine, rows) + Environment.NewLine;
    }

    public static string ToJson(IEnumerable<Device> devices) => JsonSerializer.Serialize(devices, new JsonSerializerOptions
    {
        WriteIndented = true,
        Converters = { new JsonStringEnumConverter() }
    });

    public static string ToTsv(IEnumerable<Device> devices)
    {
        var rows = new List<string> { "Status\tName\tIP Address\tMAC Address\tVendor\tOpen Ports\tServices\tLast Seen" };
        rows.AddRange(devices.Select(x => string.Join('\t', [
            x.StatusDisplay, x.DisplayName, x.IpAddress, x.MacAddress ?? "", x.Vendor,
            x.OpenPortsDisplay, x.ServicesDisplay, x.LastSeen.ToString("g")
        ])));
        return string.Join(Environment.NewLine, rows);
    }

    public static void SaveUtf8(string path, string content) => File.WriteAllText(path, content, new UTF8Encoding(true));
    private static string CsvRow(IEnumerable<string> values) => string.Join(',', values.Select(x => $"\"{x.Replace("\"", "\"\"")}\""));
}
