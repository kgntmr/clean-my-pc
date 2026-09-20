# ============================================================================
#  LOOKING FOR HOW TO START Quietpane?  This file is the app's code.
#  Close this window, then double-click "Start Quietpane" instead.
# ============================================================================
#Requires -Version 5.1
<#
.SYNOPSIS
    Quietpane - privacy, telemetry, bloat and clutter clean-up for Windows 10/11.
    Developed by KomodoWorks - https://www.komodoworks.com - free and open source (MIT).

.DESCRIPTION
    Double-click "Start Quietpane" to open the app. From PowerShell:
        .\Quietpane.ps1                          open the app (asks for administrator rights)
        .\Quietpane.ps1 -Scan                    run only the read-only scan and open the HTML report
        .\Quietpane.ps1 -SelfTest                build the window without showing it (used for testing)
        .\Quietpane.ps1 -SelfTest -Snapshot x.png -SnapshotTab 1
                                                 also render the window to an image (used for screenshots)

    Privacy: this app collects nothing and makes no network connections. See PRIVACY.md.
#>
param(
    [switch]$Scan,
    [switch]$SelfTest,
    [string]$Snapshot,
    [int]$SnapshotTab = 0
)

$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot 'src\Quietpane.psm1'

function Test-IsAdmin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ------------------------------------------------------------------ elevation
if (-not $SelfTest -and -not (Test-IsAdmin)) {
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', "`"$PSCommandPath`"")
    if ($Scan) { $argList += '-Scan' } else { $argList = @('-WindowStyle', 'Hidden') + $argList }
    try {
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList | Out-Null
    } catch {
        Write-Host 'Administrator rights are needed. Nothing was changed.' -ForegroundColor Yellow
        Start-Sleep -Seconds 3
    }
    exit
}

Import-Module $modulePath -Force
$info = Get-QpInfo

