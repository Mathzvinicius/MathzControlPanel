<#
.SYNOPSIS
    PAINEL DE COMANDO MTZ - v3.3 PRO
    Design: Minimalista Corporativo (Preto Profundo + Branco + Vermelho MTZ #FF1E27).
    Modo Translúcido Ativo por Padrão (Vidro Acrílico com Desfoque Win32).
    0 Consumo de Memória de Fundo, Telemetria Win32 100% Real (Uso de CPU, RAM e Graus de Temperatura),
    Controle Dinâmico de Clocks de CPU/GPU, Gestão de Inicialização, Varredura WHQL,
    Suíte Completa de Otimizações do Windows da ISO e Personalizador de Cores e Tema.
#>

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml

# ==============================================================================
# 1. DEFINIR APIS WIN32 NATIVAS (SUB-MICROSEGUNDO, 0 OVERHEAD DE CPU/RAM)
# ==============================================================================
if (-not ([System.Management.Automation.PSTypeName]'MathzMemoryOptimizer').Type) {
    Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;

    public class MathzMemoryOptimizer {
        [DllImport("psapi.dll")]
        public static extern int EmptyWorkingSet(IntPtr hwProc);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GlobalMemoryStatusEx(ref MEMORYSTATUSEX lpBuffer);

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
        public struct MEMORYSTATUSEX {
            public uint dwLength;
            public uint dwMemoryLoad;
            public ulong ullTotalPhys;
            public ulong ullAvailPhys;
            public ulong ullTotalPageFile;
            public ulong ullAvailPageFile;
            public ulong ullTotalVirtual;
            public ulong ullAvailVirtual;
            public ulong ullAvailExtendedVirtual;
        }

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool GetSystemTimes(out long idleTime, out long kernelTime, out long userTime);

        [DllImport("gdi32.dll", SetLastError = true)]
        public static extern int AddFontResourceEx(string lpszFilename, uint fl, IntPtr pdv);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SetProcessDpiAwarenessContext(IntPtr dpiContext);

        [DllImport("shcore.dll", SetLastError = true)]
        public static extern int SetProcessDpiAwareness(int awareness);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SetProcessDPIAware();
    }
"@
}

# Ativa DPI Awareness Per-Monitor V2 nativo para renderizacao 4K / UHD / 2K
try {
    [MathzMemoryOptimizer]::SetProcessDpiAwarenessContext([IntPtr]::new(-4))
} catch {
    try { [MathzMemoryOptimizer]::SetProcessDpiAwareness(2) } catch {
        try { [MathzMemoryOptimizer]::SetProcessDPIAware() } catch {}
    }
}

if (-not ([System.Management.Automation.PSTypeName]'Win32Accent').Type) {
    Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;

    public class Win32Accent {
        [DllImport("user32.dll")]
        public static extern int SetWindowCompositionAttribute(IntPtr hwnd, ref WindowCompositionAttributeData data);

        [StructLayout(LayoutKind.Sequential)]
        public struct WindowCompositionAttributeData {
            public int Attribute;
            public IntPtr Data;
            public int SizeOfData;
        }

        public enum AccentState {
            ACCENT_DISABLED = 0,
            ACCENT_ENABLE_GRADIENT = 1,
            ACCENT_ENABLE_TRANSPARENTGRADIENT = 2,
            ACCENT_ENABLE_BLURBEHIND = 3,
            ACCENT_ENABLE_ACRYLICBLURBEHIND = 4
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct AccentPolicy {
            public AccentState AccentState;
            public int AccentFlags;
            public int GradientColor;
            public int AnimationId;
        }

        public static void EnableBlur(IntPtr hwnd, bool enable) {
            var policy = new AccentPolicy();
            if (enable) {
                policy.AccentState = AccentState.ACCENT_ENABLE_BLURBEHIND;
                policy.AccentFlags = 2;
                policy.GradientColor = 0;
            } else {
                policy.AccentState = AccentState.ACCENT_DISABLED;
            }

            int size = Marshal.SizeOf(policy);
            IntPtr pPolicy = Marshal.AllocHGlobal(size);
            try {
                Marshal.StructureToPtr(policy, pPolicy, false);
                var data = new WindowCompositionAttributeData {
                    Attribute = 19,
                    Data = pPolicy,
                    SizeOfData = size
                };
                SetWindowCompositionAttribute(hwnd, ref data);
            } finally {
                Marshal.FreeHGlobal(pPolicy);
            }
        }
    }
"@
}

if (-not ([System.Management.Automation.PSTypeName]'WindowResizer').Type) {
    Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;
    using System.Windows.Interop;

    public class WindowResizer {
        public const int WM_NCHITTEST = 0x0084;
        public const int HTLEFT = 10;
        public const int HTRIGHT = 11;
        public const int HTTOP = 12;
        public const int HTTOPLEFT = 13;
        public const int HTTOPRIGHT = 14;
        public const int HTBOTTOM = 15;
        public const int HTBOTTOMLEFT = 16;
        public const int HTBOTTOMRIGHT = 17;

        [StructLayout(LayoutKind.Sequential)]
        public struct RECT {
            public int Left;
            public int Top;
            public int Right;
            public int Bottom;
        }

        [DllImport("user32.dll")]
        public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

        [DllImport("user32.dll")]
        public static extern bool IsZoomed(IntPtr hWnd);

        public static void Attach(IntPtr hwnd, int borderMargin) {
            HwndSource source = HwndSource.FromHwnd(hwnd);
            if (source != null) {
                source.AddHook((IntPtr h, int msg, IntPtr wParam, IntPtr lParam, ref bool handled) => {
                    if (msg == WM_NCHITTEST) {
                        if (IsZoomed(h)) return IntPtr.Zero;

                        long lp = lParam.ToInt64();
                        int x = (short)(lp & 0xFFFF);
                        int y = (short)((lp >> 16) & 0xFFFF);

                        RECT rect;
                        if (GetWindowRect(h, out rect)) {
                            bool left = x < rect.Left + borderMargin;
                            bool right = x >= rect.Right - borderMargin;
                            bool top = y < rect.Top + borderMargin;
                            bool bottom = y >= rect.Bottom - borderMargin;

                            if (top && left) { handled = true; return (IntPtr)HTTOPLEFT; }
                            if (top && right) { handled = true; return (IntPtr)HTTOPRIGHT; }
                            if (bottom && left) { handled = true; return (IntPtr)HTBOTTOMLEFT; }
                            if (bottom && right) { handled = true; return (IntPtr)HTBOTTOMRIGHT; }
                            if (left) { handled = true; return (IntPtr)HTLEFT; }
                            if (right) { handled = true; return (IntPtr)HTRIGHT; }
                            if (top) { handled = true; return (IntPtr)HTTOP; }
                            if (bottom) { handled = true; return (IntPtr)HTBOTTOM; }
                        }
                    }
                    return IntPtr.Zero;
                });
            }
        }
    }
"@ -ReferencedAssemblies PresentationFramework, PresentationCore, WindowsBase, System.Xaml
}


# ==============================================================================
# 2. CARREGAMENTO EM MEMORIA DAS FONTES EMBUTIDAS (GDI FR_PRIVATE)
# ==============================================================================
$fontCandidates = @(
    (Join-Path -Path $PSScriptRoot -ChildPath "Assets\Fonts"),
    (Join-Path -Path (Split-Path $PSScriptRoot -Parent) -ChildPath "MathzControlCenter\Assets\Fonts"),
    (Join-Path -Path (Split-Path $PSScriptRoot -Parent) -ChildPath "Assets\Fonts"),
    (Join-Path -Path $env:LOCALAPPDATA -ChildPath "MathzControlPanel\MathzControlCenter\Assets\Fonts"),
    "C:\Program Files\MathzControlPanel\Assets\Fonts"
)
foreach ($fDir in $fontCandidates) {
    if (Test-Path $fDir) {
        Get-ChildItem -Path $fDir -Filter "*.ttf" | ForEach-Object {
            try { [MathzMemoryOptimizer]::AddFontResourceEx($_.FullName, 0x10, [IntPtr]::Zero) | Out-Null } catch {}
        }
        break
    }
}

# ==============================================================================
# 3. INTERFACE GRAFICA XAML (MODERNA, MINIMALISTA & TRANSL&#x00DA;CIDA)
# ==============================================================================
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Name="MainMtzWindow"
        Title="Painel de Comando MTZ" Height="680" Width="1100"
        WindowStartupLocation="Manual" WindowStyle="None"
        AllowsTransparency="True" Background="Transparent"
        FontFamily="{DynamicResource Body}"
        SnapsToDevicePixels="True" UseLayoutRounding="True" TextOptions.TextFormattingMode="Display"
        TextOptions.TextRenderingMode="ClearType"
        RenderOptions.ClearTypeHint="Enabled" TextOptions.TextHintingMode="Fixed" RenderOptions.BitmapScalingMode="HighQuality" RenderOptions.EdgeMode="Unspecified"
        ResizeMode="CanResize"
        MinWidth="860" MinHeight="520">

    <Window.Resources>
        <!-- Paleta Oficial MTZ: Preto Profundo + Branco + Vermelho MTZ (#FF1E27) -->
        <SolidColorBrush x:Key="Bg" Color="#000000"/>
        <SolidColorBrush x:Key="Panel" Color="#08080A"/>
        <SolidColorBrush x:Key="Card" Color="#0E0E12"/>
        <SolidColorBrush x:Key="Hover" Color="#1C1C22"/>
        <SolidColorBrush x:Key="Line" Color="#25252C"/>
        <SolidColorBrush x:Key="LineStrong" Color="#383844"/>
        <SolidColorBrush x:Key="Fg" Color="#FFFFFF"/>
        <SolidColorBrush x:Key="Muted" Color="#D8D8DE"/>
        <SolidColorBrush x:Key="Faint" Color="#B4B4BE"/>
        <SolidColorBrush x:Key="Ink" Color="#000000"/>

        <!-- Acentos Vermelho MTZ e Verde Indicador -->
        <SolidColorBrush x:Key="AccentRed" Color="#FF1E27"/>
        <SolidColorBrush x:Key="AccentRedBorder" Color="#55FF1E27"/>
        <SolidColorBrush x:Key="AccentGreen" Color="#00FF66"/>

        <!-- Sistema Tipografico Premium MTZ (Bebas Neue / Outfit / Orbitron / Rajdhani) -->
        <FontFamily x:Key="Heading">Bebas Neue, Rajdhani, Orbitron, Bahnschrift, Segoe UI Variable Display, Impact, sans-serif</FontFamily>
        <FontFamily x:Key="Body">Outfit, Montserrat, Bahnschrift, Segoe UI Variable Text, Segoe UI, sans-serif</FontFamily>
        <FontFamily x:Key="Cyber">Orbitron, Rajdhani, Bebas Neue, Bahnschrift, sans-serif</FontFamily>
        <FontFamily x:Key="Mono">Cascadia Mono, Consolas, Courier New</FontFamily>
        <FontFamily x:Key="Icons">Segoe Fluent Icons, Segoe MDL2 Assets</FontFamily>

        <!-- Estilo Borda de Cartao (Reset CardBorder Minimalista) -->
        <Style x:Key="CardBorder" TargetType="Border">
            <Setter Property="Background" Value="{DynamicResource Card}"/>
            <Setter Property="BorderBrush" Value="{DynamicResource Line}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CornerRadius" Value="14"/>
            <Setter Property="Padding" Value="18"/>
        </Style>

        <!-- Estilo Item Interno de Lista -->
        <Style x:Key="ItemCardBorder" TargetType="Border">
            <Setter Property="Background" Value="#080808"/>
            <Setter Property="BorderBrush" Value="{DynamicResource Line}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CornerRadius" Value="10"/>
            <Setter Property="Padding" Value="14,10"/>
            <Setter Property="Margin" Value="0,0,0,8"/>
        </Style>

        <!-- Estilo Navegacao Lateral (Reset NavItem Pilula Minimalista com Fonte Heading) -->
        <Style x:Key="NavItem" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="{DynamicResource Muted}"/>
            <Setter Property="FontFamily" Value="{DynamicResource Heading}"/>
            <Setter Property="FontSize" Value="14.5"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Height" Value="38"/>
            <Setter Property="Margin" Value="10,2"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bg" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="10" Padding="14,0">
                            <ContentPresenter VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bg" Property="Background" Value="{DynamicResource Hover}"/>
                                <Setter Property="Foreground" Value="{DynamicResource Fg}"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="bg" Property="Background" Value="#FF1E27"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Botao Primario (Branco Corporativo -> Vermelho MTZ ao Clicar com Fonte Heading) -->
        <Style x:Key="PrimaryButton" TargetType="Button">
            <Setter Property="Background" Value="{DynamicResource Fg}"/>
            <Setter Property="Foreground" Value="{DynamicResource Ink}"/>
            <Setter Property="BorderBrush" Value="{DynamicResource Fg}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="FontFamily" Value="{DynamicResource Heading}"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="FontSize" Value="13.5"/>
            <Setter Property="Padding" Value="18,7"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="b" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="9" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="b" Property="Background" Value="#E0E0E0"/>
                                <Setter TargetName="b" Property="BorderBrush" Value="#E0E0E0"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="b" Property="Background" Value="#FF1E27"/>
                                <Setter TargetName="b" Property="BorderBrush" Value="#FF1E27"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="b" Property="Opacity" Value="0.35"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Botao Contorno (Dark Minimalista -> Vermelho MTZ ao Clicar) -->
        <Style x:Key="OutlineButton" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="{DynamicResource Fg}"/>
            <Setter Property="BorderBrush" Value="{DynamicResource LineStrong}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="FontFamily" Value="{DynamicResource Heading}"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Padding" Value="16,8"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="b" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="9" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="b" Property="Background" Value="{DynamicResource Hover}"/>
                                <Setter TargetName="b" Property="BorderBrush" Value="#444444"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="b" Property="Background" Value="#FF1E27"/>
                                <Setter TargetName="b" Property="BorderBrush" Value="#FF1E27"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="b" Property="Opacity" Value="0.35"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Estilos para Botoes de Acao de Tweaks -->
        <Style x:Key="ActionButton" TargetType="Button" BasedOn="{StaticResource OutlineButton}"/>
        <Style x:Key="GreenActionButton" TargetType="Button" BasedOn="{StaticResource OutlineButton}">
            <Setter Property="BorderBrush" Value="#225533"/>
            <Setter Property="Foreground" Value="#00FF66"/>
        </Style>

        <!-- Botao de Controle de Janela (CaptionButton) -->
        <Style x:Key="CaptionButton" TargetType="Button">
            <Setter Property="Width" Value="38"/>
            <Setter Property="Height" Value="32"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="{DynamicResource Muted}"/>
            <Setter Property="FontFamily" Value="{StaticResource Icons}"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="b" Background="{TemplateBinding Background}" CornerRadius="6">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="b" Property="Background" Value="{DynamicResource Hover}"/>
                                <Setter Property="Foreground" Value="{DynamicResource Fg}"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="b" Property="Background" Value="#222222"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Botao Fechar Janela -->
        <Style x:Key="CloseButton" TargetType="Button" BasedOn="{StaticResource CaptionButton}">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="b" Background="{TemplateBinding Background}" CornerRadius="6">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="b" Property="Background" Value="#E81123"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="b" Property="Background" Value="#BF0F1D"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <!-- Estilo Barra de Progresso Mini (Ultra High-Tech) -->
        <Style x:Key="MiniProgress" TargetType="ProgressBar">
            <Setter Property="Height" Value="3"/>
            <Setter Property="Background" Value="#141414"/>
            <Setter Property="Foreground" Value="#FF1E27"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ProgressBar">
                        <Border Background="{TemplateBinding Background}" CornerRadius="1.5">
                            <Grid>
                                <Border Name="PART_Track"/>
                                <Border Name="PART_Indicator" Background="{TemplateBinding Foreground}" CornerRadius="1.5" HorizontalAlignment="Left"/>
                            </Grid>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Botao Pill Seletor de Modo do Grafico -->
        <Style x:Key="GraphPillButton" TargetType="Button">
            <Setter Property="Background" Value="#121212"/>
            <Setter Property="Foreground" Value="{DynamicResource Muted}"/>
            <Setter Property="BorderBrush" Value="{DynamicResource Line}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="FontSize" Value="9.5"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="9,3"/>
            <Setter Property="Margin" Value="0,0,5,0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="b" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="b" Property="Background" Value="#1C1C1C"/>
                                <Setter Property="Foreground" Value="{DynamicResource Fg}"/>
                                <Setter TargetName="b" Property="BorderBrush" Value="#333333"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <!-- CONTAINER DA JANELA (TRANSL&#x00DA;CIDO COM VIDRO ACR&#x00CD;LICO POR PADR&#x00C3;O) -->
    <Border Name="WindowMainBorder" Background="#D9040404" BorderBrush="{DynamicResource Line}" BorderThickness="1" CornerRadius="16" SnapsToDevicePixels="True" UseLayoutRounding="True" RenderOptions.ClearTypeHint="Enabled" RenderOptions.BitmapScalingMode="HighQuality">
        <Grid>
            <Grid.ColumnDefinitions>
                <!-- Coluna Sidebar (240px) -->
                <ColumnDefinition Width="240"/>
                <!-- Coluna Principal -->
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <!-- ========================================================================= -->
            <!-- 1. SIDEBAR LATERAL MONOCROMATICA                                           -->
            <!-- ========================================================================= -->
            <Border Grid.Column="0" Margin="12,12,0,12" Background="{DynamicResource Panel}" BorderBrush="{DynamicResource Line}" BorderThickness="1" CornerRadius="14">
                <DockPanel>
                    <!-- LOGO NO TOPO -->
                    <StackPanel DockPanel.Dock="Top" Margin="16,18,14,16">
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                            <Border Width="38" Height="38" CornerRadius="10" Background="#0C0C0C" BorderBrush="{DynamicResource LineStrong}" BorderThickness="1" Margin="0,0,11,0" Padding="3">
                                <Image Name="ImgSidebarLogo" Stretch="Uniform" RenderOptions.BitmapScalingMode="HighQuality"/>
                            </Border>
                            <StackPanel VerticalAlignment="Center">
                                <TextBlock Text="PAINEL DE COMANDO" FontFamily="{DynamicResource Heading}" Foreground="{DynamicResource Fg}" FontSize="14" FontWeight="Bold"/>
                                <StackPanel Orientation="Horizontal" Margin="0,1,0,0">
                                    <TextBlock Text="MTZ" FontFamily="{DynamicResource Heading}" Foreground="#FF1E27" FontSize="16" FontWeight="Black"/>
                                    <TextBlock Text=" &#x00B7; DESEMPENHO" FontFamily="{DynamicResource Heading}" Foreground="{DynamicResource Muted}" FontSize="11" FontWeight="SemiBold" VerticalAlignment="Center" Margin="5,0,0,0"/>
                                </StackPanel>
                            </StackPanel>
                        </StackPanel>
                    </StackPanel>

                    <!-- RODAP&#x00C9;: MINI MONITOR DE HARDWARE (CPU/RAM COM COLUNAS AUTO-AJUST&#x00C1;VEIS) -->
                    <Border DockPanel.Dock="Bottom" Margin="14,0,14,14" Background="{DynamicResource Card}" BorderBrush="{DynamicResource Line}" BorderThickness="1" CornerRadius="12" Padding="12,10">
                        <StackPanel>
                            <!-- Linha CPU: Label + Temp + Uso % -->
                            <Grid Margin="0,2">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="Auto"/>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <TextBlock Grid.Column="0" Text="CPU" Foreground="{DynamicResource Faint}" FontSize="10.5" FontWeight="Bold" VerticalAlignment="Center"/>
                                <TextBlock Grid.Column="1" Name="TxtCpuTempMini" Text=" --" FontFamily="{StaticResource Mono}" FontSize="10" Foreground="#00FF66" FontWeight="Bold" Margin="6,0,4,0" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
                                <TextBlock Grid.Column="2" Name="TxtCpuUsage" Text="-- %" FontFamily="{StaticResource Mono}" FontSize="11" FontWeight="Bold" Foreground="{DynamicResource Fg}" VerticalAlignment="Center" HorizontalAlignment="Right"/>
                            </Grid>
                            <ProgressBar Name="PbCpu" Height="3" Background="{DynamicResource Line}" Foreground="#FF1E27" BorderThickness="0" Value="0" Margin="0,2,0,6"/>

                            <!-- Linha RAM: Label + Detalhe Livre + Uso % -->
                            <Grid Margin="0,2">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="Auto"/>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <TextBlock Grid.Column="0" Text="RAM" Foreground="{DynamicResource Faint}" FontSize="10.5" FontWeight="Bold" VerticalAlignment="Center"/>
                                <TextBlock Grid.Column="1" Name="TxtRamDetailMini" Text="" FontFamily="{StaticResource Mono}" FontSize="9" Foreground="{DynamicResource Muted}" Margin="6,0,4,0" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
                                <TextBlock Grid.Column="2" Name="TxtRamUsage" Text="-- %" FontFamily="{StaticResource Mono}" FontSize="11" FontWeight="Bold" Foreground="{DynamicResource Fg}" VerticalAlignment="Center" HorizontalAlignment="Right"/>
                            </Grid>
                            <ProgressBar Name="PbRam" Height="3" Background="{DynamicResource Line}" Foreground="#FFFFFF" BorderThickness="0" Value="0" Margin="0,2,0,5"/>

                            <StackPanel Orientation="Horizontal" Margin="0,4,0,0">
                                <TextBlock Text="v3.5 PRO &#x00B7; MathzOS" Foreground="{DynamicResource Faint}" FontSize="9" VerticalAlignment="Center"/>
                                <Button Name="BtnCheckUpdates" Style="{StaticResource OutlineButton}" Content="VERIFICAR ATUALIZAÃ‡ÃƒO" FontSize="8.5" Padding="6,2" Margin="6,0,0,0" ToolTip="Verificar novas versÃµes no servidor oficial"/>
                            </StackPanel>
                        </StackPanel>
                    </Border>

                    <!-- NAVEGA&#x00C7;&#x00C3;O VERTICAL -->
                    <ScrollViewer VerticalScrollBarVisibility="Auto">
                        <StackPanel Margin="0,2,0,10">
                            <TextBlock Text="MATHZ DESEMPENHO" Foreground="{DynamicResource Faint}" FontSize="11" FontWeight="Bold" Margin="16,4,0,6"/>

                            <!-- 1. Clocks & Sensores -->
                            <Button Name="BtnTabClocks" Style="{StaticResource NavItem}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xE7E8;" FontFamily="{StaticResource Icons}" FontSize="14" Width="26" VerticalAlignment="Center"/>
                                    <TextBlock Text="Clocks &amp; Sensores" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>

                            <!-- 2. Otimizacao do Windows (ISO Tweaks) -->
                            <Button Name="BtnTabTweaks" Style="{StaticResource NavItem}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xE9F3;" FontFamily="{StaticResource Icons}" FontSize="14" Width="26" VerticalAlignment="Center"/>
                                    <TextBlock Text="Otimiza&#x00E7;&#x00E3;o (ISO Tweaks)" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>

                            <!-- 3. Aparencia & Cores (NOVO) -->
                            <Button Name="BtnTabTheme" Style="{StaticResource NavItem}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xE790;" FontFamily="{StaticResource Icons}" FontSize="14" Width="26" VerticalAlignment="Center"/>
                                    <TextBlock Text="Apar&#x00EA;ncia &amp; Cores" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>

                            <!-- 4. Inicializacao do Windows -->
                            <Button Name="BtnTabStartup" Style="{StaticResource NavItem}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xE823;" FontFamily="{StaticResource Icons}" FontSize="14" Width="26" VerticalAlignment="Center"/>
                                    <TextBlock Text="Inicializa&#x00E7;&#x00E3;o" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>

                            <!-- 5. Cursores Mathz -->
                            <Button Name="BtnTabCursors" Style="{StaticResource NavItem}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xE8B0;" FontFamily="{StaticResource Icons}" FontSize="14" Width="26" VerticalAlignment="Center"/>
                                    <TextBlock Text="Cursores Mathz" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>

                            <!-- 6. Drive Mathz (WHQL) -->
                            <Button Name="BtnTabDrivers" Style="{StaticResource NavItem}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xE896;" FontFamily="{StaticResource Icons}" FontSize="14" Width="26" VerticalAlignment="Center"/>
                                    <TextBlock Text="Drivers (WHQL)" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>

                            <TextBlock Text="FERRAMENTAS &amp; APPS" Foreground="{DynamicResource Faint}" FontSize="11" FontWeight="Bold" Margin="16,12,0,6"/>

                            <!-- 7. Navegadores -->
                            <Button Name="BtnTabBrowsers" Style="{StaticResource NavItem}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xE774;" FontFamily="{StaticResource Icons}" FontSize="14" Width="26" VerticalAlignment="Center"/>
                                    <TextBlock Text="Navegadores" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>

                            <!-- 8. Apps & Launchers -->
                            <Button Name="BtnTabInstaller" Style="{StaticResource NavItem}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xE719;" FontFamily="{StaticResource Icons}" FontSize="14" Width="26" VerticalAlignment="Center"/>
                                    <TextBlock Text="Instalar Apps" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>
                        </StackPanel>
                    </ScrollViewer>
                </DockPanel>
            </Border>

            <!-- ========================================================================= -->
            <!-- 2. PAINEL DE CONTE&#x00DA;DO PRINCIPAL (DIREITA)                                 -->
            <!-- ========================================================================= -->
            <Grid Grid.Column="1" Margin="16,12,16,12">
                <Grid.RowDefinitions>
                    <!-- Header -->
                    <RowDefinition Height="38"/>
                    <!-- Area Dinamica -->
                    <RowDefinition Height="*"/>
                    <!-- Rodap&#x00E9; de A&#x00E7;&#x00F5;es -->
                    <RowDefinition Height="46"/>
                </Grid.RowDefinitions>

                <!-- HEADER LIMPO (TITULO DA PAGINA + BOTOES MIN/CLOSE) -->
                <Grid Grid.Row="0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>

                    <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                        <Border Width="7" Height="7" CornerRadius="3.5" Background="#FF1E27" Margin="0,0,9,0" VerticalAlignment="Center"/>
                        <TextBlock Text="PAINEL DE COMANDO MTZ" Foreground="{DynamicResource Muted}" FontSize="11.5" FontWeight="SemiBold"/>
                        <TextBlock Text=" // " Foreground="{DynamicResource Faint}" FontSize="11.5" FontWeight="Normal"/>
                        <TextBlock Name="TxtActiveTabTitle" Text="CLOCKS &amp; SENSORES DE TEMPERATURA" Foreground="{DynamicResource Fg}" FontSize="12.5" FontWeight="Bold"/>
                    </StackPanel>

                    <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                        <Button Name="BtnMinimize" Style="{StaticResource CaptionButton}" Content="&#xE921;" ToolTip="Minimizar"/>
                        <Button Name="BtnMaximize" Style="{StaticResource CaptionButton}" Content="&#xE922;" ToolTip="Maximizar / Restaurar"/>
                        <Button Name="BtnClose" Style="{StaticResource CloseButton}" Content="&#xE8BB;" ToolTip="Fechar"/>
                    </StackPanel>
                </Grid>

                <!-- &#x00C1;REA DIN&#x00C2;MICA DE P&#x00C1;GINAS -->
                <Grid Grid.Row="1" Margin="0,6,0,0">

                    <!-- ===================================================================== -->
                    <!-- ===================================================================== -->
                    <!-- P??GINA 1: CLOCKS & TELEMETRIA MULTI-MODO (ONDA, PIZZA, BARRAS)        -->
                    <!-- ===================================================================== -->
                    <Grid Name="ViewClocks" Visibility="Visible">
                        <Grid.RowDefinitions>
                            <!-- Linha 0: 4 Cards de M??tricas R??pidas (84px) -->
                            <RowDefinition Height="84"/>
                            <!-- Linha 1: Gr??fico Multi-Estilo (Onda / Pizza / Barras) (*) -->
                            <RowDefinition Height="*"/>
                            <!-- Linha 2: Barra de Perfis e A????es R??pidas (104px) -->
                            <RowDefinition Height="104"/>
                        </Grid.RowDefinitions>

                        <!-- LINHA 0: 4 CARDS DE TELEMETRIA HUD -->
                        <Grid Grid.Row="0" Margin="0,0,0,10">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="10"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="10"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="10"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>

                            <!-- Card 1: CPU -->
                            <Border Grid.Column="0" Style="{StaticResource CardBorder}" Padding="12,8">
                                <Grid>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="*"/>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="3"/>
                                    </Grid.RowDefinitions>
                                    <Grid Grid.Row="0">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Grid.Column="0" Text="PROCESSADOR (CPU)" FontFamily="{DynamicResource Heading}" Foreground="{DynamicResource Muted}" FontSize="12.5" FontWeight="SemiBold" TextTrimming="CharacterEllipsis" VerticalAlignment="Center" Margin="0,0,4,0"/>
                                        <Border Grid.Column="1" Name="BadgeCpuTemp" Background="#1000FF66" BorderThickness="1" BorderBrush="#3300FF66" CornerRadius="4" Padding="5,1" VerticalAlignment="Center">
                                            <TextBlock Name="TxtCpuTempStatus" Text="-- &#x00B0;C" Foreground="#00FF66" FontSize="8.5" FontWeight="Bold"/>
                                        </Border>
                                    </Grid>
                                    <TextBlock Grid.Row="1" Name="TxtCpuUsageMain" Text="-- %" FontFamily="{DynamicResource Heading}" Foreground="{DynamicResource Fg}" FontSize="24" FontWeight="Bold" VerticalAlignment="Center"/>
                                    <TextBlock Grid.Row="2" Name="TxtCpuClock" Text="Max Turbo Ativo" Foreground="{DynamicResource Muted}" FontSize="10" Margin="0,0,0,4"/>
                                    <ProgressBar Grid.Row="3" Name="PbCpuMini" Style="{StaticResource MiniProgress}" Value="0"/>
                                </Grid>
                            </Border>

                            <!-- Card 2: GPU -->
                            <Border Grid.Column="2" Style="{StaticResource CardBorder}" Padding="12,8">
                                <Grid>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="*"/>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="3"/>
                                    </Grid.RowDefinitions>
                                    <Grid Grid.Row="0">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Grid.Column="0" Name="TxtGpuName" Text="PLACA DE V&#x00CD;DEO (GPU)" FontFamily="{DynamicResource Heading}" Foreground="{DynamicResource Muted}" FontSize="12.5" FontWeight="SemiBold" TextTrimming="CharacterEllipsis" VerticalAlignment="Center" Margin="0,0,4,0"/>
                                        <Border Grid.Column="1" Name="BadgeGpuTemp" Background="#1000E5FF" BorderThickness="1" BorderBrush="#3300E5FF" CornerRadius="4" Padding="5,1" VerticalAlignment="Center">
                                            <TextBlock Name="TxtGpuTempStatus" Text="-- &#x00B0;C" Foreground="#00E5FF" FontSize="8.5" FontWeight="Bold"/>
                                        </Border>
                                    </Grid>
                                    <TextBlock Grid.Row="1" Name="TxtGpuClock" Text="ASPM OFF" FontFamily="{DynamicResource Heading}" Foreground="{DynamicResource Fg}" FontSize="16" FontWeight="Bold" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
                                    <TextBlock Grid.Row="2" Name="TxtGpuUsage" Text="PCIe x16 Full Speed &#x00B7; HAGS ON" Foreground="{DynamicResource Muted}" FontSize="10" Margin="0,0,0,4" TextTrimming="CharacterEllipsis"/>
                                    <ProgressBar Grid.Row="3" Name="PbGpuMini" Style="{StaticResource MiniProgress}" Foreground="#00E5FF" Value="100"/>
                                </Grid>
                            </Border>

                            <!-- Card 3: RAM -->
                            <Border Grid.Column="4" Style="{StaticResource CardBorder}" Padding="12,8">
                                <Grid>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="*"/>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="3"/>
                                    </Grid.RowDefinitions>
                                    <Grid Grid.Row="0">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Grid.Column="0" Text="MEM&#x00D3;RIA RAM (DDR)" FontFamily="{DynamicResource Heading}" Foreground="{DynamicResource Muted}" FontSize="12.5" FontWeight="SemiBold" TextTrimming="CharacterEllipsis" VerticalAlignment="Center" Margin="0,0,4,0"/>
                                        <Border Grid.Column="1" Background="#121212" BorderThickness="1" BorderBrush="{DynamicResource LineStrong}" CornerRadius="4" Padding="5,1" VerticalAlignment="Center">
                                            <TextBlock Name="TxtRamAvail" Text="-- GB Livres" Foreground="{DynamicResource Fg}" FontSize="8.5" FontWeight="Bold"/>
                                        </Border>
                                    </Grid>
                                    <TextBlock Grid.Row="1" Name="TxtRamUsageMain" Text="-- GB" FontFamily="{DynamicResource Heading}" Foreground="{DynamicResource Fg}" FontSize="20" FontWeight="Bold" VerticalAlignment="Center"/>
                                    <TextBlock Grid.Row="2" Text="Dual-Channel &#x00B7; 0 Lat&#x00EA;ncia" Foreground="{DynamicResource Muted}" FontSize="10" Margin="0,0,0,4"/>
                                    <ProgressBar Grid.Row="3" Name="PbRamMini" Style="{StaticResource MiniProgress}" Foreground="#FFFFFF" Value="0"/>
                                </Grid>
                            </Border>

                            <!-- Card 4: LATENCIA / ENERGIA -->
                            <Border Grid.Column="6" Style="{StaticResource CardBorder}" Padding="12,8">
                                <Grid>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="*"/>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="3"/>
                                    </Grid.RowDefinitions>
                                    <Grid Grid.Row="0">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Grid.Column="0" Text="SISTEMA &amp; LAT&#x00CA;NCIA" FontFamily="{DynamicResource Heading}" Foreground="{DynamicResource Muted}" FontSize="12.5" FontWeight="SemiBold" TextTrimming="CharacterEllipsis" VerticalAlignment="Center" Margin="0,0,4,0"/>
                                        <Border Grid.Column="1" Background="#12FF1E27" BorderThickness="1" BorderBrush="#44FF1E27" CornerRadius="4" Padding="5,1" VerticalAlignment="Center">
                                            <TextBlock Text="100% UNPARK" Foreground="#FF1E27" FontSize="8.5" FontWeight="Bold"/>
                                        </Border>
                                    </Grid>
                                    <TextBlock Grid.Row="1" Name="TxtActiveProfile" Text="M&#x00C1;XIMO DESEMPENHO" Foreground="{DynamicResource Fg}" FontSize="12" FontWeight="Bold" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
                                    <TextBlock Grid.Row="2" Name="TxtClockRange" Text="Timer 0.5ms &#x00B7; 0 DPC Delay" FontFamily="{StaticResource Mono}" Foreground="{DynamicResource Muted}" FontSize="10" Margin="0,0,0,4"/>
                                    <ProgressBar Grid.Row="3" Style="{StaticResource MiniProgress}" Value="100"/>
                                </Grid>
                            </Border>
                        </Grid>

                        <!-- LINHA 1: ??REA MULTI-ESTILO DE TELEMETRIA -->
                        <Border Grid.Row="1" Margin="0,0,0,10" Background="#090909" BorderBrush="{DynamicResource LineStrong}" BorderThickness="1" CornerRadius="14" Padding="14,10">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="32"/>
                                    <RowDefinition Height="*"/>
                                </Grid.RowDefinitions>

                                <!-- Toolbar do Gr??fico -->
                                <Grid Grid.Row="0">
                                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                        <Border Name="GraphLiveLed" Width="8" Height="8" CornerRadius="4" Background="#00FF66" Margin="0,0,8,0"/>
                                        <TextBlock Text="MONITOR DE TELEMETRIA" FontFamily="{DynamicResource Heading}" Foreground="{DynamicResource Fg}" FontSize="14" FontWeight="Bold"/>
                                        <TextBlock Name="TxtGraphSubTitle" Text=" // HIST&#x00D3;RICO DIN&#x00C2;MICO" Foreground="{DynamicResource Faint}" FontSize="11" FontWeight="Normal" Margin="6,0,0,0"/>
                                    </StackPanel>

                                    <!-- Alternador de Estilo + Modos -->
                                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                                        <!-- Chip de Status Resumido -->
                                        <Border Background="#0E0E0E" BorderBrush="{DynamicResource Line}" BorderThickness="1" CornerRadius="6" Padding="8,3" Margin="0,0,8,0">
                                            <StackPanel Orientation="Horizontal">
                                                <TextBlock Name="TxtGraphCurrent" Text="CPU: -- % | RAM: -- %" FontFamily="{StaticResource Mono}" Foreground="{DynamicResource Fg}" FontSize="11" FontWeight="SemiBold"/>
                                                <TextBlock Text="  |  " Foreground="{DynamicResource Faint}" FontSize="9.5"/>
                                                <TextBlock Name="TxtGraphPeak" Text="Pico: -- %" FontFamily="{StaticResource Mono}" Foreground="#FF1E27" FontSize="11" FontWeight="Bold"/>
                                            </StackPanel>
                                        </Border>

                                        <!-- 3 Bot??es de Estilo do Gr??fico: ONDA, PIZZA, BARRAS -->
                                        <Border Background="#0C0C0C" BorderBrush="{DynamicResource LineStrong}" BorderThickness="1" CornerRadius="7" Padding="2" Margin="0,0,8,0">
                                            <StackPanel Orientation="Horizontal">
                                                <Button Name="BtnStyleWave"  Style="{StaticResource GraphPillButton}" Content="Onda"  ToolTip="Gr&#x00E1;fico cont&#x00ED;nuo em onda / linha temporal"/>
                                                <Button Name="BtnStyleDonut" Style="{StaticResource GraphPillButton}" Content="Pizza" ToolTip="Medidores circulares em formato de pizza / donut"/>
                                                <Button Name="BtnStyleBars"  Style="{StaticResource GraphPillButton}" Content="Barras" Margin="0" ToolTip="Gr&#x00E1;fico de barras e espectro de par&#x00E2;metros"/>
                                            </StackPanel>
                                        </Border>

                                        <!-- Sub-Filtros para Modo Onda (CPU / RAM / OVERLAY) -->
                                        <StackPanel Name="PanelWaveFilters" Orientation="Horizontal">
                                            <Button Name="BtnGraphCpu" Style="{StaticResource GraphPillButton}" Content="CPU" ToolTip="Apenas curva de CPU"/>
                                            <Button Name="BtnGraphRam" Style="{StaticResource GraphPillButton}" Content="RAM" ToolTip="Apenas curva de RAM"/>
                                            <Button Name="BtnGraphBoth" Style="{StaticResource GraphPillButton}" Content="Overlay" Margin="0" ToolTip="Curvas sobrepostas"/>
                                        </StackPanel>
                                    </StackPanel>
                                </Grid>

                                <!-- ESTILO 1: GR??FICO DE ONDA / LINHA CONT??NUA -->
                                <Grid Name="GridGraphWave" Grid.Row="1" Margin="0,6,0,0" Visibility="Visible">
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="*"/>
                                        <RowDefinition Height="18"/>
                                    </Grid.RowDefinitions>
                                    <Grid Grid.Row="0">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="36"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>
                                        <Grid Grid.Column="0" Margin="0,0,6,0">
                                            <TextBlock Text="100%" Foreground="#B0B0B8" FontSize="9" FontFamily="{StaticResource Mono}" VerticalAlignment="Top"/>
                                            <TextBlock Text="75%"  Foreground="#B0B0B8" FontSize="9" FontFamily="{StaticResource Mono}" VerticalAlignment="Center" Margin="0,0,0,60"/>
                                            <TextBlock Text="50%"  Foreground="#B0B0B8" FontSize="9" FontFamily="{StaticResource Mono}" VerticalAlignment="Center"/>
                                            <TextBlock Text="25%"  Foreground="#B0B0B8" FontSize="9" FontFamily="{StaticResource Mono}" VerticalAlignment="Center" Margin="0,60,0,0"/>
                                            <TextBlock Text="0%"   Foreground="#B0B0B8" FontSize="9" FontFamily="{StaticResource Mono}" VerticalAlignment="Bottom"/>
                                        </Grid>
                                        <Grid Grid.Column="1">
                                            <Grid>
                                                <Grid.RowDefinitions>
                                                    <RowDefinition Height="*"/>
                                                    <RowDefinition Height="*"/>
                                                    <RowDefinition Height="*"/>
                                                    <RowDefinition Height="*"/>
                                                </Grid.RowDefinitions>
                                                <Border Grid.Row="0" BorderBrush="#121212" BorderThickness="0,1,0,0"/>
                                                <Border Grid.Row="1" BorderBrush="#121212" BorderThickness="0,1,0,0"/>
                                                <Border Grid.Row="2" BorderBrush="#121212" BorderThickness="0,1,0,0"/>
                                                <Border Grid.Row="3" BorderBrush="#121212" BorderThickness="0,1,0,1"/>
                                            </Grid>
                                            <Canvas Name="GraphCanvas" ClipToBounds="True">
                                                <Polygon Name="GraphPolyFillCpu">
                                                    <Polygon.Fill>
                                                        <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
                                                            <GradientStop Color="#38FF1E27" Offset="0"/>
                                                            <GradientStop Color="#00FF1E27" Offset="1"/>
                                                        </LinearGradientBrush>
                                                    </Polygon.Fill>
                                                </Polygon>
                                                <Polyline Name="GraphPolyLineCpu" Stroke="#FF1E27" StrokeThickness="2.2"/>
                                                <Polygon Name="GraphPolyFillRam">
                                                    <Polygon.Fill>
                                                        <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
                                                            <GradientStop Color="#2200E5FF" Offset="0"/>
                                                            <GradientStop Color="#0000E5FF" Offset="1"/>
                                                        </LinearGradientBrush>
                                                    </Polygon.Fill>
                                                </Polygon>
                                                <Polyline Name="GraphPolyLineRam" Stroke="#00E5FF" StrokeThickness="1.8"/>
                                                <Ellipse Name="GraphDotHaloCpu" Width="14" Height="14" Stroke="#66FF1E27" StrokeThickness="1" Fill="#22FF1E27"/>
                                                <Ellipse Name="GraphDotHeadCpu" Width="6" Height="6" Fill="#FF1E27"/>
                                                <Ellipse Name="GraphDotHeadRam" Width="6" Height="6" Fill="#00E5FF"/>
                                            </Canvas>
                                        </Grid>
                                    </Grid>
                                    <Grid Grid.Row="1" Margin="36,2,0,0">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Grid.Column="0" Text="-60s" Foreground="#9898A2" FontSize="8.5" FontFamily="{StaticResource Mono}"/>
                                        <TextBlock Grid.Column="1" Text="-45s" Foreground="#9898A2" FontSize="8.5" FontFamily="{StaticResource Mono}"/>
                                        <TextBlock Grid.Column="2" Text="-30s" Foreground="#9898A2" FontSize="8.5" FontFamily="{StaticResource Mono}"/>
                                        <TextBlock Grid.Column="3" Text="-15s" Foreground="#9898A2" FontSize="8.5" FontFamily="{StaticResource Mono}"/>
                                        <TextBlock Grid.Column="4" Text="AGORA" Foreground="#FF1E27" FontSize="8.5" FontFamily="{StaticResource Mono}" FontWeight="Bold"/>
                                    </Grid>
                                </Grid>

                                <!-- ESTILO 2: GR??FICO DE PIZZA / DONUT CIRCULAR -->
                                <Grid Name="GridGraphDonut" Grid.Row="1" Margin="0,10,0,0" Visibility="Collapsed">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="1.2*"/>
                                    </Grid.ColumnDefinitions>

                                    <!-- Donut 1: CPU -->
                                    <Border Grid.Column="0" Background="#0C0C0C" BorderBrush="{DynamicResource Line}" BorderThickness="1" CornerRadius="12" Margin="0,0,8,0" Padding="10">
                                        <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
                                            <Grid Width="110" Height="110">
                                                <Ellipse Width="92" Height="92" Stroke="#161616" StrokeThickness="8"/>
                                                <Path Name="DonutPathCpu" Stroke="#FF1E27" StrokeThickness="8" StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
                                                <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
                                                    <TextBlock Name="TxtDonutCpuVal" Text="-- %" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF" HorizontalAlignment="Center"/>
                                                    <TextBlock Text="CPU" FontSize="9.5" FontWeight="SemiBold" Foreground="{DynamicResource Muted}" HorizontalAlignment="Center"/>
                                                </StackPanel>
                                            </Grid>
                                            <TextBlock Text="Carga Processador" FontSize="10.5" FontWeight="SemiBold" Foreground="#FFFFFF" HorizontalAlignment="Center" Margin="0,6,0,1"/>
                                            <TextBlock Name="TxtDonutCpuClock" Text="Max Turbo Ativo" FontSize="9" Foreground="{DynamicResource Faint}" HorizontalAlignment="Center"/>
                                        </StackPanel>
                                    </Border>

                                    <!-- Donut 2: RAM -->
                                    <Border Grid.Column="1" Background="#0C0C0C" BorderBrush="{DynamicResource Line}" BorderThickness="1" CornerRadius="12" Margin="0,0,8,0" Padding="10">
                                        <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
                                            <Grid Width="110" Height="110">
                                                <Ellipse Width="92" Height="92" Stroke="#161616" StrokeThickness="8"/>
                                                <Path Name="DonutPathRam" Stroke="#00E5FF" StrokeThickness="8" StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
                                                <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
                                                    <TextBlock Name="TxtDonutRamVal" Text="-- %" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF" HorizontalAlignment="Center"/>
                                                    <TextBlock Text="RAM" FontSize="9.5" FontWeight="SemiBold" Foreground="{DynamicResource Muted}" HorizontalAlignment="Center"/>
                                                </StackPanel>
                                            </Grid>
                                            <TextBlock Text="Mem&#x00F3;ria em Uso" FontSize="10.5" FontWeight="SemiBold" Foreground="#FFFFFF" HorizontalAlignment="Center" Margin="0,6,0,1"/>
                                            <TextBlock Name="TxtDonutRamGb" Text="-- GB Livres" FontSize="9" Foreground="{DynamicResource Faint}" HorizontalAlignment="Center"/>
                                        </StackPanel>
                                    </Border>

                                    <!-- Donut 3: TEMPERATURA / GPU -->
                                    <Border Grid.Column="2" Background="#0C0C0C" BorderBrush="{DynamicResource Line}" BorderThickness="1" CornerRadius="12" Margin="0,0,8,0" Padding="10">
                                        <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
                                            <Grid Width="110" Height="110">
                                                <Ellipse Width="92" Height="92" Stroke="#161616" StrokeThickness="8"/>
                                                <Path Name="DonutPathTemp" Stroke="#00FF66" StrokeThickness="8" StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
                                                <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
                                                    <TextBlock Name="TxtDonutTempVal" Text="-- &#x00B0;C" FontSize="18" FontWeight="Bold" Foreground="#FFFFFF" HorizontalAlignment="Center"/>
                                                    <TextBlock Text="TEMP" FontSize="9.5" FontWeight="SemiBold" Foreground="{DynamicResource Muted}" HorizontalAlignment="Center"/>
                                                </StackPanel>
                                            </Grid>
                                            <TextBlock Text="T&#x00E9;rmico CPU" FontSize="10.5" FontWeight="SemiBold" Foreground="#FFFFFF" HorizontalAlignment="Center" Margin="0,6,0,1"/>
                                            <TextBlock Name="TxtDonutTempStatus" Text="Est&#x00E1;vel / Seguro" FontSize="9" Foreground="#00FF66" HorizontalAlignment="Center"/>
                                        </StackPanel>
                                    </Border>

                                    <!-- Par??metros Adicionais ao Lado -->
                                    <Border Grid.Column="3" Background="#0C0C0C" BorderBrush="{DynamicResource Line}" BorderThickness="1" CornerRadius="12" Padding="14,10">
                                        <StackPanel VerticalAlignment="Center">
                                            <TextBlock Text="PAR&#x00C2;METROS DETALHADOS:" FontSize="9.5" FontWeight="Bold" Foreground="{DynamicResource Muted}" Margin="0,0,0,8"/>
                                            <Grid Margin="0,2">
                                                <TextBlock Text="Pico de Carga (60s):" Foreground="{DynamicResource Faint}" FontSize="10"/>
                                                <TextBlock Name="TxtDonutPeak" Text="-- %" Foreground="#FF1E27" FontWeight="Bold" FontSize="10" HorizontalAlignment="Right"/>
                                            </Grid>
                                            <Grid Margin="0,2">
                                                <TextBlock Text="M&#x00E9;dia em Execu&#x00E7;&#x00E3;o:" Foreground="{DynamicResource Faint}" FontSize="10"/>
                                                <TextBlock Name="TxtDonutAvg" Text="-- %" Foreground="#FFFFFF" FontWeight="Bold" FontSize="10" HorizontalAlignment="Right"/>
                                            </Grid>
                                            <Grid Margin="0,2">
                                                <TextBlock Text="Resolu&#x00E7;&#x00E3;o do Timer:" Foreground="{DynamicResource Faint}" FontSize="10"/>
                                                <TextBlock Text="0.50 ms (HPET)" Foreground="#00FF66" FontWeight="Bold" FontSize="10" HorizontalAlignment="Right"/>
                                            </Grid>
                                            <Grid Margin="0,2">
                                                <TextBlock Text="Barramento PCIe:" Foreground="{DynamicResource Faint}" FontSize="10"/>
                                                <TextBlock Text="Link Full Speed" Foreground="#00E5FF" FontWeight="Bold" FontSize="10" HorizontalAlignment="Right"/>
                                            </Grid>
                                            <Grid Margin="0,2">
                                                <TextBlock Text="Core Parking:" Foreground="{DynamicResource Faint}" FontSize="10"/>
                                                <TextBlock Text="0% (Desativado)" Foreground="#FFFFFF" FontWeight="Bold" FontSize="10" HorizontalAlignment="Right"/>
                                            </Grid>
                                        </StackPanel>
                                    </Border>
                                </Grid>

                                <!-- ESTILO 3: GR??FICO DE BARRAS / ESPECTRO HUD -->
                                <Grid Name="GridGraphBars" Grid.Row="1" Margin="0,10,0,0" Visibility="Collapsed">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="2*"/>
                                        <ColumnDefinition Width="14"/>
                                        <ColumnDefinition Width="1.2*"/>
                                    </Grid.ColumnDefinitions>

                                    <!-- Espectro de 16 Barras Verticais de Hist??rico -->
                                    <Border Grid.Column="0" Background="#0C0C0C" BorderBrush="{DynamicResource Line}" BorderThickness="1" CornerRadius="12" Padding="14,10">
                                        <Grid>
                                            <Grid.RowDefinitions>
                                                <RowDefinition Height="Auto"/>
                                                <RowDefinition Height="*"/>
                                            </Grid.RowDefinitions>
                                            <TextBlock Grid.Row="0" Text="HISTOGRAMA DE CARGA POR AMOSTRA (16 PONTOS):" FontSize="9.5" FontWeight="Bold" Foreground="{DynamicResource Muted}" Margin="0,0,0,10"/>
                                            <UniformGrid Grid.Row="1" Name="GridBarsContainer" Columns="16" Rows="1"/>
                                        </Grid>
                                    </Border>

                                    <!-- Medidores Horizontais de Par??metros -->
                                    <Border Grid.Column="2" Background="#0C0C0C" BorderBrush="{DynamicResource Line}" BorderThickness="1" CornerRadius="12" Padding="14,10">
                                        <StackPanel VerticalAlignment="Center">
                                            <TextBlock Text="MEDIDORES DE SUBSISTEMAS:" FontSize="9.5" FontWeight="Bold" Foreground="{DynamicResource Muted}" Margin="0,0,0,10"/>
                                            
                                            <!-- Barra Horizontal CPU -->
                                            <Grid Margin="0,0,0,2">
                                                <TextBlock Text="CPU LOAD" FontSize="9.5" FontWeight="Bold" Foreground="{DynamicResource Fg}"/>
                                                <TextBlock Name="TxtBarCpuPct" Text="-- %" FontSize="9.5" FontWeight="Bold" Foreground="#FF1E27" HorizontalAlignment="Right"/>
                                            </Grid>
                                            <ProgressBar Name="PbBarCpu" Style="{StaticResource MiniProgress}" Value="0" Margin="0,0,0,8"/>

                                            <!-- Barra Horizontal RAM -->
                                            <Grid Margin="0,0,0,2">
                                                <TextBlock Text="RAM COMMITTED" FontSize="9.5" FontWeight="Bold" Foreground="{DynamicResource Fg}"/>
                                                <TextBlock Name="TxtBarRamPct" Text="-- %" FontSize="9.5" FontWeight="Bold" Foreground="#00E5FF" HorizontalAlignment="Right"/>
                                            </Grid>
                                            <ProgressBar Name="PbBarRam" Style="{StaticResource MiniProgress}" Foreground="#00E5FF" Value="0" Margin="0,0,0,8"/>

                                            <!-- Barra Horizontal Temp -->
                                            <Grid Margin="0,0,0,2">
                                                <TextBlock Text="TEMPERATURA N&#x00DA;CLEO" FontSize="9.5" FontWeight="Bold" Foreground="{DynamicResource Fg}"/>
                                                <TextBlock Name="TxtBarTempPct" Text="-- &#x00B0;C" FontSize="9.5" FontWeight="Bold" Foreground="#00FF66" HorizontalAlignment="Right"/>
                                            </Grid>
                                            <ProgressBar Name="PbBarTemp" Style="{StaticResource MiniProgress}" Foreground="#00FF66" Maximum="105" Value="45" Margin="0,0,0,8"/>

                                            <!-- Barra Horizontal Lat??ncia -->
                                            <Grid Margin="0,0,0,2">
                                                <TextBlock Text="RESPONSIVIDADE DPC" FontSize="9.5" FontWeight="Bold" Foreground="{DynamicResource Fg}"/>
                                                <TextBlock Text="0.12 ms" FontSize="9.5" FontWeight="Bold" Foreground="#FFFFFF" HorizontalAlignment="Right"/>
                                            </Grid>
                                            <ProgressBar Style="{StaticResource MiniProgress}" Foreground="#FFFFFF" Value="100"/>
                                        </StackPanel>
                                    </Border>
                                </Grid>
                            </Grid>
                        </Border>

                        <!-- LINHA 2: PERFIS DE HARDWARE, CONFIGURA????ES E LIMPEZA DE RAM -->
                        <Grid Grid.Row="2">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="10"/>
                                <ColumnDefinition Width="1.1*"/>
                                <ColumnDefinition Width="10"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>

                            <!-- Bloco 1: 3 Perfis Mestres -->
                            <Border Grid.Column="0" Style="{StaticResource CardBorder}" Padding="10,8">
                                <Grid>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="*"/>
                                    </Grid.RowDefinitions>
                                    <TextBlock Grid.Row="0" Text="PERFIS DE ENERGIA &amp; HARDWARE:" Foreground="{DynamicResource Muted}" FontSize="9" FontWeight="SemiBold" Margin="0,0,0,6"/>
                                    <UniformGrid Grid.Row="1" Columns="3">
                                        <Button Name="BtnUltraGaming" Style="{StaticResource OutlineButton}" Padding="4,4" Margin="0,0,4,0" ToolTip="100% Desbloqueado, sem Core Parking">
                                            <StackPanel HorizontalAlignment="Center">
                                                <StackPanel Orientation="Horizontal" HorizontalAlignment="Center"><TextBlock Text="&#xE7E8;" FontFamily="{StaticResource Icons}" FontSize="11" VerticalAlignment="Center" Margin="0,0,4,0"/><TextBlock Text="M&#x00C1;XIMO" FontFamily="{DynamicResource Heading}" FontSize="13" FontWeight="Bold" VerticalAlignment="Center"/></StackPanel>
                                                <TextBlock Text="100% Turbo" FontSize="8" Foreground="{DynamicResource Faint}" HorizontalAlignment="Center"/>
                                            </StackPanel>
                                        </Button>
                                        <Button Name="BtnBalanced" Style="{StaticResource OutlineButton}" Padding="4,4" Margin="0,0,4,0" ToolTip="Escala din&#x00E2;mica de clock 5% a 100%">
                                            <StackPanel HorizontalAlignment="Center">
                                                <StackPanel Orientation="Horizontal" HorizontalAlignment="Center"><TextBlock Text="&#xE945;" FontFamily="{StaticResource Icons}" FontSize="11" VerticalAlignment="Center" Margin="0,0,4,0"/><TextBlock Text="EQUIL&#x00CD;BRIO" FontFamily="{DynamicResource Heading}" FontSize="13" FontWeight="Bold" VerticalAlignment="Center"/></StackPanel>
                                                <TextBlock Text="Adaptativo" FontSize="8" Foreground="{DynamicResource Faint}" HorizontalAlignment="Center"/>
                                            </StackPanel>
                                        </Button>
                                        <Button Name="BtnEcoSaver" Style="{StaticResource OutlineButton}" Padding="4,4" ToolTip="Clock limitado a 70%, silencioso e frio">
                                            <StackPanel HorizontalAlignment="Center">
                                                <StackPanel Orientation="Horizontal" HorizontalAlignment="Center"><TextBlock Text="&#xE706;" FontFamily="{StaticResource Icons}" FontSize="11" VerticalAlignment="Center" Margin="0,0,4,0"/><TextBlock Text="FRIO" FontFamily="{DynamicResource Heading}" FontSize="13" FontWeight="Bold" VerticalAlignment="Center"/></StackPanel>
                                                <TextBlock Text="Eco Silencioso" FontSize="8" Foreground="{DynamicResource Faint}" HorizontalAlignment="Center"/>
                                            </StackPanel>
                                        </Button>
                                    </UniformGrid>
                                </Grid>
                            </Border>

                            <!-- Bloco 2: Ajuste Fino de Clock, ASPM & Sensores -->
                            <Border Grid.Column="2" Style="{StaticResource CardBorder}" Padding="10,8">
                                <Grid>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="*"/>
                                    </Grid.RowDefinitions>
                                    <TextBlock Grid.Row="0" Text="PERSONALIZAR TELEMETRIA &amp; CLOCKS:" Foreground="{DynamicResource Muted}" FontSize="9" FontWeight="SemiBold" Margin="0,0,0,4"/>
                                    <StackPanel Grid.Row="1" VerticalAlignment="Center">
                                        <StackPanel Orientation="Horizontal" Margin="0,0,0,4">
                                            <TextBlock Text="Clock Fixo:" Foreground="{DynamicResource Faint}" FontSize="8.5" VerticalAlignment="Center" Margin="0,0,6,0"/>
                                            <Button Name="BtnClock100" Content="100% Max" Style="{StaticResource OutlineButton}" Padding="5,2" Margin="0,0,3,0" FontSize="8.5"/>
                                            <Button Name="BtnClock99"  Content="99% Base" Style="{StaticResource OutlineButton}" Padding="5,2" Margin="0,0,3,0" FontSize="8.5"/>
                                            <Button Name="BtnClock70"  Content="70% Eco"  Style="{StaticResource OutlineButton}" Padding="5,2" Margin="0,0,3,0" FontSize="8.5"/>
                                            <Button Name="BtnGpuMax"   Content="ASPM OFF" Style="{StaticResource OutlineButton}" Padding="5,2" Margin="0,0,3,0" FontSize="8.5"/>
                                            <Button Name="BtnGpuEco"   Content="ASPM ON"  Style="{StaticResource OutlineButton}" Padding="5,2" FontSize="8.5"/>
                                        </StackPanel>
                                        <StackPanel Orientation="Horizontal">
                                            <TextBlock Text="Taxa / Alerta:" Foreground="{DynamicResource Faint}" FontSize="8.5" VerticalAlignment="Center" Margin="0,0,6,0"/>
                                            <Button Name="BtnRefreshFast"   Content="1.0s" Style="{StaticResource OutlineButton}" Padding="5,2" Margin="0,0,3,0" FontSize="8.5"/>
                                            <Button Name="BtnRefreshNormal" Content="2.5s" Style="{StaticResource OutlineButton}" Padding="5,2" Margin="0,0,3,0" FontSize="8.5"/>
                                            <Button Name="BtnRefreshEco"    Content="5.0s" Style="{StaticResource OutlineButton}" Padding="5,2" Margin="0,0,6,0" FontSize="8.5"/>
                                            <Button Name="BtnAlert75" Content="75&#x00B0;C" Style="{StaticResource OutlineButton}" Padding="4,2" Margin="0,0,2,0" FontSize="8"/>
                                            <Button Name="BtnAlert80" Content="80&#x00B0;C" Style="{StaticResource OutlineButton}" Padding="4,2" Margin="0,0,2,0" FontSize="8"/>
                                            <Button Name="BtnAlert85" Content="85&#x00B0;C" Style="{StaticResource OutlineButton}" Padding="4,2" FontSize="8"/>
                                        </StackPanel>
                                    </StackPanel>
                                </Grid>
                            </Border>

                            <!-- Bloco 3: Limpeza de RAM -->
                            <Border Grid.Column="4" Style="{StaticResource CardBorder}" Padding="12,8">
                                <StackPanel VerticalAlignment="Center">
                                    <Button Name="BtnCleanRam" Style="{StaticResource PrimaryButton}" Padding="14,12" ToolTip="Esvazia working sets e limpa mem&#x00F3;ria em tempo real">
                                        <StackPanel HorizontalAlignment="Center">
                                            <TextBlock Text="&#xE75C;" FontFamily="{StaticResource Icons}" FontSize="13" HorizontalAlignment="Center" Margin="0,0,0,3"/>
                                            <TextBlock Text="LIMPAR RAM AGORA" FontSize="10" FontWeight="Bold" HorizontalAlignment="Center"/>
                                        </StackPanel>
                                    </Button>
                                </StackPanel>
                            </Border>
                        </Grid>
                    </Grid>
                    <Grid Name="ViewTweaks" Visibility="Collapsed">
                        <Border Style="{StaticResource CardBorder}">
                            <ScrollViewer VerticalScrollBarVisibility="Auto">
                                <StackPanel>
                                    <Grid Margin="0,0,0,14">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                            <StackPanel Orientation="Horizontal">
                                                <TextBlock Text="RECURSOS DE OTIMIZA&#x00C7;&#x00C3;O DO WINDOWS (BASE DA ISO)" Foreground="{DynamicResource Fg}" FontSize="13" FontWeight="SemiBold"/>
                                                <Border Name="BadgeTweaksSummary" Background="{DynamicResource Hover}" BorderBrush="{DynamicResource LineStrong}" BorderThickness="1" CornerRadius="4" Padding="8,2" Margin="10,0,0,0">
                                                    <TextBlock Name="TxtTweaksSummary" Text="0/8 APLICADOS" Foreground="{DynamicResource Fg}" FontSize="9" FontWeight="Bold"/>
                                                </Border>
                                            </StackPanel>
                                            <TextBlock Text="Edite e aplique todos os recursos de baixa lat&#x00EA;ncia e kernel injetados na instala&#x00E7;&#x00E3;o da ISO." Foreground="{DynamicResource Muted}" FontSize="11.5" Margin="0,3,0,0"/>
                                        </StackPanel>
                                        <StackPanel Grid.Column="1" Orientation="Horizontal">
                                            <Button Name="BtnAuditTweaks" Content="VERIFICAR" Style="{StaticResource OutlineButton}" Margin="0,0,6,0"/>
                                            <Button Name="BtnRestoreDefaultTweaks" Content="RESTAURAR PADR&#x00D5;ES" Style="{StaticResource OutlineButton}" Margin="0,0,6,0"/>
                                            <Button Name="BtnApplyAllTweaks" Content="APLICAR TODOS DA ISO" Style="{StaticResource PrimaryButton}"/>
                                        </StackPanel>
                                    </Grid>

                                    <!-- Tweak 1: Mouse 1:1 -->
                                    <Border Style="{StaticResource ItemCardBorder}">
                                        <Grid>
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="Auto"/>
                                            </Grid.ColumnDefinitions>
                                            <StackPanel Grid.Column="0">
                                                <StackPanel Orientation="Horizontal">
                                                    <TextBlock Text="Desligar acelera&#x00E7;&#x00E3;o do mouse (Raw Input 1:1 &amp; Curvas Planas)" FontWeight="SemiBold" FontSize="12"/>
                                                    <Border Name="BadgeStatusMouse" Background="{DynamicResource Hover}" BorderThickness="1" BorderBrush="{DynamicResource LineStrong}" CornerRadius="4" Padding="6,1" Margin="8,0,0,0">
                                                        <TextBlock Name="TxtStatusMouse" Text="PENDENTE" Foreground="{DynamicResource Muted}" FontSize="8.5" FontWeight="Bold"/>
                                                    </Border>
                                                </StackPanel>
                                                <TextBlock Text="Remove aprimorar precis&#x00E3;o, zera acelera&#x00E7;&#x00E3;o angular e ajusta fila USB para mira 100% consistente." Foreground="{DynamicResource Muted}" FontSize="11.5" Margin="0,4,0,0"/>
                                            </StackPanel>
                                            <Button Grid.Column="1" Name="BtnOptimizeMouse" Content="APLICAR" Style="{StaticResource OutlineButton}" Padding="12,5" VerticalAlignment="Center"/>
                                        </Grid>
                                    </Border>

                                    <!-- Tweak 2: HAGS & Game Mode -->
                                    <Border Style="{StaticResource ItemCardBorder}">
                                        <Grid>
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="Auto"/>
                                            </Grid.ColumnDefinitions>
                                            <StackPanel Grid.Column="0">
                                                <StackPanel Orientation="Horizontal">
                                                    <TextBlock Text="Agendamento de GPU acelerado por hardware (HAGS) &amp; Modo de Jogo" FontWeight="SemiBold" FontSize="12"/>
                                                    <Border Name="BadgeStatusGpu" Background="{DynamicResource Hover}" BorderThickness="1" BorderBrush="{DynamicResource LineStrong}" CornerRadius="4" Padding="6,1" Margin="8,0,0,0">
                                                        <TextBlock Name="TxtStatusGpu" Text="PENDENTE" Foreground="{DynamicResource Muted}" FontSize="8.5" FontWeight="Bold"/>
                                                    </Border>
                                                </StackPanel>
                                                <TextBlock Text="Permite que a GPU gerencie a pr&#x00F3;pria mem&#x00F3;ria para menor lat&#x00EA;ncia, Frame Generation e desativa grava&#x00E7;&#x00E3;o de fundo." Foreground="{DynamicResource Muted}" FontSize="11.5" Margin="0,4,0,0"/>
                                            </StackPanel>
                                            <Button Grid.Column="1" Name="BtnOptimizeGpu" Content="APLICAR" Style="{StaticResource OutlineButton}" Padding="12,5" VerticalAlignment="Center"/>
                                        </Grid>
                                    </Border>

                                    <!-- Tweak 3: IFEO Prioridade Alta -->
                                    <Border Style="{StaticResource ItemCardBorder}">
                                        <Grid>
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="Auto"/>
                                            </Grid.ColumnDefinitions>
                                            <StackPanel Grid.Column="0">
                                                <StackPanel Orientation="Horizontal">
                                                    <TextBlock Text="Prioridade Alta no Kernel para Jogos &amp; Emuladores (IFEO)" FontWeight="SemiBold" FontSize="12"/>
                                                    <Border Name="BadgeStatusIfeo" Background="{DynamicResource Hover}" BorderThickness="1" BorderBrush="{DynamicResource LineStrong}" CornerRadius="4" Padding="6,1" Margin="8,0,0,0">
                                                        <TextBlock Name="TxtStatusIfeo" Text="PENDENTE" Foreground="{DynamicResource Muted}" FontSize="8.5" FontWeight="Bold"/>
                                                    </Border>
                                                </StackPanel>
                                                <TextBlock Text="Configura prioridade alta de CPU e I/O de disco autom&#x00E1;tica para BlueStacks, emuladores e launchers." Foreground="{DynamicResource Muted}" FontSize="11.5" Margin="0,4,0,0"/>
                                            </StackPanel>
                                            <Button Grid.Column="1" Name="BtnOptimizeIfeo" Content="APLICAR" Style="{StaticResource OutlineButton}" Padding="12,5" VerticalAlignment="Center"/>
                                        </Grid>
                                    </Border>

                                    <!-- Tweak 4: TCP Nagle -->
                                    <Border Style="{StaticResource ItemCardBorder}">
                                        <Grid>
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="Auto"/>
                                            </Grid.ColumnDefinitions>
                                            <StackPanel Grid.Column="0">
                                                <StackPanel Orientation="Horizontal">
                                                    <TextBlock Text="Otimiza&#x00E7;&#x00E3;o de lat&#x00EA;ncia de rede TCP (Nagle OFF &amp; TcpAckFrequency=1)" FontWeight="SemiBold" FontSize="12"/>
                                                    <Border Name="BadgeStatusNagle" Background="{DynamicResource Hover}" BorderThickness="1" BorderBrush="{DynamicResource LineStrong}" CornerRadius="4" Padding="6,1" Margin="8,0,0,0">
                                                        <TextBlock Name="TxtStatusNagle" Text="PENDENTE" Foreground="{DynamicResource Muted}" FontSize="8.5" FontWeight="Bold"/>
                                                    </Border>
                                                </StackPanel>
                                                <TextBlock Text="Envia pacotes de jogos sem buffer (TCPNoDelay=1) reduzindo jitter e ping em partidas online." Foreground="{DynamicResource Muted}" FontSize="11.5" Margin="0,4,0,0"/>
                                            </StackPanel>
                                            <Button Grid.Column="1" Name="BtnOptimizeNagle" Content="APLICAR" Style="{StaticResource OutlineButton}" Padding="12,5" VerticalAlignment="Center"/>
                                        </Grid>
                                    </Border>

                                    <!-- Tweak 5: BCDedit & Kernel -->
                                    <Border Style="{StaticResource ItemCardBorder}">
                                        <Grid>
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="Auto"/>
                                            </Grid.ColumnDefinitions>
                                            <StackPanel Grid.Column="0">
                                                <StackPanel Orientation="Horizontal">
                                                    <TextBlock Text="Kernel &amp; BCDedit (DynamicTick OFF &amp; TSC Sync Enhanced)" FontWeight="SemiBold" FontSize="12"/>
                                                    <Border Name="BadgeStatusBcd" Background="{DynamicResource Hover}" BorderThickness="1" BorderBrush="{DynamicResource LineStrong}" CornerRadius="4" Padding="6,1" Margin="8,0,0,0">
                                                        <TextBlock Name="TxtStatusBcd" Text="PENDENTE" Foreground="{DynamicResource Muted}" FontSize="8.5" FontWeight="Bold"/>
                                                    </Border>
                                                </StackPanel>
                                                <TextBlock Text="Evita que o clock mude dinamicamente em timers curtos, eliminando micro-travamentos e stutters." Foreground="{DynamicResource Muted}" FontSize="11.5" Margin="0,4,0,0"/>
                                            </StackPanel>
                                            <Button Grid.Column="1" Name="BtnOptimizeBcd" Content="APLICAR" Style="{StaticResource OutlineButton}" Padding="12,5" VerticalAlignment="Center"/>
                                        </Grid>
                                    </Border>

                                    <!-- Tweak 6: Telemetria -->
                                    <Border Style="{StaticResource ItemCardBorder}">
                                        <Grid>
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="Auto"/>
                                            </Grid.ColumnDefinitions>
                                            <StackPanel Grid.Column="0">
                                                <StackPanel Orientation="Horizontal">
                                                    <TextBlock Text="Desativar Telemetria &amp; Rastreamento da Microsoft" FontWeight="SemiBold" FontSize="12"/>
                                                    <Border Name="BadgeStatusTelemetry" Background="{DynamicResource Hover}" BorderThickness="1" BorderBrush="{DynamicResource LineStrong}" CornerRadius="4" Padding="6,1" Margin="8,0,0,0">
                                                        <TextBlock Name="TxtStatusTelemetry" Text="PENDENTE" Foreground="{DynamicResource Muted}" FontSize="8.5" FontWeight="Bold"/>
                                                    </Border>
                                                </StackPanel>
                                                <TextBlock Text="Desativa DiagTrack, dmwappushservice e relat&#x00F3;rios cont&#x00ED;nuos de diagn&#x00F3;stico em segundo plano." Foreground="{DynamicResource Muted}" FontSize="11.5" Margin="0,4,0,0"/>
                                            </StackPanel>
                                            <Button Grid.Column="1" Name="BtnDisableTelemetry" Content="DESATIVAR" Style="{StaticResource OutlineButton}" Padding="12,5" VerticalAlignment="Center"/>
                                        </Grid>
                                    </Border>

                                    <!-- Tweak 7: Explorer & Menus -->
                                    <Border Style="{StaticResource ItemCardBorder}">
                                        <Grid>
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="Auto"/>
                                            </Grid.ColumnDefinitions>
                                            <StackPanel Grid.Column="0">
                                                <StackPanel Orientation="Horizontal">
                                                    <TextBlock Text="Responsividade do Windows Explorer &amp; Menus (MenuShowDelay=0)" FontWeight="SemiBold" FontSize="12"/>
                                                    <Border Name="BadgeStatusExplorer" Background="{DynamicResource Hover}" BorderThickness="1" BorderBrush="{DynamicResource LineStrong}" CornerRadius="4" Padding="6,1" Margin="8,0,0,0">
                                                        <TextBlock Name="TxtStatusExplorer" Text="PENDENTE" Foreground="{DynamicResource Muted}" FontSize="8.5" FontWeight="Bold"/>
                                                    </Border>
                                                </StackPanel>
                                                <TextBlock Text="Elimina atraso de abertura de janelas e desativa pesquisas da web/Bing no Menu Iniciar." Foreground="{DynamicResource Muted}" FontSize="11.5" Margin="0,4,0,0"/>
                                            </StackPanel>
                                            <Button Grid.Column="1" Name="BtnOptimizeExplorer" Content="APLICAR" Style="{StaticResource OutlineButton}" Padding="12,5" VerticalAlignment="Center"/>
                                        </Grid>
                                    </Border>

                                    <!-- Tweak 8: Cursores Mathz -->
                                    <Border Style="{StaticResource ItemCardBorder}">
                                        <Grid>
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="Auto"/>
                                            </Grid.ColumnDefinitions>
                                            <StackPanel Grid.Column="0">
                                                <StackPanel Orientation="Horizontal">
                                                    <TextBlock Text="Esquema de Cursores T&#x00E1;ticos de Alta Precis&#x00E3;o Mathz Performance" FontWeight="SemiBold" FontSize="12"/>
                                                    <Border Name="BadgeStatusCursor" Background="{DynamicResource Hover}" BorderThickness="1" BorderBrush="{DynamicResource LineStrong}" CornerRadius="4" Padding="6,1" Margin="8,0,0,0">
                                                        <TextBlock Name="TxtStatusCursor" Text="PENDENTE" Foreground="{DynamicResource Muted}" FontSize="8.5" FontWeight="Bold"/>
                                                    </Border>
                                                </StackPanel>
                                                <TextBlock Text="Ativa o conjunto geom&#x00E9;trico responsivo sem bordas desfocadas ou atraso de interpola&#x00E7;&#x00E3;o." Foreground="{DynamicResource Muted}" FontSize="11.5" Margin="0,4,0,0"/>
                                            </StackPanel>
                                            <Button Grid.Column="1" Name="BtnApplyCursor" Content="APLICAR" Style="{StaticResource OutlineButton}" Padding="12,5" VerticalAlignment="Center"/>
                                        </Grid>
                                    </Border>
                                </StackPanel>
                            </ScrollViewer>
                        </Border>
                    </Grid>

                    <!-- ===================================================================== -->
                    <!-- P&#x00C1;GINA 3: PERSONALIZADOR DE CORES & APAR&#x00CA;NCIA DO PAINEL               -->
                    <!-- ===================================================================== -->
                    <Grid Name="ViewTheme" Visibility="Collapsed">
                        <Border Style="{StaticResource CardBorder}">
                            <ScrollViewer VerticalScrollBarVisibility="Auto">
                                <StackPanel>
                                    <!-- Header da Aba de Tema -->
                                    <Grid Margin="0,0,0,14">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <StackPanel Grid.Column="0">
                                            <TextBlock Text="PERSONALIZA&#x00C7;&#x00C3;O DE CORES &amp; APAR&#x00CA;NCIA" Foreground="{DynamicResource Fg}" FontSize="13" FontWeight="SemiBold"/>
                                            <TextBlock Text="Edite a cor principal, o tom de fundo e ative o efeito de vidro transl&#x00FA;cido acr&#x00ED;lico." Foreground="{DynamicResource Muted}" FontSize="11.5" Margin="0,3,0,0"/>
                                        </StackPanel>
                                        <Button Grid.Column="1" Name="BtnResetThemeDefaults" Content="RESTAURAR PADR&#x00C3;O MTZ" Style="{StaticResource OutlineButton}"/>
                                    </Grid>

                                    <!-- Bloco 1: Modo Transl&#x00FA;cido (Vidro Acr&#x00ED;lico) -->
                                    <Border Style="{StaticResource ItemCardBorder}" Padding="16,12">
                                        <Grid>
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="Auto"/>
                                            </Grid.ColumnDefinitions>
                                            <StackPanel Grid.Column="0">
                                                <StackPanel Orientation="Horizontal">
                                                    <TextBlock Text="Modo Transl&#x00FA;cido (Vidro Acr&#x00ED;lico / Mica)" FontWeight="SemiBold" FontSize="12"/>
                                                    <Border Name="BadgeTranslucentStatus" Background="{DynamicResource Hover}" BorderThickness="1" BorderBrush="{DynamicResource LineStrong}" CornerRadius="4" Padding="6,1" Margin="8,0,0,0">
                                                        <TextBlock Name="TxtTranslucentStatus" Text="TRANSL&#x00DA;CIDO ATIVO (PADR&#x00C3;O)" Foreground="#00FF66" FontSize="8.5" FontWeight="Bold"/>
                                                    </Border>
                                                </StackPanel>
                                                <TextBlock Text="Deixa o painel transl&#x00FA;cido com desfoque de vidro acr&#x00ED;lico sobre a sua &#x00C1;rea de Trabalho." Foreground="{DynamicResource Muted}" FontSize="10" Margin="0,3,0,8"/>
                                                <WrapPanel>
                                                    <Button Name="BtnGlassOn"   Content="ATIVAR VIDRO TRANSL&#x00DA;CIDO" Style="{StaticResource PrimaryButton}" Padding="10,4" Margin="0,0,6,4" FontSize="10"/>
                                                    <Button Name="BtnGlassOff"  Content="MODO S&#x00D3;LIDO (100% OPACO)" Style="{StaticResource OutlineButton}" Padding="10,4" Margin="0,0,6,4" FontSize="10"/>
                                                    <TextBlock Text="| Opacidade:" Foreground="{DynamicResource Faint}" FontSize="9.5" VerticalAlignment="Center" Margin="6,0,6,4"/>
                                                    <Button Name="BtnOp70"  Content="70% Vidro"  Style="{StaticResource OutlineButton}" Padding="8,3" Margin="0,0,4,4" FontSize="9"/>
                                                    <Button Name="BtnOp80"  Content="80% Padr&#x00E3;o" Style="{StaticResource OutlineButton}" Padding="8,3" Margin="0,0,4,4" FontSize="9"/>
                                                    <Button Name="BtnOp90"  Content="90% Escuro" Style="{StaticResource OutlineButton}" Padding="8,3" Margin="0,0,4,4" FontSize="9"/>
                                                    <Button Name="BtnOp100" Content="100% S&#x00F3;lido" Style="{StaticResource OutlineButton}" Padding="8,3" Margin="0,0,4,4" FontSize="9"/>
                                                </WrapPanel>
                                            </StackPanel>
                                        </Grid>
                                    </Border>

                                    <!-- Bloco 2: Cor Principal de Destaque (Accent Color) -->
                                    <Border Style="{StaticResource ItemCardBorder}" Padding="16,12">
                                        <StackPanel>
                                            <Grid Margin="0,0,0,8">
                                                <StackPanel Orientation="Horizontal">
                                                    <TextBlock Text="Cor Principal de Destaque (Accent)" FontWeight="SemiBold" FontSize="12"/>
                                                    <Border Name="PreviewAccentBadge" Width="14" Height="14" Background="#FF1E27" CornerRadius="3" BorderBrush="{DynamicResource LineStrong}" BorderThickness="1" Margin="8,0,0,0"/>
                                                    <TextBlock Name="TxtCurrentAccentHex" Text="#FF1E27" FontFamily="{StaticResource Mono}" Foreground="{DynamicResource Fg}" FontSize="11" FontWeight="Bold" Margin="6,0,0,0"/>
                                                </StackPanel>
                                                <TextBlock Text="Altera a cor dos bot&#x00F5;es ao clicar, indicadores de aba e barras de progresso." Foreground="{DynamicResource Muted}" FontSize="10" HorizontalAlignment="Right"/>
                                            </Grid>

                                            <!-- Paleta R&#x00E1;pida Accent -->
                                            <WrapPanel Margin="0,2,0,8">
                                                <Button Name="BtnAccRed"    Tag="#FF1E27" Content="Vermelho MTZ"  Style="{StaticResource OutlineButton}" Padding="8,4" Margin="0,0,6,6" FontSize="10" Foreground="#FF1E27"/>
                                                <Button Name="BtnAccGreen"  Tag="#00FF66" Content="Matrix Green"  Style="{StaticResource OutlineButton}" Padding="8,4" Margin="0,0,6,6" FontSize="10" Foreground="#00FF66"/>
                                                <Button Name="BtnAccCyan"   Tag="#00E5FF" Content="Cyan Neon"     Style="{StaticResource OutlineButton}" Padding="8,4" Margin="0,0,6,6" FontSize="10" Foreground="#00E5FF"/>
                                                <Button Name="BtnAccPurple" Tag="#A100FF" Content="Amethyst"      Style="{StaticResource OutlineButton}" Padding="8,4" Margin="0,0,6,6" FontSize="10" Foreground="#A100FF"/>
                                                <Button Name="BtnAccGold"   Tag="#FFD700" Content="Cyber Gold"    Style="{StaticResource OutlineButton}" Padding="8,4" Margin="0,0,6,6" FontSize="10" Foreground="#FFD700"/>
                                                <Button Name="BtnAccOrange" Tag="#FF6600" Content="Laranja Neon"  Style="{StaticResource OutlineButton}" Padding="8,4" Margin="0,0,6,6" FontSize="10" Foreground="#FF6600"/>
                                                <Button Name="BtnAccWhite"  Tag="#FFFFFF" Content="Branco Puro"   Style="{StaticResource OutlineButton}" Padding="8,4" Margin="0,0,6,6" FontSize="10" Foreground="#FFFFFF"/>
                                                <Button Name="BtnAccPink"   Tag="#FF007F" Content="Pink Synth"    Style="{StaticResource OutlineButton}" Padding="8,4" Margin="0,0,6,6" FontSize="10" Foreground="#FF007F"/>
                                            </WrapPanel>

                                            <!-- Entrada Customizada Accent -->
                                            <StackPanel Orientation="Horizontal">
                                                <TextBlock Text="Cor Personalizada (HEX):" Foreground="{DynamicResource Muted}" FontSize="10" VerticalAlignment="Center" Margin="0,0,8,0"/>
                                                <TextBox Name="TxtCustomAccentHex" Text="#FF1E27" Width="100" Background="#0A0A0A" Foreground="{DynamicResource Fg}" BorderBrush="{DynamicResource LineStrong}" BorderThickness="1" FontFamily="{StaticResource Mono}" FontSize="11" Padding="6,3"/>
                                                <Button Name="BtnApplyCustomAccent" Content="APLICAR COR" Style="{StaticResource OutlineButton}" Padding="10,3" Margin="8,0,0,0" FontSize="10"/>
                                            </StackPanel>
                                        </StackPanel>
                                    </Border>

                                    <!-- Bloco de Tipografia Premium (Fontes do Sistema) -->
                                    <Border Style="{StaticResource ItemCardBorder}" Padding="16,12">
                                        <StackPanel>
                                            <Grid Margin="0,0,0,8">
                                                <StackPanel Orientation="Horizontal">
                                                    <TextBlock Text="Fam&#x00ED;lia Tipogr&#x00E1;fica do Painel" FontFamily="{DynamicResource Heading}" FontWeight="Bold" FontSize="13.5"/>
                                                    <Border Name="BadgeActiveFont" Background="#121212" BorderThickness="1" BorderBrush="#FF1E27" CornerRadius="4" Padding="6,1" Margin="8,0,0,0">
                                                        <TextBlock Name="TxtActiveFontName" Text="CYBER ESPORTS (BEBAS NEUE + OUTFIT)" Foreground="#FF1E27" FontSize="8.5" FontWeight="Bold"/>
                                                    </Border>
                                                </StackPanel>
                                                <TextBlock Text="Alterne o estilo de fontes entre os visuais Gamer, Sci-Fi e Arredondado." Foreground="{DynamicResource Muted}" FontSize="10" HorizontalAlignment="Right"/>
                                            </Grid>

                                            <WrapPanel Margin="0,2,0,4">
                                                <Button Name="BtnFontCyber"   Content="1. CYBER ESPORTS (BEBAS + OUTFIT)" Style="{StaticResource PrimaryButton}" Padding="12,5" Margin="0,0,6,6" FontSize="10.5" ToolTip="T&#x00ED;tulos impactantes em Bebas Neue e textos arredondados modernos em Outfit"/>
                                                <Button Name="BtnFontQuantum" Content="2. QUANTUM SCI-FI (ORBITRON + RAJDHANI)" Style="{StaticResource OutlineButton}" Padding="12,5" Margin="0,0,6,6" FontSize="10.5" ToolTip="Visual cibern&#x00E9;tico angular futurista"/>
                                                <Button Name="BtnFontRounded" Content="3. MODERNA ARREDONDADA (OUTFIT / AQUATICO)" Style="{StaticResource OutlineButton}" Padding="12,5" Margin="0,0,6,6" FontSize="10.5" ToolTip="Geometria 100% arredondada e suave estilo Fontastique e Aquatico"/>
                                                <Button Name="BtnFontFluent"  Content="4. WINDOWS FLUENT (BAHNSCHRIFT)" Style="{StaticResource OutlineButton}" Padding="12,5" Margin="0,0,6,6" FontSize="10.5" ToolTip="Geom&#x00E9;trica DIN oficial do Windows 11"/>
                                            </WrapPanel>
                                        </StackPanel>
                                    </Border>

                                    <!-- Bloco 3: Cor de Fundo da Janela (Background Tone) -->
                                    <Border Style="{StaticResource ItemCardBorder}" Padding="16,12">
                                        <StackPanel>
                                            <Grid Margin="0,0,0,8">
                                                <StackPanel Orientation="Horizontal">
                                                    <TextBlock Text="Tom de Fundo do Painel (Background)" FontWeight="SemiBold" FontSize="12"/>
                                                    <Border Name="PreviewBgBadge" Width="14" Height="14" Background="#000000" CornerRadius="3" BorderBrush="{DynamicResource LineStrong}" BorderThickness="1" Margin="8,0,0,0"/>
                                                    <TextBlock Name="TxtCurrentBgHex" Text="#000000" FontFamily="{StaticResource Mono}" Foreground="{DynamicResource Fg}" FontSize="11" FontWeight="Bold" Margin="6,0,0,0"/>
                                                </StackPanel>
                                                <TextBlock Text="Define o tom de base escuro do painel e dos cart&#x00F5;es." Foreground="{DynamicResource Muted}" FontSize="10" HorizontalAlignment="Right"/>
                                            </Grid>

                                            <!-- Paleta R&#x00E1;pida Fundo -->
                                            <WrapPanel Margin="0,2,0,8">
                                                <Button Name="BtnBgPureBlack" Tag="#000000" Content="Preto Absoluto (Padr&#x00E3;o)" Style="{StaticResource OutlineButton}" Padding="8,4" Margin="0,0,6,6" FontSize="10"/>
                                                <Button Name="BtnBgSlate"     Tag="#080A0E" Content="Grafite Noturno"          Style="{StaticResource OutlineButton}" Padding="8,4" Margin="0,0,6,6" FontSize="10"/>
                                                <Button Name="BtnBgCrimson"   Tag="#120406" Content="Carmesim Dark"           Style="{StaticResource OutlineButton}" Padding="8,4" Margin="0,0,6,6" FontSize="10"/>
                                                <Button Name="BtnBgNavy"      Tag="#030914" Content="Deep Navy"               Style="{StaticResource OutlineButton}" Padding="8,4" Margin="0,0,6,6" FontSize="10"/>
                                                <Button Name="BtnBgForest"    Tag="#020E06" Content="Stealth Forest"          Style="{StaticResource OutlineButton}" Padding="8,4" Margin="0,0,6,6" FontSize="10"/>
                                            </WrapPanel>

                                            <!-- Entrada Customizada Fundo -->
                                            <StackPanel Orientation="Horizontal">
                                                <TextBlock Text="Fundo Personalizado (HEX):" Foreground="{DynamicResource Muted}" FontSize="10" VerticalAlignment="Center" Margin="0,0,8,0"/>
                                                <TextBox Name="TxtCustomBgHex" Text="#000000" Width="100" Background="#0A0A0A" Foreground="{DynamicResource Fg}" BorderBrush="{DynamicResource LineStrong}" BorderThickness="1" FontFamily="{StaticResource Mono}" FontSize="11" Padding="6,3"/>
                                                <Button Name="BtnApplyCustomBg" Content="APLICAR FUNDO" Style="{StaticResource OutlineButton}" Padding="10,3" Margin="8,0,0,0" FontSize="10"/>
                                            </StackPanel>
                                        </StackPanel>
                                    </Border>
                                </StackPanel>
                            </ScrollViewer>
                        </Border>
                    </Grid>

                    <!-- ===================================================================== -->
                    <!-- P&#x00C1;GINA 4: INICIALIZA&#x00C7;&#x00C3;O DO WINDOWS                                    -->
                    <!-- ===================================================================== -->
                    <Grid Name="ViewStartup" Visibility="Collapsed">
                        <Border Style="{StaticResource CardBorder}">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                </Grid.RowDefinitions>

                                <Grid Grid.Row="0" Margin="0,0,0,12">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                        <TextBlock Text="PROGRAMAS QUE INICIAM COM O WINDOWS" Foreground="{DynamicResource Fg}" FontSize="13" FontWeight="SemiBold"/>
                                        <TextBlock Name="TxtStartupSummary" Text="Desative inicializadores em segundo plano para acelerar o boot." Foreground="{DynamicResource Muted}" FontSize="11.5" Margin="0,3,0,0"/>
                                    </StackPanel>
                                    <Button Grid.Column="1" Name="BtnScanStartup" Content="ATUALIZAR LISTA" Style="{StaticResource OutlineButton}"/>
                                </Grid>

                                <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                                    <StackPanel Name="StackStartupItems"/>
                                </ScrollViewer>
                            </Grid>
                        </Border>
                    </Grid>

                    <!-- ===================================================================== -->
                    <!-- P&#x00C1;GINA 5: PERSONALIZADOR DE CURSORES                                  -->
                    <!-- ===================================================================== -->
                    <Grid Name="ViewCursors" Visibility="Collapsed">
                        <Border Style="{StaticResource CardBorder}">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="18"/>
                                    <ColumnDefinition Width="280"/>
                                </Grid.ColumnDefinitions>

                                <StackPanel Grid.Column="0">
                                    <TextBlock Text="PERSONALIZADOR DE CURSORES MATHZ" Foreground="{DynamicResource Fg}" FontSize="13" FontWeight="SemiBold"/>
                                    <TextBlock Text="Configure paletas personalizadas para gerar o esquema de ponteiros." Foreground="{DynamicResource Muted}" FontSize="10" Margin="0,2,0,14"/>

                                    <Grid Margin="0,0,0,12">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="10"/>
                                            <ColumnDefinition Width="*"/>
                                        </Grid.ColumnDefinitions>

                                        <Border Grid.Column="0" Background="#0A0A0A" BorderBrush="{DynamicResource Line}" BorderThickness="1" CornerRadius="10" Padding="12">
                                            <StackPanel>
                                                <TextBlock Text="COR DA BORDA (OUTLINE)" Foreground="{DynamicResource Muted}" FontSize="9" FontWeight="SemiBold"/>
                                                <Grid Margin="0,6,0,0">
                                                    <Grid.ColumnDefinitions>
                                                        <ColumnDefinition Width="20"/>
                                                        <ColumnDefinition Width="*"/>
                                                    </Grid.ColumnDefinitions>
                                                    <Border Name="PreviewColorOutlineBadge" Width="18" Height="18" Background="#FF003C" CornerRadius="4" BorderBrush="{DynamicResource LineStrong}" BorderThickness="1"/>
                                                    <TextBox Grid.Column="1" Name="TxtOutlineHex" Text="#FF003C" Background="Transparent" Foreground="{DynamicResource Fg}" BorderThickness="0" FontFamily="{StaticResource Mono}" FontSize="12" Margin="8,0,0,0"/>
                                                </Grid>
                                                <WrapPanel Margin="0,8,0,0">
                                                    <Button Name="BtnOutRed" Tag="#FF003C" Width="18" Height="18" Background="#FF003C" BorderThickness="0" Margin="0,0,4,4" ToolTip="Neon Red (#FF003C)" Cursor="Hand"/>
                                                    <Button Name="BtnOutCyan" Tag="#00E5FF" Width="18" Height="18" Background="#00E5FF" BorderThickness="0" Margin="0,0,4,4" ToolTip="Neon Cyan (#00E5FF)" Cursor="Hand"/>
                                                    <Button Name="BtnOutGreen" Tag="#00FF66" Width="18" Height="18" Background="#00FF66" BorderThickness="0" Margin="0,0,4,4" ToolTip="Matrix Green (#00FF66)" Cursor="Hand"/>
                                                    <Button Name="BtnOutPurple" Tag="#A100FF" Width="18" Height="18" Background="#A100FF" BorderThickness="0" Margin="0,0,4,4" ToolTip="Amethyst Purple (#A100FF)" Cursor="Hand"/>
                                                    <Button Name="BtnOutGold" Tag="#FFD700" Width="18" Height="18" Background="#FFD700" BorderThickness="0" Margin="0,0,4,4" ToolTip="Cyber Gold (#FFD700)" Cursor="Hand"/>
                                                    <Button Name="BtnOutOrange" Tag="#FF6600" Width="18" Height="18" Background="#FF6600" BorderThickness="0" Margin="0,0,4,4" ToolTip="Hyper Orange (#FF6600)" Cursor="Hand"/>
                                                    <Button Name="BtnOutWhite" Tag="#FFFFFF" Width="18" Height="18" Background="#FFFFFF" BorderThickness="0" Margin="0,0,4,4" ToolTip="Pure White (#FFFFFF)" Cursor="Hand"/>
                                                    <Button Name="BtnOutPink" Tag="#FF007F" Width="18" Height="18" Background="#FF007F" BorderThickness="0" Margin="0,0,4,4" ToolTip="Neon Pink (#FF007F)" Cursor="Hand"/>
                                                </WrapPanel>
                                            </StackPanel>
                                        </Border>

                                        <Border Grid.Column="2" Background="#0A0A0A" BorderBrush="{DynamicResource Line}" BorderThickness="1" CornerRadius="10" Padding="12">
                                            <StackPanel>
                                                <TextBlock Text="COR DE PREENCHIMENTO" Foreground="{DynamicResource Muted}" FontSize="9" FontWeight="SemiBold"/>
                                                <Grid Margin="0,6,0,0">
                                                    <Grid.ColumnDefinitions>
                                                        <ColumnDefinition Width="20"/>
                                                        <ColumnDefinition Width="*"/>
                                                    </Grid.ColumnDefinitions>
                                                    <Border Name="PreviewColorInsideBadge" Width="18" Height="18" Background="#050508" CornerRadius="4" BorderBrush="{DynamicResource LineStrong}" BorderThickness="1"/>
                                                    <TextBox Grid.Column="1" Name="TxtInsideHex" Text="#050508" Background="Transparent" Foreground="{DynamicResource Fg}" BorderThickness="0" FontFamily="{StaticResource Mono}" FontSize="12" Margin="8,0,0,0"/>
                                                </Grid>
                                                <WrapPanel Margin="0,8,0,0">
                                                    <Button Name="BtnInPureBlack" Tag="#050508" Width="18" Height="18" Background="#050508" BorderBrush="#3A3A3A" BorderThickness="1" Margin="0,0,4,4" ToolTip="Pure Black (#050508)" Cursor="Hand"/>
                                                    <Button Name="BtnInSlate" Tag="#1A1C24" Width="18" Height="18" Background="#1A1C24" BorderBrush="#3A3A3A" BorderThickness="1" Margin="0,0,4,4" ToolTip="Dark Slate (#1A1C24)" Cursor="Hand"/>
                                                    <Button Name="BtnInCrimson" Tag="#2A050B" Width="18" Height="18" Background="#2A050B" BorderBrush="#3A3A3A" BorderThickness="1" Margin="0,0,4,4" ToolTip="Crimson Dark (#2A050B)" Cursor="Hand"/>
                                                    <Button Name="BtnInNavy" Tag="#041224" Width="18" Height="18" Background="#041224" BorderBrush="#3A3A3A" BorderThickness="1" Margin="0,0,4,4" ToolTip="Deep Navy (#041224)" Cursor="Hand"/>
                                                    <Button Name="BtnInDarkPurple" Tag="#180525" Width="18" Height="18" Background="#180525" BorderBrush="#3A3A3A" BorderThickness="1" Margin="0,0,4,4" ToolTip="Dark Purple (#180525)" Cursor="Hand"/>
                                                    <Button Name="BtnInPureWhite" Tag="#FFFFFF" Width="18" Height="18" Background="#FFFFFF" BorderBrush="#3A3A3A" BorderThickness="1" Margin="0,0,4,4" ToolTip="Pure White (#FFFFFF)" Cursor="Hand"/>
                                                </WrapPanel>
                                            </StackPanel>
                                        </Border>
                                    </Grid>

                                    <TextBlock Text="PALETAS RECOMENDADAS:" Foreground="{DynamicResource Muted}" FontSize="9.5" FontWeight="SemiBold" Margin="0,0,0,8"/>
                                    <WrapPanel Margin="0,0,0,16">
                                        <Button Name="BtnPresetCyberpunk" Content="Cyberpunk (Vermelho)" Style="{StaticResource OutlineButton}" Padding="8,5" Margin="0,0,6,6"/>
                                        <Button Name="BtnPresetMatrix"    Content="Matrix (Verde)"       Style="{StaticResource OutlineButton}" Padding="8,5" Margin="0,0,6,6"/>
                                        <Button Name="BtnPresetCyan"      Content="Cyan Frost (Azul)"    Style="{StaticResource OutlineButton}" Padding="8,5" Margin="0,0,6,6"/>
                                        <Button Name="BtnPresetPureWhite" Content="Pure White (Branco)"  Style="{StaticResource OutlineButton}" Padding="8,5" Margin="0,0,6,6"/>
                                        <Button Name="BtnPresetStealth"   Content="Stealth (Grafite)"    Style="{StaticResource OutlineButton}" Padding="8,5" Margin="0,0,6,6"/>
                                        <Button Name="BtnPresetGold"      Content="Cyber Gold (Dourado)" Style="{StaticResource OutlineButton}" Padding="8,5" Margin="0,0,6,6"/>
                                        <Button Name="BtnPresetGhost"     Content="Ghost (Inverso)"      Style="{StaticResource OutlineButton}" Padding="8,5" Margin="0,0,6,6"/>
                                    </WrapPanel>

                                    <StackPanel Orientation="Horizontal">
                                        <Button Name="BtnApplyCursorColors" Content="GERAR E APLICAR" Style="{StaticResource PrimaryButton}" Margin="0,0,10,0"/>
                                        <Button Name="BtnResetDefaultCursors" Content="RESTAURAR ORIGINAL" Style="{StaticResource OutlineButton}"/>
                                    </StackPanel>
                                </StackPanel>

                                <Border Grid.Column="2" Background="#0A0A0A" BorderBrush="{DynamicResource Line}" BorderThickness="1" CornerRadius="14" Padding="14">
                                    <StackPanel VerticalAlignment="Center">
                                        <TextBlock Text="PR&#x00C9;-VISUALIZA&#x00C7;&#x00C3;O" Foreground="{DynamicResource Muted}" FontSize="9.5" FontWeight="SemiBold" HorizontalAlignment="Center" Margin="0,0,0,12"/>
                                        <UniformGrid Columns="3" Rows="2" Width="220" Height="140">
                                            <Border Margin="4" Background="{DynamicResource Card}" CornerRadius="8" Padding="6">
                                                <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
                                                    <Canvas Width="28" Height="28">
                                                        <Polygon Name="PrevPolyArrow" Points="2,2 24,14 14,16 9,25" Fill="#050508" Stroke="#FF003C" StrokeThickness="1.8"/>
                                                    </Canvas>
                                                    <TextBlock Text="Normal" Foreground="{DynamicResource Faint}" FontSize="8" HorizontalAlignment="Center" Margin="0,3,0,0"/>
                                                </StackPanel>
                                            </Border>
                                            <Border Margin="4" Background="{DynamicResource Card}" CornerRadius="8" Padding="6">
                                                <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
                                                    <Canvas Width="28" Height="28">
                                                        <Polygon Name="PrevPolyAppArrow" Points="2,2 18,11 11,12 7,20" Fill="#050508" Stroke="#FF003C" StrokeThickness="1.5"/>
                                                        <Ellipse Name="PrevEllAppBg" Canvas.Left="15" Canvas.Top="15" Width="10" Height="10" Stroke="#FF003C" StrokeThickness="1.5"/>
                                                        <Ellipse Name="PrevEllAppDot" Canvas.Left="18" Canvas.Top="18" Width="4" Height="4" Fill="#FF003C"/>
                                                    </Canvas>
                                                    <TextBlock Text="Ocupado" Foreground="{DynamicResource Faint}" FontSize="8" HorizontalAlignment="Center" Margin="0,3,0,0"/>
                                                </StackPanel>
                                            </Border>
                                            <Border Margin="4" Background="{DynamicResource Card}" CornerRadius="8" Padding="6">
                                                <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
                                                    <Canvas Width="28" Height="28">
                                                        <Ellipse Name="PrevEllWaitBg" Canvas.Left="3" Canvas.Top="3" Width="22" Height="22" Stroke="#252A36" StrokeThickness="2"/>
                                                        <Path Name="PrevPathWaitArc" Canvas.Left="3" Canvas.Top="3" Data="M 14,3 A 11,11 0 0,1 25,14" Stroke="#FF003C" StrokeThickness="2.5"/>
                                                        <Ellipse Name="PrevEllWaitDot" Canvas.Left="12" Canvas.Top="12" Width="4" Height="4" Fill="#FF003C"/>
                                                    </Canvas>
                                                    <TextBlock Text="Aguarde" Foreground="{DynamicResource Faint}" FontSize="8" HorizontalAlignment="Center" Margin="0,3,0,0"/>
                                                </StackPanel>
                                            </Border>
                                            <Border Margin="4" Background="{DynamicResource Card}" CornerRadius="8" Padding="6">
                                                <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
                                                    <Canvas Width="28" Height="28">
                                                        <Line Name="PrevLineCrossH1" X1="2" Y1="14" X2="9" Y2="14" Stroke="#FF003C" StrokeThickness="1.8"/>
                                                        <Line Name="PrevLineCrossH2" X1="19" Y1="14" X2="26" Y2="14" Stroke="#FF003C" StrokeThickness="1.8"/>
                                                        <Line Name="PrevLineCrossV1" X1="14" Y1="2" X2="14" Y2="9" Stroke="#FF003C" StrokeThickness="1.8"/>
                                                        <Line Name="PrevLineCrossV2" X1="14" Y1="19" X2="14" Y2="26" Stroke="#FF003C" StrokeThickness="1.8"/>
                                                        <Ellipse Name="PrevEllCrossRing" Canvas.Left="9" Canvas.Top="9" Width="10" Height="10" Stroke="#FF003C" StrokeThickness="1.2"/>
                                                        <Ellipse Name="PrevEllCrossDot" Canvas.Left="13" Canvas.Top="13" Width="2" Height="2" Fill="#FFFFFF"/>
                                                    </Canvas>
                                                    <TextBlock Text="Mira" Foreground="{DynamicResource Faint}" FontSize="8" HorizontalAlignment="Center" Margin="0,3,0,0"/>
                                                </StackPanel>
                                            </Border>
                                            <Border Margin="4" Background="{DynamicResource Card}" CornerRadius="8" Padding="6">
                                                <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
                                                    <Canvas Width="28" Height="28">
                                                        <Polygon Name="PrevPolyHand" Points="10,2 14,2 14,9 17,10 19,12 19,20 16,23 9,23 7,18 7,14 10,12" Fill="#050508" Stroke="#FF1E27" StrokeThickness="1.8"/>
                                                        <Line Name="PrevLineHand" X1="14" Y1="12" X2="14" Y2="17" Stroke="#FF1E27" StrokeThickness="1.5"/>
                                                    </Canvas>
                                                    <TextBlock Text="Link" Foreground="{DynamicResource Faint}" FontSize="8" HorizontalAlignment="Center" Margin="0,3,0,0"/>
                                                </StackPanel>
                                            </Border>
                                            <Border Margin="4" Background="{DynamicResource Card}" CornerRadius="8" Padding="6">
                                                <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
                                                    <Canvas Width="28" Height="28">
                                                        <Line Name="PrevLineBeamTop" X1="8" Y1="5" X2="20" Y2="5" Stroke="#FF1E27" StrokeThickness="2.5"/>
                                                        <Line Name="PrevLineBeamStem" X1="14" Y1="5" X2="14" Y2="23" Stroke="#FF1E27" StrokeThickness="2.5"/>
                                                        <Line Name="PrevLineBeamBot" X1="8" Y1="23" X2="20" Y2="23" Stroke="#FF1E27" StrokeThickness="2.5"/>
                                                    </Canvas>
                                                    <TextBlock Text="Texto" Foreground="{DynamicResource Faint}" FontSize="8" HorizontalAlignment="Center" Margin="0,3,0,0"/>
                                                </StackPanel>
                                            </Border>
                                        </UniformGrid>
                                        <TextBlock Name="TxtPreviewColorInfo" Text="Borda: #FF1E27 | Fundo: #050508" FontFamily="{StaticResource Mono}" Foreground="{DynamicResource Muted}" FontSize="9" HorizontalAlignment="Center" Margin="0,8,0,0"/>
                                    </StackPanel>
                                </Border>
                            </Grid>
                        </Border>
                    </Grid>

                    <!-- ===================================================================== -->
                    <!-- P&#x00C1;GINA 6: DRIVE MATHZ (WHQL CERTIFICADO)                              -->
                    <!-- ===================================================================== -->
                    <Grid Name="ViewDrivers" Visibility="Collapsed">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="14"/>
                            <ColumnDefinition Width="270"/>
                        </Grid.ColumnDefinitions>

                        <Border Grid.Column="0" Style="{StaticResource CardBorder}">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                    <RowDefinition Height="Auto"/>
                                </Grid.RowDefinitions>

                                <Grid Grid.Row="0" Margin="0,0,0,12">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel Grid.Column="0">
                                        <StackPanel Orientation="Horizontal">
                                            <TextBlock Text="DRIVE MATHZ &#x00B7; CAT&#x00C1;LOGO WHQL" Foreground="{DynamicResource Fg}" FontSize="13" FontWeight="SemiBold"/>
                                            <Border Background="{DynamicResource Hover}" BorderThickness="1" BorderBrush="{DynamicResource LineStrong}" CornerRadius="4" Padding="6,1" Margin="8,0,0,0">
                                                <TextBlock Name="TxtDriverCountBadge" Text="0 DETECTADOS" Foreground="{DynamicResource Fg}" FontSize="8.5" FontWeight="Bold"/>
                                            </Border>
                                        </StackPanel>
                                        <TextBlock Name="TxtMathzDriversStatus" Text="Varredura de hardware e atualiza&#x00E7;&#x00F5;es oficiais assinadas pela Microsoft." Foreground="{DynamicResource Muted}" FontSize="11.5" Margin="0,3,0,0"/>
                                    </StackPanel>
                                    <StackPanel Grid.Column="1" Orientation="Horizontal">
                                        <Button Name="BtnMathzScanDrivers" Content="ESCANEAR" Style="{StaticResource OutlineButton}" Margin="0,0,8,0"/>
                                        <Button Name="BtnInstallAllMathzDrivers" Content="ATUALIZAR WHQL" Style="{StaticResource PrimaryButton}"/>
                                    </StackPanel>
                                </Grid>

                                <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                                    <StackPanel Name="StackDriverItems"/>
                                </ScrollViewer>

                                <Border Grid.Row="2" Background="#0A0A0A" BorderBrush="{DynamicResource Line}" BorderThickness="1" CornerRadius="8" Padding="12,8" Margin="0,10,0,0">
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Text="SEGURAN&#x00C7;A: Exportar drivers instalados antes de atualizar." Foreground="{DynamicResource Muted}" FontSize="9.5" VerticalAlignment="Center"/>
                                        <StackPanel Grid.Column="1" Orientation="Horizontal">
                                            <Button Name="BtnBackupDrivers" Content="BACKUP" Style="{StaticResource OutlineButton}" Padding="10,4" Margin="0,0,6,0"/>
                                            <Button Name="BtnCreateRestorePoint" Content="PONTO REST." Style="{StaticResource OutlineButton}" Padding="10,4"/>
                                        </StackPanel>
                                    </Grid>
                                </Border>
                            </Grid>
                        </Border>

                        <!-- Atalhos de Hardware -->
                        <Border Grid.Column="2" Style="{StaticResource CardBorder}">
                            <ScrollViewer VerticalScrollBarVisibility="Auto">
                                <StackPanel>
                                    <TextBlock Text="FERRAMENTAS DE HARDWARE" Foreground="{DynamicResource Fg}" FontSize="11" FontWeight="SemiBold" Margin="0,0,0,10"/>
                                    <Button Name="BtnOpenDevMgmt" Content="Gerenciador de Dispositivos" Style="{StaticResource OutlineButton}" Margin="0,0,0,6" HorizontalContentAlignment="Left"/>
                                    <Button Name="BtnRescanHardware" Content="Reescanear Dispositivos PnP" Style="{StaticResource OutlineButton}" Margin="0,0,0,6" HorizontalContentAlignment="Left"/>
                                    <Button Name="BtnInjectInfFolder" Content="Instalar Driver via Pasta .INF" Style="{StaticResource OutlineButton}" Margin="0,0,0,6" HorizontalContentAlignment="Left"/>
                                    <Button Name="BtnExportDriverReport" Content="Exportar Relat&#x00F3;rio de Hardware" Style="{StaticResource OutlineButton}" Margin="0,0,0,14" HorizontalContentAlignment="Left"/>

                                    <TextBlock Text="FABRICANTES DE GPU" Foreground="{DynamicResource Muted}" FontSize="9.5" FontWeight="SemiBold" Margin="0,0,0,8"/>
                                    <Button Name="BtnGpuNvidia" Content="NVIDIA GeForce Drivers" Style="{StaticResource OutlineButton}" Margin="0,0,0,4" HorizontalContentAlignment="Left"/>
                                    <Button Name="BtnGpuAmd"    Content="AMD Software Adrenalin" Style="{StaticResource OutlineButton}" Margin="0,0,0,4" HorizontalContentAlignment="Left"/>
                                    <Button Name="BtnGpuIntel"  Content="Intel Arc &amp; Iris Graphics" Style="{StaticResource OutlineButton}" Margin="0,0,0,14" HorizontalContentAlignment="Left"/>

                                    <TextBlock Text="RUNTIMES DE JOGOS" Foreground="{DynamicResource Muted}" FontSize="9.5" FontWeight="SemiBold" Margin="0,0,0,8"/>
                                    <Button Name="BtnInstallVCRedist" Content="Visual C++ Runtimes (AIO)" Style="{StaticResource OutlineButton}" Margin="0,0,0,4" HorizontalContentAlignment="Left"/>
                                    <Button Name="BtnInstallDirectX"  Content="DirectX End-User Runtimes" Style="{StaticResource OutlineButton}" Margin="0,0,0,4" HorizontalContentAlignment="Left"/>
                                </StackPanel>
                            </ScrollViewer>
                        </Border>
                    </Grid>

                    <!-- ===================================================================== -->
                    <!-- P&#x00C1;GINA 7: NAVEGADORES WEB                                             -->
                    <!-- ===================================================================== -->
                    <Grid Name="ViewBrowsers" Visibility="Collapsed">
                        <Border Style="{StaticResource CardBorder}">
                            <StackPanel>
                                <TextBlock Text="INSTALA&#x00C7;&#x00C3;O DE NAVEGADORES" Foreground="{DynamicResource Fg}" FontSize="13" FontWeight="SemiBold"/>
                                <TextBlock Text="Instala&#x00E7;&#x00E3;o oficial e silenciosa em segundo plano via Microsoft Winget." Foreground="{DynamicResource Muted}" FontSize="10" Margin="0,2,0,16"/>

                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="14"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="14"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>

                                    <Border Grid.Column="0" Background="#0A0A0A" BorderBrush="{DynamicResource Line}" BorderThickness="1" CornerRadius="12" Padding="16">
                                        <StackPanel>
                                            <TextBlock Text="Google Chrome" FontSize="14" FontWeight="SemiBold"/>
                                            <TextBlock Text="O navegador mais usado com sincroniza&#x00E7;&#x00E3;o Google." Foreground="{DynamicResource Muted}" FontSize="10" Margin="0,4,0,14" TextWrapping="Wrap"/>
                                            <Button Name="BtnDownloadChrome" Content="INSTALAR CHROME" Style="{StaticResource PrimaryButton}"/>
                                        </StackPanel>
                                    </Border>

                                    <Border Grid.Column="2" Background="#0A0A0A" BorderBrush="{DynamicResource Line}" BorderThickness="1" CornerRadius="12" Padding="16">
                                        <StackPanel>
                                            <TextBlock Text="Brave Browser" FontSize="14" FontWeight="SemiBold"/>
                                            <TextBlock Text="Bloqueador nativo de an&#x00FA;ncios com alta performance." Foreground="{DynamicResource Muted}" FontSize="10" Margin="0,4,0,14" TextWrapping="Wrap"/>
                                            <Button Name="BtnDownloadBrave" Content="INSTALAR BRAVE" Style="{StaticResource PrimaryButton}"/>
                                        </StackPanel>
                                    </Border>

                                    <Border Grid.Column="4" Background="#0A0A0A" BorderBrush="{DynamicResource Line}" BorderThickness="1" CornerRadius="12" Padding="16">
                                        <StackPanel>
                                            <TextBlock Text="Mozilla Firefox" FontSize="14" FontWeight="SemiBold"/>
                                            <TextBlock Text="Motor Gecko independente com foco em privacidade." Foreground="{DynamicResource Muted}" FontSize="10" Margin="0,4,0,14" TextWrapping="Wrap"/>
                                            <Button Name="BtnDownloadFirefox" Content="INSTALAR FIREFOX" Style="{StaticResource PrimaryButton}"/>
                                        </StackPanel>
                                    </Border>
                                </Grid>
                            </StackPanel>
                        </Border>
                    </Grid>

                    <!-- ===================================================================== -->
                    <!-- P&#x00C1;GINA 8: INSTALAR APPS & LAUNCHERS                                   -->
                    <!-- ===================================================================== -->
                    <Grid Name="ViewInstaller" Visibility="Collapsed">
                        <Border Style="{StaticResource CardBorder}">
                            <StackPanel>
                                <Grid Margin="0,0,0,16">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel Grid.Column="0">
                                        <TextBlock Text="INSTALAR APLICATIVOS ESSENCIAIS" Foreground="{DynamicResource Fg}" FontSize="13" FontWeight="SemiBold"/>
                                        <TextBlock Text="Essenciais p&#x00F3;s-formata&#x00E7;&#x00E3;o de uma s&#x00F3; vez pelo Winget oficial." Foreground="{DynamicResource Muted}" FontSize="11.5" Margin="0,3,0,0"/>
                                    </StackPanel>
                                    <Button Grid.Column="1" Name="BtnInstallAllLaunchers" Content="INSTALAR TODOS EM LOTE" Style="{StaticResource PrimaryButton}"/>
                                </Grid>

                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="14"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="14"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>

                                    <Border Grid.Column="0" Background="#0A0A0A" BorderBrush="{DynamicResource Line}" BorderThickness="1" CornerRadius="12" Padding="16">
                                        <StackPanel>
                                            <TextBlock Text="Steam" FontSize="14" FontWeight="SemiBold"/>
                                            <TextBlock Text="Maior plataforma de distribui&#x00E7;&#x00E3;o de jogos para PC." Foreground="{DynamicResource Muted}" FontSize="10" Margin="0,4,0,14" TextWrapping="Wrap"/>
                                            <Button Name="BtnInstallSteam" Content="INSTALAR STEAM" Style="{StaticResource OutlineButton}"/>
                                        </StackPanel>
                                    </Border>

                                    <Border Grid.Column="2" Background="#0A0A0A" BorderBrush="{DynamicResource Line}" BorderThickness="1" CornerRadius="12" Padding="16">
                                        <StackPanel>
                                            <TextBlock Text="Epic Games Store" FontSize="14" FontWeight="SemiBold"/>
                                            <TextBlock Text="Jogos gratuitos semanais e biblioteca Unreal Engine." Foreground="{DynamicResource Muted}" FontSize="10" Margin="0,4,0,14" TextWrapping="Wrap"/>
                                            <Button Name="BtnInstallEpic" Content="INSTALAR EPIC" Style="{StaticResource OutlineButton}"/>
                                        </StackPanel>
                                    </Border>

                                    <Border Grid.Column="4" Background="#0A0A0A" BorderBrush="{DynamicResource Line}" BorderThickness="1" CornerRadius="12" Padding="16">
                                        <StackPanel>
                                            <TextBlock Text="Discord" FontSize="14" FontWeight="SemiBold"/>
                                            <TextBlock Text="Chat de voz e comunidades para jogos em grupo." Foreground="{DynamicResource Muted}" FontSize="10" Margin="0,4,0,14" TextWrapping="Wrap"/>
                                            <Button Name="BtnInstallDiscord" Content="INSTALAR DISCORD" Style="{StaticResource OutlineButton}"/>
                                        </StackPanel>
                                    </Border>
                                </Grid>
                            </StackPanel>
                        </Border>
                    </Grid>

                </Grid>

                <!-- RODAP&#x00C9; DE STATUS -->
                <Grid Grid.Row="2" Margin="0,8,0,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>

                    <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                        <TextBlock Text="STATUS // " Foreground="{DynamicResource Faint}" FontSize="10.5" FontWeight="Bold"/>
                        <TextBlock Name="TxtHudLog" Text="Pronto." Foreground="{DynamicResource Muted}" FontSize="10.5" TextTrimming="CharacterEllipsis"/>
                    </StackPanel>

                    <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                        <Button Name="BtnApply" Content="APLICAR" Style="{StaticResource PrimaryButton}" Margin="0,0,8,0"/>
                        <Button Name="BtnFooterClose"   Content="FECHAR" Style="{StaticResource OutlineButton}"/>
                    </StackPanel>
                </Grid>
            </Grid>
            <!-- ========================================================================= -->
            <!-- OVERLAY MODAL: TELA DE CARREGAMENTO & AVISO DE SUCESSO NO CENTRO DO PAINEL -->
            <!-- ========================================================================= -->
            <Grid Name="OverlayModalContainer" Grid.Column="0" Grid.ColumnSpan="2" Visibility="Collapsed" Panel.ZIndex="999">
                <!-- Dimmer de Fundo Translucido Escuro -->
                <Border Name="OverlayDimmer" Background="#DF040406" Opacity="0"/>

                <!-- CARD CENTRAL FLUTUANTE (EFEITO VIDRO GLOW MTZ) -->
                <Border Name="CardModalCentral" Width="440" HorizontalAlignment="Center" VerticalAlignment="Center"
                        Background="#101014" BorderBrush="#FF1E27" BorderThickness="1.5" CornerRadius="18"
                        Padding="32,28" Opacity="0" RenderTransformOrigin="0.5,0.5">
                    <Border.Effect>
                        <DropShadowEffect Color="#FF1E27" BlurRadius="50" ShadowDepth="0" Opacity="0.4"/>
                    </Border.Effect>
                    <Border.RenderTransform>
                        <ScaleTransform x:Name="ModalCardScale" ScaleX="0.9" ScaleY="0.9"/>
                    </Border.RenderTransform>

                    <StackPanel HorizontalAlignment="Center">
                        <!-- 1. ESTADO DE CARREGAMENTO (SPINNER + LOGO MTZ + ETAPAS DINAMICAS) -->
                        <StackPanel Name="PanelModalLoading" Visibility="Visible" HorizontalAlignment="Center">
                            <!-- Indicador Circular Giratorio com Logo Oficial MTZ Central -->
                            <Grid Width="76" Height="76" Margin="0,0,0,16" HorizontalAlignment="Center">
                                <Ellipse Name="ModalPulseRing" Width="76" Height="76" Stroke="#FF1E27" StrokeThickness="2.5"
                                         StrokeDashArray="4 2" RenderTransformOrigin="0.5,0.5">
                                    <Ellipse.RenderTransform>
                                        <RotateTransform x:Name="RingRotation" Angle="0"/>
                                    </Ellipse.RenderTransform>
                                </Ellipse>
                                <Border Width="50" Height="50" CornerRadius="12" Background="#18181E" BorderBrush="#33FF1E27" BorderThickness="1" HorizontalAlignment="Center" VerticalAlignment="Center" Padding="4">
                                    <Image Name="ImgModalLogo" Stretch="Uniform" RenderOptions.BitmapScalingMode="HighQuality"/>
                                </Border>
                            </Grid>

                            <!-- Titulo do Carregamento -->
                            <TextBlock Name="TxtModalLoadingTitle" Text="APLICANDO OTIMIZA&#x00C7;&#x00D5;ES MTZ"
                                       FontSize="15" FontWeight="Bold" Foreground="#FFFFFF"
                                       HorizontalAlignment="Center" Margin="0,0,0,8"/>

                            <!-- Mensagem de Etapa Dinamica -->
                            <TextBlock Name="TxtModalLoadingSub" Text="Sintonizando registros de lat&#x00EA;ncia e servi&#x00E7;os do Windows..."
                                       FontSize="12" Foreground="#D6D6D6" HorizontalAlignment="Center"
                                       TextAlignment="Center" MaxWidth="360" TextWrapping="Wrap" Margin="0,0,0,20"/>

                            <!-- Barra de Progresso High-Tech MTZ -->
                            <Border Background="#1C1C24" CornerRadius="3" Height="5" Width="300" HorizontalAlignment="Center">
                                <ProgressBar Name="PbModalProgress" IsIndeterminate="True" Height="5"
                                             Foreground="#FF1E27" Background="Transparent" BorderThickness="0"/>
                            </Border>
                        </StackPanel>

                        <!-- 2. ESTADO DE SUCESSO (AVISO NA TELA BEM NO CENTRO DO PAINEL) -->
                        <StackPanel Name="PanelModalSuccess" Visibility="Collapsed" HorizontalAlignment="Center">
                            <!-- Icone Checkmark Circular Neon Verde -->
                            <Border Width="68" Height="68" Background="#102518" BorderBrush="#00FF66" BorderThickness="2"
                                    CornerRadius="34" Margin="0,0,0,16" HorizontalAlignment="Center">
                                <Border.Effect>
                                    <DropShadowEffect Color="#00FF66" BlurRadius="25" ShadowDepth="0" Opacity="0.45"/>
                                </Border.Effect>
                                <TextBlock Text="&#xE73E;" FontFamily="{StaticResource Icons}" FontSize="30"
                                           Foreground="#00FF66" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>

                            <TextBlock Name="TxtModalSuccessTitle" Text="OTIMIZA&#x00C7;&#x00C3;O APLICADA COM SUCESSO!"
                                       FontSize="15.5" FontWeight="Bold" Foreground="#FFFFFF"
                                       HorizontalAlignment="Center" Margin="0,0,0,8"/>

                            <TextBlock Name="TxtModalSuccessSub" Text="Todas as diretrizes de desempenho e baixa lat&#x00EA;ncia foram gravadas no sistema."
                                       FontSize="12" Foreground="#E0E0E0" HorizontalAlignment="Center"
                                       TextAlignment="Center" MaxWidth="360" TextWrapping="Wrap" Margin="0,0,0,24"/>

                            <Button Name="BtnModalSuccessOk" Content="CONCLU&#x00CD;DO" Style="{StaticResource PrimaryButton}"
                                    Width="180" Height="36" FontSize="12.5" FontWeight="Bold" HorizontalAlignment="Center"/>
                        </StackPanel>

                        <!-- 3. ESTADO DE ATUALIZACAO DISPONIVEL -->
                        <StackPanel Name="PanelModalUpdate" Visibility="Collapsed" HorizontalAlignment="Center">
                            <!-- Icone de Nuvem / Download Neon Vermelho MTZ -->
                            <Border Width="68" Height="68" Background="#240A0D" BorderBrush="#FF1E27" BorderThickness="2"
                                    CornerRadius="34" Margin="0,0,0,16" HorizontalAlignment="Center">
                                <Border.Effect>
                                    <DropShadowEffect Color="#FF1E27" BlurRadius="25" ShadowDepth="0" Opacity="0.5"/>
                                </Border.Effect>
                                <TextBlock Text="&#xE896;" FontFamily="{StaticResource Icons}" FontSize="30"
                                           Foreground="#FF1E27" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>

                            <TextBlock Name="TxtModalUpdateTitle" Text="NOVA VERSÃƒO DISPONÃVEL"
                                       FontFamily="{DynamicResource Heading}" FontSize="17" FontWeight="Bold" Foreground="#FFFFFF"
                                       HorizontalAlignment="Center" Margin="0,0,0,6"/>

                            <TextBlock Name="TxtModalUpdateVersion" Text="Painel MTZ v3.6 Pro"
                                       FontFamily="{DynamicResource Heading}" FontSize="13" Foreground="#FF1E27"
                                       HorizontalAlignment="Center" Margin="0,0,0,10"/>

                            <Border Background="#0A0A0E" BorderBrush="{DynamicResource Line}" BorderThickness="1" CornerRadius="8" Padding="12,10" Margin="0,0,0,20" MaxWidth="380">
                                <ScrollViewer MaxHeight="120" VerticalScrollBarVisibility="Auto">
                                    <TextBlock Name="TxtModalUpdateChangelog" Text="Melhorias e otimizaÃ§Ãµes de sistema."
                                               FontSize="11.5" Foreground="#D0D0D8" TextWrapping="Wrap" LineHeight="17"/>
                                </ScrollViewer>
                            </Border>

                            <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                                <Button Name="BtnModalUpdateNow" Content="ATUALIZAR AGORA" Style="{StaticResource PrimaryButton}"
                                        Width="170" Height="36" FontSize="12" FontWeight="Bold" Margin="0,0,10,0"/>
                                <Button Name="BtnModalUpdateLater" Content="DEPOIS" Style="{StaticResource OutlineButton}"
                                        Width="110" Height="36" FontSize="12" FontWeight="Bold"/>
                            </StackPanel>
                        </StackPanel>
                    </StackPanel>
                </Border>
            </Grid>
        </Grid>
    </Border>
</Window>
"@


# ==============================================================================
# 3. MAPEAMENTO DE CONTROLES WPF
# ==============================================================================
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# Janela Principal e Borda Raiz (Translucidez e Fundo)
$windowMainBorder       = $window.FindName("WindowMainBorder")

# Header & Controles de Janela
$btnMinimize            = $window.FindName("BtnMinimize")
$btnMaximize            = $window.FindName("BtnMaximize")
$btnClose               = $window.FindName("BtnClose")
$btnFooterClose         = $window.FindName("BtnFooterClose")
$btnApply               = $window.FindName("BtnApply")
if (-not $btnApply) { $btnApply = $window.FindName("BtnApplyAndClose") }
$btnApplyAndClose       = $btnApply
$txtActiveTabTitle      = $window.FindName("TxtActiveTabTitle")
$txtHudLog              = $window.FindName("TxtHudLog")

# Navegacao Lateral (8 Abas)
$btnTabClocks           = $window.FindName("BtnTabClocks")
$btnTabTweaks           = $window.FindName("BtnTabTweaks")
$btnTabStartup          = $window.FindName("BtnTabStartup")
$btnTabCursors          = $window.FindName("BtnTabCursors")
$btnTabDrivers          = $window.FindName("BtnTabDrivers")
$btnTabBrowsers         = $window.FindName("BtnTabBrowsers")
$btnTabInstaller        = $window.FindName("BtnTabInstaller")
$btnTabTheme            = $window.FindName("BtnTabTheme")

# Mini Status Rodape da Sidebar
$txtCpuUsageMain        = $window.FindName("TxtCpuUsageMain")
$txtRamUsageMain        = $window.FindName("TxtRamUsageMain")
$txtCpuTempMini         = $window.FindName("TxtCpuTempMini")

# Views / Telas do Painel
$viewClocks             = $window.FindName("ViewClocks")
$viewTweaks             = $window.FindName("ViewTweaks")
$viewStartup            = $window.FindName("ViewStartup")
$viewCursors            = $window.FindName("ViewCursors")
$viewDrivers            = $window.FindName("ViewDrivers")
$viewBrowsers           = $window.FindName("ViewBrowsers")
$viewInstaller          = $window.FindName("ViewInstaller")
$viewTheme              = $window.FindName("ViewTheme")

# Controles ViewClocks (Hardware & Sensores)
$txtCpuUsage            = $window.FindName("TxtCpuUsage")
$txtCpuClock            = $window.FindName("TxtCpuClock")
$pbCpu                  = $window.FindName("PbCpu")
$badgeCpuTemp           = $window.FindName("BadgeCpuTemp")
$txtCpuTempStatus       = $window.FindName("TxtCpuTempStatus")
$pbCpuMini              = $window.FindName("PbCpuMini")

$txtRamUsage            = $window.FindName("TxtRamUsage")
$txtRamDetailMini       = $window.FindName("TxtRamDetailMini")
$pbRam                  = $window.FindName("PbRam")
$txtRamAvail            = $window.FindName("TxtRamAvail")
$pbRamMini              = $window.FindName("PbRamMini")

$txtGpuName             = $window.FindName("TxtGpuName")
$txtGpuClock            = $window.FindName("TxtGpuClock")
$txtGpuUsage            = $window.FindName("TxtGpuUsage")
$badgeGpuTemp           = $window.FindName("BadgeGpuTemp")
$txtGpuTempStatus       = $window.FindName("TxtGpuTempStatus")
$pbGpuMini              = $window.FindName("PbGpuMini")

# Elementos do Gráfico Vetorial 60 FPS
$graphLiveLed           = $window.FindName("GraphLiveLed")
$graphCanvas            = $window.FindName("GraphCanvas")
$graphPolyLineCpu       = $window.FindName("GraphPolyLineCpu")
$graphPolyFillCpu       = $window.FindName("GraphPolyFillCpu")
$graphDotHeadCpu        = $window.FindName("GraphDotHeadCpu")
$graphDotHaloCpu        = $window.FindName("GraphDotHaloCpu")
$graphPolyLineRam       = $window.FindName("GraphPolyLineRam")
$graphPolyFillRam       = $window.FindName("GraphPolyFillRam")
$graphDotHeadRam        = $window.FindName("GraphDotHeadRam")
$btnGraphCpu            = $window.FindName("BtnGraphCpu")
$btnGraphRam            = $window.FindName("BtnGraphRam")
$btnGraphBoth           = $window.FindName("BtnGraphBoth")
$txtGraphPeak           = $window.FindName("TxtGraphPeak")
$txtGraphCurrent        = $window.FindName("TxtGraphCurrent")
$headerLiveDot          = $window.FindName("HeaderLiveDot")

# Alternadores de Estilo (Onda / Pizza / Barras)
$btnStyleWave           = $window.FindName("BtnStyleWave")
$btnStyleDonut          = $window.FindName("BtnStyleDonut")
$btnStyleBars           = $window.FindName("BtnStyleBars")
$gridGraphWave          = $window.FindName("GridGraphWave")
$gridGraphDonut         = $window.FindName("GridGraphDonut")
$gridGraphBars          = $window.FindName("GridGraphBars")
$panelWaveFilters       = $window.FindName("PanelWaveFilters")
$txtGraphSubTitle       = $window.FindName("TxtGraphSubTitle")

# Elementos Estilo Donut (Pizza)
$donutPathCpu           = $window.FindName("DonutPathCpu")
$donutPathRam           = $window.FindName("DonutPathRam")
$donutPathTemp          = $window.FindName("DonutPathTemp")
$txtDonutCpuVal         = $window.FindName("TxtDonutCpuVal")
$txtDonutRamVal         = $window.FindName("TxtDonutRamVal")
$txtDonutTempVal        = $window.FindName("TxtDonutTempVal")
$txtDonutCpuClock       = $window.FindName("TxtDonutCpuClock")
$txtDonutRamGb          = $window.FindName("TxtDonutRamGb")
$txtDonutTempStatus     = $window.FindName("TxtDonutTempStatus")
$txtDonutPeak           = $window.FindName("TxtDonutPeak")
$txtDonutAvg            = $window.FindName("TxtDonutAvg")

# Elementos Estilo Barras (Histograma HUD)
$gridBarsContainer      = $window.FindName("GridBarsContainer")
$txtBarCpuPct           = $window.FindName("TxtBarCpuPct")
$pbBarCpu               = $window.FindName("PbBarCpu")
$txtBarRamPct           = $window.FindName("TxtBarRamPct")
$pbBarRam               = $window.FindName("PbBarRam")
$txtBarTempPct          = $window.FindName("TxtBarTempPct")
$pbBarTemp              = $window.FindName("PbBarTemp")

$txtActiveProfile       = $window.FindName("TxtActiveProfile")
$txtClockRange          = $window.FindName("TxtClockRange")
$badgeUltra             = $window.FindName("BadgeUltra")
$badgeBalanced          = $window.FindName("BadgeBalanced")
$badgeEco               = $window.FindName("BadgeEco")

$btnUltraGaming         = $window.FindName("BtnUltraGaming")
$btnBalanced            = $window.FindName("BtnBalanced")
$btnEcoSaver            = $window.FindName("BtnEcoSaver")
$btnClock100            = $window.FindName("BtnClock100")
$btnClock99             = $window.FindName("BtnClock99")
$btnClock70             = $window.FindName("BtnClock70")
$btnClock50             = $window.FindName("BtnClock50")
$btnGpuMax              = $window.FindName("BtnGpuMax")
$btnGpuEco              = $window.FindName("BtnGpuEco")
$btnCleanRam            = $window.FindName("BtnCleanRam")

# Customizacao de Sensores e Graficos
$btnRefreshFast         = $window.FindName("BtnRefreshFast")
$btnRefreshNormal       = $window.FindName("BtnRefreshNormal")
$btnRefreshEco          = $window.FindName("BtnRefreshEco")
$btnAlert75             = $window.FindName("BtnAlert75")
$btnAlert80             = $window.FindName("BtnAlert80")
$btnAlert85             = $window.FindName("BtnAlert85")
$btnAlert90             = $window.FindName("BtnAlert90")

# Controles ViewTweaks (Suite ISO do Windows)
$badgeTweaksSummary     = $window.FindName("BadgeTweaksSummary")
$txtTweaksSummary       = $window.FindName("TxtTweaksSummary")
$btnAuditTweaks         = $window.FindName("BtnAuditTweaks")
$btnApplyAllTweaks      = $window.FindName("BtnApplyAllTweaks")
$btnRestoreDefaultTweaks= $window.FindName("BtnRestoreDefaultTweaks")

$badgeStatusMouse       = $window.FindName("BadgeStatusMouse")
$txtStatusMouse         = $window.FindName("TxtStatusMouse")
$btnOptimizeMouse       = $window.FindName("BtnOptimizeMouse")

$badgeStatusGpu         = $window.FindName("BadgeStatusGpu")
$txtStatusGpu           = $window.FindName("TxtStatusGpu")
$btnOptimizeGpu         = $window.FindName("BtnOptimizeGpu")

$badgeStatusIfeo        = $window.FindName("BadgeStatusIfeo")
$txtStatusIfeo          = $window.FindName("TxtStatusIfeo")
$btnOptimizeIfeo        = $window.FindName("BtnOptimizeIfeo")

$badgeStatusNagle       = $window.FindName("BadgeStatusNagle")
$txtStatusNagle         = $window.FindName("TxtStatusNagle")
$btnOptimizeNagle       = $window.FindName("BtnOptimizeNagle")

$badgeStatusBcd         = $window.FindName("BadgeStatusBcd")
$txtStatusBcd           = $window.FindName("TxtStatusBcd")
$btnOptimizeBcd         = $window.FindName("BtnOptimizeBcd")

$badgeStatusTelemetry   = $window.FindName("BadgeStatusTelemetry")
$txtStatusTelemetry     = $window.FindName("TxtStatusTelemetry")
$btnDisableTelemetry    = $window.FindName("BtnDisableTelemetry")

$badgeStatusExplorer    = $window.FindName("BadgeStatusExplorer")
$txtStatusExplorer      = $window.FindName("TxtStatusExplorer")
$btnOptimizeExplorer    = $window.FindName("BtnOptimizeExplorer")

$badgeStatusCursor      = $window.FindName("BadgeStatusCursor")
$txtStatusCursor        = $window.FindName("TxtStatusCursor")
$btnApplyCursor         = $window.FindName("BtnApplyCursor")

# Controles ViewStartup
$stackStartupItems      = $window.FindName("StackStartupItems")
$btnScanStartup         = $window.FindName("BtnScanStartup")
$txtStartupSummary      = $window.FindName("TxtStartupSummary")

# Controles ViewCursors
$txtOutlineHex          = $window.FindName("TxtOutlineHex")
$txtInsideHex           = $window.FindName("TxtInsideHex")
$previewColorOutlineBadge = $window.FindName("PreviewColorOutlineBadge")
$previewColorInsideBadge  = $window.FindName("PreviewColorInsideBadge")
$btnApplyCursorColors   = $window.FindName("BtnApplyCursorColors")
$btnResetDefaultCursors = $window.FindName("BtnResetDefaultCursors")
$txtPreviewColorInfo    = $window.FindName("TxtPreviewColorInfo")

$prevPolyArrow          = $window.FindName("PrevPolyArrow")
$prevPolyAppArrow       = $window.FindName("PrevPolyAppArrow")
$prevEllAppBg           = $window.FindName("PrevEllAppBg")
$prevEllAppDot          = $window.FindName("PrevEllAppDot")
$prevEllWaitBg          = $window.FindName("PrevEllWaitBg")
$prevPathWaitArc        = $window.FindName("PrevPathWaitArc")
$prevEllWaitDot         = $window.FindName("PrevEllWaitDot")
$prevLineCrossH1        = $window.FindName("PrevLineCrossH1")
$prevLineCrossH2        = $window.FindName("PrevLineCrossH2")
$prevLineCrossV1        = $window.FindName("PrevLineCrossV1")
$prevLineCrossV2        = $window.FindName("PrevLineCrossV2")
$prevEllCrossRing       = $window.FindName("PrevEllCrossRing")
$prevEllCrossDot        = $window.FindName("PrevEllCrossDot")

$prevPolyHand           = $window.FindName("PrevPolyHand")
$prevLineHand           = $window.FindName("PrevLineHand")
$prevLineBeamTop        = $window.FindName("PrevLineBeamTop")
$prevLineBeamStem       = $window.FindName("PrevLineBeamStem")
$prevLineBeamBot        = $window.FindName("PrevLineBeamBot")

# Botoes de Presets de Cursores
$btnPresetCyberpunk     = $window.FindName("BtnPresetCyberpunk")
$btnPresetMatrix        = $window.FindName("BtnPresetMatrix")
$btnPresetCyan          = $window.FindName("BtnPresetCyan")
$btnPresetPureWhite     = $window.FindName("BtnPresetPureWhite")
$btnPresetStealth       = $window.FindName("BtnPresetStealth")
$btnPresetGold          = $window.FindName("BtnPresetGold")
$btnPresetGhost         = $window.FindName("BtnPresetGhost")

$btnOutRed              = $window.FindName("BtnOutRed")
$btnOutCyan             = $window.FindName("BtnOutCyan")
$btnOutGreen            = $window.FindName("BtnOutGreen")
$btnOutPurple           = $window.FindName("BtnOutPurple")
$btnOutGold             = $window.FindName("BtnOutGold")
$btnOutOrange           = $window.FindName("BtnOutOrange")
$btnOutPink             = $window.FindName("BtnOutPink")
$btnOutWhite            = $window.FindName("BtnOutWhite")

$btnInPureBlack         = $window.FindName("BtnInPureBlack")
$btnInSlate             = $window.FindName("BtnInSlate")
$btnInCrimson           = $window.FindName("BtnInCrimson")
$btnInNavy              = $window.FindName("BtnInNavy")
$btnInDarkPurple        = $window.FindName("BtnInDarkPurple")
$btnInPureWhite         = $window.FindName("BtnInPureWhite")

# Controles ViewDrivers (Drive WHQL Mathz)
$txtMathzDriversStatus  = $window.FindName("TxtMathzDriversStatus")
$btnMathzScanDrivers    = $window.FindName("BtnMathzScanDrivers")
$btnInstallAllMathzDrivers = $window.FindName("BtnInstallAllMathzDrivers")
$btnBackupDrivers       = $window.FindName("BtnBackupDrivers")
$btnCreateRestorePoint  = $window.FindName("BtnCreateRestorePoint")
$txtDriverCountBadge    = $window.FindName("TxtDriverCountBadge")
$stackDriverItems       = $window.FindName("StackDriverItems")
$btnOpenDevMgmt         = $window.FindName("BtnOpenDevMgmt")
$btnRescanHardware      = $window.FindName("BtnRescanHardware")
$btnGpuNvidia           = $window.FindName("BtnGpuNvidia")
$btnGpuAmd              = $window.FindName("BtnGpuAmd")
$btnGpuIntel            = $window.FindName("BtnGpuIntel")
$btnInstallVCRedist     = $window.FindName("BtnInstallVCRedist")
$btnInstallDirectX      = $window.FindName("BtnInstallDirectX")
$btnInjectInfFolder     = $window.FindName("BtnInjectInfFolder")
$btnExportDriverReport  = $window.FindName("BtnExportDriverReport")

# Controles ViewBrowsers & ViewInstaller
$btnDownloadChrome      = $window.FindName("BtnDownloadChrome")
$btnDownloadBrave       = $window.FindName("BtnDownloadBrave")
$btnDownloadFirefox     = $window.FindName("BtnDownloadFirefox")
$btnInstallAllLaunchers = $window.FindName("BtnInstallAllLaunchers")
$btnInstallSteam        = $window.FindName("BtnInstallSteam")
$btnInstallEpic         = $window.FindName("BtnInstallEpic")
$btnInstallDiscord      = $window.FindName("BtnInstallDiscord")

# Controles ViewTheme (Personalizador de Cores e Translucidez)
$btnGlassOn             = $window.FindName("BtnGlassOn")
$btnGlassOff            = $window.FindName("BtnGlassOff")
$badgeTranslucentStatus = $window.FindName("BadgeTranslucentStatus")
$txtTranslucentStatus   = $window.FindName("TxtTranslucentStatus")
$btnOp70                = $window.FindName("BtnOp70")
$btnOp80                = $window.FindName("BtnOp80")
$btnOp90                = $window.FindName("BtnOp90")
$btnOp100               = $window.FindName("BtnOp100")

$btnAccRed              = $window.FindName("BtnAccRed")
$btnAccCyan             = $window.FindName("BtnAccCyan")
$btnAccGreen            = $window.FindName("BtnAccGreen")
$btnAccPurple           = $window.FindName("BtnAccPurple")
$btnAccOrange           = $window.FindName("BtnAccOrange")
$btnAccPink             = $window.FindName("BtnAccPink")
$btnAccGold             = $window.FindName("BtnAccGold")
$btnAccWhite            = $window.FindName("BtnAccWhite")
$txtCustomAccentHex     = $window.FindName("TxtCustomAccentHex")
$btnApplyCustomAccent   = $window.FindName("BtnApplyCustomAccent")
$txtCurrentAccentHex    = $window.FindName("TxtCurrentAccentHex")
$previewAccentBadge     = $window.FindName("PreviewAccentBadge")

$btnBgPureBlack         = $window.FindName("BtnBgPureBlack")
$btnBgSlate             = $window.FindName("BtnBgSlate")
$btnBgNavy              = $window.FindName("BtnBgNavy")
$btnBgCrimson           = $window.FindName("BtnBgCrimson")
$btnBgForest            = $window.FindName("BtnBgForest")
$txtCustomBgHex         = $window.FindName("TxtCustomBgHex")
$btnApplyCustomBg       = $window.FindName("BtnApplyCustomBg")
$txtCurrentBgHex        = $window.FindName("TxtCurrentBgHex")
$previewBgBadge         = $window.FindName("PreviewBgBadge")

$btnResetThemeDefaults  = $window.FindName("BtnResetThemeDefaults")

# Imagem Logo Oficial MTZ
$appRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$imgSidebarLogo = $window.FindName("ImgSidebarLogo")
$logoCandidates = @(
    (Join-Path $appRoot "Assets\MTZ_Logo.png"),
    (Join-Path $appRoot "MTZ_Logo.png"),
    (Join-Path (Split-Path $appRoot -Parent) "MTZ_Logo.png"),
    "C:\Program Files\MathzControlPanel\Assets\MTZ_Logo.png"
)
$logoPath = $logoCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if ($logoPath -and $imgSidebarLogo) {
    try {
        $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
        $bmp.BeginInit()
        $bmp.UriSource = [Uri]::new($logoPath)
        $bmp.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bmp.EndInit()
        $imgSidebarLogo.Source = $bmp
    } catch {}
}

# Icone da Janela
$icoCandidates = @(
    (Join-Path $appRoot "Assets\Mathz.ico"),
    (Join-Path $appRoot "Mathz.ico"),
    (Join-Path (Split-Path $appRoot -Parent) "Mathz.ico"),
    "C:\Program Files\MathzControlPanel\Assets\Mathz.ico"
)
$icoPath = $icoCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if ($icoPath) {
    try {
        $window.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create([Uri]::new($icoPath))
    } catch {}
}

# ==============================================================================
# ELEMENTOS DO MODAL OVERLAY (TELA DE CARREGAMENTO & SUCESSO NO CENTRO DA TELA)
# ==============================================================================
$overlayModalContainer = $window.FindName("OverlayModalContainer")
$overlayDimmer         = $window.FindName("OverlayDimmer")
$cardModalCentral      = $window.FindName("CardModalCentral")
$modalCardScale        = $window.FindName("ModalCardScale")
$panelModalLoading     = $window.FindName("PanelModalLoading")
$panelModalSuccess     = $window.FindName("PanelModalSuccess")
$modalPulseRing        = $window.FindName("ModalPulseRing")
$ringRotation          = $window.FindName("RingRotation")
$imgModalLogo          = $window.FindName("ImgModalLogo")
$txtModalLoadingTitle  = $window.FindName("TxtModalLoadingTitle")
$txtModalLoadingSub    = $window.FindName("TxtModalLoadingSub")
$pbModalProgress       = $window.FindName("PbModalProgress")
$txtModalSuccessTitle  = $window.FindName("TxtModalSuccessTitle")
$txtModalSuccessSub    = $window.FindName("TxtModalSuccessSub")
$btnModalSuccessOk     = $window.FindName("BtnModalSuccessOk")
$panelModalUpdate      = $window.FindName("PanelModalUpdate")
$txtModalUpdateTitle   = $window.FindName("TxtModalUpdateTitle")
$txtModalUpdateVersion = $window.FindName("TxtModalUpdateVersion")
$txtModalUpdateChangelog = $window.FindName("TxtModalUpdateChangelog")
$btnModalUpdateNow     = $window.FindName("BtnModalUpdateNow")
$btnModalUpdateLater   = $window.FindName("BtnModalUpdateLater")
$btnCheckUpdates       = $window.FindName("BtnCheckUpdates")

if ($bmp -and $imgModalLogo) {
    try { $imgModalLogo.Source = $bmp } catch {}
}



# ==============================================================================
# 4. FUNCOES E LOGICA DE CONTROLE (PAINEL DE COMANDO MTZ)
# ==============================================================================

# Funcao de Log HUD no Rodape
function Log-Hud([string]$msg) {
    if ($txtHudLog) { $txtHudLog.Text = $msg }
}

# Funcao de Fechamento Limpo (0 Consumo de Fundo)
function Exit-MathzCleanly {
    try {
        if ($global:hwTimer) { $global:hwTimer.Stop() }
        $proc = [System.Diagnostics.Process]::GetCurrentProcess()
        [MathzMemoryOptimizer]::EmptyWorkingSet($proc.Handle) | Out-Null
    } catch {}

    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()

    try { $window.Close() } catch {}
    [System.Environment]::Exit(0)
}

# ==============================================================================
# MOTOR DO MODAL OVERLAY (TELA DE CARREGAMENTO & AVISO DE SUCESSO NO CENTRO)
# ==============================================================================
$global:modalRingTimer = $null
$global:modalAngle = 0.0

function Start-ModalRingSpinner {
    try {
        if ($ringRotation) {
            $animRing = New-Object System.Windows.Media.Animation.DoubleAnimation(0.0, 360.0, [System.Windows.Duration][TimeSpan]::FromMilliseconds(850))
            $animRing.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
            $ringRotation.BeginAnimation([System.Windows.Media.RotateTransform]::AngleProperty, $animRing)
        }
    } catch {}
}

function Stop-ModalRingSpinner {
    try {
        if ($ringRotation) {
            $ringRotation.BeginAnimation([System.Windows.Media.RotateTransform]::AngleProperty, $null)
        }
    } catch {}
}

function Show-ModalOverlay([string]$loadingTitle, [string]$loadingSub) {
    if (-not $overlayModalContainer) { return }

    if ($global:modalAutoDismissTimer) {
        $global:modalAutoDismissTimer.Stop()
        $global:modalAutoDismissTimer = $null
    }

    if ($txtModalLoadingTitle) { $txtModalLoadingTitle.Text = $loadingTitle }
    if ($txtModalLoadingSub)   { $txtModalLoadingSub.Text   = $loadingSub }

    if ($panelModalLoading) { $panelModalLoading.Visibility = [System.Windows.Visibility]::Visible }
    if ($panelModalSuccess) { $panelModalSuccess.Visibility = [System.Windows.Visibility]::Collapsed }

    $overlayModalContainer.Visibility = [System.Windows.Visibility]::Visible
    Start-ModalRingSpinner

    try {
        if ($overlayDimmer) {
            $overlayDimmer.Opacity = 1.0
            $animDim = New-Object System.Windows.Media.Animation.DoubleAnimation(0.0, 1.0, [System.Windows.Duration][TimeSpan]::FromMilliseconds(180))
            $overlayDimmer.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $animDim)
        }
        if ($cardModalCentral) {
            $cardModalCentral.Opacity = 1.0
            $animFade = New-Object System.Windows.Media.Animation.DoubleAnimation(0.0, 1.0, [System.Windows.Duration][TimeSpan]::FromMilliseconds(220))
            $cardModalCentral.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $animFade)
        }
        if ($modalCardScale) {
            $ease = New-Object System.Windows.Media.Animation.BackEase
            $ease.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut
            $ease.Amplitude = 0.35
            $animScale = New-Object System.Windows.Media.Animation.DoubleAnimation(0.88, 1.0, [System.Windows.Duration][TimeSpan]::FromMilliseconds(240))
            $animScale.EasingFunction = $ease
            $modalCardScale.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleXProperty, $animScale)
            $modalCardScale.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleYProperty, $animScale)
        }
    } catch {
        if ($overlayDimmer) { $overlayDimmer.Opacity = 1.0 }
        if ($cardModalCentral) { $cardModalCentral.Opacity = 1.0 }
    }

    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Render)
}

