using System.Collections.ObjectModel;
using System.Globalization;
using System.IO;
using System.Net;
using System.Windows;
using LanScope.Core.Models;
using LanScope.Core.Services;
using LanScope.Windows.Infrastructure;

namespace LanScope.Windows.ViewModels;

public sealed class MainViewModel : ObservableObject
{
    private readonly PersistenceService _persistence = new();
    private VendorLookup _vendorLookup;
    private NetworkScanner _scanner;
    private CancellationTokenSource? _scanCancellation;
    private CancellationTokenSource? _wifiCancellation;
    private AppSection _currentSection = AppSection.Scan;
    private Device? _selectedDevice;
    private ScanHistory? _selectedHistory;
    private string _statusMessage = "Ready";
    private string _wifiStatusMessage = "Ready";
    private string _searchText = "";
    private double _progress;
    private bool _isScanning;
    private bool _isWifiScanning;
    private bool _isUpdatingOui;
    private int _vendorDatabaseCount;
    private string _ipRange;
    private string _portsText;
    private double _timeoutSeconds;
    private int _concurrencyLimit;
    private bool _vendorLookupEnabled;
    private AppTheme _theme;

    public MainViewModel()
    {
        var state = _persistence.Load();
        Config = state.Config.Normalize();
        if (string.IsNullOrWhiteSpace(Config.IpRange) || Config.IpRange == "192.168.1.1-254")
            Config.IpRange = LocalNetworkService.SuggestedRange() ?? Config.IpRange;

        _ipRange = Config.IpRange;
        _portsText = string.Join(", ", Config.Ports);
        _timeoutSeconds = Config.TimeoutSeconds;
        _concurrencyLimit = Config.ConcurrencyLimit;
        _vendorLookupEnabled = Config.VendorLookupEnabled;
        _theme = Config.Theme;

        var userOui = UserOuiPath;
        var bundledOui = Path.Combine(AppContext.BaseDirectory, "Resources", "oui.json");
        _vendorLookup = new VendorLookup(File.Exists(userOui) ? userOui : bundledOui);
        _scanner = new NetworkScanner(_vendorLookup);
        _vendorDatabaseCount = _scanner.VendorDatabaseCount;

        foreach (var device in state.Favorites) Favorites.Add(device);
        foreach (var entry in state.History.OrderByDescending(x => x.StartedAt).Take(25)) History.Add(entry);
        SelectedHistory = History.FirstOrDefault();

        PrimaryScanCommand = new AsyncRelayCommand(StartPrimaryAsync, () => !IsScanning && !IsWifiScanning);
        StopScanCommand = new RelayCommand(StopScan, () => IsScanning || IsWifiScanning);
        DetectRangeCommand = new RelayCommand(DetectRange);
        ToggleFavoriteCommand = new RelayCommand(ToggleSelectedFavorite, () => SelectedDevice is not null);
        OpenBrowserCommand = new RelayCommand(() => RunDeviceAction(DeviceActionService.OpenBrowser, "Opened browser"), () => SelectedDevice?.HasWebService == true);
        OpenSshCommand = new RelayCommand(() => RunDeviceAction(DeviceActionService.OpenSsh, "Opened SSH"), () => SelectedDevice?.HasSsh == true);
        OpenSmbCommand = new RelayCommand(() => RunDeviceAction(DeviceActionService.OpenSmb, "Opened SMB share"), () => SelectedDevice?.HasSmb == true);
        OpenRdpCommand = new RelayCommand(() => RunDeviceAction(DeviceActionService.OpenRdp, "Opened Remote Desktop"), () => SelectedDevice?.HasRdp == true);
        CopyIpCommand = new RelayCommand(CopyIp, () => SelectedDevice is not null);
        CopyMacCommand = new RelayCommand(CopyMac, () => !string.IsNullOrWhiteSpace(SelectedDevice?.MacAddress));
        WakeCommand = new AsyncRelayCommand(WakeSelectedAsync, () => !string.IsNullOrWhiteSpace(SelectedDevice?.MacAddress));
        ClearHistoryCommand = new RelayCommand(ClearHistory, () => History.Count > 0);
        UpdateOuiCommand = new AsyncRelayCommand(UpdateOuiAsync, () => !IsUpdatingOui);

        App.ApplyTheme(Theme);
        RefreshDisplayedDevices();
    }

