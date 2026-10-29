using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Security.Principal;
using System.Threading;
using System.Windows.Forms;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using Microsoft.Win32;

[assembly: AssemblyTitle("Painel de Comando MTZ")]
[assembly: AssemblyDescription("Sistema de Otimização, Tweaks e Desempenho Windows MTZ")]
[assembly: AssemblyCompany("MTZ")]
[assembly: AssemblyProduct("Painel de Comando MTZ")]
[assembly: AssemblyCopyright("Copyright © MTZ 2026")]
[assembly: AssemblyVersion("3.5.0.0")]
[assembly: AssemblyFileVersion("3.5.0.0")]

namespace MathzControl
{
    public static class Program
    {
        private const string AppVersion = "v3.5-standalone";
        private static Form _splash;

        [System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true)]
        private static extern bool SetProcessDpiAwarenessContext(IntPtr dpiContext);

        [System.Runtime.InteropServices.DllImport("shcore.dll", SetLastError = true)]
        private static extern int SetProcessDpiAwareness(int awareness);

        [System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true)]
        private static extern bool SetProcessDPIAware();

        private static void EnableHighDpi()
        {
            try
            {
                // DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 = -4 (Windows 10 1703+ e Windows 11)
                SetProcessDpiAwarenessContext(new IntPtr(-4));
            }
            catch
            {
                try
                {
                    // PROCESS_PER_MONITOR_DPI_AWARE = 2 (Windows 8.1+)
                    SetProcessDpiAwareness(2);
                }
                catch
                {
                    try { SetProcessDPIAware(); } catch { }
                }
            }
        }

        [STAThread]
        public static void Main(string[] args)
        {
            // Ativa renderizacao nativa Ultra HD / 4K / 2K Per-Monitor V2 sem escala bilinear borrada
            EnableHighDpi();

            // Verificacao e Elevacao Obrigatoria de Administrador
            bool isAdmin = false;
            try
            {
                using (WindowsIdentity identity = WindowsIdentity.GetCurrent())
                {
                    WindowsPrincipal principal = new WindowsPrincipal(identity);
                    isAdmin = principal.IsInRole(WindowsBuiltInRole.Administrator);
                }
            }
            catch { }

            if (!isAdmin)
            {
                try
                {
                    ProcessStartInfo psi = new ProcessStartInfo();
                    psi.FileName = Assembly.GetExecutingAssembly().Location;
                    psi.Verb = "runas";
                    psi.UseShellExecute = true;
                    if (args != null && args.Length > 0)
                    {
                        psi.Arguments = string.Join(" ", args);
                    }
                    Process.Start(psi);
                    return;
                }
                catch (Exception)
                {
                    MessageBox.Show(
                        "O Painel de Comando MTZ necessita de privilégios de Administrador para gerenciar hardware, serviços e otimizações do Windows.\n\nPor favor, confirme a elevação de Administrador (UAC) para continuar.",
                        "Permissão de Administrador Requerida",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Warning
                    );
                    return;
                }
            }

            string localApp = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            string targetDir = Path.Combine(localApp, "MathzControlPanel");

            // Tratamento de Desinstalacao (/uninstall)
            if (args != null && args.Length > 0 && args[0].Equals("/uninstall", StringComparison.OrdinalIgnoreCase))
            {
                UninstallApp(targetDir);
                return;
            }

            // Exibe Splash Screen Profissional com a Logo Oficial MTZ
            try
            {
                _splash = CreateSplashScreen();
                if (_splash != null)
                {
                    _splash.Show();
                    _splash.Refresh();
                }
            }
            catch { }

            try
            {
                string scriptPath = Path.Combine(targetDir, "MathzControlCenter", "MathzControlCenter.ps1");
                string versionFile = Path.Combine(targetDir, "version.txt");

                // Se executado dentro da pasta de desenvolvimento com os fontes locais
                string currentDir = AppDomain.CurrentDomain.BaseDirectory;
                string localScript = Path.Combine(currentDir, "MathzControlCenter", "MathzControlCenter.ps1");
                bool isDevEnv = File.Exists(localScript) && File.Exists(Path.Combine(currentDir, "builder", "Build-MathzControlPanel.ps1"));

                if (isDevEnv)
                {
                    targetDir = currentDir;
                    scriptPath = localScript;
                }
                else
                {
                    // Modo Autonomo (Estilo APK Standalone): Auto-instalacao silenciosa
                    bool needExtract = !File.Exists(scriptPath) || !File.Exists(versionFile);
                    if (!needExtract)
                    {
                        try
                        {
                            string installedVer = File.ReadAllText(versionFile).Trim();
                            if (installedVer != AppVersion) needExtract = true;
                        }
                        catch { needExtract = true; }
                    }

                    if (!needExtract)
                    {
                        try
                        {
                            string runningExe = Assembly.GetExecutingAssembly().Location;
                            if (File.Exists(runningExe) && File.Exists(scriptPath))
                            {
                                DateTime exeTime = File.GetLastWriteTimeUtc(runningExe);
                                DateTime scriptTime = File.GetLastWriteTimeUtc(scriptPath);
                                if (exeTime > scriptTime) needExtract = true;
                            }
                        }
                        catch { }
                    }

                    if (needExtract)
                    {
                        if (!Directory.Exists(targetDir))
                        {
                            Directory.CreateDirectory(targetDir);
                        }

                        // Extrai todo o pacote embutido de forma segura sobrescrevendo arquivos
                        Assembly asm = Assembly.GetExecutingAssembly();
                        using (Stream s = asm.GetManifestResourceStream("MathzPackage.zip"))
                        {
                            if (s != null)
                            {
                                string tempZip = Path.Combine(targetDir, "package.zip");
                                try
                                {
                                    using (FileStream fs = new FileStream(tempZip, FileMode.Create, FileAccess.Write))
                                    {
                                        s.CopyTo(fs);
                                    }

                                    using (ZipArchive archive = ZipFile.OpenRead(tempZip))
                                    {
                                        string runningExe = Assembly.GetExecutingAssembly().Location;
                                        foreach (ZipArchiveEntry entry in archive.Entries)
                                        {
                                            string destPath = Path.Combine(targetDir, entry.FullName);
                                            if (string.IsNullOrEmpty(entry.Name))
                                            {
                                                if (!Directory.Exists(destPath)) Directory.CreateDirectory(destPath);
                                            }
                                            else
                                            {
                                                string dir = Path.GetDirectoryName(destPath);
                                                if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);

                                                // Pular o proprio executavel se estiver rodando bloqueado a partir de targetDir
                                                if (string.Equals(destPath, runningExe, StringComparison.OrdinalIgnoreCase))
                                                {
                                                    continue;
                                                }

                                                try
                                                {
                                                    entry.ExtractToFile(destPath, true);
                                                }
                                                catch { }
                                            }
                                        }
                                    }
                                }
                                finally
                                {
                                    try { if (File.Exists(tempZip)) File.Delete(tempZip); } catch { }
                                }

                                try { File.WriteAllText(versionFile, AppVersion); } catch { }
                            }
                        }

                        // Copia o proprio executavel para a pasta instalada
                        string currentExe = Assembly.GetExecutingAssembly().Location;
                        string installedExe = Path.Combine(targetDir, "MathzControlPanel.exe");
                        try
                        {
                            if (!string.Equals(currentExe, installedExe, StringComparison.OrdinalIgnoreCase))
                            {
                                File.Copy(currentExe, installedExe, true);
                            }
                        }
                        catch { }

                        // Cria Atalhos no Desktop e Iniciar e Registra no Windows
                        string iconPath = Path.Combine(targetDir, "Mathz.ico");
                        if (!File.Exists(iconPath))
                            iconPath = Path.Combine(targetDir, "MathzControlCenter", "Assets", "Mathz.ico");

                        CreateShortcuts(installedExe, iconPath);
                        RegisterInWindows(installedExe, iconPath, targetDir);

                        if (args != null && args.Length > 0 && args[0].Equals("/install", StringComparison.OrdinalIgnoreCase))
                        {
                            CloseSplash();
                            MessageBox.Show(
                                "Painel de Comando MTZ instalado com sucesso no seu Windows!\n\n" +
                                "O atalho foi criado na sua Área de Trabalho e no Menu Iniciar.",
                                "Painel de Comando MTZ",
                                MessageBoxButtons.OK,
                                MessageBoxIcon.Information
                            );
                        }
                    }
                }

                if (!File.Exists(scriptPath))
                {
                    CloseSplash();
                    MessageBox.Show(
                        "Não foi possível inicializar o Painel de Comando MTZ.\n\n" +
                        "Certifique-se de que os arquivos do aplicativo foram extraídos corretamente.",
                        "Painel de Comando MTZ",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Error
                    );
                    return;
                }

                // Timer de seguranca para fechar o splash em 2.2 segundos se o WPF demorar
                var safetyTimer = new System.Windows.Forms.Timer();
                safetyTimer.Interval = 2200;
                safetyTimer.Tick += (s, e) => {
                    safetyTimer.Stop();
                    safetyTimer.Dispose();
                    CloseSplash();
                };
                safetyTimer.Start();

                // Execucao NATIVA IN-PROCESS via Runspace STA (0 terminal, 0 processo powershell externo!)
                string scriptContent = File.ReadAllText(scriptPath);
                var initial = InitialSessionState.CreateDefault();
                initial.ApartmentState = ApartmentState.STA;
                initial.ThreadOptions = PSThreadOptions.UseCurrentThread;

                using (var runspace = RunspaceFactory.CreateRunspace(initial))
                {
                    runspace.Open();
                    using (var ps = PowerShell.Create())
                    {
                        ps.Runspace = runspace;

                        string setupEnv = string.Format(
                            "$global:PSScriptRoot = '{0}'; Set-Location '{0}';\n",
                            Path.GetDirectoryName(scriptPath).Replace("'", "''")
                        );

                        ps.AddScript(setupEnv + scriptContent);
                        ps.Invoke();
                    }
                }
            }
            catch (Exception ex)
            {
                CloseSplash();
                MessageBox.Show("Erro ao inicializar o Painel de Comando MTZ:\n\n" + ex.Message, "Painel de Comando MTZ", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            finally
            {
                CloseSplash();
            }
        }

        public static void CloseSplash()
        {
            if (_splash != null)
            {
                try
                {
                    if (_splash.InvokeRequired)
                    {
                        _splash.BeginInvoke(new Action(() => {
                            try { _splash.Close(); _splash.Dispose(); _splash = null; } catch { }
                        }));
                    }
                    else
                    {
                        _splash.Close();
                        _splash.Dispose();
                        _splash = null;
                    }
                }
                catch { }
            }
        }

        public static void CreateShortcuts(string targetExe, string iconPath)
        {
            try
            {
                Type shellType = Type.GetTypeFromProgID("WScript.Shell");
                if (shellType == null) return;
                dynamic shell = Activator.CreateInstance(shellType);
                if (shell == null) return;

                // 1. Atalho na Area de Trabalho
                string desktop = Environment.GetFolderPath(Environment.SpecialFolder.Desktop);
                string desktopLnk = Path.Combine(desktop, "Painel de Comando MTZ.lnk");
                dynamic shortcut = shell.CreateShortcut(desktopLnk);
                shortcut.TargetPath = targetExe;
                shortcut.WorkingDirectory = Path.GetDirectoryName(targetExe);
                shortcut.Description = "Painel de Comando MTZ - Sistema de Otimizacao & Desempenho";
                if (File.Exists(iconPath))
                {
                    shortcut.IconLocation = iconPath + ",0";
                }
                shortcut.Save();

                // 2. Atalho no Menu Iniciar
                string programs = Environment.GetFolderPath(Environment.SpecialFolder.Programs);
                string startLnk = Path.Combine(programs, "Painel de Comando MTZ.lnk");
                dynamic startShortcut = shell.CreateShortcut(startLnk);
                startShortcut.TargetPath = targetExe;
                startShortcut.WorkingDirectory = Path.GetDirectoryName(targetExe);
                startShortcut.Description = "Painel de Comando MTZ - Sistema de Otimizacao & Desempenho";
                if (File.Exists(iconPath))
                {
                    startShortcut.IconLocation = iconPath + ",0";
                }
                startShortcut.Save();
            }
            catch { }
        }

        public static void RegisterInWindows(string targetExe, string iconPath, string installDir)
        {
            try
            {
                using (RegistryKey key = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Uninstall\MathzControlPanel"))
                {
                    if (key != null)
                    {
                        key.SetValue("DisplayName", "Painel de Comando MTZ");
                        key.SetValue("DisplayVersion", "3.4 Pro");
                        key.SetValue("Publisher", "MTZ Performance");
                        key.SetValue("DisplayIcon", iconPath);
                        key.SetValue("InstallLocation", installDir);
                        key.SetValue("UninstallString", "\"" + targetExe + "\" /uninstall");
                        key.SetValue("NoModify", 1, RegistryValueKind.DWord);
                        key.SetValue("NoRepair", 1, RegistryValueKind.DWord);
                    }
                }
            }
            catch { }
        }

        public static void UninstallApp(string installDir)
        {
            try
            {
                // Remove Atalhos
                string desktopLnk = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Desktop), "Painel de Comando MTZ.lnk");
                if (File.Exists(desktopLnk)) try { File.Delete(desktopLnk); } catch { }

                string startLnk = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), "Painel de Comando MTZ.lnk");
                if (File.Exists(startLnk)) try { File.Delete(startLnk); } catch { }

                // Remove Registro
                try
                {
                    Registry.CurrentUser.DeleteSubKeyTree(@"Software\Microsoft\Windows\CurrentVersion\Uninstall\MathzControlPanel", false);
                }
                catch { }

                // Exibe Confirmacao
                MessageBox.Show(
                    "Painel de Comando MTZ desinstalado com sucesso do seu sistema.",
                    "Painel de Comando MTZ",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Information
                );
            }
            catch { }
        }

        static Form CreateSplashScreen()
        {
            Form form = new Form();
            form.Text = "Painel de Comando MTZ";
            form.FormBorderStyle = FormBorderStyle.None;
            form.StartPosition = FormStartPosition.CenterScreen;
            form.Size = new Size(360, 230);
            form.BackColor = Color.FromArgb(5, 5, 5);
            form.ShowInTaskbar = false;
            form.TopMost = true;

            // Borda Minimalista Preto & Vermelho MTZ (#FF1E27)
            Panel borderPanel = new Panel();
            borderPanel.Dock = DockStyle.Fill;
            borderPanel.Paint += (s, e) =>
            {
                using (Pen pen = new Pen(Color.FromArgb(255, 30, 39), 1.5f))
                {
                    e.Graphics.DrawRectangle(pen, 1, 1, form.Width - 2, form.Height - 2);
                }
            };
            form.Controls.Add(borderPanel);

            // Carrega Logo Oficial MTZ
            string currentDir = AppDomain.CurrentDomain.BaseDirectory;
            string logoPath = Path.Combine(currentDir, "MTZ_Logo.png");
            if (!File.Exists(logoPath))
                logoPath = Path.Combine(currentDir, "MathzControlCenter", "Assets", "MTZ_Logo.png");
            if (!File.Exists(logoPath))
                logoPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "MathzControlPanel", "MTZ_Logo.png");

            PictureBox pic = new PictureBox();
            pic.Size = new Size(76, 76);
            pic.Location = new Point((form.Width - pic.Width) / 2, 22);
            pic.SizeMode = PictureBoxSizeMode.Zoom;
            if (File.Exists(logoPath))
            {
                try { pic.Image = Image.FromFile(logoPath); } catch { }
            }
            borderPanel.Controls.Add(pic);

            Label lblTitle = new Label();
            lblTitle.Text = "PAINEL DE COMANDO MTZ";
            lblTitle.Font = new Font("Segoe UI", 11.5f, FontStyle.Bold);
            lblTitle.ForeColor = Color.White;
            lblTitle.TextAlign = ContentAlignment.MiddleCenter;
            lblTitle.Size = new Size(form.Width, 24);
            lblTitle.Location = new Point(0, 110);
            borderPanel.Controls.Add(lblTitle);

            Label lblSub = new Label();
            lblSub.Text = "Sistema de Otimização & Desempenho";
            lblSub.Font = new Font("Segoe UI", 9f, FontStyle.Regular);
            lblSub.ForeColor = Color.FromArgb(140, 140, 140);
            lblSub.TextAlign = ContentAlignment.MiddleCenter;
            lblSub.Size = new Size(form.Width, 20);
            lblSub.Location = new Point(0, 138);
            borderPanel.Controls.Add(lblSub);

            ProgressBar pb = new ProgressBar();
            pb.Style = ProgressBarStyle.Marquee;
            pb.MarqueeAnimationSpeed = 25;
            pb.Size = new Size(180, 3);
            pb.Location = new Point((form.Width - pb.Width) / 2, 178);
            borderPanel.Controls.Add(pb);

            return form;
        }
    }
}
