// Single-file wrapper: the Flutter release folder is embedded as app.zip, unpacked
// once per build into %LOCALAPPDATA%\MoustacheDare\<build id>, then launched.
using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Windows.Forms;

[assembly: AssemblyTitle("Moustache Dare")]

static class Launcher
{
    [STAThread]
    static void Main()
    {
        try
        {
            var asm = Assembly.GetExecutingAssembly();
            string buildId;
            using (var s = asm.GetManifestResourceStream("build_id.txt"))
            using (var r = new StreamReader(s)) buildId = r.ReadToEnd().Trim();

            var root = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "MoustacheDare");
            var dir = Path.Combine(root, buildId);
            var exe = Path.Combine(dir, "moustache.exe");

            if (!File.Exists(exe))
            {
                // Drop older builds before unpacking this one.
                if (Directory.Exists(root))
                    foreach (var old in Directory.GetDirectories(root))
                        try { Directory.Delete(old, true); } catch { }

                var tmp = dir + ".tmp";
                if (Directory.Exists(tmp)) Directory.Delete(tmp, true);
                using (var s = asm.GetManifestResourceStream("app.zip"))
                using (var zip = new ZipArchive(s, ZipArchiveMode.Read))
                    zip.ExtractToDirectory(tmp);
                Directory.Move(tmp, dir);
            }

            Process.Start(new ProcessStartInfo(exe) { WorkingDirectory = dir, UseShellExecute = false });
        }
        catch (Exception e)
        {
            MessageBox.Show(e.Message, "Moustache Dare", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }
}
