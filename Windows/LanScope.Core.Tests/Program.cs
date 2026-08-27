using LanScope.Core.Models;
using LanScope.Core.Services;

var tests = new (string Name, Func<Task> Run)[]
{
    ("short IP range", () => Run(() => Equal(["192.168.1.1", "192.168.1.2", "192.168.1.3"], IPRangeParser.Parse("192.168.1.1-3")))),
    ("full IP range", () => Run(() => Equal(["10.0.0.8", "10.0.0.9", "10.0.0.10"], IPRangeParser.Parse("10.0.0.8-10.0.0.10")))),
    ("CIDR skips network and broadcast", () => Run(() => Equal(["192.168.50.1", "192.168.50.2"], IPRangeParser.Parse("192.168.50.0/30")))),
    ("oversized CIDR rejected", () => Run(() => Throws<FormatException>(() => IPRangeParser.Parse("10.10.0.0/16")))),
    ("Wi-Fi netsh parser", () => Run(TestWifiParser)),
    ("CSV escaping", () => Run(TestCsvEscaping)),
    ("vendor lookup", TestVendorLookup),
    ("localhost discovery", TestLocalhostDiscovery)
};

var failures = 0;
foreach (var test in tests)
{
    try
    {
        await test.Run();
        Console.WriteLine($"PASS  {test.Name}");
    }
    catch (Exception exception)
    {
        failures++;
        Console.WriteLine($"FAIL  {test.Name}: {exception.Message}");
    }
}

Console.WriteLine($"{tests.Length - failures}/{tests.Length} tests passed");
return failures == 0 ? 0 : 1;

static Task Run(Action action)
{
    action();
    return Task.CompletedTask;
}

static void TestWifiParser()
{
    const string netsh = """
        SSID 1 : Office
            Authentication : WPA2-Personal
            BSSID 1 : aa:bb:cc:dd:ee:ff
                 Signal : 82%
                 Radio type : 802.11ax
                 Channel : 44
        """;
    var network = WifiScanner.Parse(netsh).Single();
    Assert(network.DisplaySsid == "Office", "SSID mismatch");
    Assert(network.Bssid == "AA:BB:CC:DD:EE:FF", "BSSID mismatch");
    Assert(network.SignalPercent == 82, "signal mismatch");
    Assert(network.Channel == 44, "channel mismatch");
    Assert(network.Security == "WPA2-Personal", "security mismatch");
}

static void TestCsvEscaping()
{
    var csv = ExportService.ToCsv([new Device { IpAddress = "192.0.2.1", Hostname = "lab, \"one\"" }]);
    Assert(csv.Contains("\"lab, \"\"one\"\"\""), "CSV value was not escaped");
}

static async Task TestVendorLookup()
{
    var path = Path.Combine(Path.GetTempPath(), $"lanscope-vendors-{Guid.NewGuid():N}.json");
    try
    {
        await File.WriteAllTextAsync(path, "{\"AABBCC\":\"Example Devices\"}");
        var lookup = new VendorLookup(path);
        Assert(lookup.Count == 1, "vendor count mismatch");
        Assert(lookup.Find("AA:BB:CC:00:11:22") == "Example Devices", "vendor lookup mismatch");
        Assert(lookup.Find("02:00:00:00:00:01") == "Locally Administered", "local MAC classification mismatch");
    }
    finally
    {
        if (File.Exists(path)) File.Delete(path);
    }
}

static async Task TestLocalhostDiscovery()
{
    var path = Path.Combine(Path.GetTempPath(), $"lanscope-empty-{Guid.NewGuid():N}.json");
    try
    {
        await File.WriteAllTextAsync(path, "{}");
        var scanner = new NetworkScanner(new VendorLookup(path));
        var result = await scanner.ScanAsync(new ScannerConfig
        {
            IpRange = "127.0.0.1",
            Ports = [65534],
            TimeoutSeconds = 0.2,
            ConcurrencyLimit = 1
        }, null, CancellationToken.None);
        Assert(result.Count == 1 && result[0].IpAddress == "127.0.0.1", "localhost was not discovered by ping");
    }
    finally
    {
        if (File.Exists(path)) File.Delete(path);
    }
}

static void Equal(IReadOnlyList<string> expected, IReadOnlyList<string> actual)
{
    Assert(expected.SequenceEqual(actual), $"expected [{string.Join(", ", expected)}], got [{string.Join(", ", actual)}]");
}

static void Throws<T>(Action action) where T : Exception
{
    try { action(); }
    catch (T) { return; }
    throw new Exception($"Expected {typeof(T).Name}");
}

static void Assert(bool condition, string message)
{
    if (!condition) throw new Exception(message);
}