function Open-AsUser([string]$Target) {
    # Opening through explorer.exe hands links and files to the normal (non-admin) desktop session,
    # so the browser or mail app does not run with administrator rights.
    Start-Process -FilePath 'explorer.exe' -ArgumentList "`"$Target`""
}

# ------------------------------------------------------------------ scan-only mode
if ($Scan) {
    $host.UI.RawUI.WindowTitle = "Quietpane $($info.Version) - Developed by KomodoWorks.com"
    Write-Host ''
    Write-Host '  Quietpane - read-only scan' -ForegroundColor Yellow
    Write-Host '  Developed by KomodoWorks.com  |  free and open source  |  nothing leaves this PC' -ForegroundColor DarkCyan
    Write-Host ''
    $result = @(Invoke-QpAudit)[-1]
    if ($result) { Open-AsUser $result.Report }
    Write-Host ''
    Write-Host "  Questions or feedback: $($info.BrandUrl)  |  $($info.BrandEmail)" -ForegroundColor DarkCyan
    Read-Host '  Press Enter to close'
    exit
}

# ------------------------------------------------------------------ window
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# KomodoWorks palette (from komodoworks.com): bg #FAF6EC, anchor #0F1B1C, accent #FFB627,
# secondary #1FA187 / readable #117A68, error #A83232. Headings Fraunces, body Sora
# (falls back to Georgia / Segoe UI when those fonts are not installed - no web fonts are downloaded).
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Quietpane - by KomodoWorks" Width="1100" Height="780" MinWidth="860" MinHeight="580"
        WindowStartupLocation="CenterScreen" Background="#FAF6EC" FontFamily="Sora, Segoe UI" Foreground="#0F1B1C">
  <Window.Resources>
    <SolidColorBrush x:Key="Anchor" Color="#0F1B1C"/>
    <SolidColorBrush x:Key="Accent" Color="#FFB627"/>
    <SolidColorBrush x:Key="Teal" Color="#117A68"/>
    <SolidColorBrush x:Key="Line" Color="#E6DFCC"/>
    <SolidColorBrush x:Key="Card" Color="#FFFDF8"/>

    <Style TargetType="Button">
      <Setter Property="Foreground" Value="#0F1B1C"/>
      <Setter Property="Background" Value="#FFFDF8"/>
      <Setter Property="BorderBrush" Value="#0F1B1C"/>
      <Setter Property="BorderThickness" Value="1.5"/>
      <Setter Property="Padding" Value="14,7"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}" Padding="{TemplateBinding Padding}" SnapsToDevicePixels="True">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#EFE7D3"/></Trigger>
        <Trigger Property="IsPressed" Value="True"><Setter Property="Background" Value="#E6DCC3"/></Trigger>
        <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.45"/></Trigger>
      </Style.Triggers>
    </Style>

    <Style x:Key="Primary" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
      <Setter Property="Background" Value="#FFB627"/>
      <Setter Property="BorderBrush" Value="#FFB627"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#FFC75A"/></Trigger>
        <Trigger Property="IsPressed" Value="True"><Setter Property="Background" Value="#F0A416"/></Trigger>
      </Style.Triggers>
    </Style>

    <Style TargetType="TabItem">
      <Setter Property="Foreground" Value="#4B5B5C"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TabItem">
            <Border x:Name="Bd" Background="Transparent" BorderBrush="Transparent" BorderThickness="0,0,0,3" Padding="14,9,14,7" Margin="0,0,2,0">
              <ContentPresenter ContentSource="Header" HorizontalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="Bd" Property="BorderBrush" Value="#117A68"/>
                <Setter Property="Foreground" Value="#0F1B1C"/>
                <Setter Property="FontWeight" Value="SemiBold"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="#EFE7D3"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="Hyperlink">
      <Setter Property="Foreground" Value="#FFB627"/>
      <Setter Property="TextDecorations" Value="None"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True"><Setter Property="TextDecorations" Value="Underline"/></Trigger>
      </Style.Triggers>
    </Style>
  </Window.Resources>

  <DockPanel>
    <!-- Header -->
    <Border DockPanel.Dock="Top" Background="#0F1B1C" Padding="20,12">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <Image x:Name="HeaderLogo" Width="48" Height="48" Margin="0,0,14,0" VerticalAlignment="Center" RenderOptions.BitmapScalingMode="HighQuality"/>
        <StackPanel Grid.Column="1" VerticalAlignment="Center">
          <TextBlock Text="Quietpane" Foreground="#FAF6EC" FontSize="25" FontWeight="SemiBold" FontFamily="Fraunces, Georgia"/>
          <TextBlock Foreground="#C9C2B0" FontSize="12.5" TextWrapping="Wrap" Margin="0,2,0,0"
                     Text="Switch off tracking, remove bloat, free up space. Nothing is collected and nothing leaves this PC."/>
        </StackPanel>
        <StackPanel Grid.Column="2" VerticalAlignment="Center" HorizontalAlignment="Right">
          <TextBlock HorizontalAlignment="Right" Foreground="#C9C2B0" FontSize="12.5">
            <Run Text="Developed by "/><Hyperlink x:Name="LinkHeader" FontWeight="SemiBold">KomodoWorks.com</Hyperlink>
          </TextBlock>
          <TextBlock HorizontalAlignment="Right" Foreground="#8FA3A0" FontSize="11.5" Margin="0,3,0,0" Text="Free - open source - no tracking"/>
        </StackPanel>
      </Grid>
    </Border>

    <!-- Brand strip (bottom edge) -->
    <Border DockPanel.Dock="Bottom" Background="#0F1B1C" Padding="16,6">
      <TextBlock HorizontalAlignment="Center" Foreground="#C9C2B0" FontSize="12">
        <Run Text="Developed by "/><Hyperlink x:Name="LinkFooter" FontWeight="SemiBold">KomodoWorks.com</Hyperlink>
        <Run Text="   |   "/><Hyperlink x:Name="LinkPrivacy">Privacy</Hyperlink>
        <Run Text="   |   "/><Hyperlink x:Name="LinkTerms">Terms</Hyperlink>
        <Run Text="   |   "/><Hyperlink x:Name="LinkContact">Contact</Hyperlink>
        <Run x:Name="VersionRun" Text="   |   v1.0.0   |   No data leaves this PC"/>
      </TextBlock>
    </Border>

    <!-- Action bar -->
    <Border DockPanel.Dock="Bottom" Background="#FFFDF8" BorderBrush="#E6DFCC" BorderThickness="0,1,0,0" Padding="16,10">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <TextBlock VerticalAlignment="Center" Foreground="#4B5B5C" TextTrimming="CharacterEllipsis">
          <Run x:Name="Status" Text="Starting..."/><Run Text="    "/><Hyperlink x:Name="LinkDetails" Foreground="#117A68">Show details</Hyperlink>
        </TextBlock>
        <StackPanel x:Name="AdvancedButtons" Grid.Column="1" Orientation="Horizontal">
          <Button x:Name="BtnRecommended" Content="Select recommended" Margin="0,0,8,0"/>
          <Button x:Name="BtnNone" Content="Select none" Margin="0,0,8,0"/>
          <Button x:Name="BtnPreview" Content="Preview (no changes)" Margin="0,0,8,0"/>
          <Button x:Name="BtnApply" Content="Apply selected" Style="{StaticResource Primary}" Padding="20,7"/>
        </StackPanel>
      </Grid>
    </Border>

    <!-- Content -->
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="*"/>
        <RowDefinition Height="6"/>
        <RowDefinition x:Name="LogRow" Height="0"/>
      </Grid.RowDefinitions>
      <TabControl x:Name="Tabs" Margin="14,12,14,4" Padding="0" Background="#FFFDF8" BorderBrush="#E6DFCC" BorderThickness="1"/>
      <GridSplitter x:Name="LogSplitter" Grid.Row="1" HorizontalAlignment="Stretch" Background="Transparent" Visibility="Collapsed"/>
      <TextBox x:Name="LogBox" Grid.Row="2" Margin="14,0,14,12" IsReadOnly="True" FontFamily="Consolas" FontSize="12"
               VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" TextWrapping="NoWrap"
               Background="#0F1B1C" Foreground="#FAF6EC" BorderThickness="0" Padding="10,8"/>
    </Grid>
  </DockPanel>
</Window>
'@

$window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
$ui = @{}
foreach ($n in 'Tabs', 'LogBox', 'Status', 'BtnRecommended', 'BtnNone', 'BtnPreview', 'BtnApply', 'HeaderLogo',
               'LinkHeader', 'LinkFooter', 'LinkPrivacy', 'LinkTerms', 'LinkContact', 'VersionRun',
               'LinkDetails', 'AdvancedButtons', 'LogRow', 'LogSplitter') { $ui[$n] = $window.FindName($n) }

$brushConv = New-Object System.Windows.Media.BrushConverter
$thickConv = New-Object System.Windows.ThicknessConverter
function Get-Brush([string]$Hex) { $brushConv.ConvertFromString($Hex) }
function Get-Thick([string]$Value) { $thickConv.ConvertFromString($Value) }

function Get-Bitmap([string]$Path) {
    if (-not (Test-Path $Path)) { return $null }
    $bi = New-Object System.Windows.Media.Imaging.BitmapImage
    $bi.BeginInit()
    $bi.UriSource = New-Object System.Uri($Path)
    $bi.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $bi.EndInit()
    $bi.Freeze()
    return $bi
}
$logo = Get-Bitmap $info.LogoPath
if ($logo) { $ui.HeaderLogo.Source = $logo; $window.Icon = $logo }
$ui.VersionRun.Text = "   |   v$($info.Version)   |   No data leaves this PC"

function New-Text {
    param([string]$Text, [double]$Size = 13, [string]$Weight = 'Normal', [string]$Color = '#0F1B1C', [string]$Margin = '0,0,0,6', [string]$Font = '')
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $Text
    $tb.FontSize = $Size
    $tb.TextWrapping = 'Wrap'
    $tb.FontWeight = [System.Windows.FontWeights]::$Weight
    $tb.Foreground = Get-Brush $Color
    $tb.Margin = Get-Thick $Margin
    if ($Font) { $tb.FontFamily = New-Object System.Windows.Media.FontFamily($Font) }
    return $tb
}

function New-Button([string]$Text, [string]$Margin = '0,0,8,0', [switch]$Primary) {
    $b = New-Object System.Windows.Controls.Button
    $b.Content = $Text
    $b.Margin = Get-Thick $Margin
    if ($Primary) { $b.Style = $window.FindResource('Primary') }
    return $b
}

function New-TabPage {
    param([string]$Header, [string]$Key, [string]$Intro)
    $tab = New-Object System.Windows.Controls.TabItem
    $tab.Header = $Header
    $tab.Tag = $Key
    $sv = New-Object System.Windows.Controls.ScrollViewer
    $sv.VerticalScrollBarVisibility = 'Auto'
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Margin = Get-Thick '20,16,20,16'
    if ($Intro) { [void]$sp.Children.Add((New-Text $Intro 13 'Normal' '#4B5B5C' '0,0,0,10')) }
    $sv.Content = $sp
    $tab.Content = $sv
    [void]$ui.Tabs.Items.Add($tab)
    return $sp
}

function New-GroupHeader([string]$Text) { New-Text $Text 16 'SemiBold' '#117A68' '0,18,0,0' 'Fraunces, Georgia' }

$script:Options = @{}
foreach ($k in 'privacy', 'vendors', 'apps', 'cleanup') { $script:Options[$k] = New-Object System.Collections.ArrayList }

function Add-Option {
    param($Panel, [string]$Key, [string]$Id, [string]$Title, [string]$Description, [bool]$Recommended)
    $cb = New-Object System.Windows.Controls.CheckBox
    $cb.Tag = $Id
    $cb.Margin = Get-Thick '0,10,0,0'
    $cb.VerticalContentAlignment = 'Center'
    $label = New-Text $Title 13.5 'SemiBold' '#0F1B1C' '2,0,0,0'
    $cb.Content = $label
    $desc = New-Text $Description 12.5 'Normal' '#4B5B5C' '22,2,0,0'
    [void]$Panel.Children.Add($cb)
    [void]$Panel.Children.Add($desc)
    [void]$script:Options[$Key].Add([pscustomobject]@{ Id = $Id; CheckBox = $cb; Recommended = $Recommended; Label = $label; Title = $Title; Status = 'Unknown' })
}

# ------------------------------------------------------------------ tabs
# 0. Home - the one-click screen for everyone
$homePanel = New-TabPage 'Home' 'home' ''
[void]$homePanel.Children.Add((New-Text 'Make this PC yours again.' 28 'SemiBold' '#0F1B1C' '0,4,0,6' 'Fraunces, Georgia'))
[void]$homePanel.Children.Add((New-Text 'One click switches off the tracking and ads, clears out apps you never asked for and frees up space. Only the safe, recommended bits - and you can undo all of it.' 14.5 'Normal' '#4B5B5C' '0,0,0,18'))

function New-Card([string]$Title) {
    $b = New-Object System.Windows.Controls.Border
    # Narrow enough that all five cards stay on one row even when a scrollbar appears.
    $b.Width = 186
    $b.MinHeight = 108
    $b.Padding = Get-Thick '14,12'
    $b.Margin = Get-Thick '0,0,12,12'
    $b.Background = Get-Brush '#FAF6EC'
    $b.BorderBrush = Get-Brush '#E6DFCC'
    $b.BorderThickness = Get-Thick '1'
    $sp = New-Object System.Windows.Controls.StackPanel
    [void]$sp.Children.Add((New-Text $Title 11.5 'SemiBold' '#4B5B5C' '0,0,0,4'))
    $value = New-Text 'Checking...' 21 'SemiBold' '#0F1B1C' '0,0,0,2' 'Fraunces, Georgia'
    $caption = New-Text '' 12 'Normal' '#4B5B5C' '0'
    [void]$sp.Children.Add($value)
    [void]$sp.Children.Add($caption)
    $b.Child = $sp
    return [pscustomobject]@{ Border = $b; Value = $value; Caption = $caption }
}
$cards = New-Object System.Windows.Controls.WrapPanel
$script:CardTracking = New-Card 'TRACKING & ADS'
$script:CardApps     = New-Card 'UNNEEDED APPS'
$script:CardSpace    = New-Card 'SPACE TO FREE UP'
$script:CardBrands   = New-Card 'HARDWARE & BRANDS'
$script:CardAdware   = New-Card 'ADWARE CHECK'
foreach ($c in $script:CardTracking, $script:CardApps, $script:CardSpace, $script:CardBrands, $script:CardAdware) { [void]$cards.Children.Add($c.Border) }
$script:CardAdware.Value.Text = 'Not checked yet'
$script:CardAdware.Caption.Text = 'Takes about 2 minutes and changes nothing'
[void]$homePanel.Children.Add($cards)

# Two simple bars: how full the disk is, and how much memory is in use.
function New-Meter([string]$Title, [string]$FillColour) {
    $b = New-Object System.Windows.Controls.Border
    $b.Width = 294
    $b.MinHeight = 148
    $b.Padding = Get-Thick '14,12'
    $b.Margin = Get-Thick '0,0,12,12'
    $b.Background = Get-Brush '#FFFDF8'
    $b.BorderBrush = Get-Brush '#E6DFCC'
    $b.BorderThickness = Get-Thick '1'
    $sp = New-Object System.Windows.Controls.StackPanel
    [void]$sp.Children.Add((New-Text $Title 11.5 'SemiBold' '#4B5B5C' '0,0,0,4'))
    $value = New-Text 'Checking...' 21 'SemiBold' '#0F1B1C' '0,0,0,8' 'Fraunces, Georgia'
    [void]$sp.Children.Add($value)
    $track = New-Object System.Windows.Controls.Border
    $track.Height = 16
    $track.Width = 272
    $track.HorizontalAlignment = 'Left'
    $track.Background = Get-Brush '#EDE6D5'
    $track.CornerRadius = New-Object System.Windows.CornerRadius(8)
    $fill = New-Object System.Windows.Controls.Border
    $fill.Height = 16
    $fill.Width = 0
    $fill.HorizontalAlignment = 'Left'
    $fill.Background = Get-Brush $FillColour
    $fill.CornerRadius = New-Object System.Windows.CornerRadius(8)
    $track.Child = $fill
    [void]$sp.Children.Add($track)
    $caption = New-Text '' 12 'Normal' '#4B5B5C' '0,6,0,0'
    $delta = New-Text '' 13 'SemiBold' '#117A68' '0,4,0,0'
    $delta.Visibility = 'Collapsed'
    [void]$sp.Children.Add($caption)
    [void]$sp.Children.Add($delta)
    $b.Child = $sp
    return [pscustomobject]@{ Border = $b; Value = $value; Fill = $fill; Caption = $caption; Delta = $delta; TrackWidth = 272 }
}
$meters = New-Object System.Windows.Controls.WrapPanel
$script:MeterSpace = New-Meter 'SPACE ON THIS PC' '#117A68'
$script:MeterMemory = New-Meter 'MEMORY IN USE' '#FFB627'
[void]$meters.Children.Add($script:MeterSpace.Border)
[void]$meters.Children.Add($script:MeterMemory.Border)
[void]$homePanel.Children.Add($meters)
$script:TotalsText = New-Text '' 13 'Normal' '#117A68' '2,0,0,10'
$script:TotalsText.Visibility = 'Collapsed'
[void]$homePanel.Children.Add($script:TotalsText)

$homeButtons = New-Object System.Windows.Controls.WrapPanel
$homeButtons.Margin = Get-Thick '0,6,0,0'
$btnOneClick = New-Button 'Quiet my PC now' -Primary
$btnOneClick.FontSize = 18
$btnOneClick.Padding = Get-Thick '36,14'
$btnOneClick.Margin = Get-Thick '0,0,12,8'
$btnHomeScan = New-Button 'Check for adware'
$btnHomeScan.FontSize = 15
$btnHomeScan.Padding = Get-Thick '22,14'
$btnHomeScan.Margin = Get-Thick '0,0,12,8'
[void]$homeButtons.Children.Add($btnOneClick)
[void]$homeButtons.Children.Add($btnHomeScan)
[void]$homePanel.Children.Add($homeButtons)
[void]$homePanel.Children.Add((New-Text 'You will see exactly what is about to change before it happens, you can undo all of it, and files only ever go to your Recycle Bin.' 12.5 'Normal' '#4B5B5C' '0,6,0,0'))
[void]$homePanel.Children.Add((New-Text 'A good start, not a guarantee: this tidies up the usual troublemakers, but it cannot promise a PC is clean. If yours still feels wrong afterwards, run a deeper scan with a dedicated security tool too.' 12.5 'Normal' '#9A6700' '0,8,0,0'))

$script:ResultPanel = New-Object System.Windows.Controls.Border
$script:ResultPanel.Visibility = 'Collapsed'
$script:ResultPanel.Margin = Get-Thick '0,18,0,0'
$script:ResultPanel.Padding = Get-Thick '18,14'
$script:ResultPanel.Background = Get-Brush '#EAF5F1'
$script:ResultPanel.BorderBrush = Get-Brush '#117A68'
$script:ResultPanel.BorderThickness = Get-Thick '4,0,0,0'
$resultStack = New-Object System.Windows.Controls.StackPanel
$script:ResultTitle = New-Text '' 22 'SemiBold' '#117A68' '0,0,0,6' 'Fraunces, Georgia'
$script:ResultText = New-Text '' 14 'Normal' '#0F1B1C' '0,0,0,12'
$resultButtons = New-Object System.Windows.Controls.WrapPanel
$btnRestart = New-Button 'Restart now' -Primary
$btnUndoAll = New-Button 'Undo everything I just did'
$btnShowDetails = New-Button 'Show what changed'
foreach ($b in $btnRestart, $btnUndoAll, $btnShowDetails) { $b.Margin = Get-Thick '0,0,10,4'; [void]$resultButtons.Children.Add($b) }
[void]$resultStack.Children.Add($script:ResultTitle)
[void]$resultStack.Children.Add($script:ResultText)
[void]$resultStack.Children.Add($resultButtons)
$script:ResultPanel.Child = $resultStack
[void]$homePanel.Children.Add($script:ResultPanel)
[void]$homePanel.Children.Add((New-Text 'Rather choose yourself? The Privacy, Telemetry, Apps and Free up space tabs let you pick item by item, and Preview shows what would happen without touching anything.' 12.5 'Normal' '#4B5B5C' '0,20,0,0'))

# 1. Scan
$scanPanel = New-TabPage 'Safety scan' 'scan' ('A careful look around your PC for the tricks adware uses: odd startup entries, hidden tasks, browser add-ons, tampered programs and more. It changes nothing, and the report opens in your browser when it finishes.')
$scanButtons = New-Object System.Windows.Controls.StackPanel
$scanButtons.Orientation = 'Horizontal'
$scanButtons.Margin = Get-Thick '0,6,0,10'
$btnScan = New-Button 'Run scan' -Primary
$btnOpenReport = New-Button 'Open last report'
$btnOpenReport.IsEnabled = $false
[void]$scanButtons.Children.Add($btnScan)
[void]$scanButtons.Children.Add($btnOpenReport)
[void]$scanPanel.Children.Add($scanButtons)
$scanSummary = New-Text 'No scan yet.' 15 'SemiBold' '#0F1B1C' '0,6,0,6' 'Fraunces, Georgia'
[void]$scanPanel.Children.Add($scanSummary)
[void]$scanPanel.Children.Add((New-Text 'High means have a look now, Medium means worth a look, Info is just so you know. If something suspicious turns up, the report also shows what was installed at the same moment - usually the culprit.' 12.5 'Normal' '#4B5B5C'))

# 2. Privacy & telemetry - one collapsed section per group, so nothing shouts at you
function New-Section([string]$Header) {
    $ex = New-Object System.Windows.Controls.Expander
    $ex.Header = New-Text $Header 14.5 'SemiBold' '#117A68' '0' 'Fraunces, Georgia'
    $ex.Margin = Get-Thick '0,8,0,0'
    $ex.IsExpanded = $false
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Margin = Get-Thick '8,2,0,10'
    $ex.Content = $sp
    return [pscustomobject]@{ Expander = $ex; Content = $sp }
}
$privacyPanel = New-TabPage 'Privacy' 'privacy' ('Tracking, ads, tips and background bits in Windows, Office and your browsers. Open a section to see what is inside - anything already done says so. Your security settings and Windows Update are never touched.')
foreach ($g in @((Get-QpCatalog privacy).Items | ForEach-Object { $_.Group } | Select-Object -Unique)) {
    $items = @((Get-QpCatalog privacy).Items | Where-Object { $_.Group -eq $g })
    $sec = New-Section ('{0}   ({1} settings)' -f $g, $items.Count)
    foreach ($item in $items) {
        Add-Option -Panel $sec.Content -Key 'privacy' -Id $item.Id -Title $item.Title -Description $item.Description -Recommended ([bool]$item.Recommended)
    }
    [void]$privacyPanel.Children.Add($sec.Expander)
}

# 3. Telemetry - the brand and hardware software that came with this PC
$vendorPanel = New-TabPage 'Telemetry' 'vendors' ('')
[void]$vendorPanel.Children.Add((New-Text 'Most PCs arrive with extras from the people who made them - the laptop maker, the graphics chip, the processor. A lot of it sits in the background and quietly reports home.' 13.5 'Normal' '#4B5B5C' '0,0,0,6'))
[void]$vendorPanel.Children.Add((New-Text 'Below is only what was actually found on this PC. Switching these off leaves your drivers alone, and the apps themselves still open and work normally.' 13.5 'Normal' '#4B5B5C' '0,0,0,12'))
$script:VendorIntro = New-Text 'Having a look at what came with this PC...' 13 'SemiBold' '#0F1B1C' '0,0,0,6'
[void]$vendorPanel.Children.Add($script:VendorIntro)
$script:VendorList = New-Object System.Windows.Controls.StackPanel
[void]$vendorPanel.Children.Add($script:VendorList)

# 4. Apps
$appsPanel = New-TabPage 'Apps' 'apps' ('Apps that came with Windows or were pushed onto this PC. Your Store, Camera, Photos, Calculator, Notepad, Paint, Snipping Tool and anything driver-related are never on this list. Changed your mind later? The Microsoft Store has them all.')
$script:DeprovisionCb = New-Object System.Windows.Controls.CheckBox
$script:DeprovisionCb.Content = New-Text 'Also stop removed apps being installed for new user accounts on this PC' 12.5 'Normal' '#0F1B1C' '2,0,0,0'
$script:DeprovisionCb.IsChecked = $true
$script:DeprovisionCb.Margin = Get-Thick '0,0,0,8'
[void]$appsPanel.Children.Add($script:DeprovisionCb)
$script:AppsList = New-Object System.Windows.Controls.StackPanel
[void]$script:AppsList.Children.Add((New-Text 'Looking for installed apps...' 13 'Normal' '#4B5B5C'))
[void]$appsPanel.Children.Add($script:AppsList)

# 5. Clean-up
$cleanupPanel = New-TabPage 'Free up space' 'cleanup' ('Leftovers nobody needs: temporary files, crash dumps, old installers and caches. Everything goes to your Recycle Bin, so you have the final say. Close your games and browsers first.')
$script:CleanupList = New-Object System.Windows.Controls.StackPanel
[void]$script:CleanupList.Children.Add((New-Text 'Measuring sizes...' 13 'Normal' '#4B5B5C'))
[void]$cleanupPanel.Children.Add($script:CleanupList)

# 6. Undo
$undoPanel = New-TabPage 'Undo' 'undo' ('Changed your mind? Every change is saved as a restore point, and Undo puts the settings back exactly as they were. Files are waiting in your Recycle Bin, and removed apps come back from the Microsoft Store.')
$script:UndoList = New-Object System.Windows.Controls.ListBox
$script:UndoList.MinHeight = 160
$script:UndoList.Margin = Get-Thick '0,6,0,8'
$script:UndoList.BorderBrush = Get-Brush '#E6DFCC'
[void]$undoPanel.Children.Add($script:UndoList)
$undoButtons = New-Object System.Windows.Controls.StackPanel
$undoButtons.Orientation = 'Horizontal'
$btnUndo = New-Button 'Undo selected restore point' -Primary
$btnUndoRefresh = New-Button 'Refresh list'
[void]$undoButtons.Children.Add($btnUndo)
[void]$undoButtons.Children.Add($btnUndoRefresh)
[void]$undoPanel.Children.Add($undoButtons)

# 7. About, privacy & terms
$aboutPanel = New-TabPage 'About' 'about' ''
$aboutHead = New-Object System.Windows.Controls.StackPanel
$aboutHead.Orientation = 'Horizontal'
$aboutHead.Margin = Get-Thick '0,0,0,12'
if ($logo) {
    $img = New-Object System.Windows.Controls.Image
    $img.Source = $logo; $img.Width = 72; $img.Height = 72; $img.Margin = Get-Thick '0,0,16,0'
    [void]$aboutHead.Children.Add($img)
}
$aboutTitle = New-Object System.Windows.Controls.StackPanel
$aboutTitle.VerticalAlignment = 'Center'
[void]$aboutTitle.Children.Add((New-Text "Quietpane $($info.Version)" 24 'SemiBold' '#0F1B1C' '0,0,0,2' 'Fraunces, Georgia'))
[void]$aboutTitle.Children.Add((New-Text 'Developed by KomodoWorks - an independent technology studio in Dublin, Ireland.' 13 'Normal' '#4B5B5C' '0'))
[void]$aboutHead.Children.Add($aboutTitle)
[void]$aboutPanel.Children.Add($aboutHead)

[void]$aboutPanel.Children.Add((New-GroupHeader 'Our promise'))
foreach ($line in @(
        'Collects nothing: no accounts, analytics, telemetry, crash reports, ads, cookies or tracking.',
        'Connects to nothing: the app makes no network requests. Links only open when you click them.',
        'Changes nothing without you: every change is previewed, confirmed, recorded and can be undone.',
        'Deletes nothing permanently: files go to your Recycle Bin, scheduled tasks are disabled, not deleted.',
        'Hides nothing: plain-text PowerShell you can read line by line. No installer, nothing hidden.',
        'Free and open source under the MIT License. Not affiliated with Microsoft, NVIDIA, Intel or Google.')) {
    [void]$aboutPanel.Children.Add((New-Text ('-  ' + $line) 13 'Normal' '#0F1B1C' '4,4,0,0'))
}

$aboutButtons = New-Object System.Windows.Controls.WrapPanel
$aboutButtons.Margin = Get-Thick '0,16,0,8'
$btnSite = New-Button 'Visit KomodoWorks.com' -Primary
$btnMail = New-Button "Email $($info.BrandEmail)"
$btnRepo = New-Button 'Source code on GitHub'
$btnData = New-Button 'Open this app''s data folder'
foreach ($b in $btnSite, $btnMail, $btnRepo, $btnData) { $b.Margin = Get-Thick '0,0,8,8'; [void]$aboutButtons.Children.Add($b) }
[void]$aboutPanel.Children.Add($aboutButtons)

function Get-DocText([string]$File) {
    $p = Join-Path $PSScriptRoot $File
    if (-not (Test-Path $p)) { return "$File was not found next to the app. It is available in the GitHub repository." }
    $t = Get-Content -LiteralPath $p -Raw
    $t = $t -replace '\*\*', '' -replace '(?m)^#{1,6}\s*', '' -replace '\[([^\]]+)\]\(([^)]+)\)', '$1 ($2)'
    return $t.Trim()
}
function New-DocExpander([string]$Header, [string]$File) {
    $ex = New-Object System.Windows.Controls.Expander
    $ex.Header = New-Text $Header 15 'SemiBold' '#117A68' '0' 'Fraunces, Georgia'
    $ex.Margin = Get-Thick '0,10,0,0'
    $tb = New-Object System.Windows.Controls.TextBox
    $tb.Text = Get-DocText $File
    $tb.IsReadOnly = $true
    $tb.TextWrapping = 'Wrap'
    $tb.BorderThickness = Get-Thick '0'
    $tb.Background = Get-Brush '#FAF6EC'
    $tb.Padding = Get-Thick '12,10'
    $tb.FontSize = 12.5
    $tb.Margin = Get-Thick '0,6,0,0'
    $ex.Content = $tb
    return $ex
}
$script:PrivacyExpander = New-DocExpander 'Privacy Policy' 'PRIVACY.md'
$script:TermsExpander = New-DocExpander 'Terms of Use' 'TERMS.md'
$script:LicenseExpander = New-DocExpander 'License (MIT)' 'LICENSE'
$script:SecurityExpander = New-DocExpander 'Security & genuine copies' 'SECURITY.md'
foreach ($e in $script:PrivacyExpander, $script:TermsExpander, $script:LicenseExpander, $script:SecurityExpander) { [void]$aboutPanel.Children.Add($e) }

$script:ActionButtons = @($ui.BtnRecommended, $ui.BtnNone, $ui.BtnPreview, $ui.BtnApply, $btnScan, $btnUndo, $btnUndoRefresh, $btnOneClick, $btnHomeScan, $btnUndoAll, $btnRestart)

# ------------------------------------------------------------------ links
function Show-Doc($expander) {
    $ui.Tabs.SelectedIndex = $ui.Tabs.Items.Count - 1
    $expander.IsExpanded = $true
    $expander.BringIntoView()
}
$ui.LinkHeader.Add_Click({ Open-AsUser $info.BrandUrl })
$ui.LinkFooter.Add_Click({ Open-AsUser $info.BrandUrl })
$ui.LinkContact.Add_Click({ Open-AsUser "mailto:$($info.BrandEmail)?subject=Clean%20My%20PC" })
$ui.LinkPrivacy.Add_Click({ Show-Doc $script:PrivacyExpander })
$ui.LinkTerms.Add_Click({ Show-Doc $script:TermsExpander })
$btnSite.Add_Click({ Open-AsUser $info.BrandUrl })
$btnRepo.Add_Click({ Open-AsUser $info.RepoUrl })
$btnMail.Add_Click({ Open-AsUser "mailto:$($info.BrandEmail)?subject=Clean%20My%20PC" })
$btnData.Add_Click({
    if (Test-Path $info.DataRoot) { Open-AsUser $info.DataRoot }
    else { [void][System.Windows.MessageBox]::Show('Nothing saved yet. Restore points show up here after your first change.', 'Quietpane') }
})

# ------------------------------------------------------------------ background worker
$script:Sync = [hashtable]::Synchronized(@{ Queue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[string]'; Result = $null })
$script:Job = $null
$script:FirstLoad = $true
$script:LastReport = $null
$script:LastRestorePoint = $null
$script:HomeCounts = $null
$script:LogVisible = $false

function Update-Buttons {
    $key = [string]$ui.Tabs.SelectedItem.Tag
    $optionTab = $key -in 'privacy', 'vendors', 'apps', 'cleanup'
    $idle = -not $script:Job
    # The pick-and-choose buttons only appear on the tabs where they do something.
    $ui.AdvancedButtons.Visibility = if ($optionTab) { 'Visible' } else { 'Collapsed' }
    foreach ($b in $ui.BtnRecommended, $ui.BtnNone, $ui.BtnPreview, $ui.BtnApply) { $b.IsEnabled = ($optionTab -and $idle) }
    foreach ($b in $btnScan, $btnUndo, $btnUndoRefresh, $btnOneClick, $btnHomeScan, $btnUndoAll, $btnRestart) { $b.IsEnabled = $idle }
    $btnUndoAll.IsEnabled = $idle -and [bool]$script:LastRestorePoint
    $btnOpenReport.IsEnabled = [bool]$script:LastReport
}

function Set-Busy([bool]$Busy, [string]$Text) {
    $ui.Status.Text = $Text
    if ($Busy) {
        foreach ($b in $script:ActionButtons) { $b.IsEnabled = $false }
        $window.Cursor = [System.Windows.Input.Cursors]::AppStarting
    } else {
        $window.Cursor = $null
        Update-Buttons
    }
}

function Start-Work {
    param([scriptblock]$Work, [hashtable]$Params = @{}, [scriptblock]$OnDone, [string]$StatusText = 'Working...')
    if ($script:Job) { return }
    $script:Sync.Result = $null
    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'STA'
    $rs.ThreadOptions = 'ReuseThread'
    $rs.Open()
    $rs.SessionStateProxy.SetVariable('Sync', $script:Sync)
    $rs.SessionStateProxy.SetVariable('ModulePath', $modulePath)
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    $wrapper = {
        param($WorkText, $Params)
        try {
            Import-Module $ModulePath -Force
            Set-QpLogSink { param($line) $Sync.Queue.Enqueue($line) }
            $Sync.Result = & ([scriptblock]::Create($WorkText)) @Params
        } catch {
            $Sync.Queue.Enqueue(('[{0}] ERROR   {1}' -f (Get-Date -Format 'HH:mm:ss'), $_.Exception.Message))
        }
    }
    [void]$ps.AddScript($wrapper.ToString()).AddArgument($Work.ToString()).AddArgument($Params)
    $script:Job = @{ PS = $ps; RS = $rs; Handle = $ps.BeginInvoke(); OnDone = $OnDone }
    Set-Busy $true $StatusText
}

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(150)
$timer.Add_Tick({
    $line = $null
    $got = $false
    while ($script:Sync.Queue.TryDequeue([ref]$line)) { $ui.LogBox.AppendText($line + [Environment]::NewLine); $got = $true }
    if ($got) { $ui.LogBox.ScrollToEnd() }
    if ($script:Job -and $script:Job.Handle.IsCompleted) {
        $job = $script:Job
        $script:Job = $null
        try { [void]$job.PS.EndInvoke($job.Handle) } catch { $ui.LogBox.AppendText("ERROR: $($_.Exception.Message)" + [Environment]::NewLine) }
        $job.PS.Dispose()
        $job.RS.Dispose()
        while ($script:Sync.Queue.TryDequeue([ref]$line)) { $ui.LogBox.AppendText($line + [Environment]::NewLine) }
        $ui.LogBox.ScrollToEnd()
        Set-Busy $false 'All done - nothing running.'
        if ($job.OnDone) { & $job.OnDone $script:Sync.Result }
    }
})

# ------------------------------------------------------------------ refresh state from the PC
function Set-OptionStatus($opt, [string]$Status) {
    $opt.Status = $Status
    switch ($Status) {
        'Applied'       { $opt.Label.Text = "$($opt.Title)   [already applied]"; $opt.Label.Foreground = Get-Brush '#117A68' }
        'Partial'       { $opt.Label.Text = "$($opt.Title)   [partly applied]";  $opt.Label.Foreground = Get-Brush '#9A6700' }
        'NotApplicable' { $opt.Label.Text = "$($opt.Title)   [not on this PC]";  $opt.Label.Foreground = Get-Brush '#8A9696' }
        default         { $opt.Label.Text = $opt.Title;                          $opt.Label.Foreground = Get-Brush '#0F1B1C' }
    }
}

function Select-Recommended([string]$Key) {
    foreach ($o in $script:Options[$Key]) {
        $o.CheckBox.IsChecked = ($o.Recommended -and $o.Status -notin 'Applied', 'NotApplicable')
    }
}

function Update-FromState($state) {
    if (-not $state) { return }
    foreach ($o in $script:Options['privacy']) { Set-OptionStatus $o ([string]$state.Privacy[$o.Id]) }
    Update-VendorTab @($state.Vendors)
    $script:AppsList.Children.Clear()
    $script:Options['apps'].Clear()
    $apps = @($state.Apps | Where-Object { $_ })
    if ($apps.Count -eq 0) { [void]$script:AppsList.Children.Add((New-Text 'No known bloat apps found on this PC.' 13 'SemiBold' '#117A68')) }
    foreach ($a in $apps) { Add-Option -Panel $script:AppsList -Key 'apps' -Id $a.Name -Title $a.Title -Description ("{0}  ({1})" -f $a.Description, $a.Name) -Recommended ([bool]$a.Recommended) }
    $script:CleanupList.Children.Clear()
    $script:Options['cleanup'].Clear()
    foreach ($c in @($state.Cleanup | Where-Object { $_ })) {
        $title = '{0}   ({1})' -f $c.Title, (Format-QpBytes $c.SizeBytes)
        Add-Option -Panel $script:CleanupList -Key 'cleanup' -Id $c.Id -Title $title -Description $c.Description -Recommended ([bool]$c.Recommended)
        if ($c.SizeBytes -le 0) {
            $last = $script:Options['cleanup'][$script:Options['cleanup'].Count - 1]
            Set-OptionStatus $last 'NotApplicable'
            $last.Label.Text = "$title   [nothing to clean]"
        }
    }
    $script:UndoList.Items.Clear()
    foreach ($r in @($state.Restore | Where-Object { $_ })) {
        $li = New-Object System.Windows.Controls.ListBoxItem
        $li.Content = '{0}   -   {1} change(s){2}' -f $r.Name, $r.Changes, $(if ($r.Undone) { '   (already undone)' } else { '' })
        $li.Tag = $r.Path
        [void]$script:UndoList.Items.Add($li)
    }
    if ($script:UndoList.Items.Count -eq 0) { [void]$script:UndoList.Items.Add('No restore points yet.') }
    Update-HomeCards $state
    if ($script:FirstLoad) {
        foreach ($k in 'privacy', 'vendors', 'apps', 'cleanup') { Select-Recommended $k }
        $script:FirstLoad = $false
    } else {
        foreach ($k in 'apps', 'cleanup', 'vendors') { Select-Recommended $k }
        foreach ($o in $script:Options['privacy']) { if ($o.Status -in 'Applied', 'NotApplicable') { $o.CheckBox.IsChecked = $false } }
    }
}

function Update-VendorTab($vendors) {
    # The Telemetry tab is built fresh each time: it only ever shows what is really on this PC.
    $script:VendorList.Children.Clear()
    $script:Options['vendors'].Clear()
    $script:JunkBoxes = New-Object System.Collections.ArrayList
    $vendors = @($vendors | Where-Object { $_ })
    if ($vendors.Count -eq 0) {
        $script:VendorIntro.Text = 'Nothing to do here. This PC has no extra brand software that we recognise. Lucky you.'
        return
    }
    $open = (@($vendors | ForEach-Object { $_.Open }) | Measure-Object -Sum).Sum
    $names = ($vendors | ForEach-Object { $_.Name }) -join ', '
    $script:VendorIntro.Text = if ($open -gt 0) {
        'Found software from {0}. There are {1} background thing(s) still switched on.' -f $names, $open
    } else {
        'Found software from {0}. Everything we can switch off is already off. Nicely done.' -f $names
    }
    foreach ($v in $vendors) {
        $head = if ($v.Open -gt 0) { '{0} - {1} still switched on' -f $v.Name, $v.Open } else { '{0} - all quiet' -f $v.Name }
        $sec = New-Section $head
        $sec.Expander.IsExpanded = ($v.Open -gt 0)
        if ($v.Note) { [void]$sec.Content.Children.Add((New-Text $v.Note 12.5 'Normal' '#4B5B5C' '0,0,0,6')) }
        foreach ($item in $v.Items) {
            Add-Option -Panel $sec.Content -Key 'vendors' -Id $item.Id -Title $item.Title -Description $item.Description -Recommended $item.Recommended
            Set-OptionStatus $script:Options['vendors'][$script:Options['vendors'].Count - 1] $item.Status
        }
        if ($v.Junk.Count) {
            [void]$sec.Content.Children.Add((New-Text 'Extras you could remove (optional)' 13 'SemiBold' '#0F1B1C' '0,14,0,2' 'Fraunces, Georgia'))
            [void]$sec.Content.Children.Add((New-Text 'These are ordinary programs, not drivers. Removing one cannot be undone, but you can always install it again from the maker''s website.' 12.5 'Normal' '#4B5B5C' '0,0,0,4'))
            foreach ($j in $v.Junk) {
                $cb = New-Object System.Windows.Controls.CheckBox
                $cb.Margin = Get-Thick '0,8,0,0'
                $cb.VerticalContentAlignment = 'Center'
                $cb.Content = New-Text $j.Name 13.5 'SemiBold' '#0F1B1C' '2,0,0,0'
                [void]$sec.Content.Children.Add($cb)
                [void]$sec.Content.Children.Add((New-Text $j.Why 12.5 'Normal' '#4B5B5C' '22,2,0,0'))
                [void]$script:JunkBoxes.Add([pscustomobject]@{ Key = $j.Key; Name = $j.Name; CheckBox = $cb })
            }
            $btnJunk = New-Button 'Remove the ticked extras'
            $btnJunk.Margin = Get-Thick '0,10,0,0'
            $btnJunk.Add_Click({ Remove-TickedExtras })
            [void]$sec.Content.Children.Add($btnJunk)
        }
        [void]$script:VendorList.Children.Add($sec.Expander)
    }
}

function Remove-TickedExtras {
    if ($script:Job) { return }
    $picked = @($script:JunkBoxes | Where-Object { $_.CheckBox.IsChecked })
    if ($picked.Count -eq 0) { [void][System.Windows.MessageBox]::Show('Tick the ones you want gone first.', 'Quietpane'); return }
    $list = ($picked | ForEach-Object { '  - ' + $_.Name }) -join [Environment]::NewLine
    $msg = "These programs will be removed using their own uninstallers:`n`n$list`n`n" +
           "This one CANNOT be undone by Quietpane. You can install them again from the maker's website any time.`n`n" +
           "Each uninstaller may show its own window. Go ahead?"
    if ([System.Windows.MessageBox]::Show($msg, 'Quietpane', 'YesNo', 'Warning') -ne 'Yes') { return }
    $keys = @($picked | ForEach-Object { $_.Key })
    $ui.LogBox.AppendText([Environment]::NewLine)
    Set-LogVisible $true
    Start-Work -StatusText 'Removing the extras you picked...' -Params @{ Keys = $keys } -Work { param($Keys) Invoke-QpVendorUninstall -Keys $Keys } -OnDone { Update-State }
}

function Update-HomeCards($state) {
    # Same rules as Get-QpRecommendedPlan in the engine: recommended items that are not done yet.
    $priv = @($script:Options['privacy'] | Where-Object { $_.Recommended -and $_.Status -in 'NotApplied', 'Partial' }).Count
    $apps = @($state.Apps | Where-Object { $_ -and $_.Recommended }).Count
    $bytes = [int64](@($state.Cleanup | Where-Object { $_ -and $_.Recommended -and $_.SizeBytes -gt 0 }) | Measure-Object -Property SizeBytes -Sum).Sum
    $vendors = @($state.Vendors | Where-Object { $_ })
    $brandOpen = [int](@($vendors | ForEach-Object { @($_.Items | Where-Object { $_.Recommended -and $_.Status -ne 'Applied' }).Count }) | Measure-Object -Sum).Sum
    $brandNames = ($vendors | ForEach-Object { $_.Name }) -join ', '
    $script:HomeCounts = [pscustomobject]@{ Privacy = $priv; Apps = $apps; Bytes = $bytes; Brands = $brandOpen; BrandNames = $brandNames; Total = $priv + $apps + [int]($bytes -gt 0) + [int]($brandOpen -gt 0) }

    $good = Get-Brush '#117A68'; $todo = Get-Brush '#0F1B1C'
    if ($priv) { $script:CardTracking.Value.Text = "$priv to switch off"; $script:CardTracking.Value.Foreground = $todo; $script:CardTracking.Caption.Text = 'Telemetry, ads and tips' }
    else { $script:CardTracking.Value.Text = 'All set'; $script:CardTracking.Value.Foreground = $good; $script:CardTracking.Caption.Text = 'Tracking and ads are already off' }
    if ($apps) { $script:CardApps.Value.Text = "$apps to remove"; $script:CardApps.Value.Foreground = $todo; $script:CardApps.Caption.Text = 'Pre-installed and promoted apps' }
    else { $script:CardApps.Value.Text = 'None found'; $script:CardApps.Value.Foreground = $good; $script:CardApps.Caption.Text = 'No known bloat apps on this PC' }
    if ($bytes -gt 0) { $script:CardSpace.Value.Text = Format-QpBytes $bytes; $script:CardSpace.Value.Foreground = $todo; $script:CardSpace.Caption.Text = 'Temp files, crash dumps, old installers' }
    else { $script:CardSpace.Value.Text = 'Nothing to clean'; $script:CardSpace.Value.Foreground = $good; $script:CardSpace.Caption.Text = 'Already tidy' }
    if ($vendors.Count) {
        $script:CardBrands.Border.Visibility = 'Visible'
        if ($brandOpen) { $script:CardBrands.Value.Text = "$brandOpen to quieten"; $script:CardBrands.Value.Foreground = $todo }
        else { $script:CardBrands.Value.Text = 'All quiet'; $script:CardBrands.Value.Foreground = $good }
        $script:CardBrands.Caption.Text = $brandNames
    } else {
        $script:CardBrands.Border.Visibility = 'Collapsed'
    }
    if ($script:HomeCounts.Total -eq 0) { $btnOneClick.Content = 'Your PC is already lovely' } else { $btnOneClick.Content = 'Quiet my PC now' }
    Update-Meters
}

function Set-MeterFill($meter, [double]$Ratio) {
    if ($Ratio -lt 0) { $Ratio = 0 } elseif ($Ratio -gt 1) { $Ratio = 1 }
    $meter.Fill.Width = [Math]::Max(6, [Math]::Round($meter.TrackWidth * $Ratio))
}

function Update-Meters {
    $u = Get-QpSystemUsage
    if ($u.DiskTotal -gt 0) {
        $script:MeterSpace.Value.Text = '{0} free' -f (Format-QpBytes $u.DiskFree)
        $script:MeterSpace.Caption.Text = 'of {0} on drive {1} - {2}% full' -f (Format-QpBytes $u.DiskTotal), $u.Drive, [int](100 * $u.DiskUsed / $u.DiskTotal)
        Set-MeterFill $script:MeterSpace ($u.DiskUsed / $u.DiskTotal)
    }
    if ($u.MemTotal -gt 0) {
        $script:MeterMemory.Value.Text = '{0} in use' -f (Format-QpBytes $u.MemUsed)
        $script:MeterMemory.Caption.Text = 'of {0} of memory - {1}% in use right now' -f (Format-QpBytes $u.MemTotal), [int](100 * $u.MemUsed / $u.MemTotal)
        Set-MeterFill $script:MeterMemory ($u.MemUsed / $u.MemTotal)
    }
    $t = Get-QpTotals
    if ($t.SpaceFreedBytes -gt 0 -or $t.MemoryFreedBytes -gt 0) {
        $parts = @()
        if ($t.SpaceFreedBytes -gt 0) { $parts += '{0} of space' -f (Format-QpBytes $t.SpaceFreedBytes) }
        if ($t.MemoryFreedBytes -gt 0) { $parts += '{0} of memory' -f (Format-QpBytes $t.MemoryFreedBytes) }
        $script:TotalsText.Text = 'Quietpane has freed ' + ($parts -join ' and ') + ' on this PC so far.'
        $script:TotalsText.Visibility = 'Visible'
    } else {
        $script:TotalsText.Visibility = 'Collapsed'
    }
}

function Show-MeterGains([int64]$SpaceFreed, [int64]$MemoryFreed) {
    # Green notes under each bar, showing what the run just gave back.
    if ($SpaceFreed -gt 0) {
        $script:MeterSpace.Delta.Text = '+{0} freed just now (in your Recycle Bin)' -f (Format-QpBytes $SpaceFreed)
        $script:MeterSpace.Delta.Visibility = 'Visible'
    } else { $script:MeterSpace.Delta.Visibility = 'Collapsed' }
    if ($MemoryFreed -gt 0) {
        $script:MeterMemory.Delta.Text = '+{0} of memory freed - a restart frees more' -f (Format-QpBytes $MemoryFreed)
    } else {
        $script:MeterMemory.Delta.Text = 'Memory is unchanged for now - a restart frees more'
    }
    $script:MeterMemory.Delta.Visibility = 'Visible'
}

function Set-LogVisible([bool]$Visible) {
    $ui.LogRow.Height = if ($Visible) { New-Object System.Windows.GridLength(170) } else { New-Object System.Windows.GridLength(0) }
    $ui.LogSplitter.Visibility = if ($Visible) { 'Visible' } else { 'Collapsed' }
    $ui.LinkDetails.Inlines.Clear()
    $ui.LinkDetails.Inlines.Add($(if ($Visible) { 'Hide details' } else { 'Show details' }))
    $script:LogVisible = $Visible
}

$script:ReadState = {
    @{
        Privacy = Get-QpPrivacyStatus
        Vendors = @(Get-QpVendorStatus)
        Apps    = @(Get-QpBloatApps)
        Cleanup = @(Get-QpCleanupTargets)
        Restore = @(Get-QpRestorePoints)
    }
}

function Update-State {
    Start-Work -StatusText 'Reading the current state of this PC...' -Work $script:ReadState -OnDone { param($s) Update-FromState $s }
}

# ------------------------------------------------------------------ actions
function Get-SelectedIds([string]$Key) {
    @($script:Options[$Key] | Where-Object { $_.CheckBox.IsChecked } | ForEach-Object { $_.Id })
}

function Invoke-Selected([bool]$Preview) {
    $key = [string]$ui.Tabs.SelectedItem.Tag
    $ids = Get-SelectedIds $key
    if ($ids.Count -eq 0) { [void][System.Windows.MessageBox]::Show('Pick at least one thing first.', 'Quietpane'); return }
    if (-not $Preview) {
        $msg = switch ($key) {
            'apps'    { "Remove $($ids.Count) app(s)?`n`nYou can always get them back from the Microsoft Store." }
            'cleanup' { "Move the ticked items to the Recycle Bin?`n`nNothing is deleted for good - you empty the bin yourself when you are happy." }
            default   { "Go ahead with the $($ids.Count) ticked item(s)?`n`nA restore point is saved first, so you can undo this from the Undo tab." }
        }
        if ([System.Windows.MessageBox]::Show($msg, 'Quietpane', 'YesNo', 'Question') -ne 'Yes') { return }
    }
    $ui.LogBox.AppendText([Environment]::NewLine)
    Set-LogVisible $true   # preview/apply results are shown in the details log
    $after = if ($Preview) { $null } else { { Update-State } }
    $verb = if ($Preview) { 'Previewing' } else { 'Applying' }
    switch ($key) {
        'privacy' { Start-Work -StatusText "$verb privacy changes..." -Params @{ Ids = $ids; Preview = $Preview } -OnDone $after -Work { param($Ids, $Preview) Invoke-QpPrivacy -Ids $Ids -Preview:$Preview } }
        'vendors' { Start-Work -StatusText "$verb brand and hardware changes..." -Params @{ Ids = $ids; Preview = $Preview } -OnDone $after -Work { param($Ids, $Preview) Invoke-QpVendor -Ids $Ids -Preview:$Preview } }
        'apps'    {
            $dep = [bool]$script:DeprovisionCb.IsChecked
            Start-Work -StatusText "$verb app removal..." -Params @{ Ids = $ids; Preview = $Preview; Deprovision = $dep } -OnDone $after -Work { param($Ids, $Preview, $Deprovision) Invoke-QpRemoveApps -Names $Ids -Preview:$Preview -Deprovision:$Deprovision }
        }
        'cleanup' { Start-Work -StatusText "$verb clean-up..." -Params @{ Ids = $ids; Preview = $Preview } -OnDone $after -Work { param($Ids, $Preview) Invoke-QpCleanup -Ids $Ids -Preview:$Preview } }
    }
}

$ui.BtnPreview.Add_Click({ Invoke-Selected $true })
$ui.BtnApply.Add_Click({ Invoke-Selected $false })
$ui.BtnRecommended.Add_Click({ Select-Recommended ([string]$ui.Tabs.SelectedItem.Tag) })
$ui.BtnNone.Add_Click({ foreach ($o in $script:Options[[string]$ui.Tabs.SelectedItem.Tag]) { $o.CheckBox.IsChecked = $false } })

function Start-SafetyScan {
    $ui.LogBox.AppendText([Environment]::NewLine)
    $scanSummary.Text = 'Having a look around... this takes a minute or three.'
    $script:CardAdware.Value.Text = 'Checking...'
    $script:CardAdware.Caption.Text = 'About 2 minutes - nothing is changed'
    Start-Work -StatusText 'Checking for adware and problems (read-only, about 2 minutes)...' -Work { Invoke-QpAudit } -OnDone {
        param($r)
        $r = @($r)[-1]
        if ($r -and $r.Report) {
            $script:LastReport = $r.Report
            $scanSummary.Text = ('Scan finished: {0} high, {1} medium, {2} info. The report opened in your browser and is saved on your Desktop.' -f $r.High, $r.Medium, $r.Info)
            if ($r.High -gt 0) {
                $script:CardAdware.Value.Text = "$($r.High) problem(s) found"
                $script:CardAdware.Value.Foreground = Get-Brush '#A83232'
                $script:CardAdware.Caption.Text = 'See the red items in the report that opened'
            } else {
                $script:CardAdware.Value.Text = 'Nothing serious'
                $script:CardAdware.Value.Foreground = Get-Brush '#117A68'
                $script:CardAdware.Caption.Text = "$($r.Medium) thing(s) worth a look in the report"
            }
            Open-AsUser $r.Report
            Update-Buttons
        } else {
            $scanSummary.Text = 'The check did not finish. Click "Show details" at the bottom to see why.'
            $script:CardAdware.Value.Text = 'Did not finish'
        }
    }
}
$btnScan.Add_Click({ Start-SafetyScan })
$btnHomeScan.Add_Click({ Start-SafetyScan })

# ---- One click
function Show-HomeResult($r) {
    $r = @($r)[-1]
    $script:ResultPanel.Visibility = 'Visible'
    if (-not $r) {
        $script:ResultTitle.Text = 'Something went wrong'
        $script:ResultText.Text = 'Click "Show details" at the bottom to see what happened. Anything that was changed can be undone in the Undo tab.'
        return
    }
    if ($r.Nothing) {
        $script:ResultTitle.Text = 'Already clean!'
        $script:ResultText.Text = 'This PC already has every recommended setting. Nothing needed changing.'
        $btnRestart.Visibility = 'Collapsed'; $btnUndoAll.Visibility = 'Collapsed'
        return
    }
    $lines = @()
    if ($r.Settings)      { $lines += "Switched off $($r.Settings) tracking and ads setting(s)." }
    if (@($r.BrandsQuieted).Count) { $lines += ('Quietened the extras from {0}. Their apps still work.' -f (@($r.BrandsQuieted) -join ', ')) }
    if ($r.AppsRemoved)   { $lines += "Removed $($r.AppsRemoved) unneeded app(s)." }
    if ($r.BytesFreed -gt 0) { $lines += "Freed about $(Format-QpBytes $r.BytesFreed) of space - it is in your Recycle Bin, empty it whenever you like." }
    if ($r.MemoryFreed -gt 0) { $lines += "Memory in use dropped by about $(Format-QpBytes $r.MemoryFreed)." }
    $lines += ''
    $lines += 'Restart your PC to finish. Changed your mind? "Undo everything" puts it all back.'
    Show-MeterGains ([int64]$r.BytesFreed) ([int64]$r.MemoryFreed)
    $script:ResultTitle.Text = 'All done!'
    $script:ResultText.Text = $lines -join [Environment]::NewLine
    $script:LastRestorePoint = $r.RestorePoint
    $btnRestart.Visibility = 'Visible'; $btnUndoAll.Visibility = 'Visible'
    Update-Buttons
}

$btnOneClick.Add_Click({
    $s = $script:HomeCounts
    if ($s -and $s.Total -eq 0) {
        [void][System.Windows.MessageBox]::Show('Your PC is already in great shape. Nothing left for me to do.', 'Quietpane')
        return
    }
    $lines = @()
    if ($s.Privacy) { $lines += "  - switch off $($s.Privacy) tracking and ads setting(s)" }
    if ($s.Brands)  { $lines += ('  - quieten {0} background item(s) from {1}' -f $s.Brands, $s.BrandNames) }
    if ($s.Apps)    { $lines += "  - remove $($s.Apps) unneeded app(s)" }
    if ($s.Bytes -gt 0) { $lines += "  - free about $(Format-QpBytes $s.Bytes) (files go to your Recycle Bin)" }
    $msg = "Here is what I will do:`n`n" + ($lines -join "`n") + "`n`nAll of it can be undone afterwards. Close your games and browsers first, please.`n`nShall I go ahead?"
    if ([System.Windows.MessageBox]::Show($msg, 'Quietpane', 'YesNo', 'Question') -ne 'Yes') { return }
    $script:ResultPanel.Visibility = 'Collapsed'
    $ui.LogBox.AppendText([Environment]::NewLine)
    Start-Work -StatusText 'Cleaning your PC... this usually takes less than a minute.' -Work { Invoke-QpRecommended } -OnDone { param($r) Show-HomeResult $r; Update-State }
})

