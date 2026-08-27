using System.Text.Json;
using System.Text.Json.Serialization;
using LanScope.Core.Models;

namespace LanScope.Core.Services;

public sealed class PersistenceService
{
    private readonly string _statePath;
    private readonly JsonSerializerOptions _options = new()
    {
        WriteIndented = true,
        PropertyNameCaseInsensitive = true,
        Converters = { new JsonStringEnumConverter() }
    };

    public PersistenceService(string? statePath = null)
    {
        _statePath = statePath ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "LanScope Windows",
            "state.json");
    }

    public AppStateData Load()
    {
        try
        {
            if (!File.Exists(_statePath)) return new AppStateData();
            return JsonSerializer.Deserialize<AppStateData>(File.ReadAllText(_statePath), _options) ?? new AppStateData();
        }
        catch
        {
            return new AppStateData();
        }
    }

    public void Save(AppStateData state)
    {
        var directory = Path.GetDirectoryName(_statePath)!;
        Directory.CreateDirectory(directory);
        var temporaryPath = _statePath + ".tmp";
        File.WriteAllText(temporaryPath, JsonSerializer.Serialize(state, _options));
        File.Move(temporaryPath, _statePath, true);
    }
}

public sealed class AppStateData
{
    public ScannerConfig Config { get; set; } = new();
    public List<Device> Favorites { get; set; } = [];
    public List<ScanHistory> History { get; set; } = [];
}
