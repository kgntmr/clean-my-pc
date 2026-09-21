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
    # One line that says where it has got to, rewritten in place so the window stays tidy.
    Set-QpProgressSink {
        param($p)
        $text = '  Step {0} of {1}: {2}' -f $p.Step, $p.Of, $p.Stage
        if ($p.Object) { $text += " - $($p.Object)" }
        $text += ' ({0:N0} looked at)' -f $p.Scanned
        Write-Host ("`r" + $text.PadRight(112).Substring(0, 112)) -NoNewline -ForegroundColor DarkCyan
    }
    $result = @(Invoke-QpAudit)[-1]
    Write-Host ''
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
foreach ($k in 'privacy', 'vendors', 'apps', 'startup', 'cleanup') { $script:Options[$k] = New-Object System.Collections.ArrayList }

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
[void]$homePanel.Children.Add((New-Text 'One click switches off the tracking and ads, clears out apps you never asked for and frees up space. Only the safe, recommended bits, and you can put it all back.' 14.5 'Normal' '#4B5B5C' '0,0,0,18'))

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

# Things that switched themselves back on since last time - usually a Windows or driver update.
$script:BackPanel = New-Object System.Windows.Controls.Border
$script:BackPanel.Visibility = 'Collapsed'
$script:BackPanel.Margin = Get-Thick '0,0,12,12'
$script:BackPanel.Padding = Get-Thick '16,12'
$script:BackPanel.Background = Get-Brush '#FFF4DC'
$script:BackPanel.BorderBrush = Get-Brush '#FFB627'
$script:BackPanel.BorderThickness = Get-Thick '4,0,0,0'
$backStack = New-Object System.Windows.Controls.StackPanel
$script:BackTitle = New-Text '' 17 'SemiBold' '#0F1B1C' '0,0,0,4' 'Fraunces, Georgia'
$script:BackText = New-Text '' 13.5 'Normal' '#0F1B1C' '0,0,0,4'
$script:BackList = New-Text '' 12.5 'Normal' '#4B5B5C' '0,0,0,10'
$backButtons = New-Object System.Windows.Controls.WrapPanel
$btnPutBack = New-Button 'Switch them off again' -Primary
$btnThatWasMe = New-Button 'That was me - leave them'
foreach ($b in $btnPutBack, $btnThatWasMe) { $b.Margin = Get-Thick '0,0,10,0'; [void]$backButtons.Children.Add($b) }
foreach ($x in $script:BackTitle, $script:BackText, $script:BackList, $backButtons) { [void]$backStack.Children.Add($x) }
$script:BackPanel.Child = $backStack
[void]$homePanel.Children.Add($script:BackPanel)

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
# Live tiles: how hard the PC is working right now, and how warm it is. Same shape as a meter, so the
# same fill and gain helpers work on them.
function New-LiveTile([string]$Title, [string]$FillColour) {
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Width = 150
    $sp.Margin = Get-Thick '0,0,18,4'
    [void]$sp.Children.Add((New-Text $Title 11 'SemiBold' '#4B5B5C' '0,0,0,2'))
    $value = New-Text '...' 21 'SemiBold' '#0F1B1C' '0,0,0,6' 'Fraunces, Georgia'
    [void]$sp.Children.Add($value)
    $track = New-Object System.Windows.Controls.Border
    $track.Height = 10
    $track.Width = 140
    $track.HorizontalAlignment = 'Left'
    $track.Background = Get-Brush '#EDE6D5'
    $track.CornerRadius = New-Object System.Windows.CornerRadius(5)
    $fill = New-Object System.Windows.Controls.Border
    $fill.Height = 10
    $fill.Width = 0
    $fill.HorizontalAlignment = 'Left'
    $fill.Background = Get-Brush $FillColour
    $fill.CornerRadius = New-Object System.Windows.CornerRadius(5)
    $track.Child = $fill
    [void]$sp.Children.Add($track)
    $heat = New-Text '' 12.5 'SemiBold' '#117A68' '0,7,0,0'
    $caption = New-Text '' 12 'Normal' '#4B5B5C' '0,2,0,0'
    # "What's using it": the busiest programs right now, one per line.
    $top = New-Text '' 11.5 'Normal' '#4B5B5C' '0,4,0,0'
    $top.Visibility = 'Collapsed'
    $extra = New-Text '' 11.5 'Normal' '#8A9696' '0,2,0,0'
    $extra.Visibility = 'Collapsed'
    $delta = New-Text '' 12.5 'SemiBold' '#117A68' '0,4,0,0'
    $delta.Visibility = 'Collapsed'
    foreach ($x in $heat, $caption, $top, $extra, $delta) { [void]$sp.Children.Add($x) }
    return [pscustomobject]@{ Border = $sp; Value = $value; Fill = $fill; Heat = $heat; Caption = $caption; Top = $top; Extra = $extra; Delta = $delta; TrackWidth = 140 }
}

$meters = New-Object System.Windows.Controls.WrapPanel
$script:MeterSpace = New-Meter 'SPACE ON THIS PC' '#117A68'
[void]$meters.Children.Add($script:MeterSpace.Border)

$script:LivePanel = New-Object System.Windows.Controls.Border
$script:LivePanel.MinHeight = 148
$script:LivePanel.Padding = Get-Thick '14,12,0,10'
$script:LivePanel.Margin = Get-Thick '0,0,12,12'
$script:LivePanel.Background = Get-Brush '#FFFDF8'
$script:LivePanel.BorderBrush = Get-Brush '#E6DFCC'
$script:LivePanel.BorderThickness = Get-Thick '1'
$liveStack = New-Object System.Windows.Controls.StackPanel
[void]$liveStack.Children.Add((New-Text 'RIGHT NOW' 11.5 'SemiBold' '#4B5B5C' '0,0,0,6'))
$liveTiles = New-Object System.Windows.Controls.WrapPanel
$script:TileCpu    = New-LiveTile 'PROCESSOR' '#117A68'
$script:TileGpu    = New-LiveTile 'GRAPHICS' '#117A68'
$script:TileMemory = New-LiveTile 'MEMORY' '#FFB627'
$script:TileVram   = New-LiveTile 'VIDEO MEMORY' '#FFB627'
foreach ($t in $script:TileCpu, $script:TileGpu, $script:TileMemory, $script:TileVram) { [void]$liveTiles.Children.Add($t.Border) }
[void]$liveStack.Children.Add($liveTiles)
$script:LiveNote = New-Text 'Updates every 2 seconds while this tab is open. Nothing is recorded.' 11.5 'Normal' '#8A9696' '0,4,0,0'
[void]$liveStack.Children.Add($script:LiveNote)
$script:LivePanel.Child = $liveStack
# The memory tile carries the "freed just now" note that the old memory bar used to.
$script:MeterMemory = $script:TileMemory
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
$homeHint = New-Text 'You will see exactly what is about to change before it happens. Settings can be undone, cleaned-up files go to your Recycle Bin, and removed apps can be reinstalled from the Microsoft Store.' 12.5 'Normal' '#4B5B5C' '0,6,0,0'
[void]$homePanel.Children.Add($homeHint)
$homeDisclaimer = New-Text 'A good start, not a guarantee: this tidies up the usual troublemakers, but it cannot promise a PC is clean. If yours still feels wrong afterwards, run a deeper scan with a dedicated security tool too.' 12.5 'Normal' '#9A6700' '0,8,0,0'
[void]$homePanel.Children.Add($homeDisclaimer)

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
$homeRather = New-Text 'Rather choose yourself? The Privacy, Telemetry, Apps and Free up space tabs let you pick item by item, and Preview shows what would happen without touching anything.' 12.5 'Normal' '#4B5B5C' '0,20,0,0'
[void]$homePanel.Children.Add($homeRather)

# The order people read Home in: how things stand, the one button (and what it just did), then space.
# The button stays in view without scrolling.
$homeTop = @($homePanel.Children)[0..1]
$homePanel.Children.Clear()
$meters.Margin = Get-Thick '0,20,0,0'
foreach ($x in @($homeTop) + @($cards, $script:BackPanel, $homeButtons, $homeHint, $script:ResultPanel, $meters, $script:TotalsText, $homeDisclaimer, $homeRather)) { [void]$homePanel.Children.Add($x) }

# 1. Health - how hard the PC is working, how warm it is, and how the battery and drive are holding up.
# Its own tab, so Home stays calm - and nothing here is read unless this tab is open.
$healthPanel = New-TabPage 'Health' 'health' 'How hard your PC is working right now, how warm it is, and how the battery and drive are holding up. Nothing here changes anything, and it only looks while this tab is open.'
$script:LivePanel.Margin = Get-Thick '0,4,0,12'
[void]$healthPanel.Children.Add($script:LivePanel)
$healthCards = New-Object System.Windows.Controls.WrapPanel
# Laptops only: charge, plugged in or not, and how much the battery holds compared with when it was new.
$script:BatteryCard = New-Meter 'BATTERY' '#FFB627'
$script:BatteryHealthText = New-Text '' 12.5 'Normal' '#0F1B1C' '0,6,0,0'
[void]$script:BatteryCard.Border.Child.Children.Add($script:BatteryHealthText)
$script:BatteryCard.Border.Visibility = 'Collapsed'
# The drive Windows runs from: Windows' own verdict, how much of its rated life is used, and its heat.
$script:DriveCard = New-Meter 'THE DRIVE WINDOWS IS ON' '#117A68'
$script:DriveHeatText = New-Text '' 12.5 'SemiBold' '#117A68' '0,6,0,0'
[void]$script:DriveCard.Border.Child.Children.Add($script:DriveHeatText)
$script:DriveCard.Value.Text = 'Having a look...'
foreach ($c in $script:BatteryCard, $script:DriveCard) { [void]$healthCards.Children.Add($c.Border) }
[void]$healthPanel.Children.Add($healthCards)