$btnRestart.Add_Click({
    if ([System.Windows.MessageBox]::Show('Restart now? Save anything you have open first.', 'Quietpane', 'YesNo', 'Question') -ne 'Yes') { return }
    Start-Process -FilePath 'shutdown.exe' -ArgumentList '/r', '/t', '5' -WindowStyle Hidden
})

$btnUndoAll.Add_Click({
    if (-not $script:LastRestorePoint) { return }
    if ([System.Windows.MessageBox]::Show('Put everything back exactly as it was before you pressed "Quiet my PC now"?', 'Quietpane', 'YesNo', 'Question') -ne 'Yes') { return }
    $ui.LogBox.AppendText([Environment]::NewLine)
    Start-Work -StatusText 'Putting everything back...' -Params @{ Path = $script:LastRestorePoint } -Work { param($Path) Invoke-QpUndo -Path $Path } -OnDone {
        $script:ResultTitle.Text = 'Everything is back as it was'
        $script:ResultText.Text = "All settings were restored. Files are still in your Recycle Bin, and removed apps can be reinstalled from the Microsoft Store.`nRestart your PC to finish."
        $script:LastRestorePoint = $null
        $btnUndoAll.Visibility = 'Collapsed'
        $script:MeterSpace.Delta.Visibility = 'Collapsed'
        $script:MeterMemory.Delta.Visibility = 'Collapsed'
        Update-State
    }
})