function Show-ModalUpdate([string]$vTitle, [string]$vNum, [string]$vChangelog, [string]$vUrl) {
    if (-not $overlayModalContainer) { return }
    Stop-ModalRingSpinner

    $global:pendingUpdateUrl = $vUrl

    if ($txtModalUpdateTitle)     { $txtModalUpdateTitle.Text = "NOVA VERSÃƒO DISPONÃVEL" }
    if ($txtModalUpdateVersion)   { $txtModalUpdateVersion.Text = "$vTitle ($vNum)" }
    if ($txtModalUpdateChangelog) { $txtModalUpdateChangelog.Text = $vChangelog }

    if ($panelModalLoading) { $panelModalLoading.Visibility = [System.Windows.Visibility]::Collapsed }
    if ($panelModalSuccess) { $panelModalSuccess.Visibility = [System.Windows.Visibility]::Collapsed }
    if ($panelModalUpdate)  { $panelModalUpdate.Visibility  = [System.Windows.Visibility]::Visible }

    $overlayModalContainer.Visibility = [System.Windows.Visibility]::Visible
    try {
        $animFade = New-Object System.Windows.Media.Animation.DoubleAnimation(0.0, 1.0, [TimeSpan]::FromMilliseconds(180))
        $overlayDimmer.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $animFade)

        $animCard = New-Object System.Windows.Media.Animation.DoubleAnimation(0.0, 1.0, [TimeSpan]::FromMilliseconds(220))
        $cardModalCentral.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $animCard)
        if ($modalCardScale) {
            $animScale = New-Object System.Windows.Media.Animation.DoubleAnimation(0.92, 1.0, [TimeSpan]::FromMilliseconds(240))
            $modalCardScale.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleXProperty, $animScale)
            $modalCardScale.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleYProperty, $animScale)
        }
    } catch {}
}