# 1. Safety scan - Microsoft Defender's detections plus Quietpane's own checks
$scanPanel = New-TabPage 'Safety scan' 'scan' ('We ask Microsoft Defender what it has found, and we look around for the tricks adware uses: odd startup entries, hidden tasks, browser add-ons and tampered programs. Nothing is changed while we look.')
[void]$scanPanel.Children.Add((New-Text 'Threat names come from Defender. Anything Quietpane spots on its own is marked as our own check - a signal worth knowing about, not proof.' 12.5 'Normal' '#4B5B5C' '0,0,0,10'))
$scanButtons = New-Object System.Windows.Controls.StackPanel
$scanButtons.Orientation = 'Horizontal'
$scanButtons.Margin = Get-Thick '0,0,0,10'
$btnScan = New-Button 'Check this PC' -Primary
$btnScanDeep = New-Button 'Check and ask Defender to scan'
$btnOpenReport = New-Button 'Open last report'
$btnOpenReport.IsEnabled = $false
# Stop stays enabled while everything else is greyed out - it is the one button a busy app must keep.
$btnStopScan = New-Button 'Stop'
$btnStopScan.Visibility = 'Collapsed'
$btnStopScan.ToolTip = 'Stop looking. Nothing on your PC is changed either way.'
foreach ($b in $btnScan, $btnScanDeep, $btnOpenReport, $btnStopScan) { [void]$scanButtons.Children.Add($b) }
[void]$scanPanel.Children.Add($scanButtons)
$scanSummary = New-Text 'No check yet.' 15 'SemiBold' '#0F1B1C' '0,6,0,6' 'Fraunces, Georgia'
[void]$scanPanel.Children.Add($scanSummary)
$script:ScanProgress = New-Text '' 12.5 'Normal' '#4B5B5C' '0,0,0,6'
[void]$scanPanel.Children.Add($script:ScanProgress)

# What happened, in full, once the check has finished: looked at, found, dealt with, what next.
$script:SummaryPanel = New-Object System.Windows.Controls.Border
$script:SummaryPanel.Visibility = 'Collapsed'
$script:SummaryPanel.Background = Get-Brush '#EAF5F1'
$script:SummaryPanel.BorderBrush = Get-Brush '#117A68'
$script:SummaryPanel.BorderThickness = Get-Thick '4,0,0,0'
$script:SummaryPanel.Padding = Get-Thick '16,12'
$script:SummaryPanel.Margin = Get-Thick '0,2,0,12'
$script:SummaryStack = New-Object System.Windows.Controls.StackPanel
$script:SummaryPanel.Child = $script:SummaryStack
[void]$scanPanel.Children.Add($script:SummaryPanel)

# Severity doughnut: colour, label and count, so it never depends on colour alone.
$script:SevColours = [ordered]@{ Critical = '#7B1D1D'; High = '#A83232'; Medium = '#9A6700'; Low = '#8A8578'; Info = '#117A68' }
$script:SevMeaning = @{ Critical = 'act now'; High = 'act on it'; Medium = 'worth a look'; Low = 'minor'; Info = 'just so you know' }
$script:SevCounts = [ordered]@{ Critical = 0; High = 0; Medium = 0; Low = 0; Info = 0 }
$script:SevFilter = 'All'
$script:ScanFindings = @()

$script:ChartPanel = New-Object System.Windows.Controls.Border
$script:ChartPanel.Visibility = 'Collapsed'
$script:ChartPanel.Background = Get-Brush '#FFFDF8'
$script:ChartPanel.BorderBrush = Get-Brush '#E6DFCC'
$script:ChartPanel.BorderThickness = Get-Thick '1'
$script:ChartPanel.Padding = Get-Thick '16,14'
$script:ChartPanel.Margin = Get-Thick '0,4,0,12'
$chartRow = New-Object System.Windows.Controls.StackPanel
$chartRow.Orientation = 'Horizontal'
$script:ChartCanvas = New-Object System.Windows.Controls.Canvas
$script:ChartCanvas.Width = 172; $script:ChartCanvas.Height = 172
$script:ChartCanvas.Margin = Get-Thick '0,0,22,0'
[void]$chartRow.Children.Add($script:ChartCanvas)
$script:LegendPanel = New-Object System.Windows.Controls.StackPanel
$script:LegendPanel.VerticalAlignment = 'Center'
$script:LegendPanel.MinWidth = 300
[void]$chartRow.Children.Add($script:LegendPanel)
$script:ChartPanel.Child = $chartRow
[void]$scanPanel.Children.Add($script:ChartPanel)

$script:FindingsPanel = New-Object System.Windows.Controls.StackPanel
[void]$scanPanel.Children.Add($script:FindingsPanel)

# Whatever Quietpane is holding in quarantine, with a way back out.
$script:QuarantineBox = New-Object System.Windows.Controls.Expander
$script:QuarantineBox.Header = New-Text 'In quarantine' 14.5 'SemiBold' '#117A68' '0' 'Fraunces, Georgia'
$script:QuarantineBox.Margin = Get-Thick '0,16,0,0'
$script:QuarantineBox.Visibility = 'Collapsed'
$script:QuarantinePanel = New-Object System.Windows.Controls.StackPanel
$script:QuarantinePanel.Margin = Get-Thick '8,6,0,8'
$script:QuarantineBox.Content = $script:QuarantinePanel
[void]$scanPanel.Children.Add($script:QuarantineBox)
[void]$scanPanel.Children.Add((New-Text 'A good start, not a guarantee: this looks where problems usually hide, and it cannot promise a PC is clean. If yours still feels wrong, run a deeper scan with a dedicated security tool too.' 12.5 'Normal' '#9A6700' '0,14,0,0'))

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

# 4. Apps - what starts when you sign in, and apps you could remove
$appsPanel = New-TabPage 'Apps' 'apps' ('What starts by itself when you sign in, and apps that came with Windows or were pushed onto this PC. Tick what you want, then Preview or Apply.')

$script:StartupSection = New-Section 'Starts when you sign in'
$script:StartupSection.Expander.IsExpanded = $true
[void]$script:StartupSection.Content.Children.Add((New-Text 'Switching something off works like Task Manager: the program itself is untouched and still opens when you start it - it just stops starting on its own. Undo turns it back on.' 12.5 'Normal' '#4B5B5C' '0,2,0,2'))
$script:StartupList = New-Object System.Windows.Controls.StackPanel
[void]$script:StartupList.Children.Add((New-Text 'Looking at what starts when you sign in...' 13 'Normal' '#4B5B5C'))
[void]$script:StartupSection.Content.Children.Add($script:StartupList)
[void]$appsPanel.Children.Add($script:StartupSection.Expander)

