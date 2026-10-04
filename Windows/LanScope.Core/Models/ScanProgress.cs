namespace LanScope.Core.Models;

public sealed record ScanProgress(int Completed, int Total, Device? Device = null)
{
    public double Fraction => Total == 0 ? 0 : (double)Completed / Total;
}
