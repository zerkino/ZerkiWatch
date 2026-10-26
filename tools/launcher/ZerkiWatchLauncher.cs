// ZerkiWatch.exe - tiny launcher (no embedded script, no network, no hidden payload).
// It only starts the ZerkiWatch.bat that sits next to it (the whole program is readable there).
// Elevation (administrator) is requested by app.manifest.
using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

[assembly: AssemblyTitle("ZerkiWatch")]
[assembly: AssemblyProduct("ZerkiWatch")]
[assembly: AssemblyCompany("zerkino")]
[assembly: AssemblyDescription("Launcher for ZerkiWatch.bat - https://github.com/zerkino/ZerkiWatch")]
[assembly: AssemblyCopyright("MIT License - zerkino")]
[assembly: AssemblyVersion("7.0.0.0")]
[assembly: AssemblyFileVersion("7.0.0.0")]

static class ZerkiWatchLauncher
{
    [STAThread]
    static int Main(string[] args)
    {
        string dir = AppDomain.CurrentDomain.BaseDirectory;
        string bat = Path.Combine(dir, "ZerkiWatch.bat");
        if (!File.Exists(bat))
        {
            MessageBox.Show("ZerkiWatch.bat was not found next to ZerkiWatch.exe.\nKeep both files in the same folder.", "ZerkiWatch");
            return 1;
        }
        string extra = args.Length > 0 ? " " + string.Join(" ", args) : "";
        ProcessStartInfo psi = new ProcessStartInfo("cmd.exe", "/c \"\"" + bat + "\"" + extra + "\"");
        psi.WorkingDirectory = dir;
        psi.UseShellExecute = false;
        psi.CreateNoWindow = true;
        Process.Start(psi);
        return 0;
    }
}