$script:RemoveSection = New-Section 'Apps you could remove'
$script:RemoveSection.Expander.IsExpanded = $true
[void]$script:RemoveSection.Content.Children.Add((New-Text 'Your Store, Camera, Photos, Calculator, Notepad, Paint, Snipping Tool and anything driver-related are never on this list. Changed your mind later? The Microsoft Store has them all.' 12.5 'Normal' '#4B5B5C' '0,2,0,6'))
$script:DeprovisionCb = New-Object System.Windows.Controls.CheckBox
$script:DeprovisionCb.Content = New-Text 'Also stop removed apps being installed for new user accounts on this PC' 12.5 'Normal' '#0F1B1C' '2,0,0,0'
$script:DeprovisionCb.IsChecked = $true
$script:DeprovisionCb.Margin = Get-Thick '0,0,0,8'
[void]$script:RemoveSection.Content.Children.Add($script:DeprovisionCb)
$script:AppsList = New-Object System.Windows.Controls.StackPanel
[void]$script:AppsList.Children.Add((New-Text 'Looking for installed apps...' 13 'Normal' '#4B5B5C'))
[void]$script:RemoveSection.Content.Children.Add($script:AppsList)
[void]$appsPanel.Children.Add($script:RemoveSection.Expander)

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
        'Changes nothing without you: every change is shown first and confirmed, and settings go into a restore point you can undo.',
        'Tidying up never deletes for good: files go to your Recycle Bin and scheduled tasks are switched off, not deleted. Three things can''t be undone - removing an app (the Microsoft Store has it), uninstalling a brand extra, and deleting a threat for good - and the app says so before you confirm.',
        'Hides nothing: plain-text PowerShell you can read line by line, plus a few lines of C# that ask the graphics driver for its temperature. No installer.',
        'Free and open source under the MIT License. Not affiliated with Microsoft, NVIDIA, Intel, AMD, Google or any PC maker.')) {
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

$script:ActionButtons = @($ui.BtnRecommended, $ui.BtnNone, $ui.BtnPreview, $ui.BtnApply, $btnScan, $btnUndo, $btnUndoRefresh, $btnOneClick, $btnHomeScan, $btnUndoAll, $btnRestart, $btnPutBack, $btnThatWasMe)

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
$script:Sync = [hashtable]::Synchronized(@{ Queue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[string]'; Result = $null; Progress = $null; Cancel = $false })
$script:Job = $null
$script:FirstLoad = $true
$script:LastReport = $null
$script:LastRestorePoint = $null
$script:HomeCounts = $null
$script:LogVisible = $false
$script:ScanRunning = $false
$script:ScanStarted = Get-Date
$script:ScanSeconds = 0
$script:LastScanResult = $null
# What has actually been done to findings since the last check, for the summary at the end.
$script:ActionTally = [ordered]@{ Removed = 0; Quarantined = 0; Recycled = 0; Deleted = 0; Allowed = 0; Failed = 0 }

function Select-Tab([string]$Tag) {
    # Tabs are found by name, not position, so adding a tab never sends a button to the wrong place.
    foreach ($t in $ui.Tabs.Items) { if ([string]$t.Tag -eq $Tag) { $ui.Tabs.SelectedItem = $t; return } }
}

function Update-Buttons {
    $key = [string]$ui.Tabs.SelectedItem.Tag
    $optionTab = $key -in 'privacy', 'vendors', 'apps', 'cleanup'
    $idle = -not $script:Job
    # The pick-and-choose buttons only appear on the tabs where they do something.
    $ui.AdvancedButtons.Visibility = if ($optionTab) { 'Visible' } else { 'Collapsed' }
    foreach ($b in $ui.BtnRecommended, $ui.BtnNone, $ui.BtnPreview, $ui.BtnApply) { $b.IsEnabled = ($optionTab -and $idle) }
    foreach ($b in $btnScan, $btnUndo, $btnUndoRefresh, $btnOneClick, $btnHomeScan, $btnUndoAll, $btnRestart, $btnPutBack, $btnThatWasMe) { $b.IsEnabled = $idle }
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
    $script:Sync.Progress = $null
    $script:Sync.Cancel = $false
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
            # Where the work says how far it has got, and how it asks whether Stop has been pressed.
            Set-QpProgressSink { param($p) $Sync.Progress = $p }
            Set-QpCancelCheck { [bool]$Sync.Cancel }
            $Sync.Result = & ([scriptblock]::Create($WorkText)) @Params
        } catch {
            $Sync.Queue.Enqueue(('[{0}] ERROR   {1}' -f (Get-Date -Format 'HH:mm:ss'), $_.Exception.Message))
        }
    }
    [void]$ps.AddScript($wrapper.ToString()).AddArgument($Work.ToString()).AddArgument($Params)
    $script:Job = @{ PS = $ps; RS = $rs; Handle = $ps.BeginInvoke(); OnDone = $OnDone }
    Set-Busy $true $StatusText
}

# ------------------------------------------------------------------ live readings
# A small reader of its own, separate from Start-Work, so the Home tiles never block a button. It only
# reads while Home is on screen and the window isn't minimised; the rest of the time it sleeps. That
# also matters on gaming laptops: asking the graphics card how it is doing shouldn't keep it awake.
$script:Live = [hashtable]::Synchronized(@{ Reading = $null; Seq = 0; Active = $false; Stop = $false; Health = $null; HealthSeq = 0 })
$script:LiveSeqShown = 0
$script:HealthSeqShown = 0
$script:LiveJob = $null

function Start-LiveSampler {
    if ($script:LiveJob) { return }
    $rs = [runspacefactory]::CreateRunspace()
    $rs.Open()
    $rs.SessionStateProxy.SetVariable('Live', $script:Live)
    $rs.SessionStateProxy.SetVariable('ModulePath', $modulePath)
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript({
        Import-Module $ModulePath -Force
        $monitor = $null
        $healthAt = [datetime]::MinValue
        while (-not $Live.Stop) {
            if ($Live.Active) {
                # Nothing is set up until the Health tab is first opened.
                if (-not $monitor) { $monitor = New-QpLiveMonitor; Start-Sleep -Milliseconds 1000 }   # load is measured between two moments
                $Live.Reading = Get-QpLiveReading -Monitor $monitor
                $Live.Seq = $Live.Seq + 1
                # Battery and drive health change slowly: read on opening, then every five minutes.
                if (((Get-Date) - $healthAt).TotalMinutes -ge 5) {
                    $Live.Health = @{ Battery = Get-QpBatteryHealth; Drive = Get-QpDriveHealth }
                    $Live.HealthSeq = $Live.HealthSeq + 1
                    $healthAt = Get-Date
                }
                for ($i = 0; $i -lt 10 -and -not $Live.Stop; $i++) { Start-Sleep -Milliseconds 200 }
            } else {
                Start-Sleep -Milliseconds 400
            }
        }
    }.ToString())
    $script:LiveJob = @{ PS = $ps; RS = $rs; Handle = $ps.BeginInvoke() }
}

function Stop-LiveSampler {
    if (-not $script:LiveJob) { return }
    $script:Live.Stop = $true
    $job = $script:LiveJob
    $script:LiveJob = $null
    try { [void]$job.Handle.AsyncWaitHandle.WaitOne(1500) } catch { }
    try { $job.PS.Dispose(); $job.RS.Dispose() } catch { }
}

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(150)
$timer.Add_Tick({
    $line = $null
    $got = $false
    while ($script:Sync.Queue.TryDequeue([ref]$line)) { $ui.LogBox.AppendText($line + [Environment]::NewLine); $got = $true }
    if ($got) { $ui.LogBox.ScrollToEnd() }
    if ($script:Job -and $script:ScanRunning) { Update-ScanProgress }
    $script:Live.Active = ([string]$ui.Tabs.SelectedItem.Tag -eq 'health') -and ($window.WindowState -ne 'Minimized')
    if ($script:Live.HealthSeq -ne $script:HealthSeqShown) {
        $script:HealthSeqShown = $script:Live.HealthSeq
        try { $script:BatteryHealth = $script:Live.Health.Battery; Update-DriveCard $script:Live.Health.Drive } catch { }
    }
    if ($script:Live.Seq -ne $script:LiveSeqShown) {
        $script:LiveSeqShown = $script:Live.Seq
        try { Update-LiveTiles $script:Live.Reading } catch { }   # a reading must never be able to break the window
    }
    if ($script:Job -and $script:Job.Handle.IsCompleted) {
        $job = $script:Job
        $script:Job = $null
        try { [void]$job.PS.EndInvoke($job.Handle) } catch { $ui.LogBox.AppendText("ERROR: $($_.Exception.Message)" + [Environment]::NewLine) }
        $job.PS.Dispose()
        $job.RS.Dispose()
        # Each job runs in its own worker that is thrown away afterwards; hand its memory back now rather
        # than whenever .NET gets round to it, so the app stays small between jobs.
        [GC]::Collect()
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
    $script:LastState = $state
    foreach ($o in $script:Options['privacy']) { Set-OptionStatus $o ([string]$state.Privacy[$o.Id]) }
    Update-VendorTab @($state.Vendors)
    Update-StartupList @($state.Startup | Where-Object { $_ })
    $script:AppsList.Children.Clear()
    $script:Options['apps'].Clear()
    $apps = @($state.Apps | Where-Object { $_ })
    $script:RemoveSection.Expander.Header = New-Text ('Apps you could remove   ({0} found)' -f $apps.Count) 14.5 'SemiBold' '#117A68' '0' 'Fraunces, Georgia'
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
    Update-UndoList @($state.Restore)
    Update-QuarantineList
    Update-HomeCards $state
    # What switched itself back on since last time. Skipped in self-test, which must change nothing.
    if (-not $SelfTest) {
        $drift = $null
        try { $drift = Update-QpQuietNote -State $state -Accept:$script:AcceptQuiet } catch { }
        $script:AcceptQuiet = $false
        Update-CameBack $drift
    }
    if ($script:FirstLoad) {
        foreach ($k in 'privacy', 'vendors', 'apps', 'startup', 'cleanup') { Select-Recommended $k }
        $script:FirstLoad = $false
    } else {
        foreach ($k in 'apps', 'startup', 'cleanup', 'vendors') { Select-Recommended $k }
        foreach ($o in $script:Options['privacy']) { if ($o.Status -in 'Applied', 'NotApplicable') { $o.CheckBox.IsChecked = $false } }
    }
}

$script:CameBack = $null
$script:LastState = $null
function Update-CameBack($d) {
    <# The "welcome back" panel: what switched itself back on, since when, and the likely reason. #>
    $script:CameBack = $d
    if (-not $d -or -not $d.Count) { $script:BackPanel.Visibility = 'Collapsed'; return }
    $settings = @($d.Privacy).Count + @($d.Vendors).Count
    $what = @()
    if ($settings) { $what += $(if ($settings -eq 1) { '1 setting' } else { "$settings settings" }) }
    if (@($d.Apps).Count) { $what += $(if (@($d.Apps).Count -eq 1) { '1 app' } else { "$(@($d.Apps).Count) apps" }) }
    if (@($d.Startup).Count) { $what += $(if (@($d.Startup).Count -eq 1) { '1 startup item' } else { "$(@($d.Startup).Count) startup items" }) }
    $whatText = ($what -join ', ') -replace ', ([^,]+)$', ' and $1'
    $script:BackTitle.Text = if ($d.Count -eq 1) { 'Welcome back - one thing switched itself back on' } else { "Welcome back - $($d.Count) things switched themselves back on" }
    $since = if ($d.Since) { ' since {0}' -f $d.Since.ToString('d MMMM') } else { '' }
    $why = if ($d.WindowsUpdated) { " Windows has updated in between, $($d.WindowsChange), which is the usual reason." } else { ' Updates to Windows or to your apps are the usual reason.' }
    $script:BackText.Text = "$whatText came back on$since.$why"
    $names = @(@($d.Privacy) + @($d.Vendors) + @($d.Apps) + @($d.Startup) | ForEach-Object { if ($_.Title) { $_.Title } else { $_.Id } })
    $script:BackList.Text = ($names | Select-Object -First 8) -join ', '
    if ($names.Count -gt 8) { $script:BackList.Text += (' and {0} more' -f ($names.Count - 8)) }
    $script:BackPanel.Visibility = 'Visible'
}

$btnPutBack.Add_Click({
    $d = $script:CameBack
    if (-not $d -or -not $d.Count) { return }
    $msg = "Switch these off again?`n`n" + ((@(@($d.Privacy) + @($d.Vendors) + @($d.Apps) + @($d.Startup)) | ForEach-Object { '  - ' + $(if ($_.Title) { $_.Title } else { $_.Id }) }) -join "`n") + "`n`nOnly these change, a restore point is saved first, and Undo puts them back."
    if ([System.Windows.MessageBox]::Show($msg, 'Quietpane', 'YesNo', 'Question') -ne 'Yes') { return }
    $ui.LogBox.AppendText([Environment]::NewLine)
    $params = @{
        PrivacyIds = @($d.Privacy | ForEach-Object { $_.Id }); VendorIds = @($d.Vendors | ForEach-Object { $_.Id })
        AppNames = @($d.Apps | ForEach-Object { $_.Id }); StartupIds = @($d.Startup | ForEach-Object { $_.Id })
    }
    Start-Work -StatusText 'Switching them off again...' -Params $params -Work {
        param($PrivacyIds, $VendorIds, $AppNames, $StartupIds)
        Invoke-QpPutBack -PrivacyIds $PrivacyIds -VendorIds $VendorIds -AppNames $AppNames -StartupIds $StartupIds
    } -OnDone { Update-StateAfterChange }
})

$btnThatWasMe.Add_Click({
    # Your call: the note starts afresh from how things are now, and nothing is changed.
    if ($script:LastState) { try { [void](Update-QpQuietNote -State $script:LastState -Accept) } catch { } }
    Update-CameBack $null
})

function Update-StartupList($items) {
    <#
        Only what is switched on can be ticked. Everything else is summed up in a line, so the list stays
        short: what's already off, what's always left on (and why), and what a policy controls.
    #>
    $script:StartupList.Children.Clear()
    $script:Options['startup'].Clear()
    $on     = @($items | Where-Object { $_.On -and -not $_.Keep -and -not $_.Locked } | Sort-Object Name)
    $off    = @($items | Where-Object { -not $_.On -and -not $_.Keep } | Sort-Object Name)
    $kept   = @($items | Where-Object { $_.Keep })
    $locked = @($items | Where-Object { $_.Locked -and $_.On -and -not $_.Keep })
    $script:StartupSection.Expander.Header = New-Text ('Starts when you sign in   ({0} on, {1} off)' -f ($on.Count + @($kept | Where-Object On).Count + $locked.Count), ($off.Count + @($kept | Where-Object { -not $_.On }).Count)) 14.5 'SemiBold' '#117A68' '0' 'Fraunces, Georgia'
    if (-not $on.Count) { [void]$script:StartupList.Children.Add((New-Text 'Nothing extra starts when you sign in. Lovely.' 13 'SemiBold' '#117A68' '0,8,0,0')) }
    foreach ($i in $on) {
        $bits = @()
        if ($i.Note) { $bits += $i.Note }
        if ($i.Missing) { $bits += 'The program it points to is gone, so this does nothing - switching it off just tidies up.' }
        $who = if ($i.Publisher) { "From $($i.Publisher)." } else { 'The publisher isn''t recorded.' }
        if ($i.Everyone) { $who += ' Starts for everyone who uses this PC.' }
        $bits += $who
        Add-Option -Panel $script:StartupList -Key 'startup' -Id $i.Id -Title $i.Name -Description ($bits -join ' ') -Recommended $false
        $script:Options['startup'][$script:Options['startup'].Count - 1].CheckBox.ToolTip = $i.Command
    }
    if ($locked.Count) {
        [void]$script:StartupList.Children.Add((New-Text ('Set by a policy on this PC, so they stay as they are: ' + (($locked | ForEach-Object { $_.Name }) -join ', ') + '.') 12.5 'Normal' '#4B5B5C' '0,12,0,0'))
    }
    if ($off.Count) {
        [void]$script:StartupList.Children.Add((New-Text ('Already off: ' + (($off | ForEach-Object { $_.Name }) -join ', ') + '.') 12.5 'Normal' '#8A9696' '0,12,0,0'))
    }
    $keptOn = @($kept | Where-Object On)
    if ($keptOn.Count) {
        $t = New-Text ('Always left on: ' + (($keptOn | ForEach-Object { $_.Name }) -join ', ') + '. Windows or your drivers need these.') 12.5 'Normal' '#8A9696' '0,6,0,0'
        $t.ToolTip = ($keptOn | ForEach-Object { "$($_.Name): $($_.KeepWhy)" }) -join "`n"
        [void]$script:StartupList.Children.Add($t)
    }
    # Something important switched off by someone else: say so kindly, and leave the choice with them.
    foreach ($k in @($kept | Where-Object { -not $_.On })) {
        [void]$script:StartupList.Children.Add((New-Text ('{0} is switched off at sign-in. {1} If that wasn''t on purpose, turn it back on in Task Manager > Startup apps.' -f $k.Name, $k.KeepWhy) 12.5 'Normal' '#9A6700' '0,6,0,0'))
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
    Start-Work -StatusText 'Removing the extras you picked...' -Params @{ Keys = $keys } -Work { param($Keys) Invoke-QpVendorUninstall -Keys $Keys } -OnDone { Update-StateAfterChange }
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
    # Startup is never part of one-click (what you want at sign-in is personal), so just point to it.
    $starting = @($state.Startup | Where-Object { $_ -and $_.On -and -not $_.Keep -and -not $_.Locked }).Count
    if ($starting) { $script:CardApps.Caption.Text += ('. {0} start when you sign in - see Apps' -f $starting) }
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
    if ($u.MemTotal -gt 0) { Set-MemoryTile $u.MemUsed $u.MemTotal }
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

function Get-ShortName([string]$Name) {
    # "13th Gen Intel(R) Core(TM) i7-13620H" -> "Intel Core i7-13620H"; "NVIDIA GeForce RTX 4060 Laptop GPU" -> "RTX 4060 Laptop GPU"
    $n = $Name -replace '\((R|TM)\)', '' -replace '^\s*\d+(st|nd|rd|th) Gen\s+', '' -replace '\s+CPU\s+@.*$', '' -replace '\s+with Radeon Graphics$', ''
    $n = $n -replace '^NVIDIA GeForce\s+', '' -replace '\s{2,}', ' '
    return $n.Trim()
}

function Set-MemoryTile([double]$Used, [double]$Total) {
    if ($Total -le 0) { return }
    $script:TileMemory.Value.Text = '{0:N0}%' -f (100 * $Used / $Total)
    # Memory has no temperature, so its first line says what the number is, lining up with the others.
    $script:TileMemory.Heat.Text = 'in use right now'
    $script:TileMemory.Heat.Foreground = Get-Brush '#4B5B5C'; $script:TileMemory.Heat.FontWeight = 'Normal'
    $script:TileMemory.Caption.Text = '{0} of {1}' -f (Format-QpBytes $Used), (Format-QpBytes $Total)
    Set-MeterFill $script:TileMemory ($Used / $Total)
}

$script:HeatColours = @{ ok = '#117A68'; warn = '#9A6700'; high = '#A83232'; none = '#8A9696' }
function Set-HeatText($Block, $Celsius, $MaxC, [bool]$Stuck, [string]$Tip) {
    # Number and word together, so heat never depends on colour alone.
    $deg = [char]0x00B0
    $dot = [char]0x00B7
    $h = Get-QpHeatWord -Celsius $Celsius -MaxC $MaxC
    if ($null -eq $Celsius) {
        $Block.Text = 'temperature not shared'
        $Block.Foreground = Get-Brush $script:HeatColours.none
    } elseif ($Stuck) {
        $Block.Text = '{0:N0}{1}C {2} sensor not updating' -f $Celsius, $deg, $dot
        $Block.Foreground = Get-Brush $script:HeatColours.none
        $Tip = 'This number has not changed at all for a while, so this PC''s sensor probably isn''t live. Treat it as unknown.'
    } else {
        $Block.Text = '{0:N0}{1}C {2} {3}' -f $Celsius, $deg, $dot, $h.Word
        $Block.Foreground = Get-Brush $script:HeatColours[$h.Level]
    }
    $Block.ToolTip = $Tip
}

function Set-TopText($Tile, $Top) {
    # "No Man's Sky 94%" - the busiest programs, one per line, names kept short enough for the tile.
    $lines = @(@($Top) | Where-Object { $_ } | ForEach-Object {
        $n = [string]$_.Name
        if ($n.Length -gt 22) { $n = $n.Substring(0, 21).TrimEnd() + [char]0x2026 }
        '{0} {1}%' -f $n, $_.Pct
    })
    if ($lines.Count) {
        $Tile.Top.Text = $lines -join "`n"
        $Tile.Top.ToolTip = 'The programs using it most right now, the same way Task Manager counts them.'
        $Tile.Top.Visibility = 'Visible'
    } else {
        $Tile.Top.Visibility = 'Collapsed'
    }
}

$script:BatteryHealth = $null   # how much the battery holds compared with new - read by the Health tab
function Update-BatteryCard($Live) {
    <# Charge and power every reading; how much it holds compared with new whenever that's been read. #>
    $c = $script:BatteryCard
    if (-not $Live) { $c.Border.Visibility = 'Collapsed'; return }   # a desktop, or a battery that isn't saying
    $c.Value.Text = '{0}%' -f $Live.Percent
    Set-MeterFill $c ($Live.Percent / 100)
    $c.Caption.Text = if ($Live.Charging) { 'Charging' } elseif ($Live.PluggedIn) { 'Plugged in' } else { 'On battery' }
    $h = $script:BatteryHealth
    if ($h) {
        $t = $script:BatteryHealthText
        $t.Text = 'Holds {0}% of what it did when new' -f $h.Percent
        $t.Foreground = Get-Brush $(if ($h.Percent -lt 60) { $script:HeatColours.warn } else { '#0F1B1C' })
        $tip = "Built to hold {0} Wh; it holds {1} Wh now. Every battery slowly loses capacity with age - below about 80% you may notice it runs out sooner. That's wear, not a fault." -f $h.DesignWh, $h.FullWh
        if ($h.Cycles) { $tip += " It has been through about $($h.Cycles) charge cycles." }
        $t.ToolTip = $tip
        $t.Visibility = 'Visible'
    } else {
        $script:BatteryHealthText.Visibility = 'Collapsed'
    }
    $c.Border.Visibility = 'Visible'
}

function Update-DriveCard($d) {
    <# Windows' own verdict on the drive it runs from, with wear and heat where the drive shares them. #>
    $c = $script:DriveCard
    $track = $c.Fill.Parent
    if (-not $d) {
        $c.Value.Text = 'Not shared'
        $c.Caption.Text = 'Windows did not say how this drive is doing.'
        $track.Visibility = 'Collapsed'; $script:DriveHeatText.Visibility = 'Collapsed'
        return
    }
    $deg = [char]0x00B0; $dot = [char]0x00B7
    if ($d.Health -and $d.Health -ne 'Healthy') {
        $c.Value.Text = 'Needs attention'
        $c.Value.Foreground = Get-Brush $script:HeatColours.high
        $c.Caption.Text = 'Windows reports a problem with this drive. Back up your files soon.'
    } else {
        $c.Value.Text = 'Healthy'
        $c.Value.Foreground = Get-Brush '#117A68'
        $c.Caption.Text = if ($null -ne $d.WearPct) { '{0} {1} {2}% of its rated life used' -f $d.Media, $dot, $d.WearPct } else { "$($d.Media)".Substring(0, 1).ToUpper() + "$($d.Media)".Substring(1) }
    }
    # The bar is how much of its rated life the drive has used - only when the drive says.
    if ($null -ne $d.WearPct) { Set-MeterFill $c ([math]::Min(100, $d.WearPct) / 100); $track.Visibility = 'Visible' } else { $track.Visibility = 'Collapsed' }
    if ($null -ne $d.TempC) {
        $h = Get-QpHeatWord -Celsius $d.TempC -Kind Drive
        $script:DriveHeatText.Text = '{0}{1}C {2} {3}' -f $d.TempC, $deg, $dot, $h.Word
        $script:DriveHeatText.Foreground = Get-Brush $script:HeatColours[$h.Level]
        $script:DriveHeatText.Visibility = 'Visible'
    } else {
        $script:DriveHeatText.Visibility = 'Collapsed'
    }
    $tip = "$($d.Name). 'Healthy' is Windows' own verdict on the drive."
    if ($null -ne $d.WearPct) { $tip += ' Rated life is what the maker promises for writing data; under 100% is within that.' }
    if ($d.PowerOnHours) { $tip += " Switched on for about {0:N0} hours in total." -f $d.PowerOnHours }
    $c.Border.ToolTip = $tip
}

function Update-LiveTiles($r) {
    <# Paints one reading onto the four tiles. Anything the PC doesn't share says so plainly. #>
    if (-not $r) { return }
    $deg = [char]0x00B0

    $t = $script:TileCpu
    if ($null -ne $r.CpuUsage) { $t.Value.Text = '{0:N0}%' -f $r.CpuUsage; Set-MeterFill $t ($r.CpuUsage / 100) } else { $t.Value.Text = '-' }
    $t.Caption.Text = Get-ShortName $r.CpuName
    Set-TopText $t $r.CpuTop
    Update-BatteryCard $r.Battery
    $zone = if ($r.CpuTempSource) { " ($($r.CpuTempSource))" } else { '' }
    Set-HeatText $t.Heat $r.CpuTempC $null ([bool]$r.CpuTempStuck) ("From Windows' own thermal sensor$zone. On some PCs that is the processor itself, on others a sensor close to it, so treat it as a guide. Laptops often run hot when busy - it's only a worry if it stays very hot while the PC is doing nothing.")
    # Windows holding the processor back to cool it: the moment a game suddenly stutters for no reason.
    if ($r.CpuThrottled) {
        $t.Extra.Text = 'slowing down to cool off - running at {0:N0}%' -f $r.CpuLimitPct
        $t.Extra.Foreground = Get-Brush $script:HeatColours.warn
        $t.Extra.FontWeight = 'SemiBold'
        $t.Extra.ToolTip = 'Windows is holding the processor back to shed heat, so things can feel slower until it cools. Common on laptops during games. Clear vents and a hard, flat surface help. Slowing down done inside the chip itself is not visible to Windows, so this cannot catch every case.'
        $t.Extra.Visibility = 'Visible'
    } else {
        $t.Extra.Visibility = 'Collapsed'
    }

    $gpus = @($r.Gpus)
    $g = $gpus | Select-Object -First 1
    $t = $script:TileGpu
    if ($g) {
        $t.Value.Text = '{0:N0}%' -f $g.Usage
        Set-MeterFill $t ($g.Usage / 100)
        $t.Caption.Text = Get-ShortName $g.Name
        Set-TopText $t $g.Top
        $tip = if ($g.TempMaxC) { "From the graphics driver - the same reading Task Manager shows. The driver says this card is built for up to {0:N0}{1}C." -f $g.TempMaxC, $deg } else { 'From the graphics driver - the same reading Task Manager shows.' }
        if ($null -eq $g.TempC -and -not $g.Discrete) { $tip = 'Built-in graphics share the processor''s cooling, so the driver doesn''t report its own temperature.' }
        elseif ($null -eq $g.TempC) { $tip = 'The driver isn''t sharing a temperature right now. On laptops the graphics card often sleeps when it isn''t needed.' }
        Set-HeatText $t.Heat $g.TempC $g.TempMaxC $false $tip
        # Gaming laptops have two: say how busy the other one is, quietly.
        $other = $gpus | Select-Object -Skip 1 -First 1
        if ($other) { $t.Extra.Text = 'also {0}: {1:N0}%' -f (Get-ShortName $other.Name), $other.Usage; $t.Extra.Visibility = 'Visible' } else { $t.Extra.Visibility = 'Collapsed' }
    } else {
        $t.Value.Text = '-'
        $t.Caption.Text = 'not shared by this PC'
        $t.Heat.Text = ''
        $t.Top.Visibility = 'Collapsed'
    }

    if ($null -ne $r.MemUsed) { Set-MemoryTile $r.MemUsed $r.MemTotal }

    $t = $script:TileVram
    if ($g -and $g.Discrete -and $g.DedicatedTotal -gt 0) {
        $t.Value.Text = '{0:N0}%' -f (100 * $g.DedicatedUsed / $g.DedicatedTotal)
        $t.Caption.Text = '{0} of {1}' -f (Format-QpBytes $g.DedicatedUsed), (Format-QpBytes $g.DedicatedTotal)
        $t.Heat.Text = 'on the graphics card'
        $t.Heat.Foreground = Get-Brush '#4B5B5C'; $t.Heat.FontWeight = 'Normal'
        Set-MeterFill $t ($g.DedicatedUsed / $g.DedicatedTotal)
    } elseif ($g -and $g.SharedTotal -gt 0) {
        $t.Value.Text = '{0:N0}%' -f (100 * $g.SharedUsed / $g.SharedTotal)
        $t.Caption.Text = '{0} of {1}' -f (Format-QpBytes $g.SharedUsed), (Format-QpBytes $g.SharedTotal)
        $t.Heat.Text = 'borrowed from memory'
        $t.Heat.Foreground = Get-Brush '#4B5B5C'; $t.Heat.FontWeight = 'Normal'
        Set-MeterFill $t ($g.SharedUsed / $g.SharedTotal)
    } else {
        $t.Value.Text = '-'
        $t.Caption.Text = 'not shared by this PC'
        $t.Heat.Text = ''
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

# One pass over the PC, sharing its slow lookups (see Get-QpState). Health is read by its own tab.
$script:ReadState = { Get-QpState }

function Update-State {
    Start-Work -StatusText 'Reading the current state of this PC...' -Work $script:ReadState -OnDone { param($s) Update-FromState $s }
}

$script:AcceptQuiet = $false
function Update-UndoList($points) {
    $script:UndoList.Items.Clear()
    foreach ($r in @($points | Where-Object { $_ })) {
        $li = New-Object System.Windows.Controls.ListBoxItem
        $li.Content = '{0}   -   {1} change(s){2}' -f $r.Name, $r.Changes, $(if ($r.Undone) { '   (already undone)' } else { '' })
        $li.Tag = $r.Path
        [void]$script:UndoList.Items.Add($li)
    }
    if ($script:UndoList.Items.Count -eq 0) { [void]$script:UndoList.Items.Add('No restore points yet.') }
}

function Update-StateAfterChange {
    # After something you did yourself (Apply, one-click, Undo...), the "came back" note starts afresh,
    # so your own choices are never reported as things that switched themselves back on.
    $script:AcceptQuiet = $true
    # The Undo list is quick to read, so it's brought up to date straight away rather than after the
    # full re-read - the new restore point is there the moment you look.
    try { Update-UndoList @(Get-QpRestorePoints) } catch { }
    Update-State
}

# ------------------------------------------------------------------ actions
function Get-SelectedIds([string]$Key) {
    @($script:Options[$Key] | Where-Object { $_.CheckBox.IsChecked } | ForEach-Object { $_.Id })
}

function Invoke-Selected([bool]$Preview) {
    $key = [string]$ui.Tabs.SelectedItem.Tag
    $ids = Get-SelectedIds $key
    # The Apps tab holds two lists: startup items and apps to remove. One Apply does both.
    $startupIds = if ($key -eq 'apps') { @(Get-SelectedIds 'startup') } else { @() }
    if ($ids.Count -eq 0 -and $startupIds.Count -eq 0) { [void][System.Windows.MessageBox]::Show('Pick at least one thing first.', 'Quietpane'); return }
    if (-not $Preview) {
        $msg = switch ($key) {
            'apps'    {
                $parts = @()
                if ($startupIds.Count) { $parts += "stop $($startupIds.Count) thing(s) starting when you sign in - they still open when you start them, and Undo turns them back on" }
                if ($ids.Count) { $parts += "remove $($ids.Count) app(s) - the Microsoft Store has them if you want them back" }
                "Shall I " + ($parts -join ",`nand ") + "?"
            }
            'cleanup' { "Move the ticked items to the Recycle Bin?`n`nNothing is deleted for good - you empty the bin yourself when you are happy." }
            default   { "Go ahead with the $($ids.Count) ticked item(s)?`n`nA restore point is saved first, so you can undo this from the Undo tab." }
        }
        if ([System.Windows.MessageBox]::Show($msg, 'Quietpane', 'YesNo', 'Question') -ne 'Yes') { return }
    }
    $ui.LogBox.AppendText([Environment]::NewLine)
    Set-LogVisible $true   # preview/apply results are shown in the details log
    $after = if ($Preview) { $null } else { { Update-StateAfterChange } }
    $verb = if ($Preview) { 'Previewing' } else { 'Applying' }
    switch ($key) {
        'privacy' { Start-Work -StatusText "$verb privacy changes..." -Params @{ Ids = $ids; Preview = $Preview } -OnDone $after -Work { param($Ids, $Preview) Invoke-QpPrivacy -Ids $Ids -Preview:$Preview } }
        'vendors' { Start-Work -StatusText "$verb brand and hardware changes..." -Params @{ Ids = $ids; Preview = $Preview } -OnDone $after -Work { param($Ids, $Preview) Invoke-QpVendor -Ids $Ids -Preview:$Preview } }
        'apps'    {
            $dep = [bool]$script:DeprovisionCb.IsChecked
            Start-Work -StatusText "$verb apps and startup changes..." -Params @{ Ids = $ids; Startup = $startupIds; Preview = $Preview; Deprovision = $dep } -OnDone $after -Work {
                param($Ids, $Startup, $Preview, $Deprovision)
                # An empty list arrives as $null, and @($null).Count is 1 - so count real entries only.
                $Startup = @($Startup | Where-Object { $_ }); $Ids = @($Ids | Where-Object { $_ })
                if ($Startup.Count) { Invoke-QpStartup -Ids $Startup -Preview:$Preview }
                if ($Ids.Count) { Invoke-QpRemoveApps -Names $Ids -Preview:$Preview -Deprovision:$Deprovision }
            }
        }
        'cleanup' { Start-Work -StatusText "$verb clean-up..." -Params @{ Ids = $ids; Preview = $Preview } -OnDone $after -Work { param($Ids, $Preview) Invoke-QpCleanup -Ids $Ids -Preview:$Preview } }
    }
}

$ui.BtnPreview.Add_Click({ Invoke-Selected $true })
$ui.BtnApply.Add_Click({ Invoke-Selected $false })
function Get-TabOptionKeys {
    # The Apps tab carries two lists; every other tab carries one.
    $tag = [string]$ui.Tabs.SelectedItem.Tag
    if ($tag -eq 'apps') { return @('startup', 'apps') }
    return @($tag)
}
$ui.BtnRecommended.Add_Click({ foreach ($k in Get-TabOptionKeys) { Select-Recommended $k } })
$ui.BtnNone.Add_Click({ foreach ($k in Get-TabOptionKeys) { foreach ($o in $script:Options[$k]) { $o.CheckBox.IsChecked = $false } } })

function Draw-SeverityChart {
    <# A doughnut drawn with arcs. Each slice is also a row in the legend, with its name and count. #>
    $script:ChartCanvas.Children.Clear()
    $cx = 86.0; $cy = 86.0; $r = 64.0; $thick = 24.0
    $total = 0; foreach ($k in $script:SevCounts.Keys) { $total += [int]$script:SevCounts[$k] }
    $ring = New-Object System.Windows.Shapes.Ellipse
    $ring.Width = $r * 2; $ring.Height = $r * 2
    $ring.Stroke = Get-Brush '#EDE6D5'; $ring.StrokeThickness = $thick; $ring.Fill = $null
    [System.Windows.Controls.Canvas]::SetLeft($ring, $cx - $r); [System.Windows.Controls.Canvas]::SetTop($ring, $cy - $r)
    [void]$script:ChartCanvas.Children.Add($ring)
    if ($total -gt 0) {
        $angle = -90.0
        foreach ($k in $script:SevCounts.Keys) {
            $n = [int]$script:SevCounts[$k]
            if ($n -le 0) { continue }
            $sweep = 360.0 * $n / $total
            if ($sweep -ge 359.99) {
                $full = New-Object System.Windows.Shapes.Ellipse
                $full.Width = $r * 2; $full.Height = $r * 2
                $full.Stroke = Get-Brush $script:SevColours[$k]; $full.StrokeThickness = $thick; $full.Fill = $null
                [System.Windows.Controls.Canvas]::SetLeft($full, $cx - $r); [System.Windows.Controls.Canvas]::SetTop($full, $cy - $r)
                [void]$script:ChartCanvas.Children.Add($full)
                break
            }
            $a1 = $angle * [Math]::PI / 180.0
            $a2 = ($angle + $sweep) * [Math]::PI / 180.0
            $p1 = [System.Windows.Point]::new($cx + $r * [Math]::Cos($a1), $cy + $r * [Math]::Sin($a1))
            $p2 = [System.Windows.Point]::new($cx + $r * [Math]::Cos($a2), $cy + $r * [Math]::Sin($a2))
            $fig = New-Object System.Windows.Media.PathFigure
            $fig.StartPoint = $p1
            $arc = New-Object System.Windows.Media.ArcSegment
            $arc.Point = $p2
            $arc.Size = [System.Windows.Size]::new($r, $r)
            $arc.SweepDirection = 'Clockwise'
            $arc.IsLargeArc = ($sweep -gt 180)
            [void]$fig.Segments.Add($arc)
            $geo = New-Object System.Windows.Media.PathGeometry
            [void]$geo.Figures.Add($fig)
            $path = New-Object System.Windows.Shapes.Path
            $path.Data = $geo
            $path.Stroke = Get-Brush $script:SevColours[$k]
            $path.StrokeThickness = $thick
            $path.ToolTip = '{0}: {1}' -f $k, $n
            [void]$script:ChartCanvas.Children.Add($path)
            $angle += $sweep
        }
    }
    $centre = New-Object System.Windows.Controls.StackPanel
    $centre.Width = 96
    [void]$centre.Children.Add((New-Text "$total" 30 'SemiBold' '#0F1B1C' '0' 'Fraunces, Georgia'))
    [void]$centre.Children.Add((New-Text $(if ($total -eq 1) { 'finding' } else { 'findings' }) 12 'Normal' '#4B5B5C' '0'))
    foreach ($c in $centre.Children) { $c.TextAlignment = 'Center' }
    [System.Windows.Controls.Canvas]::SetLeft($centre, $cx - 48); [System.Windows.Controls.Canvas]::SetTop($centre, $cy - 26)
    [void]$script:ChartCanvas.Children.Add($centre)

    $script:LegendPanel.Children.Clear()
    $allBtn = New-Object System.Windows.Controls.Button
    $allBtn.Content = New-Text $('Show everything ({0})' -f $total) 13 'SemiBold' '#0F1B1C' '0'
    $allBtn.Margin = Get-Thick '0,0,0,6'; $allBtn.Padding = Get-Thick '10,4'
    $allBtn.HorizontalContentAlignment = 'Left'; $allBtn.HorizontalAlignment = 'Left'
    $allBtn.Add_Click({ $script:SevFilter = 'All'; Show-Findings })
    [void]$script:LegendPanel.Children.Add($allBtn)
    foreach ($k in $script:SevCounts.Keys) {
        $n = [int]$script:SevCounts[$k]
        $row = New-Object System.Windows.Controls.Button
        $row.Margin = Get-Thick '0,1,0,1'; $row.Padding = Get-Thick '6,3'
        $row.HorizontalContentAlignment = 'Left'; $row.HorizontalAlignment = 'Left'
        $row.Background = $null; $row.BorderThickness = Get-Thick '0'
        $row.Cursor = 'Hand'
        $row.IsEnabled = ($n -gt 0)
        $row.Opacity = $(if ($n -gt 0) { 1.0 } else { 0.45 })
        $row.Tag = $k
        $inner = New-Object System.Windows.Controls.StackPanel
        $inner.Orientation = 'Horizontal'
        $key = New-Object System.Windows.Shapes.Rectangle
        $key.Width = 13; $key.Height = 13; $key.Fill = Get-Brush $script:SevColours[$k]
        $key.Margin = Get-Thick '0,0,8,0'; $key.VerticalAlignment = 'Center'
        [void]$inner.Children.Add($key)
        [void]$inner.Children.Add((New-Text ('{0} - {1}' -f $k, $script:SevMeaning[$k]) 13 'Normal' '#0F1B1C' '0,0,10,0'))
        [void]$inner.Children.Add((New-Text "$n" 13 'SemiBold' '#0F1B1C' '0'))
        $row.Content = $inner
        $row.ToolTip = "Show only $k findings"
        $row.Add_Click({ $script:SevFilter = [string]$this.Tag; Show-Findings })
        [void]$script:LegendPanel.Children.Add($row)
    }
}

function Show-ChoiceDialog {
    <# A small window offering several ways forward, safest first. Returns the chosen key, or $null. #>
    param([string]$Title, [string]$Message, [object[]]$Options)
    $dlg = New-Object System.Windows.Window
    $dlg.Title = $Title
    $dlg.SizeToContent = 'WidthAndHeight'
    $dlg.WindowStartupLocation = 'CenterOwner'
    $dlg.ResizeMode = 'NoResize'
    $dlg.Background = Get-Brush '#FAF6EC'
    if ($window -and $window.IsVisible) { $dlg.Owner = $window }
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Margin = Get-Thick '22,18'
    $sp.MaxWidth = 560
    [void]$sp.Children.Add((New-Text $Message 13.5 'Normal' '#0F1B1C' '0,0,0,14'))
    $script:ChoiceResult = $null
    foreach ($o in $Options) {
        $b = if ($o.Primary) { New-Button $o.Label -Primary } else { New-Button $o.Label }
        $b.Margin = Get-Thick '0,0,0,4'
        $b.Padding = Get-Thick '16,10'
        $b.HorizontalContentAlignment = 'Left'
        $b.HorizontalAlignment = 'Stretch'
        $b.Tag = $o.Key
        $b.Add_Click({ $script:ChoiceResult = [string]$this.Tag; $script:ChoiceDialog.Close() })
        [void]$sp.Children.Add($b)
        if ($o.Note) { [void]$sp.Children.Add((New-Text $o.Note 12 'Normal' '#4B5B5C' '4,0,0,10')) }
    }
    $cancel = New-Button 'Cancel'
    $cancel.Margin = Get-Thick '0,6,0,0'
    $cancel.Add_Click({ $script:ChoiceResult = $null; $script:ChoiceDialog.Close() })
    [void]$sp.Children.Add($cancel)
    $dlg.Content = $sp
    $script:ChoiceDialog = $dlg
    [void]$dlg.ShowDialog()
    return $script:ChoiceResult
}

function New-FindingCard($f) {
    $b = New-Object System.Windows.Controls.Border
    $b.Background = Get-Brush '#FFFDF8'
    $b.BorderBrush = Get-Brush '#E6DFCC'
    $b.BorderThickness = Get-Thick '1,1,1,1'
    $b.Margin = Get-Thick '0,0,0,10'
    $b.Padding = Get-Thick '14,12'
    $sp = New-Object System.Windows.Controls.StackPanel
    $head = New-Object System.Windows.Controls.StackPanel
    $head.Orientation = 'Horizontal'
    $chip = New-Object System.Windows.Controls.Border
    $chip.Background = Get-Brush $script:SevColours[$f.Severity]
    $chip.Padding = Get-Thick '8,2'; $chip.Margin = Get-Thick '0,0,10,0'; $chip.VerticalAlignment = 'Center'
    $chipText = New-Text ($f.Severity.ToUpper()) 11 'SemiBold' '#FFFDF8' '0'
    $chip.Child = $chipText
    [void]$head.Children.Add($chip)
    [void]$head.Children.Add((New-Text $f.Title 16 'SemiBold' '#0F1B1C' '0' 'Fraunces, Georgia'))
    [void]$sp.Children.Add($head)
    $facts = @("found by $($f.Source)")
    if ($f.Confidence) { $facts += "confidence: $($f.Confidence)" }
    if ($f.Status) { $facts += "status: $($f.Status)" }
    if ($f.Category) { $facts += $f.Category }
    [void]$sp.Children.Add((New-Text ($facts -join '   |   ') 12 'Normal' '#4B5B5C' '0,6,0,0'))
    if ($f.What) { [void]$sp.Children.Add((New-Text $f.What 13.5 'Normal' '#0F1B1C' '0,8,0,0')) }
    if ($f.Why)  { [void]$sp.Children.Add((New-Text $f.Why 13 'Normal' '#4B5B5C' '0,4,0,0')) }
    if ($f.Path) { [void]$sp.Children.Add((New-Text ('Where: ' + $f.Path) 12.5 'Normal' '#4B5B5C' '0,6,0,0')) }
    if ($f.Recommended) { [void]$sp.Children.Add((New-Text ('What to do: ' + $f.Recommended) 13 'SemiBold' '#117A68' '0,6,0,0')) }

    # Anything with a real file behind it can be acted on. Findings without a file are information only.
    # Failed counts as actionable: if an attempt did not work, the thing is still there to try again.
    $actionable = ($f.Status -in 'Detected', 'Allowed', 'Failed') -and (($f.Source -eq 'Microsoft Defender') -or ($f.Path -and (Test-Path -LiteralPath $f.Path -PathType Leaf)))
    if ($actionable) {
        $btns = New-Object System.Windows.Controls.WrapPanel
        $btns.Margin = Get-Thick '0,10,0,0'
        $remove = New-Button 'Remove it'
        $remove.Tag = $f.Id
        $remove.Add_Click({ Invoke-FindingAction ([string]$this.Tag) 'Choose' })
        $quar = New-Button 'Quarantine'
        $quar.Tag = $f.Id
        $quar.ToolTip = 'Move it into Quietpane''s own quarantine, where it cannot run. You can put it back later.'
        $quar.Add_Click({ Invoke-FindingAction ([string]$this.Tag) 'Quarantine' })
        $leave = New-Button 'Leave it for now'
        $leave.Tag = $f.Id
        $leave.Add_Click({ Invoke-FindingAction ([string]$this.Tag) 'Allow' })
        foreach ($x in $remove, $quar, $leave) { $x.Margin = Get-Thick '0,0,8,0'; [void]$btns.Children.Add($x) }
        [void]$sp.Children.Add($btns)
    }
    if ($f.Technical) {
        $ex = New-Object System.Windows.Controls.Expander
        $ex.Header = New-Text 'Technical details' 12.5 'SemiBold' '#4B5B5C' '0'
        $ex.Margin = Get-Thick '0,8,0,0'
        $tech = New-Text $f.Technical 12 'Normal' '#4B5B5C' '0,6,0,0'
        $tech.FontFamily = New-Object System.Windows.Media.FontFamily('Consolas, Courier New')
        $inner = New-Object System.Windows.Controls.StackPanel
        [void]$inner.Children.Add($tech)
        if ($f.Sha256) { [void]$inner.Children.Add((New-Text ('SHA256: ' + $f.Sha256) 12 'Normal' '#4B5B5C' '0,6,0,0')) }
        $ex.Content = $inner
        [void]$sp.Children.Add($ex)
    }
    $b.Child = $sp
    return $b
}

function Show-Findings {
    $script:FindingsPanel.Children.Clear()
    $list = @($script:ScanFindings)
    if ($script:SevFilter -ne 'All') { $list = @($list | Where-Object { $_.Severity -eq $script:SevFilter }) }
    if (-not $list.Count) {
        $msg = if ($script:SevFilter -eq 'All') { 'Nothing was found. Lovely.' } else { "Nothing at $($script:SevFilter) level." }
        [void]$script:FindingsPanel.Children.Add((New-Text $msg 13.5 'SemiBold' '#117A68' '0,4,0,0'))
        return
    }
    $rank = @{ Critical = 0; High = 1; Medium = 2; Low = 3; Info = 4 }
    $shown = @($list | Sort-Object { $rank[$_.Severity] } | Select-Object -First 60)
    $heading = if ($script:SevFilter -eq 'All') { 'What we found' } else { "$($script:SevFilter) findings" }
    [void]$script:FindingsPanel.Children.Add((New-Text $heading 16 'SemiBold' '#117A68' '0,4,0,8' 'Fraunces, Georgia'))
    foreach ($f in $shown) { [void]$script:FindingsPanel.Children.Add((New-FindingCard $f)) }
    if ($list.Count -gt $shown.Count) {
        [void]$script:FindingsPanel.Children.Add((New-Text ('...and {0} more in the full report.' -f ($list.Count - $shown.Count)) 12.5 'Normal' '#4B5B5C' '0,4,0,0'))
    }
}

function Invoke-FindingAction([string]$Id, [string]$Action) {
    $f = @($script:ScanFindings | Where-Object { $_.Id -eq $Id }) | Select-Object -First 1
    if (-not $f) { return }
    $where = if ($f.Path) { "`n$($f.Path)" } else { '' }
    $force = $false
    if ($Action -eq 'Allow') {
        $msg = "Leave this on your PC?`n`n$($f.Title)$where`n`nIt stays exactly where it is and may still be a risk. Quietpane will keep showing it, and your antivirus is not changed in any way."
        if ([System.Windows.MessageBox]::Show($msg, 'Quietpane', 'YesNo', 'Warning') -ne 'Yes') { return }
    } elseif ($Action -eq 'Quarantine') {
        $msg = "Move this into Quietpane's quarantine?`n`n$($f.Title)$where`n`nThe file is moved somewhere it cannot run, and you can put it back from this tab whenever you like."
        if ([System.Windows.MessageBox]::Show($msg, 'Quietpane', 'YesNo', 'Question') -ne 'Yes') { return }
    } elseif ($Action -eq 'Choose') {
        $options = @()
        if ($f.Source -eq 'Microsoft Defender') {
            $options += @{ Key = 'Defender'; Label = 'Let Microsoft Defender handle it'; Primary = $true; Note = 'The safest choice. Defender keeps its own copy, and Windows Security can put it back.' }
        }
        $options += @{ Key = 'Quarantine'; Label = 'Quarantine it with Quietpane'; Primary = ($f.Source -ne 'Microsoft Defender'); Note = 'Moved somewhere it cannot run. You can restore it from this tab.' }
        $options += @{ Key = 'RecycleBin'; Label = 'Move it to the Recycle Bin'; Note = 'Stays on your PC until you empty the bin.' }
        $options += @{ Key = 'Delete'; Label = 'Delete it permanently'; Note = 'Gone for good. Quietpane cannot undo this one.' }
        $chosen = Show-ChoiceDialog -Title 'Quietpane' -Message "What should happen to this?`n`n$($f.Title)$where" -Options $options
        if (-not $chosen) { return }
        $Action = $chosen
        if ($Action -eq 'Delete') {
            $msg = "Delete this file permanently?`n`n$($f.Path)`n`nThis cannot be undone by Quietpane. It does not go to the Recycle Bin and there is no restore. Quarantine is safer if you are unsure."
            if ([System.Windows.MessageBox]::Show($msg, 'Delete for good?', 'YesNo', 'Warning') -ne 'Yes') { return }
            $force = $true
        }
    }
    $ui.LogBox.AppendText([Environment]::NewLine)
    Set-LogVisible $true
    Start-Work -StatusText 'Dealing with it...' -Params @{ Finding = $f; Action = $Action; Force = $force } -Work { param($Finding, $Action, $Force) Invoke-QpRemediate -Finding $Finding -Action $Action -Force:$Force } -OnDone {
        param($r)
        $r = @($r)[-1]
        if ($r) {
            $f.Status = $r.Status
            [void][System.Windows.MessageBox]::Show($r.Note, 'Quietpane')
            Show-Findings
            Update-QuarantineList
            Add-ActionTally $r
        }
    }
}

function Update-QuarantineList {
    <# Everything Quietpane is currently holding, with a way back out. #>
    $items = @(Get-QpQuarantineItems)
    $script:QuarantinePanel.Children.Clear()
    if (-not $items.Count) {
        $script:QuarantineBox.Visibility = 'Collapsed'
        return
    }
    $script:QuarantineBox.Visibility = 'Visible'
    $script:QuarantineBox.Header = New-Text ('In quarantine ({0})' -f $items.Count) 14.5 'SemiBold' '#117A68' '0' 'Fraunces, Georgia'
    [void]$script:QuarantinePanel.Children.Add((New-Text 'These files were moved somewhere they cannot run. They are still on this PC until you delete them.' 12.5 'Normal' '#4B5B5C' '0,0,0,8'))
    foreach ($i in $items) {
        $row = New-Object System.Windows.Controls.Border
        $row.BorderBrush = Get-Brush '#E6DFCC'; $row.BorderThickness = Get-Thick '0,0,0,1'
        $row.Padding = Get-Thick '0,8'
        $sp = New-Object System.Windows.Controls.StackPanel
        [void]$sp.Children.Add((New-Text $i.FileName 13.5 'SemiBold' '#0F1B1C' '0'))
        [void]$sp.Children.Add((New-Text ('{0}   |   was at {1}   |   quarantined {2}' -f $(if ($i.ThreatName) { $i.ThreatName } else { 'Quietpane check' }), $i.OriginalPath, $i.QuarantinedAt) 12 'Normal' '#4B5B5C' '0,2,0,0'))
        $btns = New-Object System.Windows.Controls.WrapPanel
        $btns.Margin = Get-Thick '0,6,0,0'
        $restore = New-Button 'Put it back'
        $restore.Tag = $i.Id
        $restore.Add_Click({ Invoke-QuarantineAction ([string]$this.Tag) 'Restore' })
        $del = New-Button 'Delete for good'
        $del.Tag = $i.Id
        $del.Add_Click({ Invoke-QuarantineAction ([string]$this.Tag) 'Delete' })
        foreach ($x in $restore, $del) { $x.Margin = Get-Thick '0,0,8,0'; [void]$btns.Children.Add($x) }
        [void]$sp.Children.Add($btns)
        $row.Child = $sp
        [void]$script:QuarantinePanel.Children.Add($row)
    }
}

function Invoke-QuarantineAction([string]$Id, [string]$What) {
    $item = @(Get-QpQuarantineItems | Where-Object { $_.Id -eq $Id }) | Select-Object -First 1
    if (-not $item) { return }
    if ($What -eq 'Restore') {
        $msg = "Put this file back where it was?`n`n$($item.FileName)`nback to: $($item.OriginalPath)`n`nIf it really was a threat, it will be a threat again. Your antivirus may catch it straight away."
        if ([System.Windows.MessageBox]::Show($msg, 'Quietpane', 'YesNo', 'Warning') -ne 'Yes') { return }
        Start-Work -StatusText 'Putting it back...' -Params @{ Id = $Id } -Work { param($Id) Restore-QpQuarantineItem -Id $Id } -OnDone {
            param($r); $r = @($r)[-1]
            if ($r) { [void][System.Windows.MessageBox]::Show($r.Note, 'Quietpane') }
            Update-QuarantineList
        }
    } else {
        $msg = "Delete this permanently?`n`n$($item.FileName)`nfrom: $($item.OriginalPath)`n`nThis cannot be undone. The file does not go to the Recycle Bin and cannot be restored afterwards."
        if ([System.Windows.MessageBox]::Show($msg, 'Delete for good?', 'YesNo', 'Warning') -ne 'Yes') { return }
        Start-Work -StatusText 'Deleting it...' -Params @{ Id = $Id } -Work { param($Id) Remove-QpQuarantineItem -Id $Id -Force } -OnDone {
            param($r); $r = @($r)[-1]
            if ($r) { [void][System.Windows.MessageBox]::Show($r.Note, 'Quietpane') }
            Update-QuarantineList
        }
    }
}

function Update-ScanProgress {
    <# While a check runs: which step, what it is looking at, how much it has seen, how long so far. #>
    $secs = [int]((Get-Date) - $script:ScanStarted).TotalSeconds
    $clock = '{0}:{1:00}' -f [int][math]::Floor($secs / 60), ($secs % 60)
    if ($script:Sync.Cancel) { $script:ScanProgress.Text = "Stopping as soon as it is safe to...   |   $clock"; return }
    $p = $script:Sync.Progress
    if (-not $p) { $script:ScanProgress.Text = "Getting started...   |   $clock"; return }
    $bits = @()
    if ([int]$p.Of -gt 0) { $bits += 'Step {0} of {1}: {2}' -f $p.Step, $p.Of, $p.Stage } elseif ($p.Stage) { $bits += [string]$p.Stage }
    if ($p.Object) { $bits += [string]$p.Object }
    if ([int]$p.Scanned -gt 0) { $bits += '{0:N0} things looked at' -f [int]$p.Scanned }
    if ([int]$p.Found -gt 0) { $bits += '{0} worth attention so far' -f [int]$p.Found }
    $bits += $clock
    $script:ScanProgress.Text = $bits -join '   |   '
}

function Update-ScanSummary {
    <# The panel at the end of a check. Wording comes from the engine, so the log agrees with the window. #>
    if (-not $script:LastScanResult) { $script:SummaryPanel.Visibility = 'Collapsed'; return }
    $r = $script:LastScanResult
    # Something that failed to be dealt with is still there, so it still counts as outstanding.
    $outstanding = @($script:ScanFindings | Where-Object { $_.Severity -in 'Critical', 'High' -and $_.Status -in 'Detected', 'Failed' }).Count
    $s = New-QpScanSummary -Counts $r.Counts -Tally $script:ActionTally -Scanned ([int]$r.Scanned) `
        -Seconds ([int]$script:ScanSeconds) -Outstanding $outstanding -IsAdmin (Test-IsAdmin) -Cancelled ([bool]$r.Cancelled)
    $script:SummaryStack.Children.Clear()
    [void]$script:SummaryStack.Children.Add((New-Text 'How it went' 16 'SemiBold' '#117A68' '0,0,0,6' 'Fraunces, Georgia'))
    foreach ($l in $s.Lines) { [void]$script:SummaryStack.Children.Add((New-Text $l 13.5 'Normal' '#0F1B1C' '0,0,0,3')) }
    [void]$script:SummaryStack.Children.Add((New-Text $s.NextStep 13.5 'SemiBold' '#117A68' '0,8,0,0'))
    $script:SummaryPanel.Visibility = 'Visible'
}

function Add-ActionTally($r) {
    <# Keeps count of what has been done to findings since this check started. #>
    if (-not $r) { return }
    $key = ''
    if ($r.Status -eq 'Failed') { $key = 'Failed' }
    elseif ($r.Action -eq 'Allow') { $key = 'Allowed' }
    elseif ($r.Action -eq 'Quarantine') { $key = 'Quarantined' }
    elseif ($r.Action -eq 'RecycleBin') { $key = 'Recycled' }
    elseif ($r.Action -eq 'Delete') { $key = 'Deleted' }
    elseif ($r.Action -eq 'Defender') { $key = 'Removed' }
    if ($key) { $script:ActionTally[$key] = [int]$script:ActionTally[$key] + 1 }
    Update-ScanSummary
}

function Start-SafetyScan([bool]$AskDefender = $false) {
    $ui.LogBox.AppendText([Environment]::NewLine)
    $script:ScanStarted = Get-Date
    $script:ScanRunning = $true
    $script:LastScanResult = $null
    foreach ($k in @($script:ActionTally.Keys)) { $script:ActionTally[$k] = 0 }
    $script:SummaryPanel.Visibility = 'Collapsed'
    $btnStopScan.Visibility = 'Visible'
    $btnStopScan.IsEnabled = $true
    $scanSummary.Text = 'Having a look around...'
    $script:ScanProgress.Text = if ($AskDefender) { 'Asking Microsoft Defender to scan first. This can take a few minutes - Stop works at any point.' } else { 'Getting started...' }
    $script:CardAdware.Value.Text = 'Checking...'
    $script:CardAdware.Caption.Text = 'Nothing is changed while we look'
    Start-Work -StatusText 'Looking for threats and problems (nothing is changed)...' -Params @{ Deep = $AskDefender } -Work {
        param($Deep)
        if ($Deep) { Invoke-QpThreatScan -Type Quick | Out-Null }
        Invoke-QpAudit
    } -OnDone {
        param($r)
        $r = @($r | Where-Object { $_ -and $_.PSObject.Properties['Report'] })[-1]
        $script:ScanRunning = $false
        $btnStopScan.Visibility = 'Collapsed'
        $script:ScanSeconds = [int]((Get-Date) - $script:ScanStarted).TotalSeconds
        if ($r -and $r.Cancelled) {
            $script:LastScanResult = $r
            $script:ScanFindings = @()
            $script:ChartPanel.Visibility = 'Collapsed'
            $script:FindingsPanel.Children.Clear()
            $scanSummary.Text = 'Stopped. Nothing on your PC was changed.'
            $script:ScanProgress.Text = ''
            $script:CardAdware.Value.Text = 'Stopped'
            $script:CardAdware.Value.Foreground = Get-Brush '#0F1B1C'
            $script:CardAdware.Caption.Text = 'Run the check again when you have a few minutes'
            Update-ScanSummary
            Update-Buttons
            return
        }
        if ($r -and $r.Report) {
            $script:LastReport = $r.Report
            $script:LastScanResult = $r
            $script:ScanFindings = @($r.Findings)
            foreach ($k in @($script:SevCounts.Keys)) { $script:SevCounts[$k] = [int]$r.Counts[$k] }
            $script:SevFilter = 'All'
            $script:ChartPanel.Visibility = 'Visible'
            Draw-SeverityChart
            Show-Findings
            Update-ScanSummary
            $secs = $script:ScanSeconds
            $scanSummary.Text = ('Looked at {0:N0} things in {1} seconds, and found {2} worth reporting.' -f [int]$r.Scanned, $secs, $r.Total)
            $worst = @('Critical', 'High', 'Medium', 'Low', 'Info') | Where-Object { [int]$r.Counts[$_] -gt 0 } | Select-Object -First 1
            $script:ScanProgress.Text = if ($r.Defender -and $r.Defender.Note) { $r.Defender.Note } else { 'The full report also opened in your browser and is saved on your Desktop.' }
            if ($worst -in 'Critical', 'High') {
                $script:CardAdware.Value.Text = ('{0} to deal with' -f ([int]$r.Critical + [int]$r.High))
                $script:CardAdware.Value.Foreground = Get-Brush '#A83232'
                $script:CardAdware.Caption.Text = 'Open the Safety scan tab'
            } else {
                $script:CardAdware.Value.Text = 'Nothing serious'
                $script:CardAdware.Value.Foreground = Get-Brush '#117A68'
                $script:CardAdware.Caption.Text = ('{0} thing(s) worth a look' -f ([int]$r.Medium + [int]$r.Low))
            }
            Open-AsUser $r.Report
            Update-Buttons
        } else {
            $scanSummary.Text = 'The check did not finish. Click "Show details" at the bottom to see why.'
            $script:ScanProgress.Text = ''
            $script:CardAdware.Value.Text = 'Did not finish'
        }
    }
}
$btnStopScan.Add_Click({
    # Stop is a request, not a kill: the check finishes the step it is on and then stops cleanly.
    $script:Sync.Cancel = $true
    $btnStopScan.IsEnabled = $false
    $script:ScanProgress.Text = 'Stopping as soon as it is safe to...'
})
$btnScan.Add_Click({ Start-SafetyScan $false })
$btnScanDeep.Add_Click({ Start-SafetyScan $true })
$btnHomeScan.Add_Click({ Select-Tab 'scan'; Start-SafetyScan $false })

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
    Start-Work -StatusText 'Cleaning your PC... this usually takes less than a minute.' -Work { Invoke-QpRecommended } -OnDone { param($r) Show-HomeResult $r; Update-StateAfterChange }
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
        Update-StateAfterChange
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
    Start-Work -StatusText 'Undoing...' -Params @{ Path = [string]$sel.Tag } -Work { param($Path) Invoke-QpUndo -Path $Path } -OnDone { Update-StateAfterChange }
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
    Stop-LiveSampler
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
        if ([string]$ui.Tabs.SelectedItem.Tag -eq 'health') {
            # A real reading for the picture: load is measured between two moments, a second apart.
            $monitor = New-QpLiveMonitor
            Start-Sleep -Milliseconds 1000
            $script:BatteryHealth = Get-QpBatteryHealth
            Update-LiveTiles (Get-QpLiveReading -Monitor $monitor)
            Update-DriveCard (Get-QpDriveHealth)
        }
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
           "Settings you change can be undone, and cleaned-up files go to the Recycle Bin.`n" +
           "Anything that can't be undone tells you so before you confirm it.`n" +
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
    Start-LiveSampler
})
$timer.Start()
[void]$window.ShowDialog()
Stop-LiveSampler   # in case the window went away without Closing firing