    public ScannerConfig Config { get; }
    public ObservableCollection<Device> Devices { get; } = [];
    public ObservableCollection<Device> Favorites { get; } = [];
    public ObservableCollection<ScanHistory> History { get; } = [];
    public ObservableCollection<WifiNetwork> WifiNetworks { get; } = [];
    public ObservableCollection<Device> DisplayedDevices { get; } = [];
    public ObservableCollection<WifiNetwork> DisplayedWifiNetworks { get; } = [];
    public IReadOnlyList<AppTheme> Themes { get; } = Enum.GetValues<AppTheme>();

    public AsyncRelayCommand PrimaryScanCommand { get; }
    public RelayCommand StopScanCommand { get; }
    public RelayCommand DetectRangeCommand { get; }
    public RelayCommand ToggleFavoriteCommand { get; }
    public RelayCommand OpenBrowserCommand { get; }
    public RelayCommand OpenSshCommand { get; }
    public RelayCommand OpenSmbCommand { get; }
    public RelayCommand OpenRdpCommand { get; }
    public RelayCommand CopyIpCommand { get; }
    public RelayCommand CopyMacCommand { get; }
    public AsyncRelayCommand WakeCommand { get; }
    public RelayCommand ClearHistoryCommand { get; }
    public AsyncRelayCommand UpdateOuiCommand { get; }

    public AppSection CurrentSection
    {
        get => _currentSection;
        private set
        {
            if (!SetProperty(ref _currentSection, value)) return;
            SelectedDevice = null;
            OnPropertyChanged(nameof(SectionTitle));
            OnPropertyChanged(nameof(IsDeviceSection));
            OnPropertyChanged(nameof(IsScanSection));
            OnPropertyChanged(nameof(IsFavoritesSection));
            OnPropertyChanged(nameof(IsHistorySection));
            OnPropertyChanged(nameof(IsWifiSection));
            OnPropertyChanged(nameof(IsSettingsSection));
            OnPropertyChanged(nameof(PrimaryActionLabel));
            OnPropertyChanged(nameof(CanExport));
            RefreshDisplayedDevices();
            RefreshWifiNetworks();
        }
    }

    public string SectionTitle => CurrentSection switch
    {
        AppSection.Scan => "Scan",
        AppSection.Wifi => "Wi-Fi",
        AppSection.Favorites => "Favorites",
        AppSection.History => "History",
        _ => "Settings"
    };

    public bool IsDeviceSection => CurrentSection is AppSection.Scan or AppSection.Favorites or AppSection.History;
    public bool IsScanSection => CurrentSection == AppSection.Scan;
    public bool IsFavoritesSection => CurrentSection == AppSection.Favorites;
    public bool IsHistorySection => CurrentSection == AppSection.History;
    public bool IsWifiSection => CurrentSection == AppSection.Wifi;
    public bool IsSettingsSection => CurrentSection == AppSection.Settings;
    public string PrimaryActionLabel => IsScanning
        ? "Scanning..."
        : IsWifiScanning
            ? "Scanning Wi-Fi..."
            : IsWifiSection ? "Scan Wi-Fi" : "Scan";
    public bool CanStartScan => !IsScanning && !IsWifiScanning;
    public bool CanExport => IsDeviceSection && DisplayedDevices.Count > 0;
    public bool HasDisplayedDevices => DisplayedDevices.Count > 0;
    public bool HasWifiNetworks => DisplayedWifiNetworks.Count > 0;
    public bool HasSelectedDevice => SelectedDevice is not null;
    public string DeviceCountLabel => $"{DisplayedDevices.Count} found";
    public string WifiCountLabel => $"{DisplayedWifiNetworks.Count} networks";
    public int VendorDatabaseCount { get => _vendorDatabaseCount; private set => SetProperty(ref _vendorDatabaseCount, value); }

    public Device? SelectedDevice
    {
        get => _selectedDevice;
        set
        {
            if (!SetProperty(ref _selectedDevice, value)) return;
            OnPropertyChanged(nameof(HasSelectedDevice));
            RaiseDeviceCommands();
        }
    }

    public ScanHistory? SelectedHistory
    {
        get => _selectedHistory;
        set
        {
            if (!SetProperty(ref _selectedHistory, value)) return;
            if (IsHistorySection) RefreshDisplayedDevices();
        }
    }

    public string StatusMessage { get => _statusMessage; private set => SetProperty(ref _statusMessage, value); }
    public string WifiStatusMessage { get => _wifiStatusMessage; private set => SetProperty(ref _wifiStatusMessage, value); }
    public double Progress { get => _progress; private set => SetProperty(ref _progress, value); }