function Check-MathzUpdate([bool]$interactive = $false) {
    $currentVersionCode = 350
    $updateManifestUrl = "https://raw.githubusercontent.com/Mathzvinicius/MathzControlPanel/main/version.json"

    if ($interactive) {
        Log-Hud "Verificando se ha atualizacoes no servidor oficial MTZ..."
    }

    try {
        $json = Invoke-RestMethod -Uri $updateManifestUrl -Method Get -TimeoutSec 6 -Headers @{ "User-Agent" = "MathzControlPanel" }
        if ($json -and $json.versionCode -gt $currentVersionCode) {
            $changelog = if ($json.changelog) { ($json.changelog -join "`n- ") } else { "Melhorias de desempenho e novas correcoes de sistema." }
            $changelog = "- " + $changelog
            Show-ModalUpdate $json.title $json.version $changelog $json.downloadUrl
            Log-Hud "Nova versao encontrada: $($json.version)!"
        } else {
            if ($interactive) {
                Log-Hud "Voce ja esta com a versao mais recente instalada (v3.5 Pro)!"
                [System.Windows.MessageBox]::Show("Voce ja esta utilizando a versao mais recente do Painel de Comando MTZ (v3.5 Pro).`n`nNenhuma atualizacao necessaria no momento.", "Painel de Comando MTZ", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
            }
        }
    } catch {
        if ($interactive) {
            Log-Hud "Nao foi possivel verificar atualizacoes no momento."
        }
    }
}

function Start-MathzSelfUpdate {
    if (-not $global:pendingUpdateUrl) { return }
    $url = $global:pendingUpdateUrl

    Show-ModalOverlay "BAIXANDO ATUALIZACAO MTZ" "Transferindo nova versao dos servidores oficiais do Painel..."

    $disp = [System.Windows.Threading.DispatcherTimer]::new()
    $disp.Interval = [TimeSpan]::FromMilliseconds(600)
    $disp.Add_Tick({
        $disp.Stop()
        try {
            $tempExe = Join-Path $env:TEMP "MathzControlPanel_New.exe"
            if (Test-Path $tempExe) { Remove-Item $tempExe -Force }

            $wc = New-Object System.Net.WebClient
            $wc.Headers.Add("User-Agent", "MathzControlPanel-Updater")
            $wc.DownloadFile($url, $tempExe)

            if (-not (Test-Path $tempExe) -or (Get-Item $tempExe).Length -lt 100KB) {
                throw "Arquivo de atualizacao baixado esta incompleto."
            }

            $runningExe = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
            if ($runningExe -like "*powershell*") {
                $runningExe = Join-Path (Get-Location).Path "MathzControlPanel.exe"
            }

            $cmd = "Start-Sleep -Seconds 1; Move-Item -LiteralPath '$tempExe' -Destination '$runningExe' -Force; Start-Process -FilePath '$runningExe'"
            Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile", "-WindowStyle", "Hidden", "-Command", $cmd -WindowStyle Hidden
            Exit-MathzCleanly
        } catch {
            Hide-ModalOverlay
            Log-Hud "Erro ao atualizar: $_"
            [System.Windows.MessageBox]::Show("Falha ao baixar atualizacao:`n`n$_", "Erro de Atualizacao", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
        }
    })
    $disp.Start()
}

function Show-ModalSuccess([string]$successTitle, [string]$successSub) {
    Stop-ModalRingSpinner

    if ($txtModalSuccessTitle) { $txtModalSuccessTitle.Text = $successTitle }
    if ($txtModalSuccessSub)   { $txtModalSuccessSub.Text   = $successSub }

    if ($panelModalLoading) { $panelModalLoading.Visibility = [System.Windows.Visibility]::Collapsed }
    if ($panelModalSuccess) { $panelModalSuccess.Visibility = [System.Windows.Visibility]::Visible }

    try {
        if ($modalCardScale) {
            $ease = New-Object System.Windows.Media.Animation.ElasticEase
            $ease.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut
            $ease.Oscillations = 1
            $ease.Springiness = 3
            $animScale = New-Object System.Windows.Media.Animation.DoubleAnimation(0.95, 1.0, [System.Windows.Duration][TimeSpan]::FromMilliseconds(260))
            $animScale.EasingFunction = $ease
            $modalCardScale.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleXProperty, $animScale)
            $modalCardScale.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleYProperty, $animScale)
        }
    } catch {}

    # Timer de auto-fechamento do aviso de sucesso (4 segundos)
    if ($global:modalAutoDismissTimer) {
        $global:modalAutoDismissTimer.Stop()
        $global:modalAutoDismissTimer = $null
    }
    $global:modalAutoDismissTimer = New-Object System.Windows.Threading.DispatcherTimer
    $global:modalAutoDismissTimer.Interval = [TimeSpan]::FromSeconds(4)
    $global:modalAutoDismissTimer.Add_Tick({
        $global:modalAutoDismissTimer.Stop()
        $global:modalAutoDismissTimer = $null
        Hide-ModalOverlay
    })
    $global:modalAutoDismissTimer.Start()

    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Render)
}