$btnShowDetails.Add_Click({ Set-LogVisible $true })
$ui.LinkDetails.Add_Click({ Set-LogVisible (-not $script:LogVisible) })
$btnOpenReport.Add_Click({ if ($script:LastReport) { Open-AsUser $script:LastReport } })

$btnUndoRefresh.Add_Click({ Update-State })
$btnUndo.Add_Click({
    $sel = $script:UndoList.SelectedItem
    if (-not ($sel -is [System.Windows.Controls.ListBoxItem])) { [void][System.Windows.MessageBox]::Show('Pick a restore point from the list first.', 'Quietpane'); return }
    if ([System.Windows.MessageBox]::Show("Undo all changes from:`n$($sel.Content)?", 'Quietpane', 'YesNo', 'Question') -ne 'Yes') { return }
    $ui.LogBox.AppendText([Environment]::NewLine)
    Set-LogVisible $true
    Start-Work -StatusText 'Undoing...' -Params @{ Path = [string]$sel.Tag } -Work { param($Path) Invoke-QpUndo -Path $Path } -OnDone { Update-State }
})

$ui.Tabs.Add_SelectionChanged({
    param($s, $e)
    if ($e.OriginalSource -eq $ui.Tabs) { Update-Buttons }
})

$window.Add_Closing({
    param($s, $e)
    if ($script:Job) {
        if ([System.Windows.MessageBox]::Show('Something is still running. Close anyway?', 'Quietpane', 'YesNo', 'Warning') -ne 'Yes') { $e.Cancel = $true; return }
    }
    $timer.Stop()
})