    public bool IsScanning
    {
        get => _isScanning;
        private set
        {
            if (!SetProperty(ref _isScanning, value)) return;
            OnPropertyChanged(nameof(PrimaryActionLabel));
            OnPropertyChanged(nameof(CanStartScan));
            PrimaryScanCommand.RaiseCanExecuteChanged();
            StopScanCommand.RaiseCanExecuteChanged();
        }
    }

    public bool IsWifiScanning
    {
        get => _isWifiScanning;
        private set
        {
            if (!SetProperty(ref _isWifiScanning, value)) return;
            OnPropertyChanged(nameof(PrimaryActionLabel));
            OnPropertyChanged(nameof(CanStartScan));
            PrimaryScanCommand.RaiseCanExecuteChanged();
            StopScanCommand.RaiseCanExecuteChanged();
        }
    }

    public bool IsUpdatingOui
    {
        get => _isUpdatingOui;
        private set
        {
            if (!SetProperty(ref _isUpdatingOui, value)) return;
            UpdateOuiCommand.RaiseCanExecuteChanged();
        }
    }

    public string SearchText
    {
        get => _searchText;
        set
        {
            if (!SetProperty(ref _searchText, value)) return;
            RefreshDisplayedDevices();
            RefreshWifiNetworks();
        }
    }

    public string IpRange
    {
        get => _ipRange;
        set { if (SetProperty(ref _ipRange, value)) Config.IpRange = value; }
    }

    public string PortsText
    {
        get => _portsText;
        set
        {
            if (!SetProperty(ref _portsText, value)) return;
            var parsed = value.Split([',', ' ', ';'], StringSplitOptions.RemoveEmptyEntries)
                .Select(x => int.TryParse(x, out var port) ? port : 0)
                .Where(x => x is >= 1 and <= 65535).Distinct().Order().ToList();
            if (parsed.Count > 0) Config.Ports = parsed;
        }
    }

    public double TimeoutSeconds
    {
        get => _timeoutSeconds;
        set { if (SetProperty(ref _timeoutSeconds, value)) Config.TimeoutSeconds = Math.Clamp(value, 0.2, 10); }
    }

    public int ConcurrencyLimit
    {
        get => _concurrencyLimit;
        set { if (SetProperty(ref _concurrencyLimit, value)) Config.ConcurrencyLimit = Math.Clamp(value, 1, 512); }
    }

    public bool VendorLookupEnabled
    {
        get => _vendorLookupEnabled;
        set { if (SetProperty(ref _vendorLookupEnabled, value)) Config.VendorLookupEnabled = value; }
    }

    public AppTheme Theme
    {
        get => _theme;
        set
        {
            if (!SetProperty(ref _theme, value)) return;
            Config.Theme = value;
            App.ApplyTheme(value);
        }
    }

    public void Navigate(AppSection section) => CurrentSection = section;

    public void SaveState()
    {
        Config.IpRange = IpRange;
        Config.TimeoutSeconds = TimeoutSeconds;
        Config.ConcurrencyLimit = ConcurrencyLimit;
        Config.VendorLookupEnabled = VendorLookupEnabled;
        Config.Theme = Theme;
        _persistence.Save(new AppStateData
        {
            Config = Config.Normalize(),
            Favorites = Favorites.ToList(),
            History = History.Take(25).ToList()
        });
    }

    public IReadOnlyList<Device> ExportDevices() => SelectedDevice is null ? DisplayedDevices.ToList() : [SelectedDevice];

    public void SetStatus(string message)
    {
        if (IsWifiSection) WifiStatusMessage = message;
        else StatusMessage = message;
    }

    private async Task StartPrimaryAsync()
    {
        if (IsWifiSection) await StartWifiScanAsync();
        else
        {
            Navigate(AppSection.Scan);
            await StartNetworkScanAsync();
        }
    }