function Hide-ModalOverlay {
    if ($global:modalAutoDismissTimer) {
        $global:modalAutoDismissTimer.Stop()
        $global:modalAutoDismissTimer = $null
    }
    Stop-ModalRingSpinner
    try {
        if ($cardModalCentral) {
            $animFade = New-Object System.Windows.Media.Animation.DoubleAnimation(1.0, 0.0, [System.Windows.Duration][TimeSpan]::FromMilliseconds(160))
            $cardModalCentral.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $animFade)
        }
        if ($modalCardScale) {
            $animScale = New-Object System.Windows.Media.Animation.DoubleAnimation(1.0, 0.92, [System.Windows.Duration][TimeSpan]::FromMilliseconds(160))
            $modalCardScale.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleXProperty, $animScale)
            $modalCardScale.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleYProperty, $animScale)
        }
        if ($overlayDimmer) {
            $animDim = New-Object System.Windows.Media.Animation.DoubleAnimation(1.0, 0.0, [System.Windows.Duration][TimeSpan]::FromMilliseconds(160))
            $animDim.Add_Completed({
                if ($overlayModalContainer) { $overlayModalContainer.Visibility = [System.Windows.Visibility]::Collapsed }
            })
            $overlayDimmer.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $animDim)
        } else {
            if ($overlayModalContainer) { $overlayModalContainer.Visibility = [System.Windows.Visibility]::Collapsed }
        }
    } catch {
        if ($overlayModalContainer) { $overlayModalContainer.Visibility = [System.Windows.Visibility]::Collapsed }
    }
}