$ui.Tabs.SelectedIndex = 0

# ------------------------------------------------------------------ self-test / snapshot
if ($SelfTest) {
    if ($Snapshot) {
        Update-FromState (& $script:ReadState)
        $ui.LogBox.Text = "[12:00:00] STEP    Quietpane $($info.Version) - Developed by KomodoWorks.com`r`n[12:00:01] OK      Ready."
        $ui.Status.Text = 'Ready when you are.'
        $ui.Tabs.SelectedIndex = $SnapshotTab
        if ($SnapshotTab -eq ($ui.Tabs.Items.Count - 1)) { $script:PrivacyExpander.IsExpanded = $true }
        Update-Buttons
        $root = $window.Content
        $size = [System.Windows.Size]::new([double]$window.Width, [double]$window.Height - 40)
        $root.Measure($size)
        $root.Arrange([System.Windows.Rect]::new($size))
        $root.UpdateLayout()
        $rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap([int]$size.Width, [int]$size.Height, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
        $bg = New-Object System.Windows.Media.DrawingVisual
        $dc = $bg.RenderOpen(); $dc.DrawRectangle((Get-Brush '#FAF6EC'), $null, [System.Windows.Rect]::new($size)); $dc.Close()
        $rtb.Render($bg)
        $rtb.Render($root)
        $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
        $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($rtb))
        $fs = [IO.File]::Create($Snapshot); $enc.Save($fs); $fs.Close()
    }
    '{0} tabs, {1} privacy items, logo loaded: {2}, window built OK' -f $ui.Tabs.Items.Count, $script:Options['privacy'].Count, [bool]$logo
    return
}