    private async Task StartNetworkScanAsync()
    {
        IReadOnlyList<string> hosts;
        try { hosts = IPRangeParser.Parse(IpRange); }
        catch (Exception ex) { StatusMessage = ex.Message; return; }

        _scanCancellation = new CancellationTokenSource();
        IsScanning = true;
        Progress = 0;
        StatusMessage = $"Scanning {hosts.Count} host(s)...";
        Devices.Clear();
        RefreshDisplayedDevices();
        var startedAt = DateTimeOffset.Now;

        try
        {
            var progress = new Progress<ScanProgress>(update =>
            {
                Progress = update.Fraction;
                if (update.Device is not null)
                {
                    update.Device.IsFavorite = Favorites.Any(x => x.Matches(update.Device));
                    Devices.Add(update.Device);
                    RefreshDisplayedDevices();
                }
                StatusMessage = update.Device is null
                    ? $"Scanned {update.Completed} of {update.Total} host(s)"
                    : $"Found {Devices.Count} device(s)";
            });

            var finalDevices = await _scanner.ScanAsync(Config, progress, _scanCancellation.Token);
            Devices.Clear();
            foreach (var device in finalDevices)
            {
                device.IsFavorite = Favorites.Any(x => x.Matches(device));
                Devices.Add(device);
            }
            Progress = 1;
            StatusMessage = $"Scan complete · {Devices.Count} device(s)";
        }
        catch (OperationCanceledException)
        {
            StatusMessage = "Scan stopped";
        }
        catch (Exception ex)
        {
            StatusMessage = $"Scan failed: {ex.Message}";
        }
        finally
        {
            var finishedAt = DateTimeOffset.Now;
            History.Insert(0, new ScanHistory
            {
                StartedAt = startedAt,
                FinishedAt = finishedAt,
                IpRange = IpRange,
                TotalHosts = hosts.Count,
                FoundDevices = Devices.Count,
                Devices = Devices.ToList()
            });
            while (History.Count > 25) History.RemoveAt(History.Count - 1);
            SelectedHistory = History.FirstOrDefault();
            IsScanning = false;
            _scanCancellation.Dispose();
            _scanCancellation = null;
            RefreshDisplayedDevices();
            SaveState();
        }
    }

    private async Task StartWifiScanAsync()
    {
        _wifiCancellation = new CancellationTokenSource();
        IsWifiScanning = true;
        WifiStatusMessage = "Scanning nearby Wi-Fi networks...";
        WifiNetworks.Clear();
        RefreshWifiNetworks();
        try
        {
            var networks = await WifiScanner.ScanAsync(_wifiCancellation.Token);
            foreach (var network in networks) WifiNetworks.Add(network);
            WifiStatusMessage = networks.Count == 0 ? "No Wi-Fi networks found" : $"Scan complete · {networks.Count} network(s)";
        }
        catch (OperationCanceledException) { WifiStatusMessage = "Wi-Fi scan stopped"; }
        catch (Exception ex) { WifiStatusMessage = $"Wi-Fi scan failed: {ex.Message}"; }
        finally
        {
            IsWifiScanning = false;
            _wifiCancellation.Dispose();
            _wifiCancellation = null;
            RefreshWifiNetworks();
        }
    }

    private void StopScan()
    {
        StatusMessage = "Stopping scan...";
        WifiStatusMessage = "Stopping Wi-Fi scan...";
        _scanCancellation?.Cancel();
        _wifiCancellation?.Cancel();
    }

    private void DetectRange()
    {
        var range = LocalNetworkService.SuggestedRange();
        if (range is null) { StatusMessage = "Could not detect a local IPv4 range"; return; }
        IpRange = range;
        StatusMessage = $"Detected local range: {range}";
    }

    private void ToggleSelectedFavorite()
    {
        if (SelectedDevice is null) return;
        var existing = Favorites.FirstOrDefault(x => x.Matches(SelectedDevice));
        if (existing is not null)
        {
            Favorites.Remove(existing);
            SetFavoriteState(SelectedDevice, false);
            StatusMessage = $"Removed {SelectedDevice.DisplayName} from favorites";
        }
        else
        {
            SetFavoriteState(SelectedDevice, true);
            Favorites.Insert(0, SelectedDevice);
            StatusMessage = $"Added {SelectedDevice.DisplayName} to favorites";
        }
        ToggleFavoriteCommand.RaiseCanExecuteChanged();
        RefreshDisplayedDevices();
        SaveState();
    }

    private void SetFavoriteState(Device device, bool value)
    {
        foreach (var match in Devices.Where(x => x.Matches(device))) match.IsFavorite = value;
        foreach (var match in Favorites.Where(x => x.Matches(device))) match.IsFavorite = value;
        foreach (var match in History.SelectMany(x => x.Devices).Where(x => x.Matches(device))) match.IsFavorite = value;
        device.IsFavorite = value;
    }

    private void RunDeviceAction(Action<Device> action, string status)
    {
        if (SelectedDevice is null) return;
        try { action(SelectedDevice); StatusMessage = status; }
        catch (Exception ex) { StatusMessage = ex.Message; }
    }