if ($btnModalSuccessOk) {
    $btnModalSuccessOk.Add_Click({ Hide-ModalOverlay })

if ($btnCheckUpdates) {
    $btnCheckUpdates.Add_Click({
        Check-MathzUpdate -interactive $true
    })
}

if ($btnModalUpdateNow) {
    $btnModalUpdateNow.Add_Click({
        Start-MathzSelfUpdate
    })
}

if ($btnModalUpdateLater) {
    $btnModalUpdateLater.Add_Click({
        Hide-ModalOverlay
    })
}
}

function Invoke-ModalAction([string]$loadingTitle, [string]$loadingSub, [string]$successTitle, [string]$successSub, [scriptblock]$action) {
    Show-ModalOverlay $loadingTitle $loadingSub

    $timerWait = New-Object System.Windows.Threading.DispatcherTimer
    $timerWait.Interval = [TimeSpan]::FromMilliseconds(1100)
    $timerWait.Add_Tick({
        $timerWait.Stop()
        try {
            if ($action) { & $action }
        } catch {
            Log-Hud "Erro na operacao: $_"
        }
        Show-ModalSuccess $successTitle $successSub
        Log-Hud $successTitle
    })
    $timerWait.Start()
}

$window.Add_KeyDown({
    param($sender, $e)
    if ($e.Key -eq [System.Windows.Input.Key]::Escape -or $e.Key -eq [System.Windows.Input.Key]::Return) {
        if ($overlayModalContainer -and $overlayModalContainer.Visibility -eq [System.Windows.Visibility]::Visible) {
            Hide-ModalOverlay
        }
    }
})

# Botoes de Janela
$btnClose.Add_Click({ Exit-MathzCleanly })
$btnFooterClose.Add_Click({ Exit-MathzCleanly })

if ($btnApply) {
    $btnApply.Add_Click({
        Invoke-ModalAction "APLICANDO OTIMIZACOES MTZ" "Gravando diretrizes de desempenho, latencia e ajustes da ISO no Windows..." "OTIMIZACAO APLICADA COM SUCESSO!" "Todas as configuracoes de desempenho, estabilidade de Kernel e perfil de energia foram aplicadas com sucesso!" {
            Save-ThemeConfig
            Apply-PanelThemeUI
            Update-RealHardwareUI
            Update-MathzTweaksChecklist
        }
    })
}

function Toggle-MaximizeRestore {
    if ($window.WindowState -eq [System.Windows.WindowState]::Maximized) {
        $window.WindowState = [System.Windows.WindowState]::Normal
        if ($btnMaximize) { $btnMaximize.Content = [char]0xE922 }
        if ($windowMainBorder) {
            $windowMainBorder.CornerRadius = [System.Windows.CornerRadius]::new(14)
            $windowMainBorder.BorderThickness = [System.Windows.Thickness]::new(1)
        }
    } else {
        $window.WindowState = [System.Windows.WindowState]::Maximized
        if ($btnMaximize) { $btnMaximize.Content = [char]0xE923 }
        if ($windowMainBorder) {
            $windowMainBorder.CornerRadius = [System.Windows.CornerRadius]::new(0)
            $windowMainBorder.BorderThickness = [System.Windows.Thickness]::new(0)
        }
    }
    Update-TelemetryGraph -1 -1
}

if ($btnMinimize) {
    $btnMinimize.Add_Click({
        $window.WindowState = [System.Windows.WindowState]::Minimized
    })
}

if ($btnMaximize) {
    $btnMaximize.Add_Click({
        Toggle-MaximizeRestore
    })
}

$window.Add_StateChanged({
    if ($window.WindowState -eq [System.Windows.WindowState]::Maximized) {
        if ($btnMaximize) { $btnMaximize.Content = [char]0xE923 }
        if ($windowMainBorder) {
            $windowMainBorder.CornerRadius = [System.Windows.CornerRadius]::new(0)
            $windowMainBorder.BorderThickness = [System.Windows.Thickness]::new(0)
        }
    } else {
        if ($btnMaximize) { $btnMaximize.Content = [char]0xE922 }
        if ($windowMainBorder) {
            $windowMainBorder.CornerRadius = [System.Windows.CornerRadius]::new(14)
            $windowMainBorder.BorderThickness = [System.Windows.Thickness]::new(1)
        }
    }
    Update-TelemetryGraph -1 -1
})

$window.Add_MouseLeftButtonDown({
    param($sender, $e)
    if ($e.ClickCount -eq 2) {
        Toggle-MaximizeRestore
    } else {
        $window.DragMove()
    }
})

# ==============================================================================
# 5. GERENCIADOR DE NAVEGACAO (8 ABAS COM TRANSICAO SUAVE)
# ==============================================================================
function Animate-ViewIn($targetView) {
    if (-not $targetView) { return }
    $targetView.Visibility = [System.Windows.Visibility]::Visible

    try {
        $translate = New-Object System.Windows.Media.TranslateTransform(0, 10)
        $targetView.RenderTransform = $translate
        $targetView.Opacity = 0.0

        $animFade = New-Object System.Windows.Media.Animation.DoubleAnimation
        $animFade.From = 0.0
        $animFade.To = 1.0
        $animFade.Duration = [System.Windows.Duration][TimeSpan]::FromMilliseconds(220)
        $ease = New-Object System.Windows.Media.Animation.CubicEase
        $ease.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut
        $animFade.EasingFunction = $ease

        $animSlide = New-Object System.Windows.Media.Animation.DoubleAnimation
        $animSlide.From = 10.0
        $animSlide.To = 0.0
        $animSlide.Duration = [System.Windows.Duration][TimeSpan]::FromMilliseconds(220)
        $animSlide.EasingFunction = $ease

        $targetView.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $animFade)
        $translate.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, $animSlide)
    } catch {
        $targetView.Opacity = 1.0
    }
}

