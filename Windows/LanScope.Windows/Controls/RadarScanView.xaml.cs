using System.Windows;
using System.Windows.Controls;

namespace LanScope.Windows.Controls;

public partial class RadarScanView : UserControl
{
    public static readonly DependencyProperty IsScanningProperty = DependencyProperty.Register(
        nameof(IsScanning),
        typeof(bool),
        typeof(RadarScanView),
        new PropertyMetadata(false));

    public RadarScanView() => InitializeComponent();

    public bool IsScanning
    {
        get => (bool)GetValue(IsScanningProperty);
        set => SetValue(IsScanningProperty, value);
    }
}