    private void CopyIp()
    {
        if (SelectedDevice is null) return;
        Clipboard.SetText(SelectedDevice.IpAddress);
        StatusMessage = "Copied IP address";
    }

    private void CopyMac()
    {
        if (string.IsNullOrWhiteSpace(SelectedDevice?.MacAddress)) return;
        Clipboard.SetText(SelectedDevice.MacAddress);
        StatusMessage = "Copied MAC address";
    }

    private async Task WakeSelectedAsync()
    {
        if (string.IsNullOrWhiteSpace(SelectedDevice?.MacAddress)) return;
        try { await WakeOnLan.SendAsync(SelectedDevice.MacAddress); StatusMessage = "Wake-on-LAN packet sent"; }
        catch (Exception ex) { StatusMessage = $"Wake-on-LAN failed: {ex.Message}"; }
    }

    private void ClearHistory()
    {
        if (MessageBox.Show("Clear scan history? Favorites and current results stay unchanged.", "LanScope Windows", MessageBoxButton.YesNo, MessageBoxImage.Question) != MessageBoxResult.Yes)
            return;
        History.Clear();
        SelectedHistory = null;
        RefreshDisplayedDevices();
        ClearHistoryCommand.RaiseCanExecuteChanged();
        SaveState();
    }

    private async Task UpdateOuiAsync()
    {
        IsUpdatingOui = true;
        StatusMessage = "Updating OUI database from IEEE...";
        try
        {
            var count = await OuiDatabaseUpdater.UpdateAsync(UserOuiPath, CancellationToken.None);
            _vendorLookup = new VendorLookup(UserOuiPath);
            _scanner = new NetworkScanner(_vendorLookup);
            VendorDatabaseCount = count;
            StatusMessage = $"OUI database updated · {count:N0} records";
        }
        catch (Exception ex) { StatusMessage = $"OUI update failed: {ex.Message}"; }
        finally { IsUpdatingOui = false; }
    }

    private void RefreshDisplayedDevices()
    {
        IEnumerable<Device> source = CurrentSection switch
        {
            AppSection.Scan => Devices,
            AppSection.Favorites => Favorites,
            AppSection.History => SelectedHistory?.Devices ?? [],
            _ => []
        };
        var query = SearchText.Trim();
        if (query.Length > 0)
        {
            source = source.Where(x => string.Join(' ', [x.DisplayName, x.IpAddress, x.MacAddress ?? "", x.Vendor, x.ServicesDisplay])
                .Contains(query, StringComparison.CurrentCultureIgnoreCase));
        }
        ReplaceCollection(DisplayedDevices, source.OrderBy(x => IPRangeParser.ToUInt32(IPAddress.Parse(x.IpAddress))));
        OnPropertyChanged(nameof(HasDisplayedDevices));
        OnPropertyChanged(nameof(DeviceCountLabel));
        OnPropertyChanged(nameof(CanExport));
    }

    private void RefreshWifiNetworks()
    {
        IEnumerable<WifiNetwork> source = WifiNetworks;
        var query = SearchText.Trim();
        if (query.Length > 0)
        {
            source = source.Where(x => string.Join(' ', [x.DisplaySsid, x.Bssid, x.Security, x.Band, x.RadioType])
                .Contains(query, StringComparison.CurrentCultureIgnoreCase));
        }
        ReplaceCollection(DisplayedWifiNetworks, source.OrderByDescending(x => x.SignalPercent));
        OnPropertyChanged(nameof(HasWifiNetworks));
        OnPropertyChanged(nameof(WifiCountLabel));
    }

    private static void ReplaceCollection<T>(ObservableCollection<T> target, IEnumerable<T> values)
    {
        target.Clear();
        foreach (var value in values) target.Add(value);
    }

    private void RaiseDeviceCommands()
    {
        ToggleFavoriteCommand.RaiseCanExecuteChanged();
        OpenBrowserCommand.RaiseCanExecuteChanged();
        OpenSshCommand.RaiseCanExecuteChanged();
        OpenSmbCommand.RaiseCanExecuteChanged();
        OpenRdpCommand.RaiseCanExecuteChanged();
        CopyIpCommand.RaiseCanExecuteChanged();
        CopyMacCommand.RaiseCanExecuteChanged();
        WakeCommand.RaiseCanExecuteChanged();
    }

    private static string UserOuiPath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "LanScope Windows", "oui.json");
}

public enum AppSection
{
    Scan,
    Wifi,
    Favorites,
    History,
    Settings
}