# ------------------------------------------------------------------ first run notice
$acceptFile = Join-Path $info.DataRoot 'welcome-accepted.txt'
function Show-Welcome {
    if (Test-Path $acceptFile) { return $true }
    $msg = "Hello, and welcome to Quietpane $($info.Version).`n`n" +
           "Nothing leaves this PC, and nothing changes until you press a button.`n" +
           "Whatever you change, you can undo. Files only go to the Recycle Bin.`n" +
           "It is free, open source, and comes with no warranty - use it on PCs that are yours to look after.`n`n" +
           "The full privacy policy and terms are in the About tab. Sound good?"
    if ([System.Windows.MessageBox]::Show($window, $msg, 'Quietpane', 'YesNo', 'Information') -ne 'Yes') { return $false }
    try {
        New-Item -ItemType Directory -Path $info.DataRoot -Force | Out-Null
        Set-Content -Path $acceptFile -Value ("Welcome notice acknowledged {0} (version {1})" -f (Get-Date).ToString('s'), $info.Version)
    } catch { }
    return $true
}

$window.Add_ContentRendered({
    if (-not (Show-Welcome)) { $window.Close(); return }
    $ui.LogBox.AppendText(('Quietpane {0} - Developed by KomodoWorks.com. Started {1}. Administrator: {2}. This app makes no network connections.' -f $info.Version, (Get-Date -Format 'yyyy-MM-dd HH:mm'), (Test-IsAdmin)) + [Environment]::NewLine)
    Update-State
})
$timer.Start()
[void]$window.ShowDialog()