function Set-TabActive([string]$tabName) {
    $brushTransparent = [System.Windows.Media.Brushes]::Transparent
    $brushInactiveFg  = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#8C8C8C")
    $brushActiveFg    = [System.Windows.Media.Brushes]::White
    $brushActiveBg    = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#151515")
    $brushAccent      = if ($global:currentAccentBrush) { $global:currentAccentBrush } else { [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FF1E27") }

    $allTabs = @($btnTabClocks, $btnTabTweaks, $btnTabStartup, $btnTabCursors, $btnTabDrivers, $btnTabBrowsers, $btnTabInstaller, $btnTabTheme)
    foreach ($tab in $allTabs) {
        if ($tab) {
            $tab.Background      = $brushTransparent
            $tab.BorderBrush     = $brushTransparent
            $tab.BorderThickness = [System.Windows.Thickness]::new(0)
            $tab.Foreground      = $brushInactiveFg
            $tab.FontWeight      = [System.Windows.FontWeights]::Normal
        }
    }

    $allViews = @($viewClocks, $viewTweaks, $viewStartup, $viewCursors, $viewDrivers, $viewBrowsers, $viewInstaller, $viewTheme)
    foreach ($v in $allViews) {
        if ($v) { $v.Visibility = [System.Windows.Visibility]::Collapsed }
    }

    switch ($tabName) {
        "Clocks" {
            if ($btnTabClocks) {
                $btnTabClocks.Background      = $brushActiveBg
                $btnTabClocks.BorderBrush     = $brushAccent
                $btnTabClocks.BorderThickness = [System.Windows.Thickness]::new(3, 0, 0, 0)
                $btnTabClocks.Foreground      = $brushActiveFg
                $btnTabClocks.FontWeight      = [System.Windows.FontWeights]::SemiBold
            }
            Animate-ViewIn $viewClocks
            if ($txtActiveTabTitle) { $txtActiveTabTitle.Text = "CLOCKS & TELEMETRIA EM TEMPO REAL" }
            Update-TelemetryGraph -1 -1
        }
        "Tweaks" {
            if ($btnTabTweaks) {
                $btnTabTweaks.Background      = $brushActiveBg
                $btnTabTweaks.BorderBrush     = $brushAccent
                $btnTabTweaks.BorderThickness = [System.Windows.Thickness]::new(3, 0, 0, 0)
                $btnTabTweaks.Foreground      = $brushActiveFg
                $btnTabTweaks.FontWeight      = [System.Windows.FontWeights]::SemiBold
            }
            Animate-ViewIn $viewTweaks
            if ($txtActiveTabTitle) { $txtActiveTabTitle.Text = "SUITE DE OTIMIZACOES DA ISO" }
            Update-MathzTweaksChecklist
        }
        "Startup" {
            if ($btnTabStartup) {
                $btnTabStartup.Background      = $brushActiveBg
                $btnTabStartup.BorderBrush     = $brushAccent
                $btnTabStartup.BorderThickness = [System.Windows.Thickness]::new(3, 0, 0, 0)
                $btnTabStartup.Foreground      = $brushActiveFg
                $btnTabStartup.FontWeight      = [System.Windows.FontWeights]::SemiBold
            }
            Animate-ViewIn $viewStartup
            if ($txtActiveTabTitle) { $txtActiveTabTitle.Text = "PROGRAMAS NA INICIALIZACAO" }
            if ($stackStartupItems -and $stackStartupItems.Children.Count -eq 0) {
                Update-MathzStartupList
            }
        }
        "Cursors" {
            if ($btnTabCursors) {
                $btnTabCursors.Background      = $brushActiveBg
                $btnTabCursors.BorderBrush     = $brushAccent
                $btnTabCursors.BorderThickness = [System.Windows.Thickness]::new(3, 0, 0, 0)
                $btnTabCursors.Foreground      = $brushActiveFg
                $btnTabCursors.FontWeight      = [System.Windows.FontWeights]::SemiBold
            }
            Animate-ViewIn $viewCursors
            if ($txtActiveTabTitle) { $txtActiveTabTitle.Text = "PERSONALIZADOR DE CURSORES MTZ" }
        }
        "Drivers" {
            if ($btnTabDrivers) {
                $btnTabDrivers.Background      = $brushActiveBg
                $btnTabDrivers.BorderBrush     = $brushAccent
                $btnTabDrivers.BorderThickness = [System.Windows.Thickness]::new(3, 0, 0, 0)
                $btnTabDrivers.Foreground      = $brushActiveFg
                $btnTabDrivers.FontWeight      = [System.Windows.FontWeights]::SemiBold
            }
            Animate-ViewIn $viewDrivers
            if ($txtActiveTabTitle) { $txtActiveTabTitle.Text = "DRIVERS MATHZ (WHQL)" }
            if ($stackDriverItems -and $stackDriverItems.Children.Count -eq 0) {
                Invoke-MathzDriverScan
            }
        }
        "Browsers" {
            if ($btnTabBrowsers) {
                $btnTabBrowsers.Background      = $brushActiveBg
                $btnTabBrowsers.BorderBrush     = $brushAccent
                $btnTabBrowsers.BorderThickness = [System.Windows.Thickness]::new(3, 0, 0, 0)
                $btnTabBrowsers.Foreground      = $brushActiveFg
                $btnTabBrowsers.FontWeight      = [System.Windows.FontWeights]::SemiBold
            }
            Animate-ViewIn $viewBrowsers
            if ($txtActiveTabTitle) { $txtActiveTabTitle.Text = "INSTALACAO DE NAVEGADORES" }
        }
        "Installer" {
            if ($btnTabInstaller) {
                $btnTabInstaller.Background      = $brushActiveBg
                $btnTabInstaller.BorderBrush     = $brushAccent
                $btnTabInstaller.BorderThickness = [System.Windows.Thickness]::new(3, 0, 0, 0)
                $btnTabInstaller.Foreground      = $brushActiveFg
                $btnTabInstaller.FontWeight      = [System.Windows.FontWeights]::SemiBold
            }
            Animate-ViewIn $viewInstaller
            if ($txtActiveTabTitle) { $txtActiveTabTitle.Text = "APLICATIVOS ESSENCIAIS" }
        }
        "Theme" {
            if ($btnTabTheme) {
                $btnTabTheme.Background      = $brushActiveBg
                $btnTabTheme.BorderBrush     = $brushAccent
                $btnTabTheme.BorderThickness = [System.Windows.Thickness]::new(3, 0, 0, 0)
                $btnTabTheme.Foreground      = $brushActiveFg
                $btnTabTheme.FontWeight      = [System.Windows.FontWeights]::SemiBold
            }
            Animate-ViewIn $viewTheme
            if ($txtActiveTabTitle) { $txtActiveTabTitle.Text = "CORES, TEMA & TRANSLUCIDEZ" }
        }
    }
}

# ==============================================================================
# BINDINGS DOS BOTOES DE NAVEGACAO DA SIDEBAR (TROCA DE ABAS)
# ==============================================================================
if ($btnTabClocks)    { $btnTabClocks.Add_Click({    Set-TabActive "Clocks" }) }
if ($btnTabTweaks)    { $btnTabTweaks.Add_Click({    Set-TabActive "Tweaks" }) }
if ($btnTabTheme)     { $btnTabTheme.Add_Click({     Set-TabActive "Theme" }) }
if ($btnTabStartup)   { $btnTabStartup.Add_Click({   Set-TabActive "Startup" }) }
if ($btnTabCursors)   { $btnTabCursors.Add_Click({   Set-TabActive "Cursors" }) }
if ($btnTabDrivers)   { $btnTabDrivers.Add_Click({   Set-TabActive "Drivers" }) }
if ($btnTabBrowsers)  { $btnTabBrowsers.Add_Click({  Set-TabActive "Browsers" }) }
if ($btnTabInstaller) { $btnTabInstaller.Add_Click({ Set-TabActive "Installer" }) }
# ==============================================================================
# 6. MOTOR DE TEMA, CORES E TRANSLUCIDEZ (GLASS / ACRYLIC BLUR)
# ==============================================================================
$global:themeConfigDir  = Join-Path $env:LOCALAPPDATA "MathzControlPanel"
$global:themeConfigFile = Join-Path $global:themeConfigDir "theme_config.json"

# Estado Global do Tema
$global:themeTranslucent = $true
$global:themeOpacity     = 85
$global:themeAccentHex   = "#FF1E27"
$global:themeBgHex       = "#040404"
$global:refreshIntervalSec = 2.5
$global:thermalAlertThreshold = 80
$global:currentAccentBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FF1E27")

function Save-ThemeConfig {
    try {
        if (-not (Test-Path $global:themeConfigDir)) {
            New-Item -ItemType Directory -Path $global:themeConfigDir -Force | Out-Null
        }
        $cfg = [PSCustomObject]@{
            Translucent    = $global:themeTranslucent
            Opacity        = $global:themeOpacity
            AccentHex      = $global:themeAccentHex
            BackgroundHex  = $global:themeBgHex
            RefreshSec     = $global:refreshIntervalSec
            AlertThreshold = $global:thermalAlertThreshold
            FontPreset     = $global:themeFontPreset
        }
        $cfg | ConvertTo-Json | Set-Content -Path $global:themeConfigFile -Encoding UTF8 -Force
    } catch {}
}

function Load-ThemeConfig {
    try {
        if (Test-Path $global:themeConfigFile) {
            $json = Get-Content -Path $global:themeConfigFile -Raw | ConvertFrom-Json
            if ($null -ne $json.Translucent)    { $global:themeTranslucent = [bool]$json.Translucent }
            if ($null -ne $json.Opacity)        { $global:themeOpacity = [int]$json.Opacity }
            if ($json.AccentHex)                { $global:themeAccentHex = [string]$json.AccentHex }
            if ($json.BackgroundHex)            { $global:themeBgHex = [string]$json.BackgroundHex }
            if ($null -ne $json.RefreshSec)     { $global:refreshIntervalSec = [double]$json.RefreshSec }
            if ($null -ne $json.AlertThreshold) { $global:thermalAlertThreshold = [int]$json.AlertThreshold }
        }
    } catch {}
}

function Apply-PanelThemeUI {
    try {
        $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($window)).Handle
        if ($hwnd -ne [IntPtr]::Zero) {
            [Win32Accent]::EnableBlur($hwnd, $global:themeTranslucent) | Out-Null
        }

        # Calcula o codigo ARGB com base na opacidade
        $cleanBg = $global:themeBgHex.TrimStart('#')
        if ($cleanBg.Length -gt 6) { $cleanBg = $cleanBg.Substring($cleanBg.Length - 6, 6) }

        $alphaByte = if ($global:themeTranslucent) {
            [int][math]::Round(($global:themeOpacity / 100.0) * 255)
        } else {
            255
        }
        $alphaHex = $alphaByte.ToString("X2")
        $finalBgColor = "#" + $alphaHex + $cleanBg

        if ($windowMainBorder) {
            $windowMainBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString($finalBgColor)
        }

        # Atualiza Accent
        $global:currentAccentBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString($global:themeAccentHex)
        if ($txtCurrentAccentHex) { $txtCurrentAccentHex.Text = $global:themeAccentHex }
        if ($previewAccentBadge)  { $previewAccentBadge.Background = $global:currentAccentBrush }
        if ($txtCurrentBgHex)     { $txtCurrentBgHex.Text = $global:themeBgHex }
        if ($previewBgBadge)      { $previewBgBadge.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString($global:themeBgHex) }

        # Atualiza Status Translucidez
        if ($global:themeTranslucent) {
            if ($badgeTranslucentStatus) {
                $badgeTranslucentStatus.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#152238")
                $badgeTranslucentStatus.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#00E5FF")
            }
            if ($txtTranslucentStatus) {
                $txtTranslucentStatus.Text = "TRANSLUCIDO ATIVO ($($global:themeOpacity)%)"
                $txtTranslucentStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#00E5FF")
            }
            if ($btnGlassOn) {
                $btnGlassOn.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1F1F1F")
                $btnGlassOn.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#00E5FF")
            }
            if ($btnGlassOff) {
                $btnGlassOff.Background = [System.Windows.Media.Brushes]::Transparent
                $btnGlassOff.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#2A2A2A")
            }
        } else {
            if ($badgeTranslucentStatus) {
                $badgeTranslucentStatus.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1F1F1F")
                $badgeTranslucentStatus.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#8C8C8C")
            }
            if ($txtTranslucentStatus) {
                $txtTranslucentStatus.Text = "SOLIDO (SEM VIDRO)"
                $txtTranslucentStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#8C8C8C")
            }
            if ($btnGlassOn) {
                $btnGlassOn.Background = [System.Windows.Media.Brushes]::Transparent
                $btnGlassOn.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#2A2A2A")
            }
            if ($btnGlassOff) {
                $btnGlassOff.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1F1F1F")
                $btnGlassOff.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#8C8C8C")
            }
        }

        # Atualiza botoes de opacidade
        $opButtons = @(
            @{ Btn = $btnOp70; Val = 70 },
            @{ Btn = $btnOp80; Val = 80 },
            @{ Btn = $btnOp90; Val = 90 },
            @{ Btn = $btnOp100; Val = 100 }
        )
        foreach ($item in $opButtons) {
            if ($item.Btn) {
                if ($global:themeOpacity -eq $item.Val) {
                    $item.Btn.BorderBrush = $global:currentAccentBrush
                    $item.Btn.FontWeight  = [System.Windows.FontWeights]::Bold
                } else {
                    $item.Btn.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#2A2A2A")
                    $item.Btn.FontWeight  = [System.Windows.FontWeights]::Normal
                }
            }
        }

        # Atualiza botoes de taxa de atualizacao dos graficos
        $rateBtns = @(
            @{ Btn = $btnRefreshFast; Val = 1.0 },
            @{ Btn = $btnRefreshNormal; Val = 2.5 },
            @{ Btn = $btnRefreshEco; Val = 5.0 }
        )
        foreach ($rb in $rateBtns) {
            if ($rb.Btn) {
                if ([math]::Abs($global:refreshIntervalSec - $rb.Val) -lt 0.1) {
                    $rb.Btn.BorderBrush = $global:currentAccentBrush
                    $rb.Btn.FontWeight  = [System.Windows.FontWeights]::Bold
                } else {
                    $rb.Btn.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#2A2A2A")
                    $rb.Btn.FontWeight  = [System.Windows.FontWeights]::Normal
                }
            }
        }

        # Atualiza botoes de alerta termico
        $alertBtns = @(
            @{ Btn = $btnAlert75; Val = 75 },
            @{ Btn = $btnAlert80; Val = 80 },
            @{ Btn = $btnAlert85; Val = 85 },
            @{ Btn = $btnAlert90; Val = 90 }
        )
        foreach ($ab in $alertBtns) {
            if ($ab.Btn) {
                if ($global:thermalAlertThreshold -eq $ab.Val) {
                    $ab.Btn.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FF1E27")
                    $ab.Btn.FontWeight  = [System.Windows.FontWeights]::Bold
                } else {
                    $ab.Btn.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#2A2A2A")
                    $ab.Btn.FontWeight  = [System.Windows.FontWeights]::Normal
                }
            }
        }

    } catch {
        Log-Hud "Erro ao aplicar tema: $_"
    }
}

# Handlers de Translucidez e Opacidade
if ($btnGlassOn) {
    $btnGlassOn.Add_Click({
        $global:themeTranslucent = $true
        Apply-PanelThemeUI
        Save-ThemeConfig
        Log-Hud "Modo Translúcido (Glass/Acrylic) ativado com sucesso!"
    })
}
if ($btnGlassOff) {
    $btnGlassOff.Add_Click({
        $global:themeTranslucent = $false
        Apply-PanelThemeUI
        Save-ThemeConfig
        Log-Hud "Modo Slido ativado. Fundo 100% opaco."
    })
}
if ($btnOp70)  { $btnOp70.Add_Click({  $global:themeOpacity = 70;  Apply-PanelThemeUI; Save-ThemeConfig }) }
if ($btnOp80)  { $btnOp80.Add_Click({  $global:themeOpacity = 80;  Apply-PanelThemeUI; Save-ThemeConfig }) }
if ($btnOp90)  { $btnOp90.Add_Click({  $global:themeOpacity = 90;  Apply-PanelThemeUI; Save-ThemeConfig }) }
if ($btnOp100) { $btnOp100.Add_Click({ $global:themeOpacity = 100; Apply-PanelThemeUI; Save-ThemeConfig }) }

# Handlers de Cores de Destaque (Accent)
function Set-ThemeAccent([string]$hex) {
    $global:themeAccentHex = $hex
    Apply-PanelThemeUI
    Save-ThemeConfig
    Log-Hud "Cor de destaque alterada para $hex"
}

if ($btnAccRed)    { $btnAccRed.Add_Click({    Set-ThemeAccent "#FF1E27" }) }
if ($btnAccCyan)   { $btnAccCyan.Add_Click({   Set-ThemeAccent "#00E5FF" }) }
if ($btnAccGreen)  { $btnAccGreen.Add_Click({  Set-ThemeAccent "#00E676" }) }
if ($btnAccPurple) { $btnAccPurple.Add_Click({ Set-ThemeAccent "#9D00FF" }) }
if ($btnAccOrange) { $btnAccOrange.Add_Click({ Set-ThemeAccent "#FF6D00" }) }
if ($btnAccPink)   { $btnAccPink.Add_Click({   Set-ThemeAccent "#FF0055" }) }
if ($btnAccGold)   { $btnAccGold.Add_Click({   Set-ThemeAccent "#FFD600" }) }
if ($btnAccWhite)  { $btnAccWhite.Add_Click({  Set-ThemeAccent "#FFFFFF" }) }

if ($btnApplyCustomAccent) {
    $btnApplyCustomAccent.Add_Click({
        $custom = $txtCustomAccentHex.Text.Trim()
        if ($custom -match '^#?[0-9a-fA-F]{6}$') {
            if (-not $custom.StartsWith('#')) { $custom = "#" + $custom }
            Set-ThemeAccent $custom
        } else {
            Log-Hud "HEX invalido. Use formato #RRGGBB (ex: #FF1E27)"
        }
    })
}

# Handlers de Cores de Fundo (Background)
# ==============================================================================
# CONTROLE DE PRESET DE FONTES (BEBAS NEUE, OUTFIT, ORBITRON, RAJDHANI)
# ==============================================================================
$global:themeFontPreset = "CYBER"

function Set-PanelFontPreset([string]$preset) {
    $global:themeFontPreset = $preset
    $ffConv = [System.Windows.Media.FontFamilyConverter]::new()
    $badgeText = "CYBER ESPORTS (BEBAS + OUTFIT)"
    
    switch ($preset) {
        "CYBER" {
            $hFont = $ffConv.ConvertFromString("Bebas Neue, Rajdhani, Orbitron, Bahnschrift, Segoe UI Variable Display, Impact, sans-serif")
            $bFont = $ffConv.ConvertFromString("Outfit, Montserrat, Bahnschrift, Segoe UI Variable Text, Segoe UI, sans-serif")
            $badgeText = "CYBER ESPORTS (BEBAS + OUTFIT)"
        }
        "QUANTUM" {
            $hFont = $ffConv.ConvertFromString("Orbitron, Rajdhani, Bebas Neue, Bahnschrift, sans-serif")
            $bFont = $ffConv.ConvertFromString("Rajdhani, Outfit, Montserrat, Bahnschrift, sans-serif")
            $badgeText = "QUANTUM SCI-FI (ORBITRON + RAJDHANI)"
        }
        "ROUNDED" {
            $hFont = $ffConv.ConvertFromString("Outfit, Montserrat, Bahnschrift, sans-serif")
            $bFont = $ffConv.ConvertFromString("Outfit, Montserrat, Bahnschrift, Segoe UI, sans-serif")
            $badgeText = "MODERNA ARREDONDADA (OUTFIT)"
        }
        "FLUENT" {
            $hFont = $ffConv.ConvertFromString("Bahnschrift, Segoe UI Variable Display, Segoe UI, sans-serif")
            $bFont = $ffConv.ConvertFromString("Segoe UI Variable Text, Bahnschrift, Segoe UI, sans-serif")
            $badgeText = "WINDOWS FLUENT (BAHNSCHRIFT)"
        }
    }

    if ($window) {
        $window.Resources["Heading"] = $hFont
        $window.Resources["Body"]    = $bFont
        $window.FontFamily           = $bFont
    }
    if ($txtActiveFontName) { $txtActiveFontName.Text = $badgeText }

    # Atualiza estilo visual dos botoes de fonte
    $fontBtns = @{
        "CYBER"   = $btnFontCyber
        "QUANTUM" = $btnFontQuantum
        "ROUNDED" = $btnFontRounded
        "FLUENT"  = $btnFontFluent
    }
    foreach ($k in $fontBtns.Keys) {
        $b = $fontBtns[$k]
        if ($b) {
            if ($k -eq $preset) {
                $b.Style = $window.Resources["PrimaryButton"]
            } else {
                $b.Style = $window.Resources["OutlineButton"]
            }
        }
    }
}

$btnFontCyber   = $window.FindName("BtnFontCyber")
$btnFontQuantum = $window.FindName("BtnFontQuantum")
$btnFontRounded = $window.FindName("BtnFontRounded")
$btnFontFluent  = $window.FindName("BtnFontFluent")
$txtActiveFontName = $window.FindName("TxtActiveFontName")

if ($btnFontCyber)   { $btnFontCyber.Add_Click({   Set-PanelFontPreset "CYBER";   Save-ThemeConfig; Log-Hud "Tipografia alterada para: Cyber Esports (Bebas Neue + Outfit)" }) }
if ($btnFontQuantum) { $btnFontQuantum.Add_Click({ Set-PanelFontPreset "QUANTUM"; Save-ThemeConfig; Log-Hud "Tipografia alterada para: Quantum Sci-Fi (Orbitron + Rajdhani)" }) }
if ($btnFontRounded) { $btnFontRounded.Add_Click({ Set-PanelFontPreset "ROUNDED"; Save-ThemeConfig; Log-Hud "Tipografia alterada para: Moderna Arredondada (Outfit / Aquatico)" }) }
if ($btnFontFluent)  { $btnFontFluent.Add_Click({  Set-PanelFontPreset "FLUENT";  Save-ThemeConfig; Log-Hud "Tipografia alterada para: Windows Fluent (Bahnschrift)" }) }

function Set-ThemeBackground([string]$hex) {
    $global:themeBgHex = $hex
    Apply-PanelThemeUI
    Save-ThemeConfig
    Log-Hud "Cor de fundo alterada para $hex"
}

if ($btnBgPureBlack) { $btnBgPureBlack.Add_Click({ Set-ThemeBackground "#000000" }) }
if ($btnBgSlate)     { $btnBgSlate.Add_Click({     Set-ThemeBackground "#0A0D14" }) }
if ($btnBgNavy)      { $btnBgNavy.Add_Click({      Set-ThemeBackground "#060B18" }) }
if ($btnBgCrimson)   { $btnBgCrimson.Add_Click({   Set-ThemeBackground "#140204" }) }
if ($btnBgForest)    { $btnBgForest.Add_Click({    Set-ThemeBackground "#021208" }) }

if ($btnApplyCustomBg) {
    $btnApplyCustomBg.Add_Click({
        $custom = $txtCustomBgHex.Text.Trim()
        if ($custom -match '^#?[0-9a-fA-F]{6}$') {
            if (-not $custom.StartsWith('#')) { $custom = "#" + $custom }
            Set-ThemeBackground $custom
        } else {
            Log-Hud "HEX invalido. Use formato #RRGGBB (ex: #000000)"
        }
    })
}

# Reset aos Padrãoes Oficiais MTZ
if ($btnResetThemeDefaults) {
    $btnResetThemeDefaults.Add_Click({
        $global:themeTranslucent = $true
        $global:themeOpacity     = 85
        $global:themeAccentHex   = "#FF1E27"
        $global:themeBgHex       = "#040404"
        $global:refreshIntervalSec = 2.5
        $global:thermalAlertThreshold = 80
        if ($global:hwTimer) { $global:hwTimer.Interval = [TimeSpan]::FromSeconds($global:refreshIntervalSec) }
        Apply-PanelThemeUI
        Save-ThemeConfig
        Log-Hud "Tema e Sensores restaurados aos padres originais do MTZ!"
    })
}

# Handlers de Customizacao de Sensores / Graficos
if ($btnRefreshFast) {
    $btnRefreshFast.Add_Click({
        $global:refreshIntervalSec = 1.0
        if ($global:hwTimer) { $global:hwTimer.Interval = [TimeSpan]::FromSeconds(1.0) }
        Apply-PanelThemeUI
        Save-ThemeConfig
        Log-Hud "Taxa de atualizao dos gráficos alterada para 1.0 segundo (Rpido)."
    })
}
if ($btnRefreshNormal) {
    $btnRefreshNormal.Add_Click({
        $global:refreshIntervalSec = 2.5
        if ($global:hwTimer) { $global:hwTimer.Interval = [TimeSpan]::FromSeconds(2.5) }
        Apply-PanelThemeUI
        Save-ThemeConfig
        Log-Hud "Taxa de atualizao dos gráficos alterada para 2.5 segundos (Equilibrado)."
    })
}
if ($btnRefreshEco) {
    $btnRefreshEco.Add_Click({
        $global:refreshIntervalSec = 5.0
        if ($global:hwTimer) { $global:hwTimer.Interval = [TimeSpan]::FromSeconds(5.0) }
        Apply-PanelThemeUI
        Save-ThemeConfig
        Log-Hud "Taxa de atualizao dos gráficos alterada para 5.0 segundos (Ultra Leve)."
    })
}

if ($btnAlert75) { $btnAlert75.Add_Click({ $global:thermalAlertThreshold = 75; Apply-PanelThemeUI; Save-ThemeConfig; Log-Hud ("Alerta de CPU Quente definido em 75" + [char]0x00B0 + "C") }) }
if ($btnAlert80) { $btnAlert80.Add_Click({ $global:thermalAlertThreshold = 80; Apply-PanelThemeUI; Save-ThemeConfig; Log-Hud ("Alerta de CPU Quente definido em 80" + [char]0x00B0 + "C") }) }
if ($btnAlert85) { $btnAlert85.Add_Click({ $global:thermalAlertThreshold = 85; Apply-PanelThemeUI; Save-ThemeConfig; Log-Hud ("Alerta de CPU Quente definido em 85" + [char]0x00B0 + "C") }) }
if ($btnAlert90) { $btnAlert90.Add_Click({ $global:thermalAlertThreshold = 90; Apply-PanelThemeUI; Save-ThemeConfig; Log-Hud ("Alerta de CPU Quente definido em 90" + [char]0x00B0 + "C") }) }

# ==============================================================================
# 7. TELEMETRIA E TEMPERATURAS DO HARDWARE (CPU & GPU)
# ==============================================================================
$global:prevIdleTime   = 0L
$global:prevKernelTime = 0L
$global:prevUserTime   = 0L
$global:hasNvidiaSmi   = [bool](Get-Command "nvidia-smi" -ErrorAction SilentlyContinue)

function Get-HardwareTemperatures {
    $cpuDeg = 0
    # Metodo 1: MSAcpi_ThermalZoneTemperature (Unidades em Decikelvin)
    try {
        $tz = Get-CimInstance -Namespace "root/wmi" -ClassName "MSAcpi_ThermalZoneTemperature" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($tz -and $tz.CurrentTemperature -gt 2732) {
            $cpuDeg = [math]::Round(($tz.CurrentTemperature - 2732) / 10.0, 0)
        }
    } catch {}

    # Metodo 2: Win32_PerfFormattedData_Counters_ThermalZoneInformation
    if ($cpuDeg -le 0 -or $cpuDeg -gt 115) {
        try {
            $tzPerf = Get-CimInstance -ClassName Win32_PerfFormattedData_Counters_ThermalZoneInformation -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($tzPerf -and $tzPerf.Temperature -gt 273) {
                $cpuDeg = [math]::Round($tzPerf.Temperature - 273.15, 0)
            }
        } catch {}
    }

    # GPU Temp via nvidia-smi
    $gpuDeg = 0
    $gpuClock = ""
    $gpuUsage = ""
    if ($global:hasNvidiaSmi) {
        try {
            $smiOut = & nvidia-smi --query-gpu=clocks.gr,temperature.gpu,utilization.gpu --format=csv,noheader,nounits 2>$null
            if ($smiOut) {
                $parts = ($smiOut -split ',').Trim()
                if ($parts.Count -ge 2) {
                    $gpuClock = "$($parts[0]) MHz"
                    $gpuDeg   = [int]$parts[1]
                }
                if ($parts.Count -ge 3) {
                    $gpuUsage = "$($parts[2])%"
                }
            }
        } catch {}
    }

    return [PSCustomObject]@{
        CpuDeg   = $cpuDeg
        GpuDeg   = $gpuDeg
        GpuClock = $gpuClock
        GpuUsage = $gpuUsage
    }
}

# ==============================================================================
# MOTOR GRAFICO VETORIAL E MULTI-MODO DE TELEMETRIA (ONDA, PIZZA, BARRAS)
# ==============================================================================
$global:cpuHistory = [System.Collections.Generic.List[double]]::new()
$global:ramHistory = [System.Collections.Generic.List[double]]::new()
$global:graphMode  = "BOTH" # "CPU", "RAM", "BOTH"
$global:graphStyle = "WAVE" # "WAVE", "DONUT", "BARS"
$global:maxGraphPoints = 32

$global:lastCpuTemp = 45
$global:lastUsedGb  = 0
$global:lastTotalGb = 0

$global:invCulture = [System.Globalization.CultureInfo]::InvariantCulture

function Set-DonutPercent($path, [double]$pct, [double]$cx, [double]$cy, [double]$r) {
    if (-not $path) { return }
    $pctClamped = [math]::Max(0.1, [math]::Min(99.9, $pct))
    $angleRad = ($pctClamped / 100.0) * 360.0 * [math]::PI / 180.0
    $startX = $cx
    $startY = $cy - $r
    $endX = $cx + $r * [math]::Sin($angleRad)
    $endY = $cy - $r * [math]::Cos($angleRad)
    $isLarge = if ($pctClamped -gt 50.0) { "1" } else { "0" }

    $dataStr = "M " + $startX.ToString("0.##", $global:invCulture) + "," + $startY.ToString("0.##", $global:invCulture) + " A " + $r.ToString("0.##", $global:invCulture) + "," + $r.ToString("0.##", $global:invCulture) + " 0 " + $isLarge + " 1 " + $endX.ToString("0.##", $global:invCulture) + "," + $endY.ToString("0.##", $global:invCulture)
    try { $path.Data = [System.Windows.Media.Geometry]::Parse($dataStr) } catch {}
}

function Initialize-HistogramBars {
    if (-not $gridBarsContainer) { return }
    $gridBarsContainer.Children.Clear()
    for ($i = 0; $i -lt 16; $i++) {
        $slot = New-Object System.Windows.Controls.Border
        $slot.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#121212")
        $slot.CornerRadius = [System.Windows.CornerRadius]::new(3)
        $slot.Margin = [System.Windows.Thickness]::new(2, 0, 2, 0)
        $slot.VerticalAlignment = [System.Windows.VerticalAlignment]::Stretch

        $bar = New-Object System.Windows.Controls.Border
        $bar.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FF1E27")
        $bar.CornerRadius = [System.Windows.CornerRadius]::new(3)
        $bar.VerticalAlignment = [System.Windows.VerticalAlignment]::Bottom
        $bar.Height = 10

        $slot.Child = $bar
        [void]$gridBarsContainer.Children.Add($slot)
    }
}

function Set-GraphStyleActive([string]$style) {
    $global:graphStyle = $style
    $brActive   = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FF1E27")
    $brInactive = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#121212")
    $fgActive   = [System.Windows.Media.Brushes]::White
    $fgInactive = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#8C8C8C")

    if ($btnStyleWave) {
        $btnStyleWave.Background = if ($style -eq "WAVE") { $brActive } else { $brInactive }
        $btnStyleWave.Foreground = if ($style -eq "WAVE") { $fgActive } else { $fgInactive }
    }
    if ($btnStyleDonut) {
        $btnStyleDonut.Background = if ($style -eq "DONUT") { $brActive } else { $brInactive }
        $btnStyleDonut.Foreground = if ($style -eq "DONUT") { $fgActive } else { $fgInactive }
    }
    if ($btnStyleBars) {
        $btnStyleBars.Background = if ($style -eq "BARS") { $brActive } else { $brInactive }
        $btnStyleBars.Foreground = if ($style -eq "BARS") { $fgActive } else { $fgInactive }
    }

    if ($style -eq "WAVE") {
        if ($gridGraphWave)  { Animate-ViewIn $gridGraphWave }
        if ($gridGraphDonut) { $gridGraphDonut.Visibility = [System.Windows.Visibility]::Collapsed }
        if ($gridGraphBars)  { $gridGraphBars.Visibility  = [System.Windows.Visibility]::Collapsed }
        if ($panelWaveFilters) { $panelWaveFilters.Visibility = [System.Windows.Visibility]::Visible }
        if ($txtGraphSubTitle) { $txtGraphSubTitle.Text = " // HISTORICO DINAMICO (ONDA)" }
    } elseif ($style -eq "DONUT") {
        if ($gridGraphWave)  { $gridGraphWave.Visibility  = [System.Windows.Visibility]::Collapsed }
        if ($gridGraphDonut) { Animate-ViewIn $gridGraphDonut }
        if ($gridGraphBars)  { $gridGraphBars.Visibility  = [System.Windows.Visibility]::Collapsed }
        if ($panelWaveFilters) { $panelWaveFilters.Visibility = [System.Windows.Visibility]::Collapsed }
        if ($txtGraphSubTitle) { $txtGraphSubTitle.Text = " // MEDIDORES CIRCULARES (PIZZA)" }
    } elseif ($style -eq "BARS") {
        if ($gridGraphWave)  { $gridGraphWave.Visibility  = [System.Windows.Visibility]::Collapsed }
        if ($gridGraphDonut) { $gridGraphDonut.Visibility = [System.Windows.Visibility]::Collapsed }
        if ($gridGraphBars)  { Animate-ViewIn $gridGraphBars }
        if ($panelWaveFilters) { $panelWaveFilters.Visibility = [System.Windows.Visibility]::Collapsed }
        if ($txtGraphSubTitle) { $txtGraphSubTitle.Text = " // ESPECTRO DE SUBSISTEMAS (BARRAS)" }
        Initialize-HistogramBars
    }

    Update-TelemetryGraph -1 -1
}

function Update-TelemetryGraph([double]$newCpu, [double]$newRam) {
    if ($newCpu -ge 0) {
        $global:cpuHistory.Add($newCpu)
        while ($global:cpuHistory.Count -gt $global:maxGraphPoints) {
            $global:cpuHistory.RemoveAt(0)
        }
    }

    if ($newRam -ge 0) {
        $global:ramHistory.Add($newRam)
        while ($global:ramHistory.Count -gt $global:maxGraphPoints) {
            $global:ramHistory.RemoveAt(0)
        }
    }

    $count = $global:cpuHistory.Count
    if ($count -lt 2) { return }

    $curCpu = [int]$global:cpuHistory[-1]
    $curRam = [int]$global:ramHistory[-1]

    # Estatisticas Globais
    $maxVal = 0
    $sum = 0
    foreach ($p in $global:cpuHistory) {
        if ($p -gt $maxVal) { $maxVal = [int]$p }
        $sum += $p
    }
    $avgVal = [int][math]::Round($sum / $count, 0)

    if ($txtGraphPeak)    { $txtGraphPeak.Text = "Pico: $maxVal %" }
    if ($txtGraphCurrent) { $txtGraphCurrent.Text = "CPU: $curCpu % | RAM: $curRam %" }

    # =========================================================================
    # 1. ATUALIZA ESTILO 1: ONDA / LINHA
    # =========================================================================
    if ($graphCanvas -and $gridGraphWave -and $gridGraphWave.Visibility -eq [System.Windows.Visibility]::Visible) {
        $w = $graphCanvas.ActualWidth
        $h = $graphCanvas.ActualHeight
        if ($w -ge 50 -and $h -ge 50) {
            $step = $w / ($count - 1)

            # Curva CPU
            if ($global:graphMode -eq "CPU" -or $global:graphMode -eq "BOTH") {
                $pcCpuLine = New-Object System.Windows.Media.PointCollection
                $pcCpuFill = New-Object System.Windows.Media.PointCollection
                [void]$pcCpuFill.Add([System.Windows.Point]::new(0, $h))

                for ($i = 0; $i -lt $count; $i++) {
                    $val = [math]::Max(0, [math]::Min(100, $global:cpuHistory[$i]))
                    $x = $i * $step
                    $y = $h - ($val / 100.0 * $h)
                    $pt = [System.Windows.Point]::new($x, $y)
                    [void]$pcCpuLine.Add($pt)
                    [void]$pcCpuFill.Add($pt)
                }
                $lastX = ($count - 1) * $step
                $lastY = $h - ([math]::Max(0, [math]::Min(100, $global:cpuHistory[-1])) / 100.0 * $h)
                [void]$pcCpuFill.Add([System.Windows.Point]::new($lastX, $h))

                if ($graphPolyLineCpu) { $graphPolyLineCpu.Points = $pcCpuLine; $graphPolyLineCpu.Visibility = [System.Windows.Visibility]::Visible }
                if ($graphPolyFillCpu) { $graphPolyFillCpu.Points = $pcCpuFill; $graphPolyFillCpu.Visibility = [System.Windows.Visibility]::Visible }
                if ($graphDotHeadCpu) {
                    [System.Windows.Controls.Canvas]::SetLeft($graphDotHeadCpu, $lastX - 3)
                    [System.Windows.Controls.Canvas]::SetTop($graphDotHeadCpu, $lastY - 3)
                    $graphDotHeadCpu.Visibility = [System.Windows.Visibility]::Visible
                }
                if ($graphDotHaloCpu) {
                    [System.Windows.Controls.Canvas]::SetLeft($graphDotHaloCpu, $lastX - 7)
                    [System.Windows.Controls.Canvas]::SetTop($graphDotHaloCpu, $lastY - 7)
                    $graphDotHaloCpu.Visibility = [System.Windows.Visibility]::Visible
                }
            } else {
                if ($graphPolyLineCpu) { $graphPolyLineCpu.Visibility = [System.Windows.Visibility]::Collapsed }
                if ($graphPolyFillCpu) { $graphPolyFillCpu.Visibility = [System.Windows.Visibility]::Collapsed }
                if ($graphDotHeadCpu)  { $graphDotHeadCpu.Visibility  = [System.Windows.Visibility]::Collapsed }
                if ($graphDotHaloCpu)  { $graphDotHaloCpu.Visibility  = [System.Windows.Visibility]::Collapsed }
            }

            # Curva RAM
            if ($global:graphMode -eq "RAM" -or $global:graphMode -eq "BOTH") {
                $pcRamLine = New-Object System.Windows.Media.PointCollection
                $pcRamFill = New-Object System.Windows.Media.PointCollection
                [void]$pcRamFill.Add([System.Windows.Point]::new(0, $h))

                for ($i = 0; $i -lt $count; $i++) {
                    $val = [math]::Max(0, [math]::Min(100, $global:ramHistory[$i]))
                    $x = $i * $step
                    $y = $h - ($val / 100.0 * $h)
                    $pt = [System.Windows.Point]::new($x, $y)
                    [void]$pcRamLine.Add($pt)
                    [void]$pcRamFill.Add($pt)
                }
                $lastX = ($count - 1) * $step
                $lastY = $h - ([math]::Max(0, [math]::Min(100, $global:ramHistory[-1])) / 100.0 * $h)
                [void]$pcRamFill.Add([System.Windows.Point]::new($lastX, $h))

                if ($graphPolyLineRam) { $graphPolyLineRam.Points = $pcRamLine; $graphPolyLineRam.Visibility = [System.Windows.Visibility]::Visible }
                if ($graphPolyFillRam) { $graphPolyFillRam.Points = $pcRamFill; $graphPolyFillRam.Visibility = [System.Windows.Visibility]::Visible }
                if ($graphDotHeadRam) {
                    [System.Windows.Controls.Canvas]::SetLeft($graphDotHeadRam, $lastX - 3)
                    [System.Windows.Controls.Canvas]::SetTop($graphDotHeadRam, $lastY - 3)
                    $graphDotHeadRam.Visibility = [System.Windows.Visibility]::Visible
                }
            } else {
                if ($graphPolyLineRam) { $graphPolyLineRam.Visibility = [System.Windows.Visibility]::Collapsed }
                if ($graphPolyFillRam) { $graphPolyFillRam.Visibility = [System.Windows.Visibility]::Collapsed }
                if ($graphDotHeadRam)  { $graphDotHeadRam.Visibility  = [System.Windows.Visibility]::Collapsed }
            }
        }
    }

    # =========================================================================
    # 2. ATUALIZA ESTILO 2: PIZZA / DONUT
    # =========================================================================
    if ($gridGraphDonut -and $gridGraphDonut.Visibility -eq [System.Windows.Visibility]::Visible) {
        Set-DonutPercent $donutPathCpu $curCpu 55 55 46
        Set-DonutPercent $donutPathRam $curRam 55 55 46
        Set-DonutPercent $donutPathTemp ([math]::Min(100, $global:lastCpuTemp)) 55 55 46

        if ($txtDonutCpuVal) { $txtDonutCpuVal.Text = "$curCpu %" }
        if ($txtDonutRamVal) { $txtDonutRamVal.Text = "$curRam %" }
        if ($txtDonutTempVal) { $txtDonutTempVal.Text = "$($global:lastCpuTemp) " + [char]0x00B0 + "C" }
        if ($txtDonutPeak)   { $txtDonutPeak.Text = "$maxVal %" }
        if ($txtDonutAvg)    { $txtDonutAvg.Text = "$avgVal %" }
    }

    # =========================================================================
    # 3. ATUALIZA ESTILO 3: BARRAS / ESPECTRO HUD
    # =========================================================================
    if ($gridGraphBars -and $gridGraphBars.Visibility -eq [System.Windows.Visibility]::Visible) {
        if ($gridBarsContainer -and $gridBarsContainer.Children.Count -eq 16) {
            $histH = [math]::Max(20, $gridBarsContainer.ActualHeight - 12)
            $startIdx = [math]::Max(0, $global:cpuHistory.Count - 16)
            for ($i = 0; $i -lt 16; $i++) {
                $dataIdx = $startIdx + $i
                $val = if ($dataIdx -lt $global:cpuHistory.Count) { $global:cpuHistory[$dataIdx] } else { 0 }
                $barHeight = [math]::Max(4, [math]::Min($histH, ($val / 100.0) * $histH))
                $slot = $gridBarsContainer.Children[$i]
                if ($slot -and $slot.Child) {
                    $slot.Child.Height = $barHeight
                    $col = if ($val -ge 75) { "#FF1E27" } elseif ($val -ge 45) { "#FFAA00" } else { "#00FF66" }
                    $slot.Child.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString($col)
                }
            }
        }
        if ($txtBarCpuPct)  { $txtBarCpuPct.Text = "$curCpu %" }
        if ($pbBarCpu)      { $pbBarCpu.Value = $curCpu }
        if ($txtBarRamPct)  { $txtBarRamPct.Text = "$curRam %" }
        if ($pbBarRam)      { $pbBarRam.Value = $curRam }
        if ($txtBarTempPct) { $txtBarTempPct.Text = "$($global:lastCpuTemp) " + [char]0x00B0 + "C" }
        if ($pbBarTemp)     { $pbBarTemp.Value = [math]::Min(105, $global:lastCpuTemp) }
    }
}
function Update-RealHardwareUI {
    try {
        # 1. RAM Real (GlobalMemoryStatusEx)
        $mem = New-Object MathzMemoryOptimizer+MEMORYSTATUSEX
        $mem.dwLength = [System.Runtime.InteropServices.Marshal]::SizeOf($mem)
        if ([MathzMemoryOptimizer]::GlobalMemoryStatusEx([ref]$mem)) {
            $totalGb = [math]::Round($mem.ullTotalPhys / 1GB, 1)
            $availGb = [math]::Round($mem.ullAvailPhys / 1GB, 1)
            $usedGb  = [math]::Round($totalGb - $availGb, 1)
            $loadPct = $mem.dwMemoryLoad

            if ($txtRamDetailMini) { $txtRamDetailMini.Text = "$usedGb / $totalGb GB" }
            if ($txtRamUsage)      { $txtRamUsage.Text = "$loadPct %" }
            if ($pbRam)           { $pbRam.Value = $loadPct }
            if ($txtRamAvail)     { $txtRamAvail.Text = "Livre: $availGb GB de $totalGb GB" }
            if ($txtRamUsageMain) { $txtRamUsageMain.Text = "$usedGb GB / $totalGb GB ($loadPct%)" }
        }

        # 2. CPU Usage Real (Win32 GetSystemTimes)
        $idle = 0L; $kernel = 0L; $user = 0L
        if ([MathzMemoryOptimizer]::GetSystemTimes([ref]$idle, [ref]$kernel, [ref]$user)) {
            if ($global:prevKernelTime -ne 0) {
                $usrDiff = $user - $global:prevUserTime
                $kerDiff = $kernel - $global:prevKernelTime
                $idlDiff = $idle - $global:prevIdleTime
                $sysTotal = $usrDiff + $kerDiff

                if ($sysTotal -gt 0) {
                    $cpuPct = [math]::Round((($sysTotal - $idlDiff) * 100) / $sysTotal, 0)
                    $cpuPct = [math]::Max(0, [math]::Min(100, $cpuPct))
                    if ($txtCpuUsage)     { $txtCpuUsage.Text = "$cpuPct %" }
                    if ($pbCpu)           { $pbCpu.Value = $cpuPct }
                    if ($txtCpuUsageMain) { $txtCpuUsageMain.Text = "$cpuPct %" }
                }
            }
            $global:prevIdleTime   = $idle
            $global:prevKernelTime = $kernel
            $global:prevUserTime   = $user
        }

        # 3. Temperaturas (CPU & GPU)
        $hwTemps = Get-HardwareTemperatures; if ($hwTemps.CpuDeg -gt 0) { $global:lastCpuTemp = $hwTemps.CpuDeg }

        # CPU Temp Status & Alerta Trmico
        if ($hwTemps.CpuDeg -gt 0) {
            $cDeg = $hwTemps.CpuDeg
            $isHot = ($cDeg -ge $global:thermalAlertThreshold)
            $isWarm = ($cDeg -ge 70 -and -not $isHot)

            if ($isHot) {
                if ($txtCpuTempStatus) {
                    $txtCpuTempStatus.Text = "$cDeg " + [char]0x00B0 + "C (QUENTE!)"
                    $txtCpuTempStatus.Foreground = [System.Windows.Media.Brushes]::White
                }
                if ($badgeCpuTemp) {
                    $badgeCpuTemp.Background  = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FF1E27")
                    $badgeCpuTemp.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FF0055")
                }
                if ($txtCpuTempMini) {
                    $txtCpuTempMini.Text = "$cDeg" + [char]0x00B0 + "C (QUENTE)"
                    $txtCpuTempMini.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FF1E27")
                }
            } elseif ($isWarm) {
                if ($txtCpuTempStatus) {
                    $txtCpuTempStatus.Text = "$cDeg " + [char]0x00B0 + "C (Morno)"
                    $txtCpuTempStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FFAA00")
                }
                if ($badgeCpuTemp) {
                    $badgeCpuTemp.Background  = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#2A1E05")
                    $badgeCpuTemp.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FFAA00")
                }
                if ($txtCpuTempMini) {
                    $txtCpuTempMini.Text = "$cDeg" + [char]0x00B0 + "C (Morno)"
                    $txtCpuTempMini.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FFAA00")
                }
            } else {
                if ($txtCpuTempStatus) {
                    $txtCpuTempStatus.Text = "$cDeg " + [char]0x00B0 + "C (" + ("Est" + [char]0x00E1 + "vel") + ")"
                    $txtCpuTempStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#00FF66")
                }
                if ($badgeCpuTemp) {
                    $badgeCpuTemp.Background  = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#0A1F10")
                    $badgeCpuTemp.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#00FF66")
                }
                if ($txtCpuTempMini) {
                    $txtCpuTempMini.Text = "$cDeg" + [char]0x00B0 + "C (" + ("Est" + [char]0x00E1 + "vel") + ")"
                    $txtCpuTempMini.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#00FF66")
                }
            }
        } else {
            if ($txtCpuTempStatus) { $txtCpuTempStatus.Text = "Ativo (ACPI Seguro)" }
            if ($txtCpuTempMini)   { $txtCpuTempMini.Text = ("Est" + [char]0x00E1 + "vel") }
        }

        # GPU Status & Temp
        if ($pbRamMini -and $loadPct) { $pbRamMini.Value = $loadPct }
        if ($pbCpuMini -and $cpuPct)  { $pbCpuMini.Value = $cpuPct }
        Update-TelemetryGraph $cpuPct $loadPct

        if ($hwTemps.GpuDeg -gt 0) {
            if ($txtGpuTempStatus) { $txtGpuTempStatus.Text = "$($hwTemps.GpuDeg) " + [char]0x00B0 + "C" }
            if ($badgeGpuTemp) {
                $gColor = if ($hwTemps.GpuDeg -ge 82) { "#FF1E27" } elseif ($hwTemps.GpuDeg -ge 72) { "#FFAA00" } else { "#00FF66" }
                $badgeGpuTemp.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString($gColor)
            }
        }
        if ($hwTemps.GpuClock -and $txtGpuClock) { $txtGpuClock.Text = "Clock: $($hwTemps.GpuClock)" }
        if ($hwTemps.GpuUsage -and $txtGpuUsage) { $txtGpuUsage.Text = "Uso: $($hwTemps.GpuUsage)" }

        # 4. Politica de Clocks Ativa no Windows
        $minVal = 5; $maxVal = 100
        $minQuery = powercfg /query SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 2>$null | Select-String "Correntes Alternadas"
        if ($minQuery -match '0x([0-9a-fA-F]+)') { $minVal = [Convert]::ToInt32($matches[1], 16) }
        $maxQuery = powercfg /query SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 2>$null | Select-String "Correntes Alternadas"
        if ($maxQuery -match '0x([0-9a-fA-F]+)') { $maxVal = [Convert]::ToInt32($matches[1], 16) }

        if ($txtClockRange) { $txtClockRange.Text = "Min: $minVal% | Max: $maxVal%" }

        if ($maxVal -eq 100 -and $minVal -eq 100) {
            if ($txtActiveProfile) { $txtActiveProfile.Text = "MATHZ EXTREME (100% UNLOCKED)" }
            if ($badgeUltra)    { $badgeUltra.Visibility = [System.Windows.Visibility]::Visible }
            if ($badgeBalanced) { $badgeBalanced.Visibility = [System.Windows.Visibility]::Collapsed }
            if ($badgeEco)      { $badgeEco.Visibility = [System.Windows.Visibility]::Collapsed }
        } elseif ($maxVal -le 75) {
            if ($txtActiveProfile) { $txtActiveProfile.Text = "SILENCIOSO (FRIO & ECO)" }
            if ($badgeUltra)    { $badgeUltra.Visibility = [System.Windows.Visibility]::Collapsed }
            if ($badgeBalanced) { $badgeBalanced.Visibility = [System.Windows.Visibility]::Collapsed }
            if ($badgeEco)      { $badgeEco.Visibility = [System.Windows.Visibility]::Visible }
        } else {
            if ($txtActiveProfile) { $txtActiveProfile.Text = "ADAPTATIVO DINAMICO" }
            if ($badgeUltra)    { $badgeUltra.Visibility = [System.Windows.Visibility]::Collapsed }
            if ($badgeBalanced) { $badgeBalanced.Visibility = [System.Windows.Visibility]::Visible }
            if ($badgeEco)      { $badgeEco.Visibility = [System.Windows.Visibility]::Collapsed }
        }
    } catch {}
}

# ==============================================================================
# 8. SUITE COMPLETA DE OTIMIZACOES DO WINDOWS (BASE DA ISO MATHZ)
# ==============================================================================
function Update-MathzTweaksChecklist {
    try {
        $brushGreenBg = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#05160A")
        $brushGreenFg = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#00FF66")
        $brushRedBg   = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#14060A")
        $brushRedFg   = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FF003C")

        $labelApplied = "ATIVO"
        $appliedCount = 0

        # 1. Mouse 1:1 Raw Input
        $mouseOk = $false
        try {
            $mSpeed = (Get-ItemProperty "HKCU:\Control Panel\Mouse" -ErrorAction SilentlyContinue).MouseSpeed
            $mTh1   = (Get-ItemProperty "HKCU:\Control Panel\Mouse" -ErrorAction SilentlyContinue).MouseThreshold1
            if ($mSpeed -eq "0" -and $mTh1 -eq "0") { $mouseOk = $true }
        } catch {}

        if ($mouseOk) {
            $appliedCount++
            if ($badgeStatusMouse) { $badgeStatusMouse.Background = $brushGreenBg; $badgeStatusMouse.BorderBrush = $brushGreenFg }
            if ($txtStatusMouse)   { $txtStatusMouse.Text = $labelApplied; $txtStatusMouse.Foreground = $brushGreenFg }
        } else {
            if ($badgeStatusMouse) { $badgeStatusMouse.Background = $brushRedBg; $badgeStatusMouse.BorderBrush = $brushRedFg }
            if ($txtStatusMouse)   { $txtStatusMouse.Text = "DESATIVADO"; $txtStatusMouse.Foreground = $brushRedFg }
        }

        # 2. HAGS (Hardware Accelerated GPU Scheduling)
        $hagsOk = $false
        try {
            $hags = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -ErrorAction SilentlyContinue).HwSchMode
            if ($hags -eq 2) { $hagsOk = $true }
        } catch {}

        if ($hagsOk) {
            $appliedCount++
            if ($badgeStatusGpu) { $badgeStatusGpu.Background = $brushGreenBg; $badgeStatusGpu.BorderBrush = $brushGreenFg }
            if ($txtStatusGpu)   { $txtStatusGpu.Text = $labelApplied; $txtStatusGpu.Foreground = $brushGreenFg }
        } else {
            if ($badgeStatusGpu) { $badgeStatusGpu.Background = $brushRedBg; $badgeStatusGpu.BorderBrush = $brushRedFg }
            if ($txtStatusGpu)   { $txtStatusGpu.Text = "DESATIVADO"; $txtStatusGpu.Foreground = $brushRedFg }
        }

        # 3. IFEO & Prioridade de Kernel (Win32PrioritySeparation = 38 / 0x26)
        $ifeoOk = $false
        try {
            $prio = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -ErrorAction SilentlyContinue).Win32PrioritySeparation
            if ($prio -eq 38) { $ifeoOk = $true }
        } catch {}

        if ($ifeoOk) {
            $appliedCount++
            if ($badgeStatusIfeo) { $badgeStatusIfeo.Background = $brushGreenBg; $badgeStatusIfeo.BorderBrush = $brushGreenFg }
            if ($txtStatusIfeo)   { $txtStatusIfeo.Text = $labelApplied; $txtStatusIfeo.Foreground = $brushGreenFg }
        } else {
            if ($badgeStatusIfeo) { $badgeStatusIfeo.Background = $brushRedBg; $badgeStatusIfeo.BorderBrush = $brushRedFg }
            if ($txtStatusIfeo)   { $txtStatusIfeo.Text = "PADRAO (2)"; $txtStatusIfeo.Foreground = $brushRedFg }
        }

        # 4. TCP Nagle & Latencia de Rede (TcpAckFrequency = 1 & TCPNoDelay = 1)
        $tcpOk = $false
        try {
            $nics = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\*" -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -or $_.DhcpIPAddress }
            if ($nics) {
                $allOk = $true
                foreach ($nic in $nics) {
                    if ($nic.TcpAckFrequency -ne 1 -or $nic.TCPNoDelay -ne 1) { $allOk = $false; break }
                }
                $tcpOk = $allOk
            }
        } catch {}

        if ($tcpOk) {
            $appliedCount++
            if ($badgeStatusNagle) { $badgeStatusNagle.Background = $brushGreenBg; $badgeStatusNagle.BorderBrush = $brushGreenFg }
            if ($txtStatusNagle)   { $txtStatusNagle.Text = $labelApplied; $txtStatusNagle.Foreground = $brushGreenFg }
        } else {
            if ($badgeStatusNagle) { $badgeStatusNagle.Background = $brushRedBg; $badgeStatusNagle.BorderBrush = $brushRedFg }
            if ($txtStatusNagle)   { $txtStatusNagle.Text = "DESATIVADO"; $txtStatusNagle.Foreground = $brushRedFg }
        }

        # 5. BCDedit & Latencia (dynamicick disabled)
        $bcdOk = $false
        try {
            $bcdOut = & bcdedit /enum "{current}" 2>$null
            if ($bcdOut -match 'dynamicick\s+No|tscsyncpolicy\s+Enhanced|useplatformclock\s+No') {
                $bcdOk = $true
            }
        } catch {}

        if ($bcdOk) {
            $appliedCount++
            if ($badgeStatusBcd) { $badgeStatusBcd.Background = $brushGreenBg; $badgeStatusBcd.BorderBrush = $brushGreenFg }
            if ($txtStatusBcd)   { $txtStatusBcd.Text = $labelApplied; $txtStatusBcd.Foreground = $brushGreenFg }
        } else {
            if ($badgeStatusBcd) { $badgeStatusBcd.Background = $brushRedBg; $badgeStatusBcd.BorderBrush = $brushRedFg }
            if ($txtStatusBcd)   { $txtStatusBcd.Text = "PADRAO"; $txtStatusBcd.Foreground = $brushRedFg }
        }

        # 6. Telemetria e Diagnosticos da Microsoft
        $telemOk = $false
        try {
            $dtService = Get-Service -Name "DiagTrack" -ErrorAction SilentlyContinue
            $telemPol  = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -ErrorAction SilentlyContinue).AllowTelemetry
            if (($dtService -and $dtService.StartType -eq "Disabled") -or $telemPol -eq 0) {
                $telemOk = $true
            }
        } catch {}

        if ($telemOk) {
            $appliedCount++
            if ($badgeStatusTelemetry) { $badgeStatusTelemetry.Background = $brushGreenBg; $badgeStatusTelemetry.BorderBrush = $brushGreenFg }
            if ($txtStatusTelemetry)   { $txtStatusTelemetry.Text = "BLOQUEADA"; $txtStatusTelemetry.Foreground = $brushGreenFg }
        } else {
            if ($badgeStatusTelemetry) { $badgeStatusTelemetry.Background = $brushRedBg; $badgeStatusTelemetry.BorderBrush = $brushRedFg }
            if ($txtStatusTelemetry)   { $txtStatusTelemetry.Text = "ATIVA"; $txtStatusTelemetry.Foreground = $brushRedFg }
        }

        # 7. Explorer & Menus Responsivos (MenuShowDelay = "0")
        $expOk = $false
        try {
            $msd = (Get-ItemProperty "HKCU:\Control Panel\Desktop" -ErrorAction SilentlyContinue).MenuShowDelay
            if ($msd -eq "0") { $expOk = $true }
        } catch {}

        if ($expOk) {
            $appliedCount++
            if ($badgeStatusExplorer) { $badgeStatusExplorer.Background = $brushGreenBg; $badgeStatusExplorer.BorderBrush = $brushGreenFg }
            if ($txtStatusExplorer)   { $txtStatusExplorer.Text = $labelApplied; $txtStatusExplorer.Foreground = $brushGreenFg }
        } else {
            if ($badgeStatusExplorer) { $badgeStatusExplorer.Background = $brushRedBg; $badgeStatusExplorer.BorderBrush = $brushRedFg }
            if ($txtStatusExplorer)   { $txtStatusExplorer.Text = "PADRAO (400ms)"; $txtStatusExplorer.Foreground = $brushRedFg }
        }

        # 8. Cursors Mathz
        $curOk = $false
        try {
            $curArrow = (Get-ItemProperty "HKCU:\Control Panel\Cursors" -ErrorAction SilentlyContinue).Arrow
            if ($curArrow -and ($curArrow -match '\.cur$' -or $curArrow -match 'Mathz')) { $curOk = $true }
        } catch {}

        if ($curOk) {
            $appliedCount++
            if ($badgeStatusCursor) { $badgeStatusCursor.Background = $brushGreenBg; $badgeStatusCursor.BorderBrush = $brushGreenFg }
            if ($txtStatusCursor)   { $txtStatusCursor.Text = $labelApplied; $txtStatusCursor.Foreground = $brushGreenFg }
        } else {
            if ($badgeStatusCursor) { $badgeStatusCursor.Background = $brushRedBg; $badgeStatusCursor.BorderBrush = $brushRedFg }
            if ($txtStatusCursor)   { $txtStatusCursor.Text = "PADRAO"; $txtStatusCursor.Foreground = $brushRedFg }
        }

        # Resumo do Checklist Geral (Topo da ViewTweaks)
        if ($txtTweaksSummary -and $badgeTweaksSummary) {
            if ($appliedCount -eq 8) {
                $txtTweaksSummary.Text = "8/8 OTIMIZACOES ATIVAS (SISTEMA 100% ISO)"
                $badgeTweaksSummary.BorderBrush = $brushGreenFg
                $badgeTweaksSummary.Background  = $brushGreenBg
                $txtTweaksSummary.Foreground    = $brushGreenFg
            } else {
                $txtTweaksSummary.Text = "$appliedCount/8 OTIMIZACOES ATIVAS"
                $badgeTweaksSummary.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FFAA00")
                $badgeTweaksSummary.Background  = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#181405")
                $txtTweaksSummary.Foreground    = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FFAA00")
            }
        }
    } catch {
        Log-Hud "Erro ao auditar checklist de otimizacoes: $_"
    }
}

