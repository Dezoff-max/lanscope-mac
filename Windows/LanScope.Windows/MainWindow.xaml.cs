using System.Windows;
using System.Windows.Controls;
using LanScope.Core.Services;
using LanScope.Windows.ViewModels;
using Microsoft.Win32;

namespace LanScope.Windows;

public partial class MainWindow : Window
{
    private readonly MainViewModel _viewModel = new();

    public MainWindow()
    {
        InitializeComponent();
        DataContext = _viewModel;
        Closed += (_, _) => _viewModel.SaveState();
    }

    private void Navigation_Click(object sender, RoutedEventArgs e)
    {
        if (sender is RadioButton { Tag: string value } && Enum.TryParse<AppSection>(value, true, out var section))
            _viewModel.Navigate(section);
    }

    private void ExportCsv_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new SaveFileDialog
        {
            FileName = "lanscope-devices.csv",
            DefaultExt = ".csv",
            Filter = "CSV file (*.csv)|*.csv|JSON file (*.json)|*.json"
        };
        if (dialog.ShowDialog(this) != true) return;
        try
        {
            var devices = _viewModel.ExportDevices();
            var content = dialog.FileName.EndsWith(".json", StringComparison.OrdinalIgnoreCase)
                ? ExportService.ToJson(devices)
                : ExportService.ToCsv(devices);
            ExportService.SaveUtf8(dialog.FileName, content);
            _viewModel.SetStatus($"Exported {devices.Count} device(s)");
        }
        catch (Exception ex)
        {
            _viewModel.SetStatus($"Export failed: {ex.Message}");
        }
    }

    private void CopyRows_Click(object sender, RoutedEventArgs e)
    {
        var devices = _viewModel.ExportDevices();
        if (devices.Count == 0) return;
        Clipboard.SetText(ExportService.ToTsv(devices));
        _viewModel.SetStatus($"Copied {devices.Count} row(s)");
    }
}