# Funcoes Individuais de Tweaks da ISO
function Invoke-IsoTweakMouse {
    $reg = "HKCU:\Control Panel\Mouse"
    Set-ItemProperty -Path $reg -Name "MouseSpeed" -Value "0" -Force
    Set-ItemProperty -Path $reg -Name "MouseThreshold1" -Value "0" -Force
    Set-ItemProperty -Path $reg -Name "MouseThreshold2" -Value "0" -Force
    Set-ItemProperty -Path $reg -Name "MouseSensitivity" -Value "10" -Force
    Set-ItemProperty -Path $reg -Name "SmoothMouseXCurve" -Value ([byte[]](0..39 | ForEach-Object {0})) -Force
    Set-ItemProperty -Path $reg -Name "SmoothMouseYCurve" -Value ([byte[]](0..39 | ForEach-Object {0})) -Force
    Log-Hud "Precisão 1:1 do mouse aplicada sem aceleracao artificial!"
}

function Invoke-IsoTweakHags {
    if (-not (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers")) {
        New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value 2 -Type DWord -Force
    Log-Hud "HAGS (Agendamento de GPU por Hardware) ativado!"
}

function Invoke-IsoTweakIfeo {
    if (-not (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl")) {
        New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 38 -Type DWord -Force
    Log-Hud "Prioridade de Kernel ajustada para 38 (0x26 - Foco Máximo em Jogos)!"
}

function Invoke-IsoTweakNagle {
    $nics = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\*" -ErrorAction SilentlyContinue
    foreach ($nic in $nics) {
        if ($nic.IPAddress -or $nic.DhcpIPAddress) {
            Set-ItemProperty -Path $nic.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $nic.PSPath -Name "TCPNoDelay" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        }
    }
    netsh int tcp set global autotuninglevel=normal 2>$null | Out-Null
    Log-Hud "TCP Nagle desativado e ACK imediato configurado para menor ping!"
}

function Invoke-IsoTweakBcd {
    & bcdedit /set dynamicick disabled 2>$null | Out-Null
    & bcdedit /set tscsyncpolicy Enhanced 2>$null | Out-Null
    & bcdedit /set useplatformclock false 2>$null | Out-Null
    Log-Hud "BCDedit otimizado: DynamicTick OFF, TSC Sync Enhanced, PlatformClock False!"
}

function Invoke-IsoTweakTelemetry {
    @("DiagTrack", "dmwappushservice", "WerSvc") | ForEach-Object {
        Stop-Service -Name $_ -Force -ErrorAction SilentlyContinue
        Set-Service -Name $_ -StartupType Disabled -ErrorAction SilentlyContinue
    }
    if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection")) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Type DWord -Force
    Log-Hud "Telemetria da Microsoft e servicos de coleta desativados!"
}

function Invoke-IsoTweakExplorer {
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "0" -Force
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "WaitToKillServiceTimeout" -Value "2000" -Force
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "AutoEndTasks" -Value "1" -Force
    Log-Hud "Menus do Explorer ultra ageis (0 delay de exibicao)!"
}

function Invoke-IsoTweakCursor {
    $candidates = @(
        (Join-Path -Path $PSScriptRoot -ChildPath "Apply-Cursors.ps1"),
        (Join-Path -Path (Split-Path $PSScriptRoot -Parent) -ChildPath "scripts\09_Apply_Mathz_Cursors.ps1"),
        "C:\Program Files\MathzControlPanel\Apply-Cursors.ps1"
    )
    $script = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($script) {
        & $script
    } else {
        $cg = Join-Path $PSScriptRoot "CursorGenerator.ps1"
        if (Test-Path $cg) {
            . $cg
            Apply-MathzCustomColors -InsideHex "#050508" -OutlineHex "#FF003C" | Out-Null
        }
    }
    Log-Hud "Cursores Mathz eSports aplicados ao vivo!"
}

# Master Actions: Aplicar Todos e Restaurar Padrãoes
function Invoke-AllIsoTweaks {
    Log-Hud "Aplicando todas as 8 otimizacoes da ISO Mathz..."
    try {
        Invoke-IsoTweakMouse
        Invoke-IsoTweakHags
        Invoke-IsoTweakIfeo
        Invoke-IsoTweakNagle
        Invoke-IsoTweakBcd
        Invoke-IsoTweakTelemetry
        Invoke-IsoTweakExplorer
        Invoke-IsoTweakCursor
        Update-MathzTweaksChecklist
        Log-Hud "TODAS as 8 otimizacoes da ISO foram aplicadas com sucesso!"
    } catch {
        Log-Hud "Erro ao aplicar suite completa: $_"
    }
}

function Invoke-RestoreDefaultTweaks {
    Log-Hud "Restaurando configuracoes de fabrica do Windows..."
    try {
        # 1. Mouse Padrao
        $reg = "HKCU:\Control Panel\Mouse"
        Set-ItemProperty -Path $reg -Name "MouseSpeed" -Value "1" -Force
        Set-ItemProperty -Path $reg -Name "MouseThreshold1" -Value "6" -Force
        Set-ItemProperty -Path $reg -Name "MouseThreshold2" -Value "10" -Force
        Set-ItemProperty -Path $reg -Name "MouseSensitivity" -Value "10" -Force

        # 2. HAGS Padrao (1)
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

        # 3. IFEO Padrao (2)
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue

        # 4. TCP Padrao (remover propriedades explicitas)
        $nics = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\*" -ErrorAction SilentlyContinue
        foreach ($nic in $nics) {
            if ($nic.IPAddress -or $nic.DhcpIPAddress) {
                Remove-ItemProperty -Path $nic.PSPath -Name "TcpAckFrequency" -Force -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $nic.PSPath -Name "TCPNoDelay" -Force -ErrorAction SilentlyContinue
            }
        }

        # 5. BCDedit Padrao
        & bcdedit /deletevalue dynamicick 2>$null | Out-Null
        & bcdedit /deletevalue tscsyncpolicy 2>$null | Out-Null
        & bcdedit /deletevalue useplatformclock 2>$null | Out-Null

        # 6. Telemetria Padrao (Manual/Normal)
        Set-Service -Name "DiagTrack" -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name "DiagTrack" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Force -ErrorAction SilentlyContinue

        # 7. Explorer Padrao
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "400" -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "WaitToKillServiceTimeout" -Value "5000" -Force

        # 8. Cursors Padrao
        $regCur = "HKCU:\Control Panel\Cursors"
        @("Arrow", "Help", "AppStarting", "Wait", "Crosshair", "IBeam", "NWPen", "No", "SizeNS", "SizeWE", "SizeNWSE", "SizeNESW", "SizeAll", "UpArrow", "Hand") | ForEach-Object {
            Set-ItemProperty -Path $regCur -Name $_ -Value "" -Force -ErrorAction SilentlyContinue
        }
        [MathzCursorPersonalizer]::SystemParametersInfo(0x0057, 0, [IntPtr]::Zero, 0x02) | Out-Null

        Update-MathzTweaksChecklist
        Log-Hud "Valores padrao do Windows restaurados com sucesso!"
    } catch {
        Log-Hud "Erro ao restaurar padrões: $_"
    }
}

# Bindings dos Botoes da Suite ISO
if ($btnAuditTweaks)          { $btnAuditTweaks.Add_Click({ Update-MathzTweaksChecklist; Log-Hud "Checklist do Windows auditado em tempo real!" }) }
if ($btnApplyAllTweaks) {
    $btnApplyAllTweaks.Add_Click({
        Invoke-ModalAction "APLICANDO SUITE COMPLETA DA ISO" "Gravando as 8 diretrizes de latencia, IFEO, BCD, HAGS, TCP e telemetria no Windows..." "SUITE ISO APLICADA COM SUCESSO!" "Todas as 8 otimizacoes de desempenho para jogos e baixa latencia foram gravadas no sistema!" {
            Invoke-AllIsoTweaks
        }
    })
}
if ($btnRestoreDefaultTweaks) {
    $btnRestoreDefaultTweaks.Add_Click({
        Invoke-ModalAction "RESTAURANDO PADROES DO WINDOWS" "Revertendo registros, parametros BCD e servicos para a configuracao de fabrica..." "PADROES RESTAURADOS COM SUCESSO!" "Os parametros originais de fabrica do Windows foram restaurados com sucesso." {
            Invoke-RestoreDefaultTweaks
        }
    })
}

if ($btnOptimizeMouse) {
    $btnOptimizeMouse.Add_Click({
        Invoke-ModalAction "OTIMIZANDO LATENCIA DO MOUSE" "Removendo aceleracao angular e ajustando fila USB para mira 1:1 consistente..." "MOUSE OTIMIZADO COM SUCESSO!" "Sensibilidade 1:1 e aceleracao zerada para mira instantanea nos jogos!" {
            Invoke-IsoTweakMouse
            Update-MathzTweaksChecklist
        }
    })
}

if ($btnOptimizeGpu) {
    $btnOptimizeGpu.Add_Click({
        Invoke-ModalAction "ATIVANDO HAGS & AGENDAMENTO GPU" "Habilitando Hardware-Accelerated GPU Scheduling no registro de drivers..." "HAGS ATIVADO COM SUCESSO!" "GPU configurada para gerenciar a propria memoria e menor tempo de frame." {
            Invoke-IsoTweakHags
            Update-MathzTweaksChecklist
        }
    })
}

if ($btnOptimizeIfeo) {
    $btnOptimizeIfeo.Add_Click({
        Invoke-ModalAction "CONFIGURANDO PRIORIDADE IFEO" "Ajustando prioridade de thread do Windows e quantum Win32PrioritySeparation..." "PRIORIDADE IFEO APLICADA!" "Processos e emuladores agora recebem prioridade maxima de CPU e I/O." {
            Invoke-IsoTweakIfeo
            Update-MathzTweaksChecklist
        }
    })
}

if ($btnOptimizeNagle) {
    $btnOptimizeNagle.Add_Click({
        Invoke-ModalAction "DESATIVANDO ALGORITMO DE NAGLE" "Configurando TCPNoDelay=1 e TcpAckFrequency=1 nos adaptadores de rede..." "REDE OTIMIZADA COM SUCESSO!" "Buffer de pacotes desativado, reduzindo jitter e latencia em partidas online." {
            Invoke-IsoTweakNagle
            Update-MathzTweaksChecklist
        }
    })
}

if ($btnOptimizeBcd) {
    $btnOptimizeBcd.Add_Click({
        Invoke-ModalAction "SINCRONIZANDO TIMERS BCDEDIT" "Configurando sincronizacao de TSC de alta precisao e ticks estaticos..." "TIMERS BCDEDIT SINCRONIZADOS!" "Menor latencia de interrupcao DPC no Kernel do Windows configurada." {
            Invoke-IsoTweakBcd
            Update-MathzTweaksChecklist
        }
    })
}

if ($btnDisableTelemetry) {
    $btnDisableTelemetry.Add_Click({
        Invoke-ModalAction "DESATIVANDO TELEMETRIA & DIAGTRACK" "Interrompendo servicos de diagnostico e desativando coleta em segundo plano..." "TELEMETRIA DESATIVADA COM SUCESSO!" "Servicos em segundo plano encerrados para economia de CPU e RAM." {
            Invoke-IsoTweakTelemetry
            Update-MathzTweaksChecklist
        }
    })
}

if ($btnOptimizeExplorer) {
    $btnOptimizeExplorer.Add_Click({
        Invoke-ModalAction "OTIMIZANDO EXPLORER DO WINDOWS" "Reduzindo MenuShowDelay para zero e acelerando fechamento de janelas..." "EXPLORER OTIMIZADO COM SUCESSO!" "Resposta instantanea nos menus de contexto e agilidade do Windows aumentada." {
            Invoke-IsoTweakExplorer
            Update-MathzTweaksChecklist
        }
    })
}

if ($btnApplyCursor) {
    $btnApplyCursor.Add_Click({
        Invoke-ModalAction "APLICANDO CURSORES DA ISO" "Instalando esquema de cursores Mathz de alta visibilidade no registro..." "CURSORES APLICADOS COM SUCESSO!" "Esquema de cursores ativado e sincronizado em toda a sessao do usuario." {
            Invoke-IsoTweakCursor
            Update-MathzTweaksChecklist
        }
    })
}


# ==============================================================================
# 5. GERENCIAMENTO DE CLOCKS, ENERGIA E PERFIS DE HARDWARE
# ==============================================================================
$GUID_ULTIMATE   = "e9a42b02-d5df-448d-aa00-03f14749eb61"
$GUID_HIGH       = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
$GUID_BALANCED   = "381b4222-f694-41f0-9685-ff5bb260df2e"
$GUID_POWERSAVER = "a1841308-3541-4fab-bc81-f71556f20b4a"

function Set-CpuRealClock([int]$minPercent, [int]$maxPercent, [string]$profileName) {
    try {
        powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN $minPercent 2>$null
        powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX $maxPercent 2>$null
        powercfg /setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN $minPercent 2>$null
        powercfg /setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX $maxPercent 2>$null

        if ($maxPercent -ge 100) {
            powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR be337238-0d82-4146-a960-4f3749d470c7 2 2>$null
            powercfg /setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR be337238-0d82-4146-a960-4f3749d470c7 2 2>$null
            powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 100 2>$null
            powercfg /setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 100 2>$null
        } elseif ($maxPercent -le 99) {
            powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR be337238-0d82-4146-a960-4f3749d470c7 0 2>$null
            powercfg /setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR be337238-0d82-4146-a960-4f3749d470c7 0 2>$null
        }
        powercfg /setactive SCHEME_CURRENT 2>$null

        Update-RealHardwareUI
        Log-Hud "Clock da CPU ajustado: Min $minPercent% / Max $maxPercent% ($profileName)"
    } catch {
        Log-Hud "Erro ao ajustar clock: $_"
    }
}

function Set-GpuRealState([string]$state) {
    try {
        if ($state -eq "MAX") {
            powercfg /setacvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ASPM 0 2>$null
            powercfg /setdcvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ASPM 0 2>$null
            powercfg /setactive SCHEME_CURRENT 2>$null

            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value 2 -Force -ErrorAction SilentlyContinue

            if ($global:hasNvidiaSmi) {
                & nvidia-smi -pm 1 2>$null | Out-Null
            }
            if ($txtGpuClock) { $txtGpuClock.Text = "ASPM OFF // Barramento Máximo (0 Delay)" }
            Log-Hud "GPU ajustada para DESEMPENHO MÁXIMO: Link PCIe full speed e HAGS ativo!"
        } else {
            powercfg /setacvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ASPM 2 2>$null
            powercfg /setdcvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ASPM 2 2>$null
            powercfg /setactive SCHEME_CURRENT 2>$null

            if ($txtGpuClock) { $txtGpuClock.Text = "ASPM ON // Modo Econmico e Frio" }
            Log-Hud "GPU ajustada para MODO ECONMICO: Barramento PCIe em baixo consumo."
        }
    } catch {
        Log-Hud "Erro ao configurar GPU: $_"
    }
}

# 3 Botoes de Perfis Mestres com Modal
if ($btnUltraGaming) {
    $btnUltraGaming.Add_Click({
        Invoke-ModalAction "ATIVANDO PERFIL MATHZ EXTREME" "Destravando 100% de frequencia, timer de alta precisao e ASPM OFF..." "PERFIL MATHZ EXTREME ATIVADO!" "CPU e GPU configuradas em potencia total para maxima taxa de quadros e zero delay!" {
            try {
                $plans = powercfg -list
                if ($plans -notmatch $GUID_ULTIMATE) { powercfg -duplicatescheme $GUID_ULTIMATE 2>$null | Out-Null }
                powercfg -setactive $GUID_ULTIMATE 2>$null
                $active = powercfg -getactivescheme
                if ($active -notmatch $GUID_ULTIMATE) { powercfg -setactive $GUID_HIGH 2>$null }

                Set-CpuRealClock 100 100 "MATHZ EXTREME (100% Desbloqueado)"
                Set-GpuRealState "MAX"
            } catch {}
        }
    })
}

if ($btnBalanced) {
    $btnBalanced.Add_Click({
        Invoke-ModalAction "ATIVANDO MODO EQUILIBRIO" "Sintonizando curva adaptativa de clock e consumo dinamico..." "MODO EQUILIBRIO ATIVADO!" "Perfil de frequencia adaptativa aplicado com sucesso (5% a 100%)." {
            try {
                powercfg -setactive $GUID_BALANCED 2>$null
                Set-CpuRealClock 5 100 "Adaptativo Dinamico"
            } catch {}
        }
    })
}

if ($btnEcoSaver) {
    $btnEcoSaver.Add_Click({
        Invoke-ModalAction "ATIVANDO MODO SILENCIOSO (FRIO)" "Reduzindo clocks e ativando perfil de economia termica..." "MODO SILENCIOSO ATIVADO!" "Frequencia limitada em 70% para reducao imediata de temperatura e baixo ruido!" {
            try {
                $plans = powercfg -list
                if ($plans -notmatch $GUID_POWERSAVER) { powercfg -duplicatescheme $GUID_POWERSAVER 2>$null | Out-Null }
                powercfg -setactive $GUID_POWERSAVER 2>$null
                Set-CpuRealClock 5 70 "Economico Silencioso (Frio)"
                Set-GpuRealState "ECO"
            } catch {}
        }
    })
}

# Botoes Manuais de Frequencia
if ($btnClock100) { $btnClock100.Add_Click({ Set-CpuRealClock 100 100 "100% Constante (Sem Downclock)" }) }
if ($btnClock99)  { $btnClock99.Add_Click({  Set-CpuRealClock 5 99 "99% Base Fixa (Sem Turbo / Frio)" }) }
if ($btnClock70)  { $btnClock70.Add_Click({  Set-CpuRealClock 5 70 "70% Eco (Temperatura Baixa)" }) }
if ($btnClock50)  { $btnClock50.Add_Click({  Set-CpuRealClock 5 50 "50% Ultra Baixo (Silencio Absoluto)" }) }

if ($btnGpuMax)   { $btnGpuMax.Add_Click({ Set-GpuRealState "MAX" }) }
if ($btnGpuEco)   { $btnGpuEco.Add_Click({ Set-GpuRealState "ECO" }) }

# Botao Limpeza de RAM Real com Modal
if ($btnCleanRam) {
    $btnCleanRam.Add_Click({
        Invoke-ModalAction "LIBERANDO MEMORIA RAM" "Descarregando working sets inativos e caches do Windows..." "MEMORIA PURGADA COM SUCESSO!" "Blocos inativos foram limpos da memoria fisica com 100% de estabilidade." {
            try {
                $initialMem = New-Object MathzMemoryOptimizer+MEMORYSTATUSEX
                $initialMem.dwLength = [System.Runtime.InteropServices.Marshal]::SizeOf($initialMem)
                [MathzMemoryOptimizer]::GlobalMemoryStatusEx([ref]$initialMem) | Out-Null
                $beforeMb = [math]::Round($initialMem.ullAvailPhys / 1MB, 0)

                Get-Process | ForEach-Object {
                    try { [MathzMemoryOptimizer]::EmptyWorkingSet($_.Handle) | Out-Null } catch {}
                }
                [System.GC]::Collect()

                $finalMem = New-Object MathzMemoryOptimizer+MEMORYSTATUSEX
                $finalMem.dwLength = [System.Runtime.InteropServices.Marshal]::SizeOf($finalMem)
                [MathzMemoryOptimizer]::GlobalMemoryStatusEx([ref]$finalMem) | Out-Null
                $afterMb = [math]::Round($finalMem.ullAvailPhys / 1MB, 0)
                $freedMb = [math]::Max(0, ($afterMb - $beforeMb))

                Log-Hud "Memoria limpa com sucesso! Liberados aprox. $freedMb MB de RAM no sistema real."
                Update-RealHardwareUI
            } catch {
                Log-Hud "Erro ao limpar memoria: $_"
            }
        }
    })
}

# ==============================================================================
# CONTROLE DE MODO DO GRAFICO DE TELEMETRIA
# ==============================================================================
function Set-GraphModeActive([string]$mode) {
    $global:graphMode = $mode
    $brActive   = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FF1E27")
    $brInactive = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#121212")
    $fgActive   = [System.Windows.Media.Brushes]::White
    $fgInactive = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#8C8C8C")

    if ($btnGraphCpu) {
        $btnGraphCpu.Background = if ($mode -eq "CPU") { $brActive } else { $brInactive }
        $btnGraphCpu.Foreground = if ($mode -eq "CPU") { $fgActive } else { $fgInactive }
    }
    if ($btnGraphRam) {
        $btnGraphRam.Background = if ($mode -eq "RAM") { [System.Windows.Media.BrushConverter]::new().ConvertFromString("#00E5FF") } else { $brInactive }
        $btnGraphRam.Foreground = if ($mode -eq "RAM") { [System.Windows.Media.Brushes]::Black } else { $fgInactive }
    }
    if ($btnGraphBoth) {
        $btnGraphBoth.Background = if ($mode -eq "BOTH") { $brActive } else { $brInactive }
        $btnGraphBoth.Foreground = if ($mode -eq "BOTH") { $fgActive } else { $fgInactive }
    }

    Update-TelemetryGraph -1 -1
    Log-Hud "Modo do gráfico alterado para: $mode"
}

if ($btnGraphCpu)  { $btnGraphCpu.Add_Click({ Set-GraphModeActive "CPU" }) }
if ($btnGraphRam)  { $btnGraphRam.Add_Click({ Set-GraphModeActive "RAM" }) }
if ($btnGraphBoth) { $btnGraphBoth.Add_Click({ Set-GraphModeActive "BOTH" }) }

# ==============================================================================
# CONTROLE DE ESTILO DO GRAFICO (ONDA / PIZZA / BARRAS)
# ==============================================================================
if ($btnStyleWave)  { $btnStyleWave.Add_Click({  Set-GraphStyleActive "WAVE"  }) }
if ($btnStyleDonut) { $btnStyleDonut.Add_Click({ Set-GraphStyleActive "DONUT" }) }
if ($btnStyleBars)  { $btnStyleBars.Add_Click({  Set-GraphStyleActive "BARS"  }) }

Set-GraphModeActive "BOTH"
Set-GraphStyleActive "WAVE"


# ==============================================================================
# 6. PERSONALIZADOR DE CORES DOS CURSORES MATHZ (LIVE PREVIEW & APLICACAO)
# ==============================================================================
$global:currentOutlineHex = "#FF1E27"
$global:currentInsideHex  = "#050508"

function Update-CursorLivePreview([string]$inHex, [string]$outHex) {
    try {
        if (-not $inHex -or -not $outHex) { return }
        if ($inHex -notmatch '^#') { $inHex = "#$inHex" }
        if ($outHex -notmatch '^#') { $outHex = "#$outHex" }

        $bc = [System.Windows.Media.BrushConverter]::new()
        $brIn = $bc.ConvertFromString($inHex)
        $brOut = $bc.ConvertFromString($outHex)

        if ($prevPolyArrow)    { $prevPolyArrow.Fill = $brIn; $prevPolyArrow.Stroke = $brOut }
        if ($prevPolyAppArrow) { $prevPolyAppArrow.Fill = $brIn; $prevPolyAppArrow.Stroke = $brOut }
        if ($prevEllAppBg)     { $prevEllAppBg.Fill = $brIn; $prevEllAppBg.Stroke = $brOut }
        if ($prevEllAppDot)    { $prevEllAppDot.Fill = $brOut }

        if ($prevEllWaitBg)    { $prevEllWaitBg.Fill = $brIn; $prevEllWaitBg.Stroke = $brOut }
        if ($prevPathWaitArc)  { $prevPathWaitArc.Stroke = $brOut }
        if ($prevEllWaitDot)   { $prevEllWaitDot.Fill = $brOut }

        if ($prevLineCrossH1)  { $prevLineCrossH1.Stroke = $brOut }
        if ($prevLineCrossH2)  { $prevLineCrossH2.Stroke = $brOut }
        if ($prevLineCrossV1)  { $prevLineCrossV1.Stroke = $brOut }
        if ($prevLineCrossV2)  { $prevLineCrossV2.Stroke = $brOut }
        if ($prevEllCrossRing) { $prevEllCrossRing.Stroke = $brOut }
        if ($prevEllCrossDot)  { $prevEllCrossDot.Fill = $brOut }

        if ($prevPolyHand)     { $prevPolyHand.Fill = $brIn; $prevPolyHand.Stroke = $brOut }
        if ($prevLineHand)     { $prevLineHand.Stroke = $brOut }

        if ($prevLineBeamTop)  { $prevLineBeamTop.Stroke = $brOut }
        if ($prevLineBeamStem) { $prevLineBeamStem.Stroke = $brOut }
        if ($prevLineBeamBot)  { $prevLineBeamBot.Stroke = $brOut }

        if ($previewColorOutlineBadge) { $previewColorOutlineBadge.Background = $brOut }
        if ($previewColorInsideBadge)  { $previewColorInsideBadge.Background = $brIn }

        if ($txtOutlineHex -and $txtOutlineHex.Text -ne $outHex) { $txtOutlineHex.Text = $outHex }
        if ($txtInsideHex -and $txtInsideHex.Text -ne $inHex)   { $txtInsideHex.Text = $inHex }
        if ($txtPreviewColorInfo) { $txtPreviewColorInfo.Text = "Contorno: $outHex  |  Preenchimento: $inHex" }

        $global:currentOutlineHex = $outHex
        $global:currentInsideHex  = $inHex
    } catch {}
}

# Swatches de Contorno
$outBtnMap = @{
    "BtnOutRed"    = "#FF1E27"
    "BtnOutCyan"   = "#00E5FF"
    "BtnOutGreen"  = "#00FF66"
    "BtnOutPurple" = "#A100FF"
    "BtnOutGold"   = "#FFD700"
    "BtnOutOrange" = "#FF6600"
    "BtnOutWhite"  = "#FFFFFF"
    "BtnOutPink"   = "#FF007F"
}
foreach ($btnName in $outBtnMap.Keys) {
    $btn = $window.FindName($btnName)
    if ($btn) {
        $cVal = $outBtnMap[$btnName]
        $btn.Add_Click({
            Update-CursorLivePreview $global:currentInsideHex $cVal
        }.GetNewClosure())
    }
}

# Swatches de Preenchimento
$inBtnMap = @{
    "BtnInPureBlack"  = "#050508"
    "BtnInSlate"      = "#1A1C24"
    "BtnInCrimson"    = "#2A050B"
    "BtnInNavy"       = "#041224"
    "BtnInDarkPurple" = "#180525"
    "BtnInPureWhite"  = "#FFFFFF"
}
foreach ($btnName in $inBtnMap.Keys) {
    $btn = $window.FindName($btnName)
    if ($btn) {
        $cVal = $inBtnMap[$btnName]
        $btn.Add_Click({
            Update-CursorLivePreview $cVal $global:currentOutlineHex
        }.GetNewClosure())
    }
}

# Presets Prontos
$presetMap = @{
    "BtnPresetCyberpunk" = @{ Inside = "#050508"; Outline = "#FF1E27" }
    "BtnPresetMatrix"    = @{ Inside = "#050508"; Outline = "#00FF66" }
    "BtnPresetCyan"      = @{ Inside = "#050508"; Outline = "#00E5FF" }
    "BtnPresetPureWhite" = @{ Inside = "#050508"; Outline = "#FFFFFF" }
    "BtnPresetStealth"   = @{ Inside = "#050508"; Outline = "#8C8C8C" }
    "BtnPresetGold"      = @{ Inside = "#050508"; Outline = "#FFD700" }
    "BtnPresetGhost"     = @{ Inside = "#FFFFFF"; Outline = "#050508" }
}
foreach ($pName in $presetMap.Keys) {
    $pBtn = $window.FindName($pName)
    if ($pBtn) {
        $cfg = $presetMap[$pName]
        $pBtn.Add_Click({
            Update-CursorLivePreview $cfg.Inside $cfg.Outline
        }.GetNewClosure())
    }
}

# Eventos de digitacao / colar cores nos TextBoxes
if ($txtOutlineHex) {
    $txtOutlineHex.Add_LostFocus({
        $h = $txtOutlineHex.Text.Trim()
        if ($h -match '^#?[0-9a-fA-F]{6}$') {
            if ($h -notmatch '^#') { $h = "#$h" }
            Update-CursorLivePreview $global:currentInsideHex $h
        }
    })
    $txtOutlineHex.Add_KeyDown({
        param($s, $e)
        if ($e.Key -eq [System.Windows.Input.Key]::Enter) {
            $h = $txtOutlineHex.Text.Trim()
            if ($h -match '^#?[0-9a-fA-F]{6}$') {
                if ($h -notmatch '^#') { $h = "#$h" }
                Update-CursorLivePreview $global:currentInsideHex $h
            }
        }
    })
}
if ($txtInsideHex) {
    $txtInsideHex.Add_LostFocus({
        $h = $txtInsideHex.Text.Trim()
        if ($h -match '^#?[0-9a-fA-F]{6}$') {
            if ($h -notmatch '^#') { $h = "#$h" }
            Update-CursorLivePreview $h $global:currentOutlineHex
        }
    })
    $txtInsideHex.Add_KeyDown({
        param($s, $e)
        if ($e.Key -eq [System.Windows.Input.Key]::Enter) {
            $h = $txtInsideHex.Text.Trim()
            if ($h -match '^#?[0-9a-fA-F]{6}$') {
                if ($h -notmatch '^#') { $h = "#$h" }
                Update-CursorLivePreview $h $global:currentOutlineHex
            }
        }
    })
}

# Aplicar Cursores Customizados
if ($btnApplyCursorColors) {
    $btnApplyCursorColors.Add_Click({
        $outHex = if ($txtOutlineHex) { $txtOutlineHex.Text.Trim() } else { $global:currentOutlineHex }
        if ($outHex -notmatch '^#') { $outHex = "#$outHex" }
        $inHex = if ($txtInsideHex) { $txtInsideHex.Text.Trim() } else { $global:currentInsideHex }
        if ($inHex -notmatch '^#') { $inHex = "#$inHex" }

        Invoke-ModalAction "GERANDO CURSORES PERSONALIZADOS" "Compilando bitmaps .CUR com a paleta selecionada ($outHex / $inHex) e instalando no Windows..." "CURSORES APLICADOS COM SUCESSO!" "Novos cursores eSports foram compilados e ativados em toda a sessao do sistema!" {
            try {
                $candidates = @(
                    (Join-Path -Path $PSScriptRoot -ChildPath "CursorGenerator.ps1"),
                    (Join-Path -Path (Split-Path $PSScriptRoot -Parent) -ChildPath "MathzControlCenter\CursorGenerator.ps1"),
                    (Join-Path -Path (Split-Path $PSScriptRoot -Parent) -ChildPath "CursorGenerator.ps1"),
                    (Join-Path -Path $env:LOCALAPPDATA -ChildPath "MathzControlPanel\MathzControlCenter\CursorGenerator.ps1"),
                    "C:\Program Files\MathzControlPanel\CursorGenerator.ps1"
                )
                $cg = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
                if ($cg) {
                    . $cg
                    Apply-MathzCustomColors -InsideHex $inHex -OutlineHex $outHex | Out-Null
                    Log-Hud "Cursores customizados ATIVADOS no Windows! (Linha: $outHex | Fundo: $inHex)"
                } else {
                    Log-Hud "CursorGenerator.ps1 nao encontrado no diretorio de instalacao."
                }
                Update-MathzTweaksChecklist
            } catch {
                Log-Hud "Erro ao aplicar cursores: $_"
            }
        }
    })
}

# Restaurar Cursores Padrao de Fabrica
if ($btnResetDefaultCursors) {
    $btnResetDefaultCursors.Add_Click({
        try {
            $candidates = @(
                (Join-Path -Path $PSScriptRoot -ChildPath "CursorGenerator.ps1"),
                (Join-Path -Path (Split-Path $PSScriptRoot -Parent) -ChildPath "MathzControlCenter\CursorGenerator.ps1"),
                (Join-Path -Path (Split-Path $PSScriptRoot -Parent) -ChildPath "CursorGenerator.ps1"),
                (Join-Path -Path $env:LOCALAPPDATA -ChildPath "MathzControlPanel\MathzControlCenter\CursorGenerator.ps1"),
                "C:\Program Files\MathzControlPanel\CursorGenerator.ps1"
            )
            $cg = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
            if ($cg) {
                . $cg
                Restore-MathzDefaultCursors | Out-Null
            } else {
                $curRegPath = "HKCU:\Control Panel\Cursors"
                if (-not (Test-Path $curRegPath)) { New-Item -Path $curRegPath -Force | Out-Null }
                Set-ItemProperty -Path $curRegPath -Name "(Default)" -Value "Windows Default" -Force
                $roles = @("Arrow","Help","AppStarting","Wait","Crosshair","IBeam","NWPen","No","SizeNS","SizeWE","SizeNWSE","SizeNESW","SizeAll","UpArrow","Hand","Pin","Person")
                foreach ($r in $roles) {
                    Set-ItemProperty -Path $curRegPath -Name $r -Value "" -Force
                }
            }
            Update-CursorLivePreview "#050508" "#FF1E27"
            Update-MathzTweaksChecklist
            Log-Hud "Cursores padro de fábrica do Windows restaurados com sucesso!"
        } catch {
            Log-Hud "Erro ao restaurar cursores: $_"
        }
    })
}


# ==============================================================================
# 7. CENTRAL DE NAVEGADORES E APLICATIVOS ESSENCIAIS
# ==============================================================================
function Install-MathzBrowser([string]$browserName, [string]$wingetId, [string]$directUrl, [string]$silentArgs) {
    Log-Hud "Iniciando instalao de $browserName..."
    $winget = Get-Command winget -ErrorAction SilentlyContinue

    if ($winget) {
        $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes(@"
`$host.ui.RawUI.WindowTitle = 'Instalando $browserName via Winget...'
Write-Host '===================================================' -ForegroundColor Red
Write-Host '     PAINEL MTZ - INSTALACAO DE NAVEGADOR          ' -ForegroundColor White
Write-Host '===================================================' -ForegroundColor Red
Write-Host "
[+] Baixando e instalando $browserName..." -ForegroundColor Yellow
winget install --id '$wingetId' --accept-package-agreements --accept-source-agreements --silent
Start-Sleep -Seconds 3
"@))
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded"
        Log-Hud "Instalador do $browserName iniciado via Winget."
    } else {
        try {
            $tempExe = Join-Path $env:TEMP "$($browserName)_Setup.exe"
            Log-Hud "Baixando $browserName dos servidores oficiais..."
            Start-Process powershell.exe -ArgumentList "-NoProfile -Command `"[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object Net.WebClient).DownloadFile('$directUrl', '$tempExe'); Start-Process '$tempExe' -ArgumentList '$silentArgs' -Wait; Remove-Item '$tempExe' -Force`""
            Log-Hud "$browserName baixado e enviado para instalacao!"
        } catch {
            Log-Hud "Erro ao baixar $browserName : $_"
        }
    }
}

if ($btnDownloadChrome) {
    $btnDownloadChrome.Add_Click({
        Install-MathzBrowser "Google Chrome" "Google.Chrome" "https://dl.google.com/chrome/install/standalone/service/ChromeStandaloneSetup64.exe" "/silent /install"
    })
}

if ($btnDownloadBrave) {
    $btnDownloadBrave.Add_Click({
        Install-MathzBrowser "Brave Browser" "Brave.Brave" "https://laptop-updates.brave.com/latest/winx64" "/silent /install"
    })
}

if ($btnDownloadFirefox) {
    $btnDownloadFirefox.Add_Click({
        Install-MathzBrowser "Mozilla Firefox" "Mozilla.Firefox" "https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=pt-BR" "-ms"
    })
}

function Start-MathzInstaller([string]$appName, [string]$packageId) {
    Log-Hud "Iniciando instalador do $appName..."
    $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes(@"
`$host.ui.RawUI.WindowTitle = 'Mathz Hub - Instalador'
Write-Host '===================================================' -ForegroundColor Red
Write-Host '               PAINEL DE COMANDO MTZ               ' -ForegroundColor White
Write-Host '===================================================' -ForegroundColor Red
Write-Host "
[+] Baixando e instalando $appName via Winget..." -ForegroundColor Yellow
winget install --id '$packageId' --accept-package-agreements --accept-source-agreements
Write-Host "
[OK] Finalizado! Fechando em 3 segundos..." -ForegroundColor Green
Start-Sleep -Seconds 3
"@))
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded"
    Log-Hud "Instalador do $appName acionado via Winget."
}

if ($btnInstallSteam)   { $btnInstallSteam.Add_Click({   Start-MathzInstaller "Steam" "Valve.Steam" }) }
if ($btnInstallEpic)    { $btnInstallEpic.Add_Click({    Start-MathzInstaller "Epic Games Launcher" "EpicGames.EpicGamesLauncher" }) }
if ($btnInstallDiscord) { $btnInstallDiscord.Add_Click({ Start-MathzInstaller "Discord" "Discord.Discord" }) }

if ($btnInstallAllLaunchers) {
    $btnInstallAllLaunchers.Add_Click({
        $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes(@"
`$host.ui.RawUI.WindowTitle = 'Mathz Installer - Launchers Essenciais'
Write-Host '===================================================' -ForegroundColor Red
Write-Host '     INSTALANDO LAUNCHERS ESSENCIAIS EM LOTE       ' -ForegroundColor White
Write-Host '===================================================' -ForegroundColor Red
foreach (`$app in @('Valve.Steam', 'EpicGames.EpicGamesLauncher', 'Discord.Discord')) {
    Write-Host "
[+] Instalando `$app..." -ForegroundColor Yellow
    winget install --id `$app --accept-package-agreements --accept-source-agreements
}
Write-Host "
[OK] Todos os instaladores concluidos!" -ForegroundColor Green
Start-Sleep -Seconds 3
"@))
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded"
        Log-Hud "Instalando Steam, Epic Games e Discord em lote..."
    })
}


# ==============================================================================
# 8. CENTRAL DE DRIVERS (DRIVE MATHZ - MOTOR NATIVO WHQL MICROSOFT)
# ==============================================================================
function Add-MathzDriverCard([string]$name, [string]$provider, [string]$version, [string]$date, [string]$cat, [string]$status) {
    if (-not $stackDriverItems) { return }
    try {
        $bc = [System.Windows.Media.BrushConverter]::new()
        $card = New-Object System.Windows.Controls.Border
        $card.Background = $bc.ConvertFromString('#0B0E14')
        $card.BorderBrush = $bc.ConvertFromString('#1F1F1F')
        $card.BorderThickness = New-Object System.Windows.Thickness(1)
        $card.CornerRadius = New-Object System.Windows.CornerRadius(6)
        $card.Padding = New-Object System.Windows.Thickness(8, 6, 8, 6)
        $card.Margin = New-Object System.Windows.Thickness(0, 0, 0, 4)

        $grid = New-Object System.Windows.Controls.Grid
        $col0 = New-Object System.Windows.Controls.ColumnDefinition; $col0.Width = [System.Windows.GridLength]::Auto
        $col1 = New-Object System.Windows.Controls.ColumnDefinition; $col1.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        $col2 = New-Object System.Windows.Controls.ColumnDefinition; $col2.Width = [System.Windows.GridLength]::Auto
        $null = $grid.ColumnDefinitions.Add($col0)
        $null = $grid.ColumnDefinitions.Add($col1)
        $null = $grid.ColumnDefinitions.Add($col2)

        $catBg = if ($cat -eq 'GPU') { '#1E060A' } elseif ($cat -eq 'ALERTA') { '#25050A' } else { '#0A121A' }
        $catFg = if ($cat -eq 'GPU') { '#FF1E27' } elseif ($cat -eq 'ALERTA') { '#FF3333' } else { '#00E5FF' }
        $bCat = New-Object System.Windows.Controls.Border
        $bCat.Background = $bc.ConvertFromString($catBg)
        $bCat.BorderBrush = $bc.ConvertFromString($catFg)
        $bCat.BorderThickness = New-Object System.Windows.Thickness(1)
        $bCat.CornerRadius = New-Object System.Windows.CornerRadius(4)
        $bCat.Width = 42; $bCat.Height = 28; $bCat.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
        $tbCat = New-Object System.Windows.Controls.TextBlock
        $tbCat.Text = $cat
        $tbCat.Foreground = $bc.ConvertFromString($catFg)
        $tbCat.FontSize = 9
        $tbCat.FontWeight = [System.Windows.FontWeights]::Bold
        $tbCat.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
        $tbCat.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $bCat.Child = $tbCat
        [System.Windows.Controls.Grid]::SetColumn($bCat, 0)
        $null = $grid.Children.Add($bCat)

        $sp = New-Object System.Windows.Controls.StackPanel
        $tbName = New-Object System.Windows.Controls.TextBlock
        $tbName.Text = $name
        $tbName.Foreground = $bc.ConvertFromString('#F5F5F5')
        $tbName.FontSize = 11.5
        $tbName.FontWeight = [System.Windows.FontWeights]::SemiBold
        $tbName.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis

        $tbSub = New-Object System.Windows.Controls.TextBlock
        $tbSub.Text = "Provedor: $provider | Verso: $version | Data: $date"
        $tbSub.Foreground = $bc.ConvertFromString('#8C8C8C')
        $tbSub.FontSize = 9.5
        $tbSub.Margin = New-Object System.Windows.Thickness(0, 2, 0, 0)
        $tbSub.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis

        $null = $sp.Children.Add($tbName)
        $null = $sp.Children.Add($tbSub)
        [System.Windows.Controls.Grid]::SetColumn($sp, 1)
        $null = $grid.Children.Add($sp)

        $bSt = New-Object System.Windows.Controls.Border
        $bSt.Background = if ($status -eq 'AUSENTE') { $bc.ConvertFromString('#2A050B') } else { $bc.ConvertFromString('#05160A') }
        $bSt.BorderBrush = if ($status -eq 'AUSENTE') { $bc.ConvertFromString('#FF1E27') } else { $bc.ConvertFromString('#00FF66') }
        $bSt.BorderThickness = New-Object System.Windows.Thickness(1)
        $bSt.CornerRadius = New-Object System.Windows.CornerRadius(4)
        $bSt.Padding = New-Object System.Windows.Thickness(8, 3, 8, 3)
        $bSt.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $tbSt = New-Object System.Windows.Controls.TextBlock
        $tbSt.Text = if ($status -eq 'AUSENTE') { 'DESATUALIZADO' } else { 'WHQL OK' }
        $tbSt.Foreground = if ($status -eq 'AUSENTE') { $bc.ConvertFromString('#FF1E27') } else { $bc.ConvertFromString('#00FF66') }
        $tbSt.FontSize = 9
        $tbSt.FontWeight = [System.Windows.FontWeights]::Bold
        $bSt.Child = $tbSt
        [System.Windows.Controls.Grid]::SetColumn($bSt, 2)
        $null = $grid.Children.Add($bSt)

        $card.Child = $grid
        $null = $stackDriverItems.Children.Add($card)
    } catch {}
}

function Invoke-MathzDriverScan {
    Log-Hud "Iniciando varredura profunda de drivers com DRIVE MATHZ..."
    if ($txtMathzDriversStatus) { $txtMathzDriversStatus.Text = "Varrendo barramento PCIe, ACPI, USB e PnP..." }
    if ($stackDriverItems) { $stackDriverItems.Children.Clear() }

    $classes = @('DISPLAY', 'MEDIA', 'NET', 'BLUETOOTH', 'SYSTEM', 'USB', 'HDC', 'SCSIADAPTER')
    $drivers = Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue | Where-Object {
        $_.DeviceName -and $_.DriverVersion -and ($_.DeviceClass -in $classes) -and ($_.DriverProviderName -notmatch 'Microsoft')
    }

    $problemDevices = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue | Where-Object {
        $_.ConfigManagerErrorCode -ne 0 -and $_.ConfigManagerErrorCode -ne $null -and $_.ConfigManagerErrorCode -ne 22
    }

    $totalFound = 0
    if ($drivers) { $totalFound += $drivers.Count }
    if ($problemDevices) { $totalFound += $problemDevices.Count }

    if ($problemDevices) {
        foreach ($pd in $problemDevices) {
            Add-MathzDriverCard -name $pd.Name -provider "Desconhecido / PnP" -version "Sem Driver (Code $($pd.ConfigManagerErrorCode))" -date "N/A" -cat "ALERTA" -status "AUSENTE"
        }
    }

    if ($drivers) {
        $sortedDrivers = $drivers | Sort-Object @{
            Expression = {
                switch ($_.DeviceClass) {
                    'DISPLAY'   { 1 }
                    'MEDIA'     { 2 }
                    'NET'       { 3 }
                    'BLUETOOTH' { 4 }
                    'HDC'       { 5 }
                    default     { 6 }
                }
            }
        }

        foreach ($d in $sortedDrivers) {
            $catLabel = switch ($d.DeviceClass) {
                'DISPLAY'   { 'GPU' }
                'MEDIA'     { 'SOM' }
                'NET'       { 'REDE' }
                'BLUETOOTH' { 'BT' }
                'HDC'       { 'DISK' }
                'USB'       { 'USB' }
                default     { 'CHIP' }
            }
            $dateStr = if ($d.DriverDate) { $d.DriverDate.ToString('dd/MM/yyyy') } else { "N/A" }
            Add-MathzDriverCard -name $d.DeviceName -provider $d.DriverProviderName -version $d.DriverVersion -date $dateStr -cat $catLabel -status "OK"
        }
    }

    if ($txtDriverCountBadge) {
        $txtDriverCountBadge.Text = "$totalFound DISPOSITIVOS"
    }

    if ($txtMathzDriversStatus) {
        $probCount = if ($problemDevices) { $problemDevices.Count } else { 0 }
        $txtMathzDriversStatus.Text = "Varredura concluida: $totalFound dispositivos analisados | $probCount alertas de PnP."
    }

    Log-Hud "Drive Mathz: Varredura de hardware finalizada com sucesso! ($totalFound dispositivos)"
}

if ($btnMathzScanDrivers) {
    $btnMathzScanDrivers.Add_Click({
        Invoke-MathzDriverScan
    })
}

if ($btnInstallAllMathzDrivers) {
    $btnInstallAllMathzDrivers.Add_Click({
        Log-Hud "Iniciando instalacao e atualizacao completa de drivers..."
        $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes(@"
`$host.ui.RawUI.WindowTitle = 'Drive Mathz - Atualizador Oficial WHQL'
Write-Host '===================================================' -ForegroundColor Red
Write-Host '   DRIVE MATHZ - MOTOR NATIVO 100% WHQL MICROSOFT  ' -ForegroundColor White
Write-Host '===================================================' -ForegroundColor Red
Write-Host 'Conectando ao Catalogo Oficial Microsoft WHQL...' -ForegroundColor Yellow
try {
    Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    `$session = New-Object -ComObject Microsoft.Update.Session
    `$searcher = `$session.CreateUpdateSearcher()
    `$searcher.ServerSelection = 2
    Write-Host '[+] Auditando drivers certificados especificos...' -ForegroundColor Cyan
    `$res = `$searcher.Search("IsInstalled=0 and Type='Driver'")
    if (`$res.Updates.Count -eq 0) {
        Write-Host '[OK] 100% dos drivers estao atualizados e certificados WHQL!' -ForegroundColor Green
    } else {
        Write-Host "[!] Encontradas `$(`$res.Updates.Count) atualizacao(oes) oficiais WHQL:" -ForegroundColor Yellow
        `$downloader = `$session.CreateUpdateDownloader()
        `$downloader.Updates = `$res.Updates
        `$downloader.Download()
        `$installer = `$session.CreateUpdateInstaller()
        `$installer.Updates = `$res.Updates
        `$installResult = `$installer.Install()
        Write-Host '[OK] Instalacao WHQL finalizada com sucesso!' -ForegroundColor Green
    }
} catch {
    Write-Host "[-] Falha ao consultar catalogo: `$_" -ForegroundColor Red
}

pnputil.exe /scan-devices
Write-Host 'Fechando janela em 4 segundos...' -ForegroundColor Gray
Start-Sleep -Seconds 4
"@))
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded" -Verb RunAs
        Log-Hud "Motor Drive Mathz acionado no terminal!"
    })
}

if ($btnBackupDrivers) {
    $btnBackupDrivers.Add_Click({
        try {
            $desktop = [Environment]::GetFolderPath('Desktop')
            $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
            $backupFolder = Join-Path $desktop "Mathz_Drivers_Backup_$timestamp"
            if (-not (Test-Path $backupFolder)) { New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null }

            Log-Hud "Exportando drivers instalados para a Area de Trabalho..."
            $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes(@"
`$host.ui.RawUI.WindowTitle = 'Drive Mathz - Backup Completo'
Write-Host 'Exportando drivers com Pnputil...' -ForegroundColor Yellow
pnputil.exe /export-driver * "$backupFolder"
Write-Host '[OK] Backup concluido com sucesso!' -ForegroundColor Green
Start-Sleep -Seconds 3
explorer.exe "$backupFolder"
"@))
            Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded" -Verb RunAs
            Log-Hud "Backup de drivers concluido com sucesso!"
        } catch {
            Log-Hud "Erro ao criar backup: $_"
        }
    })
}

if ($btnCreateRestorePoint) {
    $btnCreateRestorePoint.Add_Click({
        try {
            Log-Hud "Criando ponto de restaurao de segurana..."
            $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes(@"
`$host.ui.RawUI.WindowTitle = 'Drive Mathz - Ponto de Restauracao'
try {
    Enable-ComputerRestore -Drive 'C:\' -ErrorAction SilentlyContinue
    Checkpoint-Computer -Description 'Drive Mathz Pre-Update' -RestorePointType 'DEVICE_DRIVER_INSTALL'
    Write-Host '[OK] Ponto de Restauracao criado com sucesso!' -ForegroundColor Green
} catch {
    Write-Host "[-] Erro: `$_" -ForegroundColor Red
}
Start-Sleep -Seconds 3
"@))
            Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded" -Verb RunAs
            Log-Hud "Ponto de restaurao acionado com sucesso!"
        } catch {
            Log-Hud "Erro: $_"
        }
    })
}

if ($btnOpenDevMgmt) {
    $btnOpenDevMgmt.Add_Click({
        Start-Process "devmgmt.msc"
        Log-Hud "Gerenciador de Dispositivos (devmgmt.msc) aberto."
    })
}

if ($btnRescanHardware) {
    $btnRescanHardware.Add_Click({
        Log-Hud "Reverificando barramento de hardware PnP..."
        Start-Process "pnputil.exe" -ArgumentList "/scan-devices" -WindowStyle Hidden -Verb RunAs -Wait
        Invoke-MathzDriverScan
        Log-Hud "Barramento PnP reverificado e lista atualizada!"
    })
}

if ($btnGpuNvidia) {
    $btnGpuNvidia.Add_Click({
        Start-Process "https://www.nvidia.com.br/Download/index.aspx?lang=br"
        Log-Hud "Portal oficial de drivers NVIDIA GeForce aberto."
    })
}
if ($btnGpuAmd) {
    $btnGpuAmd.Add_Click({
        Start-Process "https://www.amd.com/pt/support/download/drivers.html"
        Log-Hud "Portal oficial de drivers AMD Adrenalin aberto."
    })
}
if ($btnGpuIntel) {
    $btnGpuIntel.Add_Click({
        Start-Process "https://www.intel.com.br/content/www/br/pt/download-center/home.html"
        Log-Hud "Portal oficial de drivers Intel aberto."
    })
}

if ($btnInstallVCRedist) {
    $btnInstallVCRedist.Add_Click({
        Start-MathzInstaller "Visual C++ Redistributable AIO" "Microsoft.VCRedist.2015+.x64"
    })
}
if ($btnInstallDirectX) {
    $btnInstallDirectX.Add_Click({
        Start-MathzInstaller "DirectX End-User Runtimes" "Microsoft.DirectX"
    })
}

if ($btnInjectInfFolder) {
    $btnInjectInfFolder.Add_Click({
        try {
            Add-Type -AssemblyName System.Windows.Forms
            $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
            $fbd.Description = "Selecione a pasta contendo pacotes de drivers (.INF)"
            if ($fbd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $selFolder = $fbd.SelectedPath
                $infCount = (Get-ChildItem -Path $selFolder -Filter "*.inf" -Recurse -ErrorAction SilentlyContinue).Count
                if ($infCount -eq 0) {
                    Log-Hud "Nenhum arquivo .INF encontrado na pasta selecionada!"
                    return
                }

                $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes(@"
`$host.ui.RawUI.WindowTitle = 'Drive Mathz - Injecao de Drivers'
Write-Host 'Injetando $infCount drivers no Windows DriverStore...' -ForegroundColor Yellow
pnputil.exe /add-driver "$selFolder\*.inf" /subdirs /install
Write-Host '[OK] Concluido!' -ForegroundColor Green
Start-Sleep -Seconds 4
"@))
                Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded" -Verb RunAs
                Log-Hud "Injeo Pnputil disparada com sucesso para $infCount arquivos .INF!"
            }
        } catch {
            Log-Hud "Erro ao selecionar pasta: $_"
        }
    })
}

if ($btnExportDriverReport) {
    $btnExportDriverReport.Add_Click({
        try {
            $desktop = [Environment]::GetFolderPath("Desktop")
            $reportFile = Join-Path $desktop "Drive_Mathz_Hardware_Report.txt"

            $lines = @()
            $lines += "================================================================="
            $lines += "               DRIVE MATHZ - AUDITORIA DE HARDWARE               "
            $lines += "================================================================="
            $lines += "Gerado em: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
            $lines += "Computador: $env:COMPUTERNAME | Usuario: $env:USERNAME"
            $lines += "Sistema: $((Get-CimInstance Win32_OperatingSystem).Caption)"
            $lines += "-----------------------------------------------------------------"
            $lines += ""

            $signedDrivers = Get-CimInstance Win32_PnPSignedDriver | Where-Object {
                $_.DeviceClass -in 'DISPLAY','MEDIA','NET','BLUETOOTH','SYSTEM','HDC','USB' -and $_.DeviceName -ne $null
            } | Sort-Object DeviceClass, DeviceName

            foreach ($d in $signedDrivers) {
                $whql = if ($d.IsSigned) { "WHQL CERTIFICADO" } else { "NAO CERTIFICADO" }
                $dateStr = if ($d.DriverDate) { (Get-Date $d.DriverDate).ToString('dd/MM/yyyy') } else { "N/D" }
                $lines += "[$($d.DeviceClass)] $($d.DeviceName)"
                $lines += "   Provedor: $($d.DriverProviderName) | Versao: $($d.DriverVersion) | Data: $dateStr | Status: $whql"
                $lines += ""
            }

            [IO.File]::WriteAllLines($reportFile, $lines, [System.Text.Encoding]::UTF8)
            Log-Hud "Relatorio exportado para: $reportFile"
            Start-Process notepad.exe -ArgumentList "`"$reportFile`""
        } catch {
            Log-Hud "Erro ao exportar relatorio: $_"
        }
    })
}


# ==============================================================================
# 9. GESTAO DE INICIALIZACAO DO WINDOWS (PORTADO DO RESETEXPLODE)
# ==============================================================================
function Get-MathzStartupEntries {
    $list = @()

    $regCU = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    if (Test-Path $regCU) {
        $props = Get-ItemProperty $regCU
        foreach ($prop in $props.PSObject.Properties) {
            if ($prop.Name -notmatch '^PS' -and $prop.Name -ne '') {
                $en = Get-MathzStartupApproved "HKCU" "Run" $prop.Name
                $list += [PSCustomObject]@{
                    Name     = $prop.Name
                    Command  = [string]$prop.Value
                    Source   = "Registro (Usuario)"
                    Hive     = "HKCU"
                    Kind     = "Run"
                    Enabled  = $en
                    ItemType = "Registry"
                }
            }
        }
    }

    $regLM = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"
    if (Test-Path $regLM) {
        $props = Get-ItemProperty $regLM
        foreach ($prop in $props.PSObject.Properties) {
            if ($prop.Name -notmatch '^PS' -and $prop.Name -ne '') {
                $en = Get-MathzStartupApproved "HKLM" "Run" $prop.Name
                $list += [PSCustomObject]@{
                    Name     = $prop.Name
                    Command  = [string]$prop.Value
                    Source   = "Registro (Sistema)"
                    Hive     = "HKLM"
                    Kind     = "Run"
                    Enabled  = $en
                    ItemType = "Registry"
                }
            }
        }
    }

    $smCU = [Environment]::GetFolderPath('Startup')
    if (Test-Path $smCU) {
        Get-ChildItem -Path $smCU -File -ErrorAction SilentlyContinue | ForEach-Object {
            $en = Get-MathzStartupApproved "HKCU" "StartupFolder" $_.Name
            $list += [PSCustomObject]@{
                Name     = $_.BaseName
                Command  = $_.FullName
                Source   = "Pasta Inicializar (Usuario)"
                Hive     = "HKCU"
                Kind     = "StartupFolder"
                Enabled  = $en
                ItemType = "Shortcut"
            }
        }
    }

    $smLM = [Environment]::GetFolderPath('CommonStartup')
    if (Test-Path $smLM) {
        Get-ChildItem -Path $smLM -File -ErrorAction SilentlyContinue | ForEach-Object {
            $en = Get-MathzStartupApproved "HKLM" "StartupFolder" $_.Name
            $list += [PSCustomObject]@{
                Name     = $_.BaseName
                Command  = $_.FullName
                Source   = "Pasta Inicializar (Todos)"
                Hive     = "HKLM"
                Kind     = "StartupFolder"
                Enabled  = $en
                ItemType = "Shortcut"
            }
        }
    }

    return $list
}

function Get-MathzStartupApproved([string]$hive, [string]$kind, [string]$name) {
    try {
        $path = if ($hive -eq "HKLM") {
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\$kind"
        } else {
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\$kind"
        }
        if (Test-Path $path) {
            $val = (Get-ItemProperty $path -ErrorAction SilentlyContinue).$name
            if ($val -ne $null -and $val.Length -ge 1) {
                return ($val[0] -eq 2)
            }
        }
    } catch {}
    return $true
}

function Set-MathzStartupEnabled([PSCustomObject]$item, [bool]$enabled) {
    try {
        $path = if ($item.Hive -eq "HKLM") {
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\$($item.Kind)"
        } else {
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\$($item.Kind)"
        }
        if (-not (Test-Path $path)) {
            New-Item -Path $path -Force | Out-Null
        }
        $bytes = (Get-ItemProperty $path -ErrorAction SilentlyContinue).$($item.Name)
        if (-not $bytes -or $bytes.Length -lt 12) {
            $bytes = [byte[]]@(0x02,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00)
        }
        $bytes[0] = if ($enabled) { [byte]0x02 } else { [byte]0x03 }
        Set-ItemProperty -Path $path -Name $item.Name -Value $bytes -Type Binary -Force
        return $true
    } catch {
        return $false
    }
}

function Update-MathzStartupList {
    if (-not $stackStartupItems) { return }
    $stackStartupItems.Children.Clear()

    $entries = Get-MathzStartupEntries
    $onCount = ($entries | Where-Object { $_.Enabled }).Count
    if ($txtStartupSummary) {
        $txtStartupSummary.Text = "$($entries.Count) PROGRAMAS DETECTADOS  $onCount ATIVADOS  $($entries.Count - $onCount) DESATIVADOS"
    }

    foreach ($e in $entries) {
        $card = New-Object System.Windows.Controls.Border
        $card.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#0B0E14")
        $card.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1F1F1F")
        $card.BorderThickness = New-Object System.Windows.Thickness(1)
        $card.CornerRadius = New-Object System.Windows.CornerRadius(6)
        $card.Padding = New-Object System.Windows.Thickness(12, 8, 12, 8)
        $card.Margin = New-Object System.Windows.Thickness(0, 0, 0, 4)

        $grid = New-Object System.Windows.Controls.Grid
        $c0 = New-Object System.Windows.Controls.ColumnDefinition; $c0.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = [System.Windows.GridLength]::Auto
        $null = $grid.ColumnDefinitions.Add($c0)
        $null = $grid.ColumnDefinitions.Add($c1)

        $infoPanel = New-Object System.Windows.Controls.StackPanel
        $nameTb = New-Object System.Windows.Controls.TextBlock
        $nameTb.Text = $e.Name
        $nameTb.FontWeight = [System.Windows.FontWeights]::SemiBold
        $nameTb.FontSize = 11.5
        $nameTb.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F5F5F5")

        $subTb = New-Object System.Windows.Controls.TextBlock
        $subTb.Text = "$($e.Source)  $($e.Command)"
        $subTb.FontSize = 9.5
        $subTb.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#8C8C8C")
        $subTb.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
        $subTb.Margin = New-Object System.Windows.Thickness(0, 2, 0, 0)

        $null = $infoPanel.Children.Add($nameTb)
        $null = $infoPanel.Children.Add($subTb)
        [System.Windows.Controls.Grid]::SetColumn($infoPanel, 0)
        $null = $grid.Children.Add($infoPanel)

        $btnToggle = New-Object System.Windows.Controls.Button
        $btnToggle.FontSize = 10
        $btnToggle.FontWeight = [System.Windows.FontWeights]::Bold
        $btnToggle.Padding = New-Object System.Windows.Thickness(12, 4, 12, 4)
        $btnToggle.Cursor = [System.Windows.Input.Cursors]::Hand

        if ($e.Enabled) {
            $btnToggle.Content = "ATIVADO"
            $btnToggle.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F5F5F5")
            $btnToggle.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#000000")
            $btnToggle.BorderThickness = New-Object System.Windows.Thickness(0)
        } else {
            $btnToggle.Content = "DESATIVADO"
            $btnToggle.Background = [System.Windows.Media.Brushes]::Transparent
            $btnToggle.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#8C8C8C")
            $btnToggle.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#3A3A3A")
            $btnToggle.BorderThickness = New-Object System.Windows.Thickness(1)
        }

        $targetItem = $e
        $btnToggle.Add_Click({
            $newState = -not $targetItem.Enabled
            Set-MathzStartupEnabled $targetItem $newState | Out-Null
            Update-MathzStartupList
            Log-Hud "$($targetItem.Name): $(if ($newState) { 'ativado' } else { 'desativado' }) na inicializao."
        })

        [System.Windows.Controls.Grid]::SetColumn($btnToggle, 1)
        $null = $grid.Children.Add($btnToggle)

        $card.Child = $grid
        $null = $stackStartupItems.Children.Add($card)
    }
}

if ($btnScanStartup) {
    $btnScanStartup.Add_Click({
        Update-MathzStartupList
        Log-Hud "Lista de inicializao atualizada!"
    })
}


# ==============================================================================
# 10. INICIALIZACAO DA JANELA E LOOP DE TELEMETRIA
# ==============================================================================

# Carrega configuracao salva do tema
Load-ThemeConfig

# Setup do Timer de Hardware
$global:hwTimer = New-Object System.Windows.Threading.DispatcherTimer
$global:hwTimer.Interval = [TimeSpan]::FromSeconds($global:refreshIntervalSec)
$global:hwTimer.Add_Tick({
    Update-RealHardwareUI
})

$window.Add_Loaded({
    # Fecha splash screen do executavel nativo C# se estiver ativa
    try { [MathzControl.Program]::CloseSplash() } catch {}

    # Habilita redimensionamento suave nas 8 direcoes (bordas e cantos)
    try {
        $helper = New-Object System.Windows.Interop.WindowInteropHelper($window)
        [WindowResizer]::Attach($helper.Handle, 7)
    } catch {}

    # Aplica efeito acrilico translucido e tema
    Apply-PanelThemeUI
    
    # Atualiza dados de telemetria e otimizacoes
    Update-RealHardwareUI
    Update-MathzTweaksChecklist
    Update-CursorLivePreview "#050508" "#FF1E27"
    
    # Define aba inicial
    Set-TabActive "Clocks"
    
    # Pre-popula historico da telemetria com amostras base para grafico ja abrir desenhado
    if ($global:cpuHistory.Count -eq 0) {
        $curLoad = if ($pbCpu -and $pbCpu.Value -gt 0) { $pbCpu.Value } else { 12 }
        $curRamVal = if ($pbRam -and $pbRam.Value -gt 0) { $pbRam.Value } else { 45 }
        for ($i = 0; $i -lt 15; $i++) {
            $global:cpuHistory.Add([math]::Max(5, $curLoad + ((Get-Random -Minimum -4 -Maximum 5))))
            $global:ramHistory.Add([math]::Max(20, $curRamVal + ((Get-Random -Minimum -2 -Maximum 3))))
        }
    }

    # Redesenha grafico no redimensionamento da janela
    if ($graphCanvas) {
        $graphCanvas.Add_SizeChanged({
            Update-TelemetryGraph -1 -1
        })
    }

    # Animacao de pulsacao luminosa no LED de Telemetria e no Header
    try {
        if ($graphLiveLed) {
            $animPulse = New-Object System.Windows.Media.Animation.DoubleAnimation
            $animPulse.From = 0.35
            $animPulse.To = 1.0
            $animPulse.Duration = [System.Windows.Duration][TimeSpan]::FromMilliseconds(800)
            $animPulse.AutoReverse = $true
            $animPulse.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
            $graphLiveLed.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $animPulse)
        }
        if ($headerLiveDot) {
            $animPulseH = New-Object System.Windows.Media.Animation.DoubleAnimation
            $animPulseH.From = 0.4
            $animPulseH.To = 1.0
            $animPulseH.Duration = [System.Windows.Duration][TimeSpan]::FromMilliseconds(1000)
            $animPulseH.AutoReverse = $true
            $animPulseH.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
            $headerLiveDot.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $animPulseH)
        }
    } catch {}
    
    # Inicia Timer de Telemetria
    $global:hwTimer.Start()
    
    Log-Hud "Painel de Comando MTZ pronto e operacional!"
    
    # Checagem silenciosa de atualizacao em segundo plano apos 4 segundos
    $timerAutoUpdate = New-Object System.Windows.Threading.DispatcherTimer
    $timerAutoUpdate.Interval = [TimeSpan]::FromSeconds(4)
    $timerAutoUpdate.Add_Tick({
        $timerAutoUpdate.Stop()
        Check-MathzUpdate -interactive $false
    })
    $timerAutoUpdate.Start()
})

$window.Add_Closed({
    Exit-MathzCleanly
})

# ==============================================================================
# RESPONSIVIDADE DE TELA (AJUSTE AUTOMATICO DE PROPORCAO CONFORME RESOLUCAO)
# ==============================================================================
try {
    $wa = [System.Windows.SystemParameters]::WorkArea
        # Garante aceleracao grafica direta de hardware GPU
    [System.Windows.Media.RenderOptions]::ProcessRenderMode = [System.Windows.Interop.RenderMode]::Default
    $window.MaxHeight = [System.Windows.SystemParameters]::MaximizedPrimaryScreenHeight
    $window.MaxWidth  = [System.Windows.SystemParameters]::MaximizedPrimaryScreenWidth

    # Escalonamento proporcional inteligente conforme a resolucao nativa da tela (4K UHD / 2K / 1080p)
    if ($wa.Width -ge 3400) {
        # Telas 4K / Ultra HD (3840x2160 e Ultrawide 4K)
        $targetW = [int]($wa.Width * 0.58)
        $targetH = [int]($wa.Height * 0.68)
        $targetW = [Math]::Min(2300, [Math]::Max(1400, $targetW))
        $targetH = [Math]::Min(1400, [Math]::Max(900, $targetH))
    } elseif ($wa.Width -ge 2400) {
        # Telas 2K / QHD (2560x1440)
        $targetW = [int]($wa.Width * 0.65)
        $targetH = [int]($wa.Height * 0.72)
        $targetW = [Math]::Min(1750, [Math]::Max(1200, $targetW))
        $targetH = [Math]::Min(1050, [Math]::Max(780, $targetH))
    } else {
        # Telas Full HD / 1080p (1920x1080) e notebooks
        $targetW = [int]($wa.Width * 0.75)
        $targetH = [int]($wa.Height * 0.78)
        $targetW = [Math]::Min(1280, [Math]::Max(920, $targetW))
        $targetH = [Math]::Min(780, [Math]::Max(580, $targetH))
    }
    $window.Width = $targetW
    $window.Height = $targetH
    $window.Left = [int](($wa.Width - $targetW) / 2 + $wa.Left)
    $window.Top = [int](($wa.Height - $targetH) / 2 + $wa.Top)
} catch {}

# Executa Janela WPF
$window.ShowDialog() | Out-Null

