#Requires -Version 5.1
<#
.SYNOPSIS
    Interactive Windows terminal makeover.

.DESCRIPTION
    Downloads and configures Oh My Posh, a Nerd Font, Fastfetch, a Windows
    Terminal color theme (windowsterminalthemes.dev / iTerm2-Color-Schemes),
    transparency, ASCII art, and a sharper PowerShell command line.

    Run from Windows Terminal or PowerShell:
        powershell -ExecutionPolicy Bypass -File .\Install-BetterTerminal.ps1

    Or double-click Start-BetterTerminal.cmd
#>
[CmdletBinding()]
param()

Set-StrictMode -Off
$ErrorActionPreference = 'Stop'
$script:Esc = [char]27
$script:NerdFontsVersion = 'v3.5.1'
$script:ThemeSourceUrl = 'https://raw.githubusercontent.com/mbadolato/iTerm2-Color-Schemes/master/windowsterminal'
$script:ThemeCatalogUrl = 'https://api.github.com/repos/mbadolato/iTerm2-Color-Schemes/contents/windowsterminal'
$script:ThemeSiteUrl = 'https://windowsterminalthemes.dev/'
$script:NerdFontsReleaseUrl = 'https://github.com/ryanoasis/nerd-fonts/releases/download'
$script:NerdFontsSiteUrl = 'https://www.nerdfonts.com/'
$script:OhMyPoshSiteUrl = 'https://ohmyposh.dev/docs/installation/prompt'
$script:OhMyPoshThemesUrl = 'https://ohmyposh.dev/docs/themes'
$script:OhMyPoshInstallUrl = 'https://ohmyposh.dev/install.ps1'
$script:FastfetchRepoUrl = 'https://github.com/fastfetch-cli/fastfetch'
$script:TerminalIconsUrl = 'https://github.com/devblackops/terminal-icons'
$script:TerminalIconsGallery = 'https://www.powershellgallery.com/packages/Terminal-Icons'
$script:AsciiGalleryUrl = 'https://www.asciiart.eu/gallery'
$script:RemoteThemeCache = @{}
$script:RemoteThemeNames = $null
$script:PreviewForm = $null
$script:DidLiveBackup = $false
$script:AllThemes = $null
$script:AllFonts = $null
$script:AllArts = $null
$script:AllPosh = $null
$script:LogoLineCache = @{}
$script:FetchPreviewCache = @{}
$script:CatalogRoot = $null

# -----------------------------------------------------------------------------
# Console + color helpers
# -----------------------------------------------------------------------------

function Enable-VirtualTerminal {
    try {
        $code = @'
using System;
using System.Runtime.InteropServices;
public static class TerminalVt {
    [DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int n);
    [DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr h, out uint m);
    [DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr h, uint m);
}
'@
        if (-not ([System.Management.Automation.PSTypeName]'TerminalVt').Type) {
            Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue | Out-Null
        }
        $handle = [TerminalVt]::GetStdHandle(-11)
        $mode = [uint32]0
        [void][TerminalVt]::GetConsoleMode($handle, [ref]$mode)
        [void][TerminalVt]::SetConsoleMode($handle, ($mode -bor 4))
    } catch {
        # Continue without VT if the console refuses it.
    }

    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        $OutputEncoding = [System.Text.Encoding]::UTF8
    } catch {}
}

function ConvertFrom-HexColor {
    param([string]$Hex)
    if ([string]::IsNullOrWhiteSpace($Hex)) { $Hex = '#808080' }
    $clean = $Hex.Trim().TrimStart('#')
    if ($clean.Length -eq 3) {
        $clean = -join ($clean.ToCharArray() | ForEach-Object { "$_$_" })
    }
    if ($clean.Length -lt 6) { $clean = '808080' }
    [pscustomobject]@{
        R = [Convert]::ToInt32($clean.Substring(0, 2), 16)
        G = [Convert]::ToInt32($clean.Substring(2, 2), 16)
        B = [Convert]::ToInt32($clean.Substring(4, 2), 16)
    }
}

function Get-Fg {
    param([string]$Hex)
    $c = ConvertFrom-HexColor $Hex
    "$script:Esc[38;2;$($c.R);$($c.G);$($c.B)m"
}

function Get-Bg {
    param([string]$Hex)
    $c = ConvertFrom-HexColor $Hex
    "$script:Esc[48;2;$($c.R);$($c.G);$($c.B)m"
}

function Get-Reset { "$script:Esc[0m" }

function Write-Color {
    param(
        [string]$Text,
        [string]$Foreground = '#E6EDF3',
        [string]$Background,
        [switch]$NoNewline
    )
    $out = (Get-Fg $Foreground)
    if ($Background) { $out += (Get-Bg $Background) }
    $out += $Text + (Get-Reset)
    if ($NoNewline) { Write-Host $out -NoNewline } else { Write-Host $out }
}

function Clear-ScreenSoft {
    Clear-Host
    Write-Host ""
}

function Get-VisibleLength {
    param([string]$Text)
    if ($null -eq $Text) { return 0 }
    $plain = [regex]::Replace($Text, "$([char]27)\[[0-9;]*m", '')
    return $plain.Length
}

function Pad-Visible {
    param([string]$Text, [int]$Width)
    $len = Get-VisibleLength $Text
    if ($len -ge $Width) { return $Text }
    return ($Text + (' ' * ($Width - $len)))
}

# -----------------------------------------------------------------------------
# Catalog data
# -----------------------------------------------------------------------------

function Get-BuiltInThemes {
    @(
        @{ name = 'Dracula'; source = 'iTerm2-Color-Schemes'; background = '#282a36'; foreground = '#f8f8f2'; black = '#21222c'; red = '#ff5555'; green = '#50fa7b'; yellow = '#f1fa8c'; blue = '#bd93f9'; purple = '#ff79c6'; cyan = '#8be9fd'; white = '#f8f8f2'; brightBlack = '#6272a4'; brightRed = '#ff6e6e'; brightGreen = '#69ff94'; brightYellow = '#ffffa5'; brightBlue = '#d6acff'; brightPurple = '#ff92df'; brightCyan = '#a4ffff'; brightWhite = '#ffffff'; cursorColor = '#f8f8f2'; selectionBackground = '#44475a' }
        @{ name = 'Nord'; source = 'iTerm2-Color-Schemes'; background = '#2e3440'; foreground = '#d8dee9'; black = '#3b4252'; red = '#bf616a'; green = '#a3be8c'; yellow = '#ebcb8b'; blue = '#81a1c1'; purple = '#b48ead'; cyan = '#88c0d0'; white = '#e5e9f0'; brightBlack = '#596377'; brightRed = '#bf616a'; brightGreen = '#a3be8c'; brightYellow = '#ebcb8b'; brightBlue = '#81a1c1'; brightPurple = '#b48ead'; brightCyan = '#8fbcbb'; brightWhite = '#eceff4'; cursorColor = '#eceff4'; selectionBackground = '#434c5e' }
        @{ name = 'TokyoNight'; source = 'iTerm2-Color-Schemes'; background = '#1a1b26'; foreground = '#c0caf5'; black = '#15161e'; red = '#f7768e'; green = '#9ece6a'; yellow = '#e0af68'; blue = '#7aa2f7'; purple = '#bb9af7'; cyan = '#7dcfff'; white = '#a9b1d6'; brightBlack = '#414868'; brightRed = '#f7768e'; brightGreen = '#9ece6a'; brightYellow = '#e0af68'; brightBlue = '#7aa2f7'; brightPurple = '#bb9af7'; brightCyan = '#7dcfff'; brightWhite = '#c0caf5'; cursorColor = '#c0caf5'; selectionBackground = '#33467c' }
        @{ name = 'TokyoNight Storm'; source = 'iTerm2-Color-Schemes'; background = '#24283b'; foreground = '#c0caf5'; black = '#1d202f'; red = '#f7768e'; green = '#9ece6a'; yellow = '#e0af68'; blue = '#7aa2f7'; purple = '#bb9af7'; cyan = '#7dcfff'; white = '#a9b1d6'; brightBlack = '#414868'; brightRed = '#f7768e'; brightGreen = '#9ece6a'; brightYellow = '#e0af68'; brightBlue = '#7aa2f7'; brightPurple = '#bb9af7'; brightCyan = '#7dcfff'; brightWhite = '#c0caf5'; cursorColor = '#c0caf5'; selectionBackground = '#364a82' }
        @{ name = 'Catppuccin Mocha'; source = 'windowsterminalthemes.dev'; background = '#1e1e2e'; foreground = '#cdd6f4'; black = '#45475a'; red = '#f38ba8'; green = '#a6e3a1'; yellow = '#f9e2af'; blue = '#89b4fa'; purple = '#f5c2e7'; cyan = '#94e2d5'; white = '#bac2de'; brightBlack = '#585b70'; brightRed = '#f38ba8'; brightGreen = '#a6e3a1'; brightYellow = '#f9e2af'; brightBlue = '#89b4fa'; brightPurple = '#f5c2e7'; brightCyan = '#94e2d5'; brightWhite = '#a6adc8'; cursorColor = '#f5e0dc'; selectionBackground = '#585b70' }
        @{ name = 'Catppuccin Macchiato'; source = 'windowsterminalthemes.dev'; background = '#24273a'; foreground = '#cad3f5'; black = '#494d64'; red = '#ed8796'; green = '#a6da95'; yellow = '#eed49f'; blue = '#8aadf4'; purple = '#f5bde6'; cyan = '#8bd5ca'; white = '#b8c0e0'; brightBlack = '#5b6078'; brightRed = '#ed8796'; brightGreen = '#a6da95'; brightYellow = '#eed49f'; brightBlue = '#8aadf4'; brightPurple = '#f5bde6'; brightCyan = '#8bd5ca'; brightWhite = '#b8c0e0'; cursorColor = '#f4dbd6'; selectionBackground = '#5b6078' }
        @{ name = 'Catppuccin Frappe'; source = 'windowsterminalthemes.dev'; background = '#303446'; foreground = '#c6d0f5'; black = '#51576d'; red = '#e78284'; green = '#a6d189'; yellow = '#e5c890'; blue = '#8caaee'; purple = '#f4b8e4'; cyan = '#81c8be'; white = '#b5bfe2'; brightBlack = '#626880'; brightRed = '#e78284'; brightGreen = '#a6d189'; brightYellow = '#e5c890'; brightBlue = '#8caaee'; brightPurple = '#f4b8e4'; brightCyan = '#81c8be'; brightWhite = '#a5adce'; cursorColor = '#f2d5cf'; selectionBackground = '#626880' }
        @{ name = 'Catppuccin Latte'; source = 'windowsterminalthemes.dev'; background = '#eff1f5'; foreground = '#4c4f69'; black = '#5c5f77'; red = '#d20f39'; green = '#40a02b'; yellow = '#df8e1d'; blue = '#1e66f5'; purple = '#ea76cb'; cyan = '#179299'; white = '#acb0be'; brightBlack = '#6c6f85'; brightRed = '#d20f39'; brightGreen = '#40a02b'; brightYellow = '#df8e1d'; brightBlue = '#1e66f5'; brightPurple = '#ea76cb'; brightCyan = '#179299'; brightWhite = '#bcc0cc'; cursorColor = '#dc8a78'; selectionBackground = '#acb0be' }
        @{ name = 'Gruvbox Dark'; source = 'iTerm2-Color-Schemes'; background = '#282828'; foreground = '#ebdbb2'; black = '#282828'; red = '#cc241d'; green = '#98971a'; yellow = '#d79921'; blue = '#458588'; purple = '#b16286'; cyan = '#689d6a'; white = '#a89984'; brightBlack = '#928374'; brightRed = '#fb4934'; brightGreen = '#b8bb26'; brightYellow = '#fabd2f'; brightBlue = '#83a598'; brightPurple = '#d3869b'; brightCyan = '#8ec07c'; brightWhite = '#ebdbb2'; cursorColor = '#ebdbb2'; selectionBackground = '#665c54' }
        @{ name = 'One Half Dark'; source = 'iTerm2-Color-Schemes'; background = '#282c34'; foreground = '#dcdfe4'; black = '#282c34'; red = '#e06c75'; green = '#98c379'; yellow = '#e5c07b'; blue = '#61afef'; purple = '#c678dd'; cyan = '#56b6c2'; white = '#dcdfe4'; brightBlack = '#5a6374'; brightRed = '#e06c75'; brightGreen = '#98c379'; brightYellow = '#e5c07b'; brightBlue = '#61afef'; brightPurple = '#c678dd'; brightCyan = '#56b6c2'; brightWhite = '#dcdfe4'; cursorColor = '#dcdfe4'; selectionBackground = '#474e5d' }
        @{ name = 'Kanagawa'; source = 'windowsterminalthemes.dev'; background = '#1F1F28'; foreground = '#DCD7BA'; black = '#1F1F28'; red = '#E82424'; green = '#76946A'; yellow = '#FF9E3B'; blue = '#658594'; purple = '#957FB8'; cyan = '#9CABCA'; white = '#DCD7BA'; brightBlack = '#2A2A37'; brightRed = '#FF5D62'; brightGreen = '#98BB6C'; brightYellow = '#E6C384'; brightBlue = '#7FB4CA'; brightPurple = '#D27E99'; brightCyan = '#A3D4D5'; brightWhite = '#DCD7BA'; cursorColor = '#DCD7BA'; selectionBackground = '#2A2A37' }
        @{ name = 'Horizon'; source = 'windowsterminalthemes.dev'; background = '#1c1e26'; foreground = '#bdc0c2'; black = '#0a0a0d'; red = '#E95678'; green = '#29D398'; yellow = '#FAB795'; blue = '#26BBD9'; purple = '#EE64AC'; cyan = '#59E1E3'; white = '#e5e5e5'; brightBlack = '#848484'; brightRed = '#EC6A88'; brightGreen = '#3FDAA4'; brightYellow = '#FBC3A7'; brightBlue = '#3FC4DE'; brightPurple = '#F075B5'; brightCyan = '#6BE4E6'; brightWhite = '#e5e5e5'; cursorColor = '#e5e5e5'; selectionBackground = '#2e303e' }
        @{ name = 'CyberPunk2077'; source = 'windowsterminalthemes.dev'; background = '#272932'; foreground = '#E455AE'; black = '#272932'; red = '#710000'; green = '#1AC5B0'; yellow = '#FDF500'; blue = '#9381FF'; purple = '#742D8B'; cyan = '#00D0DB'; white = '#D1C5C0'; brightBlack = '#7b8097'; brightRed = '#C71515'; brightGreen = '#40FFE9'; brightYellow = '#fff955'; brightBlue = '#37EBF3'; brightPurple = '#CB1DCD'; brightCyan = '#37EBF3'; brightWhite = '#C1DEFF'; cursorColor = '#FDF500'; selectionBackground = '#742D8B' }
        @{ name = 'Night Owl'; source = 'iTerm2-Color-Schemes'; background = '#011627'; foreground = '#d6deeb'; black = '#011627'; red = '#ef5350'; green = '#22da6e'; yellow = '#addb67'; blue = '#82aaff'; purple = '#c792ea'; cyan = '#21c7a8'; white = '#ffffff'; brightBlack = '#575656'; brightRed = '#ef5350'; brightGreen = '#22da6e'; brightYellow = '#ffeb95'; brightBlue = '#82aaff'; brightPurple = '#c792ea'; brightCyan = '#7fdbca'; brightWhite = '#ffffff'; cursorColor = '#80a4c2'; selectionBackground = '#1d3b53' }
        @{ name = 'GitHub Dark'; source = 'iTerm2-Color-Schemes'; background = '#0d1117'; foreground = '#e6edf3'; black = '#484f58'; red = '#ff7b72'; green = '#3fb950'; yellow = '#d29922'; blue = '#58a6ff'; purple = '#bc8cff'; cyan = '#39c5cf'; white = '#b1bac4'; brightBlack = '#6e7681'; brightRed = '#ffa198'; brightGreen = '#56d364'; brightYellow = '#e3b341'; brightBlue = '#79c0ff'; brightPurple = '#d2a8ff'; brightCyan = '#56d4dd'; brightWhite = '#ffffff'; cursorColor = '#e6edf3'; selectionBackground = '#163356' }
        @{ name = 'Atom One Dark'; source = 'iTerm2-Color-Schemes'; background = '#21252b'; foreground = '#abb2bf'; black = '#21252b'; red = '#e06c75'; green = '#98c379'; yellow = '#e5c07b'; blue = '#61afef'; purple = '#c678dd'; cyan = '#56b6c2'; white = '#abb2bf'; brightBlack = '#5c6370'; brightRed = '#e06c75'; brightGreen = '#98c379'; brightYellow = '#e5c07b'; brightBlue = '#61afef'; brightPurple = '#c678dd'; brightCyan = '#56b6c2'; brightWhite = '#ffffff'; cursorColor = '#abb2bf'; selectionBackground = '#323842' }
        @{ name = 'Rose Pine'; source = 'iTerm2-Color-Schemes'; background = '#191724'; foreground = '#e0def4'; black = '#26233a'; red = '#eb6f92'; green = '#31748f'; yellow = '#f6c177'; blue = '#9ccfd8'; purple = '#c4a7e7'; cyan = '#ebbcba'; white = '#e0def4'; brightBlack = '#6e6a86'; brightRed = '#eb6f92'; brightGreen = '#31748f'; brightYellow = '#f6c177'; brightBlue = '#9ccfd8'; brightPurple = '#c4a7e7'; brightCyan = '#ebbcba'; brightWhite = '#e0def4'; cursorColor = '#e0def4'; selectionBackground = '#403d52' }
        @{ name = 'Cobalt2'; source = 'iTerm2-Color-Schemes'; background = '#132738'; foreground = '#ffffff'; black = '#000000'; red = '#ff0000'; green = '#38de21'; yellow = '#ffe50a'; blue = '#1460d2'; purple = '#ff005d'; cyan = '#00bbbb'; white = '#bbbbbb'; brightBlack = '#555555'; brightRed = '#f40e17'; brightGreen = '#3bd01d'; brightYellow = '#edc809'; brightBlue = '#5555ff'; brightPurple = '#ff55ff'; brightCyan = '#6ae3fa'; brightWhite = '#ffffff'; cursorColor = '#f0cc09'; selectionBackground = '#183c66' }
        @{ name = 'Ayu'; source = 'iTerm2-Color-Schemes'; background = '#0f1419'; foreground = '#e6e1cf'; black = '#000000'; red = '#ff3333'; green = '#b8cc52'; yellow = '#e7c547'; blue = '#36a3d9'; purple = '#f07178'; cyan = '#95e6cb'; white = '#ffffff'; brightBlack = '#323232'; brightRed = '#ff6565'; brightGreen = '#eafe84'; brightYellow = '#fff779'; brightBlue = '#68d5ff'; brightPurple = '#ffa3aa'; brightCyan = '#c7fffd'; brightWhite = '#ffffff'; cursorColor = '#f29718'; selectionBackground = '#253340' }
        @{ name = 'Snazzy'; source = 'iTerm2-Color-Schemes'; background = '#282a36'; foreground = '#eff0eb'; black = '#282a36'; red = '#ff5c57'; green = '#5af78e'; yellow = '#f3f99d'; blue = '#57c7ff'; purple = '#ff6ac1'; cyan = '#9aedfe'; white = '#f1f1f0'; brightBlack = '#686868'; brightRed = '#ff5c57'; brightGreen = '#5af78e'; brightYellow = '#f3f99d'; brightBlue = '#57c7ff'; brightPurple = '#ff6ac1'; brightCyan = '#9aedfe'; brightWhite = '#eff0eb'; cursorColor = '#97979b'; selectionBackground = '#3e4149' }
        @{ name = 'Everforest Dark Med'; source = 'iTerm2-Color-Schemes'; background = '#2d353b'; foreground = '#d3c6aa'; black = '#475258'; red = '#e67e80'; green = '#a7c080'; yellow = '#dbbc7f'; blue = '#7fbbb3'; purple = '#d699b6'; cyan = '#83c092'; white = '#d3c6aa'; brightBlack = '#475258'; brightRed = '#e67e80'; brightGreen = '#a7c080'; brightYellow = '#dbbc7f'; brightBlue = '#7fbbb3'; brightPurple = '#d699b6'; brightCyan = '#83c092'; brightWhite = '#d3c6aa'; cursorColor = '#d3c6aa'; selectionBackground = '#543a48' }
        @{ name = 'Material Dark'; source = 'iTerm2-Color-Schemes'; background = '#232322'; foreground = '#ece4d5'; black = '#212121'; red = '#b7141f'; green = '#457b24'; yellow = '#f6981e'; blue = '#134eb2'; purple = '#560088'; cyan = '#0e717c'; white = '#efefec'; brightBlack = '#424242'; brightRed = '#e83b3f'; brightGreen = '#7aba3a'; brightYellow = '#ffea2e'; brightBlue = '#54a4f3'; brightPurple = '#aa4dbc'; brightCyan = '#26bbd1'; brightWhite = '#d9d7cc'; cursorColor = '#16afca'; selectionBackground = '#4e4e4e' }
        @{ name = 'Afterglow'; source = 'iTerm2-Color-Schemes'; background = '#212121'; foreground = '#d0d0d0'; black = '#151515'; red = '#ac4142'; green = '#7e8e50'; yellow = '#e5b567'; blue = '#6c99bb'; purple = '#9f4e85'; cyan = '#7dd6cf'; white = '#d0d0d0'; brightBlack = '#505050'; brightRed = '#ac4142'; brightGreen = '#7e8e50'; brightYellow = '#e5b567'; brightBlue = '#6c99bb'; brightPurple = '#9f4e85'; brightCyan = '#7dd6cf'; brightWhite = '#f5f5f5'; cursorColor = '#d0d0d0'; selectionBackground = '#303030' }
        @{ name = 'Adventure Time'; source = 'iTerm2-Color-Schemes'; background = '#1f1d45'; foreground = '#f8dcc0'; black = '#050404'; red = '#bd0013'; green = '#4ab118'; yellow = '#e7741e'; blue = '#0f4ac6'; purple = '#665993'; cyan = '#70a598'; white = '#f8dcc0'; brightBlack = '#4e7cbf'; brightRed = '#fc5f5a'; brightGreen = '#9eff6e'; brightYellow = '#efc11a'; brightBlue = '#1997c6'; brightPurple = '#9b5953'; brightCyan = '#c8faf4'; brightWhite = '#f6f5fb'; cursorColor = '#efbf38'; selectionBackground = '#706b4e' }
        @{ name = 'Ubuntu'; source = 'iTerm2-Color-Schemes'; background = '#300a24'; foreground = '#eeeeec'; black = '#2e3436'; red = '#cc0000'; green = '#4e9a06'; yellow = '#c4a000'; blue = '#3465a4'; purple = '#75507b'; cyan = '#06989a'; white = '#d3d7cf'; brightBlack = '#555753'; brightRed = '#ef2929'; brightGreen = '#8ae234'; brightYellow = '#fce94f'; brightBlue = '#729fcf'; brightPurple = '#ad7fa8'; brightCyan = '#34e2e2'; brightWhite = '#eeeeec'; cursorColor = '#bbbbbb'; selectionBackground = '#b5d5ff' }
    )
}

function Get-ThemeCatalog {
    if ($script:AllThemes -and $script:AllThemes.Count -gt 0) { return $script:AllThemes }
    @(Get-BuiltInThemes | ForEach-Object { New-ThemeObject $_ })
}

function Get-FontCatalog {
    if ($script:AllFonts -and $script:AllFonts.Count -gt 0) { return $script:AllFonts }
    @(
        @{ Id = 'Meslo'; Label = 'Meslo'; Face = 'MesloLGM Nerd Font'; OmpName = 'meslo'; Size = 'small download'; Note = 'Recommended. Icons look right.'; Guesses = @('MesloLGM Nerd Font', 'MesloLGS Nerd Font', 'MesloLGL Nerd Font', 'Meslo LG M', 'Meslo LG S'); StandIns = @('Consolas') }
        @{ Id = 'CascadiaCode'; Label = 'Cascadia (CaskaydiaCove)'; Face = 'CaskaydiaCove NF'; OmpName = 'cascadiacode'; Size = 'medium download'; Note = 'The usual Windows Terminal font.'; Guesses = @('CaskaydiaCove NF', 'CaskaydiaCove Nerd Font', 'CaskaydiaCove NFM', 'Cascadia Code'); StandIns = @('Cascadia Code', 'Cascadia Mono') }
        @{ Id = 'FiraCode'; Label = 'Fira Code'; Face = 'FiraCode Nerd Font'; OmpName = 'firacode'; Size = 'medium download'; Note = 'Letter pairs can join together.'; Guesses = @('FiraCode Nerd Font', 'Fira Code', 'Fira Mono'); StandIns = @('Calibri') }
        @{ Id = 'JetBrainsMono'; Label = 'JetBrains Mono'; Face = 'JetBrainsMono NF'; OmpName = 'jetbrainsmono'; Size = 'medium download'; Note = 'Clear and tall.'; Guesses = @('JetBrainsMono NF', 'JetBrainsMono Nerd Font', 'JetBrainsMono NFM'); StandIns = @('Bahnschrift') }
        @{ Id = 'Hack'; Label = 'Hack'; Face = 'Hack Nerd Font'; OmpName = 'hack'; Size = 'small download'; Note = 'Simple and easy to read.'; Guesses = @('Hack Nerd Font', 'Hack'); StandIns = @('Lucida Console') }
        @{ Id = 'GeistMono'; Label = 'Geist Mono'; Face = 'GeistMono Nerd Font'; OmpName = 'geistmono'; Size = 'larger download'; Note = 'Modern and sharp.'; Guesses = @('GeistMono Nerd Font', 'Geist Mono'); StandIns = @('Segoe UI') }
        @{ Id = 'IosevkaTerm'; Label = 'Iosevka Term'; Face = 'IosevkaTerm Nerd Font'; OmpName = 'iosevkaterm'; Size = 'larger download'; Note = 'Narrow letters.'; Guesses = @('IosevkaTerm Nerd Font', 'Iosevka Term', 'Iosevka'); StandIns = @('Yu Gothic', 'MS Gothic', 'Malgun Gothic') }
        @{ Id = 'SauceCodePro'; Label = 'Source Code Pro'; Face = 'SauceCodePro Nerd Font'; OmpName = 'sourcecodepro'; Size = 'medium download'; Note = 'A classic coding font.'; Guesses = @('SauceCodePro Nerd Font', 'Source Code Pro'); StandIns = @('Cambria', 'Constantia') }
        @{ Id = 'RobotoMono'; Label = 'Roboto Mono'; Face = 'RobotoMono Nerd Font'; OmpName = 'robotomono'; Size = 'small download'; Note = 'Friendly spacing.'; Guesses = @('RobotoMono Nerd Font', 'Roboto Mono'); StandIns = @('Verdana') }
        @{ Id = 'UbuntuMono'; Label = 'Ubuntu Mono'; Face = 'UbuntuMono Nerd Font'; OmpName = 'ubuntumono'; Size = 'small download'; Note = 'The classic Ubuntu look.'; Guesses = @('UbuntuMono Nerd Font', 'Ubuntu Mono'); StandIns = @('Trebuchet MS') }
        @{ Id = 'Inconsolata'; Label = 'Inconsolata'; Face = 'Inconsolata Nerd Font'; OmpName = 'inconsolata'; Size = 'small download'; Note = 'Soft, print-like letters.'; Guesses = @('Inconsolata Nerd Font', 'Inconsolata'); StandIns = @('Georgia', 'Palatino Linotype') }
        @{ Id = 'CommitMono'; Label = 'Commit Mono'; Face = 'CommitMono Nerd Font'; OmpName = 'commitmono'; Size = 'medium download'; Note = 'A newer coding font.'; Guesses = @('CommitMono Nerd Font', 'Commit Mono'); StandIns = @('Arial', 'Franklin Gothic Medium') }
    )
}

function Get-InstalledFontMap {
    if ($script:InstalledFontMap) { return $script:InstalledFontMap }
    Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
    $map = @{}
    $col = New-Object System.Drawing.Text.InstalledFontCollection
    foreach ($family in $col.Families) {
        $map[$family.Name] = $family
        $map[$family.Name.ToLowerInvariant()] = $family
    }
    $script:InstalledFontMap = $map
    return $map
}

function Find-InstalledFamily {
    param($Map, [string[]]$Names)
    foreach ($name in $Names) {
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        if ($Map.ContainsKey($name)) { return $Map[$name] }
        $lower = $name.ToLowerInvariant()
        if ($Map.ContainsKey($lower)) { return $Map[$lower] }
    }
    return $null
}

function Get-NerdFontSearchNames {
    param($Font)
    if (-not $Font) { return @() }
    $id = [string]$Font.Id
    $names = @()
    if ($Font.Face) { $names += [string]$Font.Face }
    if ($Font.Guesses) { $names += @($Font.Guesses | Where-Object { $_ -match 'Nerd|\bNF\b|\bNFM\b|\bNFP\b' }) }
    $names += "$id Nerd Font"
    $names += "$id Nerd Font Mono"
    $names += "$id NF"
    $names += "$id NFM"
    $names += "$id NFP"
    if ($id -eq 'CascadiaMono') {
        $names += @('CaskaydiaMono Nerd Font', 'CaskaydiaMono Nerd Font Mono', 'CaskaydiaMono NF', 'CaskaydiaMono NFM', 'CaskaydiaMono NFP')
    }
    if ($id -eq 'CascadiaCode') {
        $names += @('CaskaydiaCove Nerd Font', 'CaskaydiaCove Nerd Font Mono', 'CaskaydiaCove NF', 'CaskaydiaCove NFM', 'CaskaydiaCove NFP')
    }
    return @($names | Where-Object { $_ } | Select-Object -Unique)
}

function Test-FontInstalled {
    param($Font)
    if (-not $Font) { return $false }
    $map = Get-InstalledFontMap
    return [bool](Find-InstalledFamily -Map $map -Names (Get-NerdFontSearchNames $Font))
}

function Sync-InstalledFontFace {
    param($Font)
    if (-not $Font) { return }
    $map = Get-InstalledFontMap
    $found = Find-InstalledFamily -Map $map -Names (Get-NerdFontSearchNames $Font)
    if (-not $found) {
        $needle = [string]$Font.Id
        if ($needle -eq 'CascadiaMono') { $needle = 'CaskaydiaMono' }
        if ($needle -eq 'CascadiaCode') { $needle = 'CaskaydiaCove' }
        foreach ($key in @($map.Keys)) {
            if ($key -like "*$needle*" -and $key -match 'Nerd|\bNF') {
                $found = $map[$key]
                break
            }
        }
    }
    if ($found) { $Font.Face = $found.Name }
}

function Get-UsableFontFace {
    param($Font)
    if (-not $Font) { return $null }
    Sync-InstalledFontFace $Font
    $face = [string]$Font.Face
    if ([string]::IsNullOrWhiteSpace($face)) { return $null }
    $map = Get-InstalledFontMap
    $exact = Find-InstalledFamily -Map $map -Names @($face)
    if ($exact) { return [string]$exact.Name }
    return $null
}

function Clear-MissingEditorFonts {
    $paths = @(
        (Join-Path $env:APPDATA 'Cursor\User\settings.json'),
        (Join-Path $env:APPDATA 'Code\User\settings.json')
    )
    $map = $null
    foreach ($path in $paths) {
        if (-not (Test-Path $path)) { continue }
        try {
            $raw = Get-Content -Path $path -Raw -Encoding UTF8
            $json = $raw | ConvertFrom-Json
            $face = [string]$json.'terminal.integrated.fontFamily'
            if ([string]::IsNullOrWhiteSpace($face)) { continue }
            if (-not $map) { $map = Get-InstalledFontMap }
            if (Find-InstalledFamily -Map $map -Names @($face)) { continue }
            $json.PSObject.Properties.Remove('terminal.integrated.fontFamily')
            Write-Utf8NoBom -Path $path -Text ($json | ConvertTo-Json -Depth 40)
        } catch {}
    }
}

function Ensure-FontReady {
    param($Font)
    if (-not $Font) { return $false }
    if (Test-FontInstalled $Font) {
        Sync-InstalledFontFace $Font
        return $true
    }
    if ($script:StudioForm -and -not $script:StudioForm.IsDisposed) {
        $script:StudioForm.UseWaitCursor = $true
        if ($script:StudioUi -and $script:StudioUi.Picks) {
            $script:StudioUi.Picks.Text = "Downloading $($Font.Label) from nerdfonts.com ..."
        }
        [System.Windows.Forms.Application]::DoEvents()
    }
    $ok = Install-NerdFontPackage -Font $Font
    $script:InstalledFontMap = $null
    $script:TypefaceCache = @{}
    if ($ok) { Sync-InstalledFontFace $Font }
    if ($script:StudioForm -and -not $script:StudioForm.IsDisposed) {
        $script:StudioForm.UseWaitCursor = $false
    }
    return (Test-FontInstalled $Font)
}

function Resolve-PreviewTypeface {
    param(
        $FontEntry,
        [single]$Size = 12
    )
    if (-not $script:TypefaceCache) { $script:TypefaceCache = @{} }
    $cacheKey = "$(if ($FontEntry) { $FontEntry.Id } else { 'none' })|$Size"
    if ($script:TypefaceCache.ContainsKey($cacheKey)) { return $script:TypefaceCache[$cacheKey] }

    $map = Get-InstalledFontMap
    $wanted = @()
    $standIns = @()
    if ($FontEntry) {
        if ($FontEntry.Face) { $wanted += $FontEntry.Face }
        if ($FontEntry.Guesses) { $wanted += $FontEntry.Guesses }
        if ($FontEntry.Label) { $wanted += $FontEntry.Label }
        if ($FontEntry.StandIns) { $standIns += $FontEntry.StandIns }
    }

    $family = Find-InstalledFamily -Map $map -Names $wanted
    if (-not $family) { $family = Find-InstalledFamily -Map $map -Names $standIns }
    if (-not $family) { $family = Find-InstalledFamily -Map $map -Names @('Cascadia Mono', 'Cascadia Code', 'Consolas', 'Courier New') }
    if (-not $family) { $family = New-Object System.Drawing.FontFamily 'Consolas' }

    $style = [System.Drawing.FontStyle]::Regular
    if (-not $family.IsStyleAvailable($style)) { $style = [System.Drawing.FontStyle]::Bold }
    $drawing = New-Object System.Drawing.Font($family, $Size, $style, [System.Drawing.GraphicsUnit]::Point)
    $exact = $false
    if ($FontEntry -and $FontEntry.Face) {
        $exact = ($family.Name -eq $FontEntry.Face -or $family.Name -like '*Nerd*' -or ($FontEntry.Guesses -contains $family.Name))
    }
    $result = [pscustomobject]@{
        Font    = $drawing
        Family  = $family.Name
        Exact   = [bool]$exact
        Wanted  = $(if ($FontEntry) { $FontEntry.Label } else { $family.Name })
    }
    $script:TypefaceCache[$cacheKey] = $result
    return $result
}

function Get-PoshContext {
    $folder = Split-Path (Get-Location) -Leaf
    if ([string]::IsNullOrWhiteSpace($folder)) { $folder = 'Documents' }
    @{
        user   = $env:USERNAME
        host   = $env:COMPUTERNAME
        folder = $folder
        path   = "~/$folder"
        time   = (Get-Date -Format 'HH:mm')
    }
}

function Expand-PoshTemplate {
    param([string]$Text, $Ctx)
    if ([string]::IsNullOrEmpty($Text)) { return '' }
    $Text.Replace('{user}', $Ctx.user).Replace('{host}', $Ctx.host).Replace('{folder}', $Ctx.folder).Replace('{path}', $Ctx.path).Replace('{time}', $Ctx.time)
}

function Get-PoshPreviewText {
    param($Posh, $Ctx)
    if (-not $Posh) { return '' }
    if (-not $Ctx) { $Ctx = Get-PoshContext }
    $bits = @()
    foreach ($chip in @($Posh.Chips)) {
        $bits += (Expand-PoshTemplate -Text $chip.T -Ctx $Ctx).Trim()
    }
    if ($Posh.Line2) {
        $bits += '|'
        foreach ($chip in @($Posh.Line2)) {
            $bits += (Expand-PoshTemplate -Text $chip.T -Ctx $Ctx).Trim()
        }
    }
    return ($bits -join '  ')
}

function Get-PoshCatalog {
    if ($script:AllPosh -and $script:AllPosh.Count -gt 0) { return $script:AllPosh }
    # Official bundled themes from https://ohmyposh.dev/docs/themes
    @(
        @{
            Id = 'jandedobbeleer'; Label = 'jandedobbeleer'; Kind = 'diamond'
            Chips = @(
                @{ T = ' {user} '; B = '#c386f1'; F = '#ffffff' }
                @{ T = '  {path} '; B = '#ff479c'; F = '#ffffff' }
                @{ T = ' main ↑1 '; B = '#fffb38'; F = '#193549' }
                @{ T = '  24.12.0 '; B = '#6CA35E'; F = '#ffffff' }
                @{ T = '  734ms '; B = '#83769c'; F = '#ffffff' }
                @{ T = '  '; B = '#00897b'; F = '#ffffff' }
            )
        }
        @{
            Id = 'M365Princess'; Label = 'M365Princess'; Kind = 'diamond'
            Chips = @(
                @{ T = ' {user} '; B = '#9A348E'; F = '#FFFFFF' }
                @{ T = ' {path} '; B = '#DA627D'; F = '#FFFFFF' }
                @{ T = ' ➜ (main) '; B = '#FCA17D'; F = '#FFFFFF' }
                @{ T = '  24.12.0 '; B = '#86BBD8'; F = '#FFFFFF' }
                @{ T = ' ♥ {time} '; B = '#33658A'; F = '#FFFFFF' }
            )
        }
        @{
            Id = 'agnoster'; Label = 'agnoster'; Kind = 'powerline'
            Chips = @(
                @{ T = '  '; B = '#ffe9aa'; F = '#100e23' }
                @{ T = ' {user}@{host} '; B = '#ffffff'; F = '#100e23' }
                @{ T = ' {path} '; B = '#91ddff'; F = '#100e23' }
                @{ T = ' main '; B = '#95ffa4'; F = '#193549' }
                @{ T = '  .venv 3.12 '; B = '#906cff'; F = '#100e23' }
                @{ T = ' 0 '; B = '#ff8080'; F = '#ffffff' }
            )
        }
        @{
            Id = 'agnosterplus'; Label = 'agnosterplus'; Kind = 'powerline'
            Chips = @(
                @{ T = ' {user}@{host} '; B = '#ffffff'; F = '#100e23' }
                @{ T = ' {path} '; B = '#91ddff'; F = '#100e23' }
                @{ T = ' main '; B = '#95ffa4'; F = '#193549' }
            )
        }
        @{
            Id = 'aliens'; Label = 'aliens'; Kind = 'diamond'
            Chips = @(
                @{ T = ' {user}@{host} '; B = '#2e9599'; F = '#ffffff' }
                @{ T = ' {path} '; B = '#ffffff'; F = '#2e9599' }
                @{ T = ' main '; B = '#c386f1'; F = '#ffffff' }
                @{ T = ' .venv 3.12 '; B = '#ffe9aa'; F = '#100e23' }
            )
        }
        @{
            Id = 'amro'; Label = 'amro'; Kind = 'plain'
            Chips = @(
                @{ T = ' {user} on'; B = ''; F = '#ffffff' }
                @{ T = '  {path}'; B = ''; F = '#61AFEF' }
                @{ T = ' main'; B = ''; F = '#98C379' }
            )
        }
        @{
            Id = 'atomic'; Label = 'atomic'; Kind = 'diamond'
            Chips = @(
                @{ T = '  pwsh '; B = '#ffffff'; F = '#111111' }
                @{ T = '  {path} '; B = '#4F6F1F'; F = '#ffffff' }
                @{ T = ' main ↑1 '; B = '#046afa'; F = '#ffffff' }
                @{ T = '  24.12.0 '; B = '#6CA35E'; F = '#ffffff' }
            )
            Line2 = @(
                @{ T = '  '; B = ''; F = '#ffffff' }
            )
        }
        @{
            Id = 'avit'; Label = 'avit'; Kind = 'plain'
            Chips = @(
                @{ T = '{path}'; B = ''; F = '#ffffff' }
                @{ T = ' main'; B = ''; F = '#98C379' }
                @{ T = ' '; B = ''; F = '#E5C07B' }
                @{ T = ' '; B = ''; F = '#61AFEF' }
            )
        }
        @{
            Id = 'blue-owl'; Label = 'blue-owl'; Kind = 'powerline'
            Chips = @(
                @{ T = ' ⚡  '; B = '#ffffff'; F = '#1d2433' }
                @{ T = ' {path} '; B = '#33e7ff'; F = '#1d2433' }
                @{ T = ' main  +1 '; B = '#27b9c2'; F = '#1d2433' }
                @{ T = ' {user} / {host} '; B = '#1d2433'; F = '#33e7ff' }
                @{ T = ' ❯ '; B = ''; F = '#33e7ff' }
            )
        }
        @{
            Id = 'blueish'; Label = 'blueish'; Kind = 'powerline'
            Chips = @(
                @{ T = '  '; B = '#575656'; F = '#ffffff' }
                @{ T = ' {user}@{host} '; B = '#81C596'; F = '#011627' }
                @{ T = '  {path} '; B = '#4B78E6'; F = '#ffffff' }
                @{ T = ' main '; B = '#C386F1'; F = '#ffffff' }
                @{ T = ' ➜ '; B = ''; F = '#4B78E6' }
            )
        }
        @{
            Id = 'bubbles'; Label = 'bubbles'; Kind = 'bubbles'
            Chips = @(
                @{ T = ' {user} '; B = '#9A348E'; F = '#FFFFFF' }
                @{ T = '  {path} '; B = '#DA627D'; F = '#FFFFFF' }
                @{ T = ' main '; B = '#FCA17D'; F = '#FFFFFF' }
                @{ T = ' ❯ '; B = '#33658A'; F = '#FFFFFF' }
            )
        }
        @{
            Id = 'catppuccin'; Label = 'catppuccin'; Kind = 'diamond'
            Chips = @(
                @{ T = '  {user}@{host} '; B = '#CBA6F7'; F = '#1E1E2E' }
                @{ T = ' {path} '; B = '#89B4FA'; F = '#1E1E2E' }
                @{ T = ' main '; B = '#A6E3A1'; F = '#1E1E2E' }
            )
        }
        @{
            Id = 'catppuccin_mocha'; Label = 'catppuccin_mocha'; Kind = 'plain'
            Chips = @(
                @{ T = ' {user}@{host}'; B = ''; F = '#CBA6F7' }
                @{ T = ' {path}'; B = ''; F = '#89B4FA' }
                @{ T = ' main'; B = ''; F = '#A6E3A1' }
                @{ T = ' '; B = ''; F = '#F9E2AF' }
            )
        }
        @{
            Id = 'cobalt2'; Label = 'cobalt2'; Kind = 'diamond'
            Chips = @(
                @{ T = ' {path} '; B = '#1478DB'; F = '#ffffff' }
                @{ T = ' main  +1 '; B = '#047D7E'; F = '#ffffff' }
            )
        }
        @{
            Id = 'craver'; Label = 'craver'; Kind = 'powerline'
            Chips = @(
                @{ T = '  '; B = '#282c34'; F = '#e5c07b' }
                @{ T = '  '; B = '#3a3f4b'; F = '#ffffff' }
                @{ T = '  {path} '; B = '#0184bc'; F = '#ffffff' }
                @{ T = ' main  +1 '; B = '#8cc265'; F = '#ffffff' }
                @{ T = ' ➜ '; B = ''; F = '#8cc265' }
            )
        }
        @{
            Id = 'dracula'; Label = 'dracula'; Kind = 'diamond'
            Chips = @(
                @{ T = ' {user} '; B = '#BD93F9'; F = '#282A36' }
                @{ T = ' {path} '; B = '#FF79C6'; F = '#282A36' }
                @{ T = '  (main) '; B = '#50FA7B'; F = '#282A36' }
                @{ T = '  24.12.0 '; B = '#8BE9FD'; F = '#282A36' }
                @{ T = ' ♥ '; B = '#FFB86C'; F = '#282A36' }
            )
        }
        @{
            Id = 'fish'; Label = 'fish'; Kind = 'powerline'
            Chips = @(
                @{ T = ' 0    {user}@{host} '; B = '#ffffff'; F = '#100e23' }
                @{ T = ' {path} '; B = '#91ddff'; F = '#100e23' }
                @{ T = ' main '; B = '#95ffa4'; F = '#193549' }
            )
        }
        @{
            Id = 'gruvbox'; Label = 'gruvbox'; Kind = 'powerline'
            Chips = @(
                @{ T = '  '; B = '#689d6a'; F = '#282828' }
                @{ T = ' {path} '; B = '#458588'; F = '#ebdbb2' }
                @{ T = ' main ↑1 '; B = '#98971a'; F = '#282828' }
                @{ T = '  3.12 '; B = '#d79921'; F = '#282828' }
            )
        }
        @{
            Id = 'half-life'; Label = 'half-life'; Kind = 'plain'
            Chips = @(
                @{ T = '{user} in'; B = ''; F = '#ffffff' }
                @{ T = ' {path}'; B = ''; F = '#5AF78E' }
                @{ T = ' on  main'; B = ''; F = '#57C7FF' }
                @{ T = ' λ'; B = ''; F = '#F3F99D' }
            )
        }
        @{
            Id = 'iterm2'; Label = 'iterm2'; Kind = 'powerline'
            Chips = @(
                @{ T = '  '; B = '#ffe9aa'; F = '#100e23' }
                @{ T = ' {user} '; B = '#ffffff'; F = '#100e23' }
                @{ T = '  {path} '; B = '#91ddff'; F = '#100e23' }
                @{ T = ' main  +1 '; B = '#95ffa4'; F = '#193549' }
            )
        }
        @{
            Id = 'lambda'; Label = 'lambda'; Kind = 'plain'
            Chips = @(
                @{ T = '  {path}'; B = ''; F = '#61AFEF' }
                @{ T = ' git: main'; B = ''; F = '#98C379' }
            )
        }
        @{
            Id = 'material'; Label = 'material'; Kind = 'plain'
            Chips = @(
                @{ T = '❯ ❯'; B = ''; F = '#C3E88D' }
                @{ T = '  {path}'; B = ''; F = '#82AAFF' }
                @{ T = ' git:( main )'; B = ''; F = '#C792EA' }
            )
        }
        @{
            Id = 'montys'; Label = 'montys'; Kind = 'diamond'
            Chips = @(
                @{ T = '  {host} '; B = '#1BD760'; F = '#111111' }
                @{ T = '  {path} '; B = '#33e7ff'; F = '#111111' }
                @{ T = ' ➜ (main) '; B = '#016d7d'; F = '#ffffff' }
                @{ T = '  24.12.0 '; B = '#6CA35E'; F = '#ffffff' }
                @{ T = ' {time} '; B = '#ebcc34'; F = '#111111' }
            )
        }
        @{
            Id = 'night-owl'; Label = 'night-owl'; Kind = 'diamond'
            Chips = @(
                @{ T = '  '; B = '#011627'; F = '#d6deeb' }
                @{ T = ' {path} '; B = '#82aaff'; F = '#011627' }
                @{ T = '  main ↑1 '; B = '#22da6e'; F = '#011627' }
                @{ T = '  734ms '; B = '#c792ea'; F = '#011627' }
            )
            Line2 = @(
                @{ T = '  '; B = ''; F = '#82aaff' }
            )
        }
        @{
            Id = 'paradox'; Label = 'paradox'; Kind = 'powerline'
            Chips = @(
                @{ T = '  '; B = '#ffe9aa'; F = '#100e23' }
                @{ T = ' {user}@{host} '; B = '#ffffff'; F = '#100e23' }
                @{ T = ' {path} '; B = '#91ddff'; F = '#100e23' }
                @{ T = ' main '; B = '#95ffa4'; F = '#193549' }
                @{ T = '  .venv '; B = '#906cff'; F = '#100e23' }
                @{ T = ' ❯ '; B = ''; F = '#ffffff' }
            )
        }
        @{
            Id = 'powerlevel10k_classic'; Label = 'powerlevel10k_classic'; Kind = 'powerline'
            Chips = @(
                @{ T = '  '; B = '#dacaec'; F = '#000000' }
                @{ T = '  {path} '; B = '#424242'; F = '#dacaec' }
                @{ T = ' main '; B = '#9ece6a'; F = '#000000' }
                @{ T = ' {user}@{host} '; B = '#ffffff'; F = '#424242' }
                @{ T = ' ❯ '; B = ''; F = '#9ece6a' }
            )
        }
        @{
            Id = 'powerlevel10k_lean'; Label = 'powerlevel10k_lean'; Kind = 'plain'
            Chips = @(
                @{ T = '{path}'; B = ''; F = '#76cce0' }
                @{ T = ' main'; B = ''; F = '#9ece6a' }
                @{ T = ' ❯'; B = ''; F = '#e0af68' }
            )
        }
        @{
            Id = 'powerlevel10k_rainbow'; Label = 'powerlevel10k_rainbow'; Kind = 'powerline'
            Chips = @(
                @{ T = '  '; B = '#dacaec'; F = '#090c31' }
                @{ T = '  {path} '; B = '#769ff0'; F = '#090c31' }
                @{ T = ' main ↑1 '; B = '#9ece6a'; F = '#090c31' }
                @{ T = ' 24.12  '; B = '#40a02b'; F = '#ffffff' }
                @{ T = ' {time} '; B = '#d20f39'; F = '#ffffff' }
            )
            Line2 = @(
                @{ T = ' ❯ '; B = ''; F = '#dacaec' }
            )
        }
        @{
            Id = 'powerline'; Label = 'powerline'; Kind = 'powerline'
            Chips = @(
                @{ T = '  '; B = '#ffe9aa'; F = '#100e23' }
                @{ T = ' {user}@{host} '; B = '#ffffff'; F = '#100e23' }
                @{ T = ' {path} '; B = '#91ddff'; F = '#100e23' }
                @{ T = ' main '; B = '#95ffa4'; F = '#193549' }
            )
        }
        @{
            Id = 'pure'; Label = 'pure'; Kind = 'plain'
            Chips = @(
                @{ T = '{user}'; B = ''; F = '#ffffff' }
                @{ T = ' {path}'; B = ''; F = '#5AF78E' }
                @{ T = ' main ↑1'; B = ''; F = '#FF6AC1' }
                @{ T = ' ❯'; B = ''; F = '#57C7FF' }
            )
        }
        @{
            Id = 'quick-term'; Label = 'quick-term'; Kind = 'diamond'
            Chips = @(
                @{ T = '  '; B = '#0077c2'; F = '#ffffff' }
                @{ T = ' {user} '; B = '#d3d7cf'; F = '#000000' }
                @{ T = ' {path} '; B = '#3465a4'; F = '#ffffff' }
                @{ T = ' main ↑1 '; B = '#4e9a06'; F = '#ffffff' }
                @{ T = ' {time} '; B = '#c4a000'; F = '#000000' }
            )
            Line2 = @(
                @{ T = ' $ '; B = ''; F = '#4e9a06' }
            )
        }
        @{
            Id = 'robbyrussell'; Label = 'robbyrussell'; Kind = 'plain'
            Chips = @(
                @{ T = '➜'; B = ''; F = '#98C379' }
                @{ T = '  {folder}'; B = ''; F = '#56B6C2' }
                @{ T = ' git:( main )'; B = ''; F = '#E06C75' }
                @{ T = ' ✗'; B = ''; F = '#E5C07B' }
            )
        }
        @{
            Id = 'slim'; Label = 'slim'; Kind = 'plain'
            Chips = @(
                @{ T = '  {user}'; B = ''; F = '#61AFEF' }
                @{ T = '  {path}'; B = ''; F = '#56B6C2' }
                @{ T = ' main ↑1'; B = ''; F = '#98C379' }
                @{ T = ' ❯'; B = ''; F = '#E5C07B' }
            )
        }
        @{
            Id = 'spaceship'; Label = 'spaceship'; Kind = 'plain'
            Chips = @(
                @{ T = '{user}'; B = ''; F = '#F1FA8C' }
                @{ T = ' in'; B = ''; F = '#ffffff' }
                @{ T = '  {path}'; B = ''; F = '#8BE9FD' }
                @{ T = ' on'; B = ''; F = '#ffffff' }
                @{ T = '  main'; B = ''; F = '#FF79C6' }
                @{ T = ' ❯'; B = ''; F = '#50FA7B' }
            )
        }
        @{
            Id = 'star'; Label = 'star'; Kind = 'plain'
            Chips = @(
                @{ T = '{user} in'; B = ''; F = '#ffffff' }
                @{ T = ' {path}'; B = ''; F = '#61AFEF' }
                @{ T = ' on  main'; B = ''; F = '#98C379' }
                @{ T = ' via   24.12'; B = ''; F = '#E5C07B' }
                @{ T = ' ➜'; B = ''; F = '#C678DD' }
            )
        }
        @{
            Id = 'tokyo'; Label = 'tokyo'; Kind = 'plain'
            Chips = @(
                @{ T = '┏ [  {time} ]'; B = ''; F = '#7aa2f7' }
                @{ T = ' [  {user} :: {host} ]'; B = ''; F = '#bb9af7' }
            )
            Line2 = @(
                @{ T = '┗ [  {path} ]'; B = ''; F = '#7dcfff' }
                @{ T = ' [  main ]'; B = ''; F = '#9ece6a' }
                @{ T = ' >'; B = ''; F = '#e0af68' }
            )
        }
        @{
            Id = 'tokyonight_storm'; Label = 'tokyonight_storm'; Kind = 'plain'
            Chips = @(
                @{ T = '➜ {path}'; B = ''; F = '#7aa2f7' }
                @{ T = ' ⚡'; B = ''; F = '#e0af68' }
                @{ T = ' (main)'; B = ''; F = '#9ece6a' }
                @{ T = '  24.12.0'; B = ''; F = '#73daca' }
                @{ T = ' ▶'; B = ''; F = '#bb9af7' }
            )
        }
        @{
            Id = 'unicorn'; Label = 'unicorn'; Kind = 'powerline'
            Chips = @(
                @{ T = '  '; B = '#ffffff'; F = '#111111' }
                @{ T = '  {path} '; B = '#ff479c'; F = '#ffffff' }
                @{ T = ' main ↑1 '; B = '#fffb38'; F = '#193549' }
                @{ T = ' ⚡ 🦄 '; B = ''; F = '#ff79c6' }
            )
        }
        @{
            Id = 'velvet'; Label = 'velvet'; Kind = 'diamond'
            Chips = @(
                @{ T = '  '; B = '#603C66'; F = '#ffffff' }
                @{ T = ' {path} '; B = '#8B5F89'; F = '#ffffff' }
                @{ T = ' main ↑1 '; B = '#D291BC'; F = '#2a1830' }
                @{ T = '  '; B = '#FF8CC6'; F = '#2a1830' }
            )
        }
        @{
            Id = '1_shell'; Label = '1_shell'; Kind = 'plain'
            Chips = @(
                @{ T = ' {user} on'; B = ''; F = '#ffffff' }
                @{ T = '  main ↑1'; B = ''; F = '#98C379' }
                @{ T = '   {{  {path} }}'; B = ''; F = '#61AFEF' }
            )
        }
    )
}

function Get-AsciiCatalog {
    if ($script:AllArts -and $script:AllArts.Count -gt 0) { return $script:AllArts }
    @(
        @{
            Id = 'windows11'
            Category = 'Official Fastfetch'
            Label = 'Windows 11'
            Kind = 'builtin'
            Source = 'Windows 11'
            Lines = @(
                '    ██████████    ██████████'
                '    ██████████    ██████████'
                '    ██████████    ██████████'
                '    ██████████    ██████████'
                ''
                '    ██████████    ██████████'
                '    ██████████    ██████████'
                '    ██████████    ██████████'
                '    ██████████    ██████████'
            )
        }
        @{
            Id = 'windows'
            Category = 'Official Fastfetch'
            Label = 'Windows'
            Kind = 'builtin'
            Source = 'Windows'
            Lines = @(
                '        ,.=:!!t3Z3z_,'
                '       :tt:::tt333EE3'
                '       Et:::ztt33EEE'
                '      ;tt:::tt333EE7'
                '     :Et:::zt333EEQ.'
                '    ;3=*^```"*4EEZ'
                '    @Ee.,      ..,'
                '   ;EEEEEEttttt33#'
            )
        }
        @{
            Id = 'windows-small'
            Category = 'Official Fastfetch'
            Label = 'Windows small'
            Kind = 'small'
            Source = 'Windows'
            Lines = @(
                '        lllllll   lllllll'
                '        lllllll   lllllll'
                '        lllllll   lllllll'
                ''
                '        lllllll   lllllll'
                '        lllllll   lllllll'
                '        lllllll   lllllll'
            )
        }
        @{
            Id = 'windows-auto'
            Category = 'Official Fastfetch'
            Label = 'Auto (detect this PC)'
            Kind = 'auto'
            Source = ''
            Lines = @(
                '  Auto (detect this PC)'
            )
        }
        @{
            Id = 'terminal'
            Category = 'Computers'
            Label = 'Retro terminal'
            Source = 'original, Computers category at asciiart.eu/gallery'
            Lines = @(
                '      .---------------.'
                '     /  Better Term  /|'
                '    /______________ / |'
                '    |  .---------. |  |'
                '    |  | >_      | |  |'
                '    |  |         | |  |'
                '    |  |  fetch  | | /'
                '    |  ''---------'' |/'
                '    ''---------------'''
            )
        }
        @{
            Id = 'owl'
            Category = 'Animals'
            Label = 'Night owl'
            Source = 'original, Animals category at asciiart.eu/gallery'
            Lines = @(
                '       ,___,'
                '      (o,o)'
                '      /)  )'
                '     /"---"'
                '    /  ||'
                '   (   ||   )'
                '    ''--''--'''
            )
        }
        @{
            Id = 'cat'
            Category = 'Animals'
            Label = 'Sitting cat'
            Source = 'original, Animals category at asciiart.eu/gallery'
            Lines = @(
                '      /\_/\ '
                '     ( o.o )'
                '      > ^ <'
                '     /     \'
                '    (       )'
                '     \__v__/'
            )
        }
        @{
            Id = 'rocket'
            Category = 'Space'
            Label = 'Rocket'
            Source = 'original, Space category at asciiart.eu/gallery'
            Lines = @(
                '        /\ '
                '       /  \'
                '      | /\ |'
                '      | || |'
                '      | || |'
                '     / |  | \'
                '    |  |  |  |'
                '     ''-''''-'''
                '      / || \'
                '     /  \/  \'
            )
        }
        @{
            Id = 'planet'
            Category = 'Space'
            Label = 'Planet ring'
            Source = 'original, Space category at asciiart.eu/gallery'
            Lines = @(
                '        _____'
                '    .-''       ''-.'
                '   /             \'
                '  |   o     *     |'
                '   \    .-.      /'
                '    ''._/   \_.-'''
                '  ~~~~''-----''~~~~'
            )
        }
        @{
            Id = 'tree'
            Category = 'Nature'
            Label = 'Pine tree'
            Source = 'original, Nature category at asciiart.eu/gallery'
            Lines = @(
                '        /\ '
                '       /  \'
                '      /_  _\'
                '      /    \'
                '     /      \'
                '    /_      _\'
                '      | || |'
                '      |_||_|'
            )
        }
        @{
            Id = 'mountain'
            Category = 'Nature'
            Label = 'Mountains'
            Source = 'original, Nature category at asciiart.eu/gallery'
            Lines = @(
                '           /\ '
                '          /  \  /\ '
                '         /    \/  \'
                '        /  /\      \'
                '    ___/__/  \______\'
            )
        }
        @{
            Id = 'coffee'
            Category = 'Food and drinks'
            Label = 'Coffee mug'
            Source = 'original, Food category at asciiart.eu/gallery'
            Lines = @(
                '      (  )  (   ) )'
                '       ) (  )  (  ('
                '       ( ) (    ) )'
                '       _____________'
                '      <_____________> ___'
                '      |             |/ _ \'
                '      |               | | |'
                '      |               |_| |'
                '   ___|             |\___/'
                '  /    \___________/    \'
                '  \_____________________/'
            )
        }
        @{
            Id = 'castle'
            Category = 'Buildings'
            Label = 'Castle'
            Source = 'original, Buildings category at asciiart.eu/gallery'
            Lines = @(
                '      [][][]  [][][]'
                '      |    |__|    |'
                '      |   ______   |'
                '      |  |      |  |'
                '      |  | [][] |  |'
                '      |__|______|__|'
            )
        }
        @{
            Id = 'car'
            Category = 'Vehicles'
            Label = 'Little car'
            Source = 'original, Vehicles category at asciiart.eu/gallery'
            Lines = @(
                '        ______'
                '       /|_||_\`.__'
                '      (   _    _ _\'
                '      =`-(_)--(_)-'''
            )
        }
        @{
            Id = 'ghost'
            Category = 'Miscellaneous'
            Label = 'Friendly ghost'
            Source = 'original, Miscellaneous category at asciiart.eu/gallery'
            Lines = @(
                '       .-. '
                '      (o o)'
                '      | O |'
                '      |   |'
                '      ''~~~'''
            )
        }
        @{
            Id = 'robot'
            Category = 'Computers'
            Label = 'Robot'
            Source = 'original, Computers category at asciiart.eu/gallery'
            Lines = @(
                '       [o_o]'
                '        | |'
                '      --[=]--'
                '        | |'
                '       d   b'
            )
        }
        @{
            Id = 'fish'
            Category = 'Animals'
            Label = 'Fish'
            Source = 'original, Animals category at asciiart.eu/gallery'
            Lines = @(
                '     ><(((('' >'
                '               ><> '
                '   <  )))><'
            )
        }
        @{
            Id = 'none'
            Category = 'Official Fastfetch'
            Label = 'No logo (info only)'
            Kind = 'none'
            Source = ''
            Lines = @('  (no logo)')
        }
    )
}

function New-ThemeObject {
    param($Map)
    [pscustomobject]$Map
}

# -----------------------------------------------------------------------------
# UI chrome
# -----------------------------------------------------------------------------

function Show-Banner {
    param(
        [string]$Title = 'Better Terminal Setup',
        [int]$Step = 0,
        [int]$Total = 6
    )
    $w = 62
    $line = ('=' * $w)
    Write-Color $line '#7AA2F7'
    Write-Color ('  ' + $Title) '#C0CAF5'
    if ($Step -gt 0) {
        $filled = '#' * $Step
        $empty = '-' * [Math]::Max(0, ($Total - $Step))
        Write-Color ("  Step $Step of $Total    [$filled$empty]") '#89B4FA'
    } else {
        Write-Color '  Make your terminal look better, one simple step at a time.' '#89B4FA'
    }
    Write-Color $line '#7AA2F7'
    Write-Host ""
}

function Show-BoxLine {
    param([string]$Text, [string]$Color = '#A9B1D6')
    Write-Color ('  ' + $Text) $Color
}

function Read-Choice {
    param(
        [string]$Prompt,
        [string]$Default = ''
    )
    $suffix = if ($Default) { "  (press Enter for $Default)" } else { '' }
    Write-Color -NoNewline "  > $Prompt$suffix : " '#7DCFFF'
    $value = Read-Host
    if ([string]::IsNullOrWhiteSpace($value)) { return $Default }
    return $value.Trim()
}

function Read-YesNo {
    param(
        [string]$Prompt,
        [string]$Default = 'Y'
    )
    $hint = if ($Default -match '^[Yy]') { 'Y = yes, N = no' } else { 'N = no, Y = yes' }
    $answer = Read-Choice -Prompt "$Prompt  ($hint)" -Default $Default
    return ($answer -match '^[Yy]')
}

function Wait-Continue {
    Write-Host ""
    [void](Read-Choice -Prompt 'Press Enter to go to the next step' -Default '')
}

function Show-WhatIs {
    param(
        [string]$Name,
        [string]$Plain,
        [string]$Url
    )
    Write-Color "  $Name" '#A6E3A1'
    Write-Color "    $Plain" '#C0CAF5'
    Write-Color "    Comes from: $Url" '#89B4FA'
    Write-Host ""
}

function Show-SourceCard {
    param(
        [string]$Name,
        [string]$What,
        [string]$Url,
        [string]$How
    )
    Show-WhatIs -Name $Name -Plain $What -Url $Url
}

# -----------------------------------------------------------------------------
# Color preview popup + live Windows Terminal
# -----------------------------------------------------------------------------

function ConvertTo-DrawingColor {
    param([string]$Hex)
    try {
        return [System.Drawing.ColorTranslator]::FromHtml($Hex)
    } catch {
        return [System.Drawing.Color]::FromArgb(40, 42, 54)
    }
}

function Blend-DrawingColor {
    param(
        [System.Drawing.Color]$Front,
        [System.Drawing.Color]$Back,
        [int]$SolidPercent
    )
    $p = [Math]::Min(100, [Math]::Max(0, $SolidPercent)) / 100.0
    $r = [int][Math]::Round(($Front.R * $p) + ($Back.R * (1.0 - $p)))
    $g = [int][Math]::Round(($Front.G * $p) + ($Back.G * (1.0 - $p)))
    $b = [int][Math]::Round(($Front.B * $p) + ($Back.B * (1.0 - $p)))
    return [System.Drawing.Color]::FromArgb(255, $r, $g, $b)
}

function Update-GlassTickLabels {
    $bar = $script:GlassTicks
    $slider = $script:GlassSlider
    if (-not $bar -or -not $slider) { return }
    $bar.Controls.Clear()
    $w = $slider.ClientSize.Width
    if ($w -lt 40) { return }
    $pad = 14
    $inner = [Math]::Max(1, $w - (2 * $pad))
    foreach ($n in 0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100) {
        $lbl = New-Object System.Windows.Forms.Label
        $lbl.AutoSize = $true
        $lbl.Text = [string]$n
        $lbl.ForeColor = [System.Drawing.Color]::FromArgb(200, 205, 216)
        $lbl.BackColor = $bar.BackColor
        $lbl.Font = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Bold)
        [void]$bar.Controls.Add($lbl)
        $x = $pad + [int](($inner * $n) / 100) - [int]($lbl.PreferredSize.Width / 2)
        if ($x -lt 0) { $x = 0 }
        $maxX = [Math]::Max(0, $bar.ClientSize.Width - $lbl.PreferredSize.Width)
        if ($x -gt $maxX) { $x = $maxX }
        $lbl.Location = New-Object System.Drawing.Point($x, 1)
    }
}

function Initialize-PreviewPopup {
    if ($script:PreviewForm -and -not $script:PreviewForm.IsDisposed) { return $true }

    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
        [System.Windows.Forms.Application]::EnableVisualStyles()
    } catch {
        Write-Color '  Could not open a preview window. Colors will still be saved to Windows Terminal.' '#F9E2AF'
        return $false
    }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Your terminal preview — watch this change'
    $form.Size = New-Object System.Drawing.Size(720, 460)
    $form.MinimumSize = New-Object System.Drawing.Size(640, 400)
    $form.StartPosition = 'CenterScreen'
    $form.TopMost = $true
    $form.MaximizeBox = $false
    $form.ShowInTaskbar = $true

    $title = New-Object System.Windows.Forms.Label
    $title.Dock = 'Top'
    $title.Height = 40
    $title.TextAlign = 'MiddleLeft'
    $title.Padding = New-Object System.Windows.Forms.Padding(14, 0, 0, 0)
    $title.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)

    $swatch = New-Object System.Windows.Forms.FlowLayoutPanel
    $swatch.Dock = 'Bottom'
    $swatch.Height = 40
    $swatch.Padding = New-Object System.Windows.Forms.Padding(10, 8, 10, 8)

    $prompt = New-Object System.Windows.Forms.Label
    $prompt.Dock = 'Bottom'
    $prompt.Height = 56
    $prompt.TextAlign = 'MiddleLeft'
    $prompt.Padding = New-Object System.Windows.Forms.Padding(16, 0, 0, 0)
    $prompt.Font = New-Object System.Drawing.Font('Consolas', 12, [System.Drawing.FontStyle]::Bold)

    $split = New-Object System.Windows.Forms.TableLayoutPanel
    $split.Dock = 'Fill'
    $split.ColumnCount = 2
    $split.RowCount = 1
    $split.Padding = New-Object System.Windows.Forms.Padding(16, 12, 16, 8)
    [void]$split.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 44)))
    [void]$split.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 56)))

    $artBox = New-Object System.Windows.Forms.Label
    $artBox.Dock = 'Fill'
    $artBox.Font = New-Object System.Drawing.Font('Consolas', 10)
    $artBox.AutoSize = $false

    $infoBox = New-Object System.Windows.Forms.Label
    $infoBox.Dock = 'Fill'
    $infoBox.Font = New-Object System.Drawing.Font('Consolas', 11)
    $infoBox.AutoSize = $false

    $split.Controls.Add($artBox, 0, 0)
    $split.Controls.Add($infoBox, 1, 0)

    $form.Controls.Add($split)
    $form.Controls.Add($prompt)
    $form.Controls.Add($swatch)
    $form.Controls.Add($title)

    $form.Add_FormClosing({
        param($sender, $e)
        if (-not $script:AllowPreviewClose -and $e.CloseReason -eq [System.Windows.Forms.CloseReason]::UserClosing) {
            $e.Cancel = $true
            $sender.Hide()
        }
    })

    $script:PreviewForm = $form
    $script:PreviewTitle = $title
    $script:PreviewArt = $artBox
    $script:PreviewInfo = $infoBox
    $script:PreviewPrompt = $prompt
    $script:PreviewSwatch = $swatch
    $form.Show()
    return $true
}

function Close-PreviewPopup {
    $script:AllowPreviewClose = $true
    if ($script:PreviewForm -and -not $script:PreviewForm.IsDisposed) {
        try {
            $script:PreviewForm.Close()
            $script:PreviewForm.Dispose()
        } catch {}
    }
    $script:PreviewForm = $null
}

function Update-PreviewPopup {
    param(
        $Theme,
        $Art,
        $Font,
        $Posh,
        [int]$Opacity = 80
    )

    if (-not $Theme) { return }
    if (-not (Initialize-PreviewPopup)) { return }

    $bg = ConvertTo-DrawingColor $Theme.background
    $fg = ConvertTo-DrawingColor $Theme.foreground
    $accent = ConvertTo-DrawingColor $Theme.blue
    $cyan = ConvertTo-DrawingColor $Theme.cyan
    $green = ConvertTo-DrawingColor $Theme.green
    $yellow = ConvertTo-DrawingColor $Theme.yellow

    $script:PreviewForm.BackColor = $bg
    $script:PreviewTitle.BackColor = $accent
    $script:PreviewTitle.ForeColor = $bg
    $script:PreviewTitle.Text = "  $($Theme.name)    transparency $Opacity%"

    $script:PreviewArt.BackColor = $bg
    $script:PreviewArt.ForeColor = $cyan
    $script:PreviewInfo.BackColor = $bg
    $script:PreviewInfo.ForeColor = $fg
    $script:PreviewPrompt.BackColor = $bg
    $script:PreviewPrompt.ForeColor = $green
    $script:PreviewSwatch.BackColor = $bg

    $script:PreviewArt.Text = Get-ArtPreviewText $Art

    $fontName = if ($Font) { $Font.Label } else { 'current font' }
    $promptName = if ($Posh) { $Posh.Label } else { 'Oh My Posh' }
    $script:PreviewInfo.Text = @(
        "$($env:USERNAME)@$($env:COMPUTERNAME)"
        '-----------'
        'OS       Windows'
        'Shell    PowerShell'
        'Term     Windows Terminal'
        "Font     $fontName"
        "Prompt   $promptName"
        "Theme    $($Theme.name)"
    ) -join [Environment]::NewLine

    $promptText = if ($Posh) { Get-PoshPreviewText -Posh $Posh } else { 'ready' }
    $script:PreviewPrompt.Text = "  $promptText"

    $script:PreviewSwatch.Controls.Clear()
    $dots = @(
        @{ N = 'red'; C = $Theme.red },
        @{ N = 'green'; C = $Theme.green },
        @{ N = 'yellow'; C = $Theme.yellow },
        @{ N = 'blue'; C = $Theme.blue },
        @{ N = 'purple'; C = $Theme.purple },
        @{ N = 'cyan'; C = $Theme.cyan }
    )
    foreach ($dot in $dots) {
        $chip = New-Object System.Windows.Forms.Label
        $chip.AutoSize = $false
        $chip.Size = New-Object System.Drawing.Size(78, 24)
        $chip.Margin = New-Object System.Windows.Forms.Padding(4, 0, 4, 0)
        $chip.TextAlign = 'MiddleCenter'
        $chip.Text = $dot.N
        $chip.BackColor = ConvertTo-DrawingColor $dot.C
        $chip.ForeColor = $bg
        $chip.Font = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Bold)
        $script:PreviewSwatch.Controls.Add($chip)
    }

    if (-not $script:PreviewForm.Visible) { $script:PreviewForm.Show() }
    $script:PreviewForm.BringToFront()
    [System.Windows.Forms.Application]::DoEvents()
}

function Update-WindowsTerminalLivePreview {
    param(
        $Theme,
        $Font,
        [int]$Opacity = 80
    )

    if (-not $Theme) { return }
    $path = Get-WindowsTerminalSettingsPath
    if (-not (Test-Path $path)) { return }

    $liveFont = $Font
    if (-not $liveFont -and $script:StudioPlan) { $liveFont = $script:StudioPlan.Font }
    if ($liveFont -and -not (Test-FontInstalled $liveFont)) { $liveFont = $null }
    $state = [pscustomobject]@{
        Theme             = $Theme
        Font              = $liveFont
        ApplyTransparency = $true
        Opacity           = $Opacity
        UseAcrylic        = if ($script:StudioPlan) { [bool]$script:StudioPlan.UseAcrylic } else { $true }
    }

    try {
        if (-not $script:DidLiveBackup) {
            [void](Set-WindowsTerminalLook -State $state -Quiet)
            $script:DidLiveBackup = $true
        } else {
            [void](Set-WindowsTerminalLook -State $state -Quiet -NoBackup)
        }
    } catch {
        # Preview popup still works if live apply fails.
    }
}

function Write-PreviewWindow {
    param(
        $Theme,
        $Art,
        $Font,
        $Posh,
        [int]$Opacity = 80,
        [int]$Width = 58
    )

    if (-not $Theme) { return }

    Update-PreviewPopup -Theme $Theme -Art $Art -Font $Font -Posh $Posh -Opacity $Opacity
    Update-WindowsTerminalLivePreview -Theme $Theme -Font $Font -Opacity $Opacity

    $name = $Theme.name
    Write-Color "  The preview window changed to $name." '#A6E3A1'
    if ($env:WT_SESSION) {
        Write-Color '  Your Windows Terminal colors updated too. Look at this window.' '#89B4FA'
    } else {
        Write-Color '  Watch the popup for real colors. Windows Terminal will match when it is open.' '#89B4FA'
    }

    $reset = Get-Reset
    Write-Host -NoNewline '  '
    foreach ($item in @(
        @{ N = 'red'; C = $Theme.red },
        @{ N = 'green'; C = $Theme.green },
        @{ N = 'yellow'; C = $Theme.yellow },
        @{ N = 'blue'; C = $Theme.blue },
        @{ N = 'purple'; C = $Theme.purple },
        @{ N = 'cyan'; C = $Theme.cyan }
    )) {
        Write-Host -NoNewline ((Get-Bg $item.C) + (Get-Fg $Theme.background) + " $($item.N) " + $reset + ' ')
    }
    Write-Host ""
}

function Get-ThemeShade {
    param($Theme)
    $c = ConvertFrom-HexColor $Theme.background
    $lum = (0.299 * $c.R) + (0.587 * $c.G) + (0.114 * $c.B)
    if ($lum -gt 140) { return 'Light' }
    return 'Dark'
}

function New-ClickTable {
    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Dock = 'Fill'
    $grid.ReadOnly = $true
    $grid.AllowUserToAddRows = $false
    $grid.AllowUserToDeleteRows = $false
    $grid.AllowUserToResizeRows = $false
    $grid.SelectionMode = 'FullRowSelect'
    $grid.MultiSelect = $false
    $grid.RowHeadersVisible = $false
    $grid.AutoSizeColumnsMode = 'Fill'
    $grid.BackgroundColor = [System.Drawing.Color]::FromArgb(28, 28, 34)
    $grid.GridColor = [System.Drawing.Color]::FromArgb(50, 50, 58)
    $grid.BorderStyle = 'None'
    $grid.EnableHeadersVisualStyles = $false
    $grid.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(45, 48, 62)
    $grid.ColumnHeadersDefaultCellStyle.ForeColor = [System.Drawing.Color]::White
    $grid.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $grid.ColumnHeadersHeight = 34
    $grid.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(34, 36, 46)
    $grid.DefaultCellStyle.ForeColor = [System.Drawing.Color]::FromArgb(230, 232, 240)
    $grid.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(88, 130, 247)
    $grid.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::White
    $grid.DefaultCellStyle.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    $grid.RowTemplate.Height = 30
    $grid.AlternatingRowsDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(40, 42, 54)
    return $grid
}

function Get-StudioHardwareInfo {
    if ($script:StudioHw) { return $script:StudioHw }

    $os = 'Windows'
    $cpu = [string]$env:PROCESSOR_IDENTIFIER
    $gpu = ''
    $mem = '?'
    $disk = '?'
    $uptime = ''
    $kernel = [string][System.Environment]::OSVersion.Version
    try {
        $win = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        if ($win.Caption) { $os = $win.Caption.Trim() }
        if ($win.Version) { $kernel = [string]$win.Version }
        if ($win.LastBootUpTime) {
            $hours = [int](((Get-Date) - $win.LastBootUpTime).TotalHours)
            $uptime = "$hours hours"
        }
        if ($win.TotalVisibleMemorySize) {
            $tot = [math]::Round($win.TotalVisibleMemorySize / 1MB, 0)
            $used = [math]::Round(($win.TotalVisibleMemorySize - $win.FreePhysicalMemory) / 1MB, 0)
            $mem = "$used / $tot GB"
        }
    } catch {}
    try {
        $p = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
        if ($p.Name) { $cpu = [string]$p.Name }
    } catch {}
    try {
        $g = Get-CimInstance Win32_VideoController -ErrorAction Stop | Where-Object { $_.Name } | Select-Object -First 1
        if ($g.Name) { $gpu = [string]$g.Name }
    } catch {}
    try {
        $d = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
        if ($d.Size) {
            $disk = ('{0} / {1} GB' -f [math]::Round($d.FreeSpace / 1GB, 0), [math]::Round($d.Size / 1GB, 0))
        }
    } catch {}
    if ($cpu.Length -gt 34) { $cpu = $cpu.Substring(0, 32) + '...' }
    if ($gpu.Length -gt 34) { $gpu = $gpu.Substring(0, 32) + '...' }
    if ($os.Length -gt 34) { $os = $os.Substring(0, 32) + '...' }

    $script:StudioHw = [pscustomobject]@{
        OS     = $os
        Kernel = $kernel
        CPU    = $cpu
        GPU    = $gpu
        Memory = $mem
        Disk   = $disk
        Uptime = $uptime
    }
    return $script:StudioHw
}

function Update-StudioPreview {
    $Theme = $script:StudioPlan.Theme
    $Art = $script:StudioPlan.Art
    $Font = $script:StudioPlan.Font
    $Posh = $script:StudioPlan.Posh
    $Opacity = [int]$script:StudioPlan.Opacity
    if (-not $Theme -or -not $script:StudioUi) { return }

    $themeBg = ConvertTo-DrawingColor $Theme.background
    $fg = ConvertTo-DrawingColor $Theme.foreground
    $accent = ConvertTo-DrawingColor $Theme.blue
    $cyan = ConvertTo-DrawingColor $Theme.cyan
    $wall = [System.Drawing.Color]::FromArgb(88, 108, 142)
    $bg = Blend-DrawingColor -Front $themeBg -Back $wall -SolidPercent $Opacity

    $ui = $script:StudioUi
    if ($ui.Desktop) { $ui.Desktop.BackColor = $wall }
    $ui.Preview.BackColor = $bg
    $ui.Title.BackColor = $accent
    $ui.Title.ForeColor = $themeBg
    $fontLabel = if ($Font) { $Font.Label } else { 'font' }
    $artLabel = if ($Art) { $Art.Label } else { 'logo' }
    $ui.Title.Text = "  $artLabel    $fontLabel    $($Theme.name)    $Opacity% solid"
    $ui.Art.BackColor = $bg
    $ui.Art.ForeColor = $fg
    if ($ui.Info) {
        $ui.Info.Visible = $false
    }
    $ui.Swatch.BackColor = $bg
    if ($ui.PromptStrip) { $ui.PromptStrip.BackColor = $bg }
    if ($ui.PromptName) {
        $ui.PromptName.BackColor = $bg
        $ui.PromptName.ForeColor = $fg
    }

    $ui.Art.Text = Get-FastfetchFullPreview -Art $Art
    if ($script:ArtGrid -and $script:ArtGrid.CurrentRow -and $Art) {
        try { $script:ArtGrid.CurrentRow.Cells[1].Value = Get-ArtSnippet $Art } catch {}
    }

    $sampleFace = Resolve-PreviewTypeface -FontEntry $Font -Size 11
    $ui.Art.Font = New-Object System.Drawing.Font('Consolas', 8)
    if ($ui.FontSample) {
        $ui.FontSample.BackColor = $bg
        $ui.FontSample.ForeColor = $fg
        $ui.FontSample.Font = $sampleFace.Font
        $shown = $sampleFace.Family
        $ui.FontSample.Text = "  $fontLabel    ABCDEF  abcdef  012345  =>  !=  </>  { }"
        if (-not $sampleFace.Exact) {
            $ui.FontSample.Text = "  $fontLabel  (closest now: $shown)    ABCDEF  abcdef  012345"
        }
    }
    Update-PromptStrip -Theme $Theme -Posh $Posh -Font $Font

    $ui.Swatch.Controls.Clear()
    foreach ($dot in @(
        @{ N = 'red'; C = $Theme.red },
        @{ N = 'green'; C = $Theme.green },
        @{ N = 'yellow'; C = $Theme.yellow },
        @{ N = 'blue'; C = $Theme.blue },
        @{ N = 'purple'; C = $Theme.purple },
        @{ N = 'cyan'; C = $Theme.cyan }
    )) {
        $chip = New-Object System.Windows.Forms.Label
        $chip.AutoSize = $false
        $chip.Size = New-Object System.Drawing.Size(54, 16)
        $chip.Margin = New-Object System.Windows.Forms.Padding(3, 0, 3, 0)
        $chip.TextAlign = 'MiddleCenter'
        $chip.Text = $dot.N
        $chip.BackColor = ConvertTo-DrawingColor $dot.C
        $chip.ForeColor = $bg
        $chip.Font = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Bold)
        $ui.Swatch.Controls.Add($chip)
    }

    if ($ui.Picks) {
        $ui.Picks.Text = "Selected:  $($Theme.name)   |   $(if ($Font) { $Font.Label } else { 'font' })   |   $(if ($Art) { $Art.Label } else { 'art' })   |   $(if ($Posh) { $Posh.Label } else { 'prompt' })   |   $Opacity%"
    }

    Update-WindowsTerminalLivePreview -Theme $Theme -Font $Font -Opacity $Opacity
}

function Filter-ClickTable {
    param($Grid, [string]$Query)
    if (-not $Grid) { return }
    foreach ($row in $Grid.Rows) {
        if ($row.IsNewRow) { continue }
        if ([string]::IsNullOrWhiteSpace($Query)) {
            $row.Visible = $true
            continue
        }
        $hit = $false
        foreach ($cell in $row.Cells) {
            if ([string]$cell.Value -like "*$Query*") { $hit = $true; break }
        }
        $row.Visible = $hit
    }
}

function Select-StudioTab {
    param([string]$Name)
    if (-not $script:StudioTabs) { return }
    foreach ($page in $script:StudioTabs.TabPages) {
        if ($page.Text -eq $Name) {
            $script:StudioTabs.SelectedTab = $page
            return
        }
    }
}

function Count-VisibleRows {
    param($Grid)
    $n = 0
    if (-not $Grid) { return 0 }
    foreach ($row in $Grid.Rows) {
        if (-not $row.IsNewRow -and $row.Visible) { $n++ }
    }
    return $n
}

function Get-CurrentStudioGrid {
    $name = ''
    if ($script:StudioTabs -and $script:StudioTabs.SelectedTab) {
        $name = [string]$script:StudioTabs.SelectedTab.Text
    }
    switch ($name) {
        'Colors' { return $script:ThemeGrid }
        'Fonts' { return $script:FontGrid }
        'Fastfetch' { return $script:ArtGrid }
        'Prompt' { return $script:PoshGrid }
        default { return $null }
    }
}

function Update-StudioSearch {
    $raw = ''
    if ($script:StudioSearch) { $raw = [string]$script:StudioSearch.Text }
    if ($null -eq $raw) { $raw = '' }
    $q = $raw.Trim()

    Filter-ClickTable -Grid $script:ThemeGrid -Query ''
    Filter-ClickTable -Grid $script:FontGrid -Query ''
    Filter-ClickTable -Grid $script:ArtGrid -Query ''
    Filter-ClickTable -Grid $script:PoshGrid -Query ''

    $tabName = ''
    if ($script:StudioTabs -and $script:StudioTabs.SelectedTab) {
        $tabName = [string]$script:StudioTabs.SelectedTab.Text
    }

    if ($tabName -eq 'Transparency') {
        if ($q -match '^\d{1,3}$') {
            $n = [int]$q
            if ($n -ge 0 -and $n -le 100 -and $script:GlassSlider) {
                $script:GlassSlider.Value = $n
            }
        }
        return
    }

    Filter-ClickTable -Grid (Get-CurrentStudioGrid) -Query $q
}

function Add-PromptChip {
    param(
        $Panel,
        $Text,
        $BackColor,
        $ForeColor,
        $Font,
        $Gap = 0
    )
    $chip = New-Object System.Windows.Forms.Label
    $chip.AutoSize = $true
    $chip.Padding = New-Object System.Windows.Forms.Padding(1, 1, 1, 1)
    $chip.Margin = New-Object System.Windows.Forms.Padding($Gap, 1, 0, 1)
    $chip.Text = $Text
    $chip.BackColor = $BackColor
    $chip.ForeColor = $ForeColor
    $chip.Font = $Font
    $chip.UseMnemonic = $false
    $Panel.Controls.Add($chip)
}

function Add-PoshChipRow {
    param($HostPanel, $Chips, $Kind, $Ctx, $Font, $TermBg)
    $row = New-Object System.Windows.Forms.FlowLayoutPanel
    $row.Dock = 'Top'
    $row.Height = 22
    $row.BackColor = $TermBg
    $row.WrapContents = $false
    $row.AutoScroll = $true
    $row.FlowDirection = 'LeftToRight'
    $row.Padding = New-Object System.Windows.Forms.Padding(4, 0, 4, 0)
    $list = @($Chips)
    $kind = [string]$Kind
    for ($i = 0; $i -lt $list.Count; $i++) {
        $chip = $list[$i]
        $text = Expand-PoshTemplate -Text $chip.T -Ctx $Ctx
        $hasBack = -not [string]::IsNullOrWhiteSpace($chip.B)
        $fore = if ($chip.F) { ConvertTo-DrawingColor $chip.F } else { [System.Drawing.Color]::White }
        $back = if ($hasBack) { ConvertTo-DrawingColor $chip.B } else { $TermBg }
        if ($kind -eq 'bubbles' -and $hasBack) {
            Add-PromptChip -Panel $row -Text ('' + $text + '') -BackColor $TermBg -ForeColor $back -Font $Font -Gap 6
            continue
        }
        if (($kind -eq 'diamond') -and $i -eq 0 -and $hasBack) {
            Add-PromptChip -Panel $row -Text '' -BackColor $TermBg -ForeColor $back -Font $Font
        }
        Add-PromptChip -Panel $row -Text $text -BackColor $back -ForeColor $fore -Font $Font
        $nextHasBack = ($i -lt ($list.Count - 1)) -and (-not [string]::IsNullOrWhiteSpace($list[$i + 1].B))
        if ($hasBack -and ($kind -eq 'powerline' -or $kind -eq 'diamond') -and $nextHasBack) {
            $nextBack = ConvertTo-DrawingColor $list[$i + 1].B
            Add-PromptChip -Panel $row -Text '' -BackColor $nextBack -ForeColor $back -Font $Font
        } elseif ($hasBack -and ($kind -eq 'powerline' -or $kind -eq 'diamond') -and -not $nextHasBack) {
            Add-PromptChip -Panel $row -Text '' -BackColor $TermBg -ForeColor $back -Font $Font
        }
    }
    $HostPanel.Controls.Add($row)
}

function Update-PromptStrip {
    param($Theme, $Posh, $Font)
    $ui = $script:StudioUi
    if (-not $ui -or -not $ui.PromptStrip) { return }

    $termBg = if ($ui.Preview) { $ui.Preview.BackColor } else { ConvertTo-DrawingColor $Theme.background }
    $ui.PromptStrip.Controls.Clear()
    $ui.PromptStrip.BackColor = $termBg
    $face = Resolve-PreviewTypeface -FontEntry $Font -Size 8
    $ctx = Get-PoshContext
    if (-not $Posh) { $Posh = (Get-PoshCatalog | Select-Object -First 1) }

    if ($Posh.Line2) {
        Add-PoshChipRow -HostPanel $ui.PromptStrip -Chips $Posh.Line2 -Kind $Posh.Kind -Ctx $ctx -Font $face.Font -TermBg $termBg
    }
    Add-PoshChipRow -HostPanel $ui.PromptStrip -Chips $Posh.Chips -Kind $Posh.Kind -Ctx $ctx -Font $face.Font -TermBg $termBg

    if ($ui.PromptName) {
        $ui.PromptName.Text = "  $($Posh.Label)   —  official Oh My Posh theme"
        $ui.PromptName.BackColor = $termBg
        $ui.PromptName.ForeColor = ConvertTo-DrawingColor $Theme.foreground
    }
}

function Show-ChoiceStudio {
    param($Plan)

    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
        [System.Windows.Forms.Application]::EnableVisualStyles()
    } catch {
        Write-Color '  Could not open the clickable window. Using the older step-by-step screens.' '#F9E2AF'
        return $null
    }

    $themes = @(Get-ThemeCatalog)
    $fonts = @(Get-FontCatalog)
    $arts = @(Get-AsciiCatalog)
    $poshItems = @(Get-PoshCatalog)

    if (-not $Plan.Theme) { $Plan.Theme = $themes[0] }
    if (-not $Plan.Font) { $Plan.Font = $fonts[0] }
    if (-not $Plan.Art) { $Plan.Art = $arts[0] }
    if (-not $Plan.Posh) { $Plan.Posh = $poshItems[0] }

    $script:StudioPlan = $Plan
    $script:StudioResult = 'cancel'

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Better Terminal — pick from the list'
    $form.Size = New-Object System.Drawing.Size(1000, 820)
    $form.MinimumSize = New-Object System.Drawing.Size(880, 720)
    $form.StartPosition = 'CenterScreen'
    $form.TopMost = $true
    $form.BackColor = [System.Drawing.Color]::FromArgb(22, 22, 28)
    $form.ForeColor = [System.Drawing.Color]::White
    $form.Font = New-Object System.Drawing.Font('Segoe UI', 10)

    $header = New-Object System.Windows.Forms.Label
    $header.Dock = 'Top'
    $header.Height = 36
    $header.Text = "  Everything is already downloaded. $($themes.Count) colors, $($fonts.Count) fonts, $($arts.Count) Fastfetch logos, $($poshItems.Count) prompts. Search clears when you change tabs."
    $header.TextAlign = 'MiddleLeft'
    $header.BackColor = [System.Drawing.Color]::FromArgb(36, 38, 52)
    $header.Font = New-Object System.Drawing.Font('Segoe UI', 11)

    $picks = New-Object System.Windows.Forms.Label
    $picks.Dock = 'Bottom'
    $picks.Height = 28
    $picks.TextAlign = 'MiddleLeft'
    $picks.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 36)
    $picks.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)

    $buttons = New-Object System.Windows.Forms.Panel
    $buttons.Dock = 'Bottom'
    $buttons.Height = 64
    $buttons.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 36)

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'Use this look'
    $ok.Size = New-Object System.Drawing.Size(160, 38)
    $ok.Location = New-Object System.Drawing.Point(20, 12)
    $ok.BackColor = [System.Drawing.Color]::FromArgb(88, 166, 120)
    $ok.ForeColor = [System.Drawing.Color]::White
    $ok.FlatStyle = 'Flat'
    $ok.Add_Click({
        $script:StudioResult = 'ok'
        Close-PreviewPopup
        $script:StudioForm.Close()
    })

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'Cancel'
    $cancel.Size = New-Object System.Drawing.Size(120, 38)
    $cancel.Location = New-Object System.Drawing.Point(196, 12)
    $cancel.BackColor = [System.Drawing.Color]::FromArgb(70, 70, 80)
    $cancel.ForeColor = [System.Drawing.Color]::White
    $cancel.FlatStyle = 'Flat'
    $cancel.Add_Click({
        $script:StudioResult = 'cancel'
        $script:StudioForm.Close()
    })

    $buttons.Controls.Add($ok)
    $buttons.Controls.Add($cancel)

    $tabs = New-Object System.Windows.Forms.TabControl
    $tabs.Dock = 'Fill'
    $tabs.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)

    $darkPage = [System.Drawing.Color]::FromArgb(18, 18, 22)
    $darkText = [System.Drawing.Color]::FromArgb(230, 232, 240)

    $themeTab = New-Object System.Windows.Forms.TabPage
    $themeTab.Text = 'Colors'
    $fontTab = New-Object System.Windows.Forms.TabPage
    $fontTab.Text = 'Fonts'
    $artTab = New-Object System.Windows.Forms.TabPage
    $artTab.Text = 'Fastfetch'
    $poshTab = New-Object System.Windows.Forms.TabPage
    $poshTab.Text = 'Prompt'
    $glassTab = New-Object System.Windows.Forms.TabPage
    $glassTab.Text = 'Transparency'
    foreach ($page in @($themeTab, $fontTab, $artTab, $poshTab, $glassTab)) {
        $page.UseVisualStyleBackColor = $false
        $page.BackColor = $darkPage
        $page.ForeColor = $darkText
    }

    $themeGrid = New-ClickTable
    [void]$themeGrid.Columns.Add('Name', 'Theme')
    [void]$themeGrid.Columns.Add('Shade', 'Dark / Light')
    foreach ($t in $themes) {
        $i = $themeGrid.Rows.Add($t.name, (Get-ThemeShade $t))
        $themeGrid.Rows[$i].Tag = $t
    }
    $themeGrid.Add_SelectionChanged({
        if ($script:ThemeGrid.CurrentRow -and $script:ThemeGrid.CurrentRow.Tag) {
            $script:StudioPlan.Theme = $script:ThemeGrid.CurrentRow.Tag
            Update-StudioPreview
        }
    })
    $themeTab.Controls.Add($themeGrid)

    $fontGrid = New-ClickTable
    [void]$fontGrid.Columns.Add('Name', 'Font')
    [void]$fontGrid.Columns.Add('Note', 'Why pick it')
    foreach ($f in $fonts) {
        $note = $f.Note
        if ($f.Id -eq 'Meslo') { $note = 'Recommended. ' + $note }
        $i = $fontGrid.Rows.Add($f.Label, $note)
        $fontGrid.Rows[$i].Tag = $f
    }
    $fontGrid.Add_SelectionChanged({
        if ($script:FontGrid.CurrentRow -and $script:FontGrid.CurrentRow.Tag) {
            $script:StudioPlan.Font = $script:FontGrid.CurrentRow.Tag
            Update-StudioPreview
        }
    })
    $fontGrid.Add_CellFormatting({
        param($s, $e)
        if ($e.ColumnIndex -ne 0 -or $e.RowIndex -lt 0) { return }
        $entry = $script:FontGrid.Rows[$e.RowIndex].Tag
        if (-not $entry) { return }
        $look = Resolve-PreviewTypeface -FontEntry $entry -Size 11
        $e.CellStyle.Font = $look.Font
    })
    $fontTab.Controls.Add($fontGrid)

    $artGrid = New-ClickTable
    [void]$artGrid.Columns.Add('Name', 'Logo')
    [void]$artGrid.Columns.Add('Picture', 'ASCII art')
    foreach ($a in $arts) {
        $i = $artGrid.Rows.Add($a.Label, (Get-ArtSnippet $a))
        $artGrid.Rows[$i].Tag = $a
    }
    $artGrid.Add_SelectionChanged({
        if ($script:ArtGrid.CurrentRow -and $script:ArtGrid.CurrentRow.Tag) {
            $script:StudioPlan.Art = $script:ArtGrid.CurrentRow.Tag
            Update-StudioPreview
        }
    })
    $artTab.Controls.Add($artGrid)

    $poshGrid = New-ClickTable
    $poshGrid.RowTemplate.Height = 38
    [void]$poshGrid.Columns.Add('Name', 'Theme')
    [void]$poshGrid.Columns.Add('Look', 'Official look (ohmyposh.dev/docs/themes)')
    $poshCtx = Get-PoshContext
    foreach ($p in $poshItems) {
        $i = $poshGrid.Rows.Add($p.Label, (Get-PoshPreviewText -Posh $p -Ctx $poshCtx))
        $poshGrid.Rows[$i].Tag = $p
    }
    $poshGrid.Add_SelectionChanged({
        if ($script:PoshGrid.CurrentRow -and $script:PoshGrid.CurrentRow.Tag) {
            $script:StudioPlan.Posh = $script:PoshGrid.CurrentRow.Tag
            Update-StudioPreview
        }
    })
    $poshGrid.Add_CellFormatting({
        param($s, $e)
        if ($e.RowIndex -lt 0) { return }
        $entry = $script:StudioPlan.Font
        $look = Resolve-PreviewTypeface -FontEntry $entry -Size 10
        $e.CellStyle.Font = $look.Font
    })
    $poshTab.Controls.Add($poshGrid)

    $glassWrap = New-Object System.Windows.Forms.Panel
    $glassWrap.Dock = 'Fill'
    $glassWrap.BackColor = $darkPage
    $glassWrap.Padding = New-Object System.Windows.Forms.Padding(16)

    $glassHelp = New-Object System.Windows.Forms.Label
    $glassHelp.Dock = 'Top'
    $glassHelp.Height = 70
    $glassHelp.ForeColor = $darkText
    $glassHelp.BackColor = $darkPage
    $glassHelp.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $glassHelp.Text = "Transparency: how solid should the window be? Drag from 0 to 100.`r`n0 = wallpaper shows through.  50 = half glass.  100 = fully solid.`r`nSearch 80 to jump the slider. The small terminal shows the look."
    $glassHelp.TextAlign = 'MiddleLeft'

    $glassPct = New-Object System.Windows.Forms.Label
    $glassPct.Dock = 'Top'
    $glassPct.Height = 48
    $glassPct.ForeColor = [System.Drawing.Color]::FromArgb(120, 200, 140)
    $glassPct.BackColor = $darkPage
    $glassPct.Font = New-Object System.Drawing.Font('Segoe UI', 22, [System.Drawing.FontStyle]::Bold)
    $glassPct.Text = "$([int]$Plan.Opacity)% solid"
    $glassPct.TextAlign = 'MiddleLeft'

    $slideBox = New-Object System.Windows.Forms.Panel
    $slideBox.Dock = 'Top'
    $slideBox.Height = 96
    $slideBox.BackColor = $darkPage

    $tickBar = New-Object System.Windows.Forms.Panel
    $tickBar.Dock = 'Bottom'
    $tickBar.Height = 22
    $tickBar.BackColor = $darkPage

    $slider = New-Object System.Windows.Forms.TrackBar
    $slider.Dock = 'Fill'
    $slider.Minimum = 0
    $slider.Maximum = 100
    $slider.TickFrequency = 10
    $slider.SmallChange = 1
    $slider.LargeChange = 10
    $slider.TickStyle = 'BottomRight'
    $slider.Value = [Math]::Min(100, [Math]::Max(0, [int]$Plan.Opacity))
    $slider.BackColor = $darkPage
    $slider.AutoSize = $false

    $slideBox.Controls.Add($slider)
    $slideBox.Controls.Add($tickBar)
    $slideBox.Add_Resize({ Update-GlassTickLabels })

    $blur = New-Object System.Windows.Forms.CheckBox
    $blur.Text = 'Soft blur behind the text (keep the window dark)'
    $blur.Checked = [bool]$Plan.UseAcrylic
    $blur.Dock = 'Top'
    $blur.Height = 40
    $blur.ForeColor = $darkText
    $blur.BackColor = $darkPage
    $blur.Font = New-Object System.Drawing.Font('Segoe UI', 11)

    $script:GlassPct = $glassPct
    $script:GlassTicks = $tickBar
    $slider.Add_ValueChanged({
        $script:StudioPlan.Opacity = $script:GlassSlider.Value
        if ($script:GlassPct) { $script:GlassPct.Text = "$($script:GlassSlider.Value)% solid" }
        Update-StudioPreview
    })
    $blur.Add_CheckedChanged({
        $script:StudioPlan.UseAcrylic = $script:GlassBlur.Checked
        Update-StudioPreview
    })
    $glassWrap.Controls.Add($blur)
    $glassWrap.Controls.Add($slideBox)
    $glassWrap.Controls.Add($glassPct)
    $glassWrap.Controls.Add($glassHelp)
    $glassTab.Controls.Add($glassWrap)

    [void]$tabs.TabPages.Add($themeTab)
    [void]$tabs.TabPages.Add($fontTab)
    [void]$tabs.TabPages.Add($artTab)
    [void]$tabs.TabPages.Add($poshTab)
    [void]$tabs.TabPages.Add($glassTab)

    $searchBar = New-Object System.Windows.Forms.Panel
    $searchBar.Dock = 'Top'
    $searchBar.Height = 44
    $searchBar.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 36)

    $searchLabel = New-Object System.Windows.Forms.Label
    $searchLabel.Text = 'Search'
    $searchLabel.Location = New-Object System.Drawing.Point(12, 12)
    $searchLabel.AutoSize = $true
    $searchLabel.ForeColor = [System.Drawing.Color]::FromArgb(200, 210, 230)

    $searchBox = New-Object System.Windows.Forms.TextBox
    $searchBox.Location = New-Object System.Drawing.Point(68, 9)
    $searchBox.Width = 420
    $searchBox.Text = ''

    $find = New-Object System.Windows.Forms.Button
    $find.Text = 'Find'
    $find.Location = New-Object System.Drawing.Point(500, 7)
    $find.Size = New-Object System.Drawing.Size(70, 26)
    $find.FlatStyle = 'Flat'
    $find.BackColor = [System.Drawing.Color]::FromArgb(70, 70, 80)
    $find.ForeColor = [System.Drawing.Color]::White

    $searchHint = New-Object System.Windows.Forms.Label
    $searchHint.Text = 'clears when you change tabs'
    $searchHint.Location = New-Object System.Drawing.Point(580, 12)
    $searchHint.AutoSize = $true
    $searchHint.ForeColor = [System.Drawing.Color]::FromArgb(140, 150, 168)

    $searchBar.Controls.Add($searchLabel)
    $searchBar.Controls.Add($searchBox)
    $searchBar.Controls.Add($find)
    $searchBar.Controls.Add($searchHint)

    $find.Add_Click({ Update-StudioSearch })
    $searchBox.Add_TextChanged({ Update-StudioSearch })
    $searchBox.Add_KeyDown({
        param($s, $e)
        if ($e.KeyCode -eq 'Enter') { Update-StudioSearch }
    })
    $desktop = New-Object System.Windows.Forms.Panel
    $desktop.Dock = 'Top'
    $desktop.Height = 390
    $desktop.BackColor = [System.Drawing.Color]::FromArgb(88, 108, 142)
    $desktop.Padding = New-Object System.Windows.Forms.Padding(10, 8, 10, 8)

    $preview = New-Object System.Windows.Forms.Panel
    $preview.Dock = 'Fill'
    $preview.BackColor = [System.Drawing.Color]::FromArgb(12, 12, 16)

    $title = New-Object System.Windows.Forms.Label
    $title.Dock = 'Top'
    $title.Height = 22
    $title.TextAlign = 'MiddleLeft'
    $title.BackColor = [System.Drawing.Color]::FromArgb(12, 12, 16)
    $title.ForeColor = [System.Drawing.Color]::FromArgb(200, 210, 230)
    $title.Text = '  Your terminal'
    $title.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
    $title.Padding = New-Object System.Windows.Forms.Padding(8, 0, 0, 0)

    $promptName = New-Object System.Windows.Forms.Label
    $promptName.Visible = $false
    $promptName.Height = 0

    $promptStrip = New-Object System.Windows.Forms.Panel
    $promptStrip.Dock = 'Bottom'
    $promptStrip.Height = 44
    $promptStrip.BackColor = [System.Drawing.Color]::FromArgb(12, 12, 16)
    $promptStrip.Padding = New-Object System.Windows.Forms.Padding(2, 1, 2, 1)

    $fontSample = New-Object System.Windows.Forms.Label
    $fontSample.Dock = 'Bottom'
    $fontSample.Height = 22
    $fontSample.TextAlign = 'MiddleLeft'
    $fontSample.BackColor = [System.Drawing.Color]::FromArgb(12, 12, 16)
    $fontSample.ForeColor = [System.Drawing.Color]::FromArgb(220, 220, 228)
    $fontSample.Font = New-Object System.Drawing.Font('Consolas', 10)
    $fontSample.UseMnemonic = $false
    $fontSample.Text = '  Click a font to see the letters change here.'
    $fontSample.Padding = New-Object System.Windows.Forms.Padding(8, 0, 0, 0)

    $swatch = New-Object System.Windows.Forms.FlowLayoutPanel
    $swatch.Dock = 'Bottom'
    $swatch.Height = 20
    $swatch.BackColor = [System.Drawing.Color]::FromArgb(12, 12, 16)
    $swatch.Padding = New-Object System.Windows.Forms.Padding(6, 1, 6, 1)

    $cols = New-Object System.Windows.Forms.Panel
    $cols.Dock = 'Fill'
    $cols.BackColor = [System.Drawing.Color]::FromArgb(12, 12, 16)
    $cols.Padding = New-Object System.Windows.Forms.Padding(8, 4, 8, 4)

    $artBox = New-Object System.Windows.Forms.TextBox
    $artBox.Dock = 'Fill'
    $artBox.Multiline = $true
    $artBox.ReadOnly = $true
    $artBox.WordWrap = $false
    $artBox.ScrollBars = 'Both'
    $artBox.BorderStyle = 'None'
    $artBox.TabStop = $false
    $artBox.Font = New-Object System.Drawing.Font('Consolas', 8)
    $artBox.BackColor = [System.Drawing.Color]::FromArgb(12, 12, 16)
    $artBox.ForeColor = [System.Drawing.Color]::FromArgb(220, 220, 228)
    $artBox.Text = '  Fastfetch will show here.'
    $infoBox = New-Object System.Windows.Forms.Label
    $infoBox.Visible = $false
    $infoBox.Height = 0
    $cols.Controls.Add($artBox)

    $preview.Controls.Add($cols)
    $preview.Controls.Add($fontSample)
    $preview.Controls.Add($promptStrip)
    $preview.Controls.Add($swatch)
    $preview.Controls.Add($title)
    $desktop.Controls.Add($preview)

    $form.Controls.Add($tabs)
    $form.Controls.Add($searchBar)
    $form.Controls.Add($desktop)
    $form.Controls.Add($buttons)
    $form.Controls.Add($picks)
    $form.Controls.Add($header)

    $script:StudioForm = $form
    $script:ThemeGrid = $themeGrid
    $script:FontGrid = $fontGrid
    $script:ArtGrid = $artGrid
    $script:PoshGrid = $poshGrid
    $script:StudioTabs = $tabs
    $script:StudioSearch = $searchBox
    $tabs.Add_SelectedIndexChanged({
        if ($script:StudioSearch -and $script:StudioSearch.Text) {
            $script:StudioSearch.Text = ''
        }
        Update-StudioSearch
    })
    $script:GlassSlider = $slider
    $script:GlassBlur = $blur
    $script:StudioUi = @{
        Desktop     = $desktop
        Preview     = $preview
        Title       = $title
        Art         = $artBox
        Info        = $infoBox
        PromptStrip = $promptStrip
        PromptName  = $promptName
        FontSample  = $fontSample
        Swatch      = $swatch
        Picks       = $picks
    }

    $form.Add_Shown({
        $script:StudioForm.Activate()
        $script:StudioForm.BringToFront()
        Update-GlassTickLabels
        if ($script:ThemeGrid.Rows.Count -gt 0) { $script:ThemeGrid.Rows[0].Selected = $true }
        if ($script:FontGrid.Rows.Count -gt 0) { $script:FontGrid.Rows[0].Selected = $true }
        if ($script:ArtGrid.Rows.Count -gt 0) { $script:ArtGrid.Rows[0].Selected = $true }
        if ($script:PoshGrid.Rows.Count -gt 0) { $script:PoshGrid.Rows[0].Selected = $true }
        Update-StudioPreview
    })

    [void]$form.ShowDialog()

    if ($script:StudioResult -ne 'ok') { return $null }
    return $script:StudioPlan
}

# -----------------------------------------------------------------------------
# Network: live theme catalog
# -----------------------------------------------------------------------------

function Get-RemoteThemeNames {
    if ($script:AllThemes -and $script:AllThemes.Count -gt 0) {
        $script:RemoteThemeNames = @($script:AllThemes | ForEach-Object { $_.name })
        return $script:RemoteThemeNames
    }
    if ($script:RemoteThemeNames) { return $script:RemoteThemeNames }
    Write-Color '  Loading full theme list from GitHub (iTerm2-Color-Schemes)...' '#89B4FA'
    try {
        $headers = @{ 'User-Agent' = 'BetterTerminalSetup' }
        $items = Invoke-RestMethod -Uri $script:ThemeCatalogUrl -Headers $headers -TimeoutSec 30
        $script:RemoteThemeNames = @(
            $items |
                Where-Object { $_.name -like '*.json' } |
                ForEach-Object { $_.name -replace '\.json$', '' }
        )
        Write-Color ("  Found $($script:RemoteThemeNames.Count) themes.") '#A6E3A1'
    } catch {
        Write-Color "  Could not load the full catalog: $($_.Exception.Message)" '#F38BA8'
        $script:RemoteThemeNames = @()
    }
    return $script:RemoteThemeNames
}

function Get-ThemeFromWeb {
    param([string]$Name)
    if ($script:RemoteThemeCache.ContainsKey($Name)) {
        return $script:RemoteThemeCache[$Name]
    }
    if ($script:AllThemes) {
        $hit = @($script:AllThemes | Where-Object { $_.name -eq $Name } | Select-Object -First 1)
        if ($hit.Count -gt 0 -and $hit[0]) {
            $script:RemoteThemeCache[$Name] = $hit[0]
            return $hit[0]
        }
    }

    $encoded = [Uri]::EscapeDataString($Name)
    $url = "$script:ThemeSourceUrl/$encoded.json"
    try {
        $raw = Invoke-RestMethod -Uri $url -Headers @{ 'User-Agent' = 'BetterTerminalSetup' } -TimeoutSec 20
        $map = @{
            name                = $raw.name
            source              = 'iTerm2-Color-Schemes / windowsterminalthemes.dev'
            background          = $raw.background
            foreground          = $raw.foreground
            black               = $raw.black
            red                 = $raw.red
            green               = $raw.green
            yellow              = $raw.yellow
            blue                = $raw.blue
            purple              = $raw.purple
            cyan                = $raw.cyan
            white               = $raw.white
            brightBlack         = $raw.brightBlack
            brightRed           = $raw.brightRed
            brightGreen         = $raw.brightGreen
            brightYellow        = $raw.brightYellow
            brightBlue          = $raw.brightBlue
            brightPurple        = $raw.brightPurple
            brightCyan          = $raw.brightCyan
            brightWhite         = $raw.brightWhite
            cursorColor         = $raw.cursorColor
            selectionBackground = $raw.selectionBackground
        }
        $obj = New-ThemeObject $map
        $script:RemoteThemeCache[$Name] = $obj
        return $obj
    } catch {
        Write-Color "  Could not download theme '$Name'." '#F38BA8'
        return $null
    }
}

function Convert-ToTerminalScheme {
    param($Theme)
    [pscustomobject]@{
        name                = [string]$Theme.name
        background          = [string]$Theme.background
        foreground          = [string]$Theme.foreground
        black               = [string]$Theme.black
        red                 = [string]$Theme.red
        green               = [string]$Theme.green
        yellow              = [string]$Theme.yellow
        blue                = [string]$Theme.blue
        purple              = [string]$Theme.purple
        cyan                = [string]$Theme.cyan
        white               = [string]$Theme.white
        brightBlack         = [string]$Theme.brightBlack
        brightRed           = [string]$Theme.brightRed
        brightGreen         = [string]$Theme.brightGreen
        brightYellow        = [string]$Theme.brightYellow
        brightBlue          = [string]$Theme.brightBlue
        brightPurple        = [string]$Theme.brightPurple
        brightCyan          = [string]$Theme.brightCyan
        brightWhite         = [string]$Theme.brightWhite
        cursorColor         = [string]$Theme.cursorColor
        selectionBackground = [string]$Theme.selectionBackground
    }
}

# -----------------------------------------------------------------------------
# Paths + tools
# -----------------------------------------------------------------------------

function Get-WindowsTerminalSettingsPath {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
    )
    foreach ($path in $candidates) {
        if (Test-Path $path) { return $path }
    }
    return $candidates[0]
}

function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machine;$user"
    $poshThemes = [Environment]::GetEnvironmentVariable('POSH_THEMES_PATH', 'User')
    if ($poshThemes) { $env:POSH_THEMES_PATH = $poshThemes }
}

function Test-CommandExists {
    param([string]$Name)
    $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-WingetCommand {
    if (Test-CommandExists 'winget') { return 'winget' }
    $app = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
    if (Test-Path $app) { return $app }
    return $null
}

function Invoke-WingetInstall {
    param(
        [string]$PackageId,
        [string]$DisplayName
    )
    $winget = Get-WingetCommand
    if (-not $winget) { return $false }
    Write-Color "  Installing $DisplayName with winget ($PackageId)..." '#89B4FA'
    & $winget install --id $PackageId -e --accept-package-agreements --accept-source-agreements --disable-interactivity
    Update-SessionPath
    return ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189)
}

function Get-PoshThemesDirectory {
    Update-SessionPath
    if ($env:POSH_THEMES_PATH -and (Test-Path $env:POSH_THEMES_PATH)) {
        return $env:POSH_THEMES_PATH
    }
    $guesses = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\oh-my-posh\themes'),
        (Join-Path $env:LOCALAPPDATA 'oh-my-posh\themes')
    )
    foreach ($g in $guesses) {
        if (Test-Path $g) { return $g }
    }
    return $null
}

function ConvertFrom-Jsonc {
    param([string]$Text)
    $noBlock = [regex]::Replace($Text, '(?s)/\*.*?\*/', '')
    $lines = $noBlock -split "`n" | ForEach-Object {
        if ($_ -match '^\s*//') { '' } else { $_ }
    }
    ($lines -join "`n") | ConvertFrom-Json
}

function Write-Utf8NoBom {
    param(
        [string]$Path,
        [string]$Text
    )
    $enc = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $Text, $enc)
}

# -----------------------------------------------------------------------------
# Full catalogs: download everything first, then pick
# -----------------------------------------------------------------------------

function Get-CatalogRoot {
    if ($script:CatalogRoot -and (Test-Path $script:CatalogRoot)) { return $script:CatalogRoot }
    $path = Join-Path $env:LOCALAPPDATA 'BetterTerminal'
    New-Item -ItemType Directory -Force -Path $path | Out-Null
    $script:CatalogRoot = $path
    return $path
}

function Get-ThemeColorValue {
    param($Raw, [string]$Name, [string]$Fallback)
    $prop = $Raw.PSObject.Properties[$Name]
    if ($prop -and $prop.Value) { return [string]$prop.Value }
    return $Fallback
}

function New-ThemeFromRaw {
    param($Raw, [string]$FallbackName)
    $name = Get-ThemeColorValue -Raw $Raw -Name 'name' -Fallback $FallbackName
    if ([string]::IsNullOrWhiteSpace($name)) { $name = $FallbackName }
    New-ThemeObject @{
        name                = $name
        source              = 'iTerm2-Color-Schemes / windowsterminalthemes.dev'
        background          = (Get-ThemeColorValue -Raw $Raw -Name 'background' -Fallback '#1e1e2e')
        foreground          = (Get-ThemeColorValue -Raw $Raw -Name 'foreground' -Fallback '#cdd6f4')
        black               = (Get-ThemeColorValue -Raw $Raw -Name 'black' -Fallback '#11111b')
        red                 = (Get-ThemeColorValue -Raw $Raw -Name 'red' -Fallback '#f38ba8')
        green               = (Get-ThemeColorValue -Raw $Raw -Name 'green' -Fallback '#a6e3a1')
        yellow              = (Get-ThemeColorValue -Raw $Raw -Name 'yellow' -Fallback '#f9e2af')
        blue                = (Get-ThemeColorValue -Raw $Raw -Name 'blue' -Fallback '#89b4fa')
        purple              = (Get-ThemeColorValue -Raw $Raw -Name 'purple' -Fallback '#cba6f7')
        cyan                = (Get-ThemeColorValue -Raw $Raw -Name 'cyan' -Fallback '#94e2d5')
        white               = (Get-ThemeColorValue -Raw $Raw -Name 'white' -Fallback '#cdd6f4')
        brightBlack         = (Get-ThemeColorValue -Raw $Raw -Name 'brightBlack' -Fallback '#45475a')
        brightRed           = (Get-ThemeColorValue -Raw $Raw -Name 'brightRed' -Fallback '#f38ba8')
        brightGreen         = (Get-ThemeColorValue -Raw $Raw -Name 'brightGreen' -Fallback '#a6e3a1')
        brightYellow        = (Get-ThemeColorValue -Raw $Raw -Name 'brightYellow' -Fallback '#f9e2af')
        brightBlue          = (Get-ThemeColorValue -Raw $Raw -Name 'brightBlue' -Fallback '#89b4fa')
        brightPurple        = (Get-ThemeColorValue -Raw $Raw -Name 'brightPurple' -Fallback '#cba6f7')
        brightCyan          = (Get-ThemeColorValue -Raw $Raw -Name 'brightCyan' -Fallback '#94e2d5')
        brightWhite         = (Get-ThemeColorValue -Raw $Raw -Name 'brightWhite' -Fallback '#ffffff')
        cursorColor         = (Get-ThemeColorValue -Raw $Raw -Name 'cursorColor' -Fallback '#cdd6f4')
        selectionBackground = (Get-ThemeColorValue -Raw $Raw -Name 'selectionBackground' -Fallback '#45475a')
    }
}

function Import-ThemesFromFolder {
    param([string]$Folder)
    $list = @()
    $seen = @{}
    $files = @(Get-ChildItem -Path $Folder -Filter '*.json' -File -ErrorAction SilentlyContinue)
    foreach ($file in $files) {
        try {
            $raw = Get-Content -Path $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            $obj = New-ThemeFromRaw -Raw $raw -FallbackName $file.BaseName
            $key = $obj.name.ToLowerInvariant()
            if ($seen.ContainsKey($key)) { continue }
            $seen[$key] = $true
            $list += $obj
            $script:RemoteThemeCache[$obj.name] = $obj
        } catch {}
    }
    return @($list | Sort-Object name)
}

function Import-AllColorThemes {
    $root = Get-CatalogRoot
    $themeRoot = Join-Path $root 'themes'
    $wt = Join-Path $themeRoot 'windowsterminal'
    New-Item -ItemType Directory -Force -Path $wt | Out-Null

    $existing = @(Get-ChildItem -Path $wt -Filter '*.json' -File -ErrorAction SilentlyContinue)
    if ($existing.Count -lt 50) {
        Write-Color '  Downloading every Windows Terminal color theme' '#CBA6F7'
        Show-WhatIs -Name 'Color themes' -Plain 'All official color themes for the picker.' -Url $script:ThemeSiteUrl
        $ok = $false
        try {
            $headers = @{ 'User-Agent' = 'BetterTerminalSetup' }
            $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/mbadolato/iTerm2-Color-Schemes/releases/latest' -Headers $headers -TimeoutSec 30
            $asset = @($rel.assets | Where-Object { $_.name -eq 'windowsterminal-themes.tgz' } | Select-Object -First 1)
            if ($asset) {
                Write-Color "  From: $($asset.browser_download_url)" '#89B4FA'
                $tgz = Join-Path $env:TEMP 'windowsterminal-themes.tgz'
                Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tgz -UseBasicParsing -TimeoutSec 60
                if (Test-Path $themeRoot) { Remove-Item $themeRoot -Recurse -Force }
                New-Item -ItemType Directory -Force -Path $themeRoot | Out-Null
                tar -xf $tgz -C $themeRoot
                $ok = $true
            }
        } catch {
            Write-Color "  Theme pack download failed: $($_.Exception.Message)" '#F9E2AF'
        }
        if (-not $ok) {
            try {
                Write-Color '  Trying the full GitHub zip next...' '#89B4FA'
                $zipUrl = 'https://github.com/mbadolato/iTerm2-Color-Schemes/archive/refs/heads/master.zip'
                $zip = Join-Path $env:TEMP 'iTerm2-Color-Schemes-master.zip'
                Invoke-WebRequest -Uri $zipUrl -OutFile $zip -UseBasicParsing -TimeoutSec 90
                $extract = Join-Path $env:TEMP 'iTerm2-Color-Schemes-master'
                if (Test-Path $extract) { Remove-Item $extract -Recurse -Force }
                Expand-Archive -Path $zip -DestinationPath $extract -Force
                $found = Get-ChildItem -Path $extract -Recurse -Directory -Filter 'windowsterminal' | Select-Object -First 1
                if ($found) {
                    if (Test-Path $themeRoot) { Remove-Item $themeRoot -Recurse -Force }
                    New-Item -ItemType Directory -Force -Path $themeRoot | Out-Null
                    Copy-Item -Path $found.FullName -Destination $wt -Recurse -Force
                    $ok = $true
                }
            } catch {
                Write-Color "  Could not download the full color list: $($_.Exception.Message)" '#F38BA8'
            }
        }
    } else {
        Write-Color "  Using $($existing.Count) color themes already saved on this PC." '#A6E3A1'
    }

    if (-not (Test-Path $wt)) { $wt = $themeRoot }
    $loaded = @(Import-ThemesFromFolder -Folder $wt)
    if ($loaded.Count -eq 0) {
        $parent = Get-ChildItem -Path $themeRoot -Recurse -Directory -Filter 'windowsterminal' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($parent) { $loaded = @(Import-ThemesFromFolder -Folder $parent.FullName) }
    }
    if ($loaded.Count -eq 0) {
        Write-Color '  Using the built-in color list instead.' '#F9E2AF'
        $loaded = @(Get-BuiltInThemes | ForEach-Object { New-ThemeObject $_ })
    }
    $script:AllThemes = $loaded
    $script:RemoteThemeNames = @($loaded | ForEach-Object { $_.name })
    Write-Color "  Color themes ready: $($loaded.Count)" '#A6E3A1'
    return $loaded.Count
}

function ConvertTo-SpacedName {
    param([string]$Id)
    if ([string]::IsNullOrWhiteSpace($Id)) { return $Id }
    $s = $Id -creplace '([a-z])([A-Z])', '$1 $2'
    $s = $s -creplace '([A-Z]+)([A-Z][a-z])', '$1 $2'
    $s = $s -creplace '([A-Za-z])([0-9])', '$1 $2'
    return $s.Trim()
}

function Import-AllNerdFonts {
    $root = Get-CatalogRoot
    $cache = Join-Path $root 'nerd-fonts.json'
    $items = @()
    if (Test-Path $cache) {
        try { $items = @(Get-Content -Path $cache -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { $items = @() }
    }
    if ($items.Count -lt 20) {
        Write-Color '  Downloading the full Nerd Fonts list' '#CBA6F7'
        Show-WhatIs -Name 'Nerd Fonts' -Plain 'Every official coding font name for the picker. The font you click is installed when you save.' -Url $script:NerdFontsSiteUrl
        try {
            $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/tags/$script:NerdFontsVersion" -Headers @{ 'User-Agent' = 'BetterTerminalSetup' } -TimeoutSec 30
            $skip = @('FontPatcher.zip', 'NerdFontsSymbolsOnly.zip')
            $zips = @($rel.assets | Where-Object { $_.name -like '*.zip' -and ($skip -notcontains $_.name) })
            $items = @()
            foreach ($zip in $zips) {
                $id = [IO.Path]::GetFileNameWithoutExtension($zip.name)
                $items += [pscustomobject]@{ Id = $id; Zip = [string]$zip.name }
            }
            ($items | ConvertTo-Json -Depth 4) | Set-Content -Path $cache -Encoding UTF8
            Write-Color "  From: $($rel.html_url)" '#89B4FA'
        } catch {
            Write-Color "  Could not load the full font list: $($_.Exception.Message)" '#F38BA8'
            $items = @()
        }
    } else {
        Write-Color "  Using $($items.Count) font names already saved on this PC." '#A6E3A1'
    }

    $notes = @{
        Meslo          = 'Recommended. Icons look right.'
        CascadiaCode   = 'The usual Windows Terminal font.'
        FiraCode       = 'Letter pairs can join together.'
        JetBrainsMono  = 'Clear and tall.'
        Hack           = 'Simple and easy to read.'
        GeistMono      = 'Modern and sharp.'
        IosevkaTerm    = 'Narrow letters.'
        SauceCodePro   = 'A classic coding font.'
        RobotoMono     = 'Friendly spacing.'
        UbuntuMono     = 'The classic Ubuntu look.'
        Inconsolata    = 'Soft, print-like letters.'
        CommitMono     = 'A newer coding font.'
    }
    $faces = @{
        CascadiaCode = @{ Face = 'CaskaydiaCove NF'; Label = 'Cascadia (CaskaydiaCove)'; Omp = 'cascadiacode'; Guesses = @('CaskaydiaCove NF', 'CaskaydiaCove Nerd Font', 'CaskaydiaCove NFM') }
        CascadiaMono = @{ Face = 'CaskaydiaMono NF'; Label = 'Cascadia Mono'; Omp = 'cascadiamono'; Guesses = @('CaskaydiaMono NF', 'CaskaydiaMono Nerd Font', 'CaskaydiaMono NFM', 'CaskaydiaMono NFP') }
        SauceCodePro = @{ Face = 'SauceCodePro Nerd Font'; Label = 'Source Code Pro'; Omp = 'sourcecodepro'; Guesses = @('SauceCodePro Nerd Font', 'Source Code Pro') }
        Meslo        = @{ Face = 'MesloLGM Nerd Font'; Label = 'Meslo'; Omp = 'meslo'; Guesses = @('MesloLGM Nerd Font', 'MesloLGS Nerd Font', 'MesloLGL Nerd Font', 'Meslo LG M', 'Meslo LG S') }
    }
    $standIns = @('Consolas', 'Cascadia Code', 'Calibri', 'Bahnschrift', 'Lucida Console', 'Segoe UI', 'Yu Gothic', 'Cambria', 'Verdana', 'Trebuchet MS', 'Georgia', 'Arial')
    $catalog = @()
    $i = 0
    foreach ($item in ($items | Sort-Object { if ($_.Id -eq 'Meslo') { '0' } else { $_.Id } })) {
        $id = [string]$item.Id
        $special = $faces[$id]
        $label = if ($special) { $special.Label } else { ConvertTo-SpacedName $id }
        $face = if ($special) { $special.Face } else { "$id Nerd Font" }
        $omp = if ($special) { $special.Omp } else { $id.ToLowerInvariant() }
        $guesses = if ($special) { @($special.Guesses) } else { @($face, "$id Nerd Font Mono", $id) }
        $note = if ($notes.ContainsKey($id)) { $notes[$id] } else { 'Official Nerd Font' }
        if ($id -eq 'Meslo') { $note = 'Recommended. Icons look right.' }
        $catalog += [pscustomobject]@{
            Id       = $id
            Label    = $label
            Face     = $face
            OmpName  = $omp
            Zip      = if ($item.Zip) { [string]$item.Zip } else { "$id.zip" }
            Size     = 'from Nerd Fonts'
            Note     = $note
            Guesses  = $guesses
            StandIns = @($standIns[$i % $standIns.Count])
        }
        $i++
    }
    if ($catalog.Count -eq 0) {
        $script:AllFonts = $null
        $catalog = @(Get-FontCatalog)
    }
    $script:AllFonts = @($catalog)
    Write-Color "  Fonts ready: $($script:AllFonts.Count)" '#A6E3A1'
    return $script:AllFonts.Count
}

function ConvertTo-PoshChipText {
    param([string]$Type, [string]$Template)
    $t = if ($null -eq $Template) { '' } else { [string]$Template }
    $t = [regex]::Replace($t, '\{\{\s*if[^\}]+\}\}.*?\{\{\s*end\s*\}\}', '', 'IgnoreCase, Singleline')
    $t = [regex]::Replace($t, '\{\{[^}]*UserName[^}]*\}\}', '{user}')
    $t = [regex]::Replace($t, '\{\{[^}]*HostName[^}]*\}\}', '{host}')
    $t = [regex]::Replace($t, '\{\{[^}]*\.(Path|Folder|PWD|Location)[^}]*\}\}', '{path}')
    $t = [regex]::Replace($t, '\{\{[^}]*Time[^}]*\}\}', '{time}')
    $t = [regex]::Replace($t, '\{\{[^}]*HEAD[^}]*\}\}', 'main')
    $t = [regex]::Replace($t, '\{\{[^}]+\}\}', '')
    $t = [regex]::Replace($t, '\s+', ' ')
    if ([string]::IsNullOrWhiteSpace($t)) {
        switch -Regex ($Type) {
            'session' { return ' {user} ' }
            'path' { return ' {path} ' }
            'git' { return ' main ' }
            'os' { return '  ' }
            'time' { return ' {time} ' }
            'shell' { return ' pwsh ' }
            default { return " $Type " }
        }
    }
    if ($t -notmatch '^\s') { $t = " $t" }
    if ($t -notmatch '\s$') { $t = "$t " }
    return $t
}

function Resolve-OmpColor {
    param($Value, $Palette)
    if ($null -eq $Value) { return '' }
    if ($Value -is [System.Array]) {
        if ($Value.Count -eq 0) { return '' }
        $Value = $Value[0]
    }
    $c = [string]$Value
    if ([string]::IsNullOrWhiteSpace($c) -or $c -eq 'transparent') { return '' }
    if ($c.StartsWith('p:') -and $Palette) {
        $key = $c.Substring(2)
        if ($Palette.ContainsKey($key)) { return [string]$Palette[$key] }
    }
    if ($c -match '^#[0-9A-Fa-f]{3,8}$') { return $c }
    if ($Palette -and $Palette.ContainsKey($c)) { return [string]$Palette[$c] }
    return ''
}

function Convert-OmpFileToCatalog {
    param([string]$Path)
    $id = [IO.Path]::GetFileNameWithoutExtension($Path) -replace '\.omp$', ''
    $text = Get-Content -Path $Path -Raw -Encoding UTF8
    $json = $null
    try { $json = ConvertFrom-Jsonc -Text $text } catch { return $null }
    if (-not $json) { return $null }

    $palette = @{}
    if ($json.palette) {
        foreach ($p in $json.palette.PSObject.Properties) {
            $palette[$p.Name] = [string]$p.Value
        }
    }

    $kind = 'plain'
    $chips = @()
    $line2 = $null
    $blocks = @()
    if ($json.blocks) { $blocks = @($json.blocks | Where-Object { $_.type -ne 'rprompt' }) }
    for ($b = 0; $b -lt $blocks.Count; $b++) {
        $row = @()
        foreach ($seg in @($blocks[$b].segments)) {
            if ($row.Count -ge 6) { break }
            $style = [string]$seg.style
            if ($style -match 'diamond') { $kind = 'diamond' }
            elseif ($style -match 'powerline' -and $kind -eq 'plain') { $kind = 'powerline' }
            $bg = Resolve-OmpColor -Value $seg.background -Palette $palette
            $fg = Resolve-OmpColor -Value $seg.foreground -Palette $palette
            if ([string]::IsNullOrWhiteSpace($fg)) { $fg = '#ffffff' }
            $row += [pscustomobject]@{
                T = (ConvertTo-PoshChipText -Type ([string]$seg.type) -Template ([string]$seg.template))
                B = $bg
                F = $fg
            }
        }
        if ($b -eq 0) { $chips = $row }
        elseif ($b -eq 1 -and $row.Count -gt 0) { $line2 = $row }
    }
    if ($chips.Count -eq 0) {
        $chips = @(
            [pscustomobject]@{ T = " $id "; B = '#89B4FA'; F = '#1e1e2e' }
            [pscustomobject]@{ T = ' {path} '; B = '#45475a'; F = '#cdd6f4' }
        )
    }
    $entry = [pscustomobject]@{
        Id        = $id
        Label     = $id
        Kind      = $kind
        Chips     = $chips
        ThemePath = $Path
    }
    if ($line2) { $entry | Add-Member -NotePropertyName Line2 -NotePropertyValue $line2 }
    return $entry
}

function Import-AllPoshThemes {
    $root = Get-CatalogRoot
    $dest = Join-Path $root 'posh-themes'
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    $files = @(Get-ChildItem -Path $dest -Filter '*.omp.json' -File -ErrorAction SilentlyContinue)
    $themeDir = Get-PoshThemesDirectory
    if ($themeDir -and $themeDir -ne $dest) {
        $local = @(Get-ChildItem -Path $themeDir -Filter '*.omp.json' -File -ErrorAction SilentlyContinue)
        foreach ($file in $local) {
            $copy = Join-Path $dest $file.Name
            if (-not (Test-Path $copy)) { Copy-Item $file.FullName $copy -Force }
        }
        $files = @(Get-ChildItem -Path $dest -Filter '*.omp.json' -File -ErrorAction SilentlyContinue)
    }
    if ($files.Count -lt 20) {
        Write-Color '  Downloading every official Oh My Posh theme' '#CBA6F7'
        Show-WhatIs -Name 'Oh My Posh themes' -Plain 'All official prompt themes for the picker.' -Url $script:OhMyPoshThemesUrl
        try {
            $api = Invoke-RestMethod -Uri 'https://api.github.com/repos/JanDeDobbeleer/oh-my-posh/contents/themes' -Headers @{ 'User-Agent' = 'BetterTerminalSetup' } -TimeoutSec 30
            $remote = @($api | Where-Object { $_.name -like '*.omp.json' })
            $n = 0
            foreach ($item in $remote) {
                $n++
                $out = Join-Path $dest $item.name
                if (Test-Path $out) { continue }
                Invoke-WebRequest -Uri $item.download_url -OutFile $out -UseBasicParsing -TimeoutSec 20
                if ($n % 20 -eq 0) { Write-Color "    saved $n of $($remote.Count) prompts..." '#89B4FA' }
            }
            Write-Color "  From: https://github.com/JanDeDobbeleer/oh-my-posh/tree/main/themes" '#89B4FA'
        } catch {
            Write-Color "  Could not download every prompt: $($_.Exception.Message)" '#F38BA8'
        }
        $files = @(Get-ChildItem -Path $dest -Filter '*.omp.json' -File -ErrorAction SilentlyContinue)
    } else {
        Write-Color "  Using $($files.Count) prompt themes already saved on this PC." '#A6E3A1'
    }

    $catalog = @()
    foreach ($file in ($files | Sort-Object Name)) {
        $entry = Convert-OmpFileToCatalog -Path $file.FullName
        if ($entry) { $catalog += $entry }
    }
    if ($catalog.Count -eq 0) {
        $script:AllPosh = $null
        $catalog = @(Get-PoshCatalog)
    }
    $preferred = @('jandedobbeleer', 'M365Princess', 'agnoster', 'spaceship', 'dracula')
    $script:AllPosh = @(
        $catalog | Sort-Object {
            $idx = [array]::IndexOf($preferred, $_.Id)
            if ($idx -ge 0) { '{0:D3}{1}' -f $idx, $_.Id } else { '9{0}' -f $_.Id }
        }
    )
    Write-Color "  Prompt themes ready: $($script:AllPosh.Count)" '#A6E3A1'
    return $script:AllPosh.Count
}

function ConvertTo-LogoId {
    param([string]$Name)
    ($Name.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
}

function Import-AllFastfetchLogos {
    $official = @()
    $seen = @{}
    $front = @()
    if (Test-CommandExists 'fastfetch') {
        Write-Color '  Reading every official Fastfetch logo' '#CBA6F7'
        Show-WhatIs -Name 'Fastfetch logos' -Plain 'All built-in Fastfetch pictures for the picker.' -Url $script:FastfetchRepoUrl
        $raw = @()
        try { $raw = @(fastfetch --list-logos 2>$null) } catch { $raw = @() }
        foreach ($line in $raw) {
            if ($line -notmatch '^\s*\d+\)') { continue }
            $matches = [regex]::Matches([string]$line, '"([^"]+)"')
            if ($matches.Count -eq 0) { continue }
            $name = $matches[0].Groups[1].Value
            $id = ConvertTo-LogoId $name
            if ([string]::IsNullOrWhiteSpace($id) -or $seen.ContainsKey($id)) { continue }
            $seen[$id] = $true
            $kind = 'builtin'
            $category = 'Official Fastfetch'
            if ($name -match 'small') { $category = 'Official Fastfetch (small)' }
            $entry = [pscustomobject]@{
                Id       = $id
                Category = $category
                Label    = $name
                Kind     = $kind
                Source   = $name
                Lines    = @("  $name")
            }
            if ($name -match '^(Windows 11|Windows11|Windows|Windows small|Windows_small)$') {
                $front += $entry
            } else {
                $official += $entry
            }
        }
        Write-Color "  Fastfetch logos found: $($seen.Count)" '#A6E3A1'
    } else {
        Write-Color '  Fastfetch is not on PATH yet. Using the built-in logo list.' '#F9E2AF'
    }

    $script:AllArts = $null
    $builtIn = @(Get-AsciiCatalog)
    $extras = @($builtIn | Where-Object { $_.Category -ne 'Official Fastfetch' })
    $auto = [pscustomobject]@{
        Id = 'windows-auto'; Category = 'Official Fastfetch'; Label = 'Auto (detect this PC)'; Kind = 'auto'; Source = ''; Lines = @('  Auto (detect this PC)')
    }
    $none = [pscustomobject]@{
        Id = 'none'; Category = 'Official Fastfetch'; Label = 'No logo (info only)'; Kind = 'none'; Source = ''; Lines = @('  (no logo)')
    }
    if ($official.Count -eq 0 -and $front.Count -eq 0) {
        $script:AllArts = @($builtIn)
    } else {
        $frontOrder = @('Windows 11', 'Windows11', 'Windows', 'Windows small', 'Windows_small')
        $frontSorted = @(
            $front | Sort-Object {
                $idx = [array]::IndexOf($frontOrder, $_.Label)
                if ($idx -ge 0) { $idx } else { 50 }
            }
        )
        $script:AllArts = @($frontSorted + @($auto, $none) + ($official | Sort-Object Label) + $extras)
    }
    foreach ($art in @($script:AllArts | Select-Object -First 6)) {
        if ($art.Kind -eq 'builtin' -or $art.Kind -eq 'small' -or $art.Kind -eq 'auto') {
            Ensure-ArtLines $art
        }
    }
    Write-Color "  Fastfetch list ready: $($script:AllArts.Count)" '#A6E3A1'
    return $script:AllArts.Count
}

function Strip-AnsiText {
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    $clean = [regex]::Replace($Text, "$([char]27)\[[0-9;?]*[A-Za-z]", '')
    $clean = [regex]::Replace($clean, "$([char]27)\][^\x07]*\x07", '')
    return $clean
}

function Test-PlaceholderArtLines {
    param($Art)
    if (-not $Art -or -not $Art.Lines) { return $true }
    $lines = @($Art.Lines)
    if ($lines.Count -eq 0) { return $true }
    if ($lines.Count -gt 2) { return $false }
    $joined = ($lines -join ' ').Trim()
    if ([string]::IsNullOrWhiteSpace($joined)) { return $true }
    foreach ($probe in @($Art.Label, $Art.Source, $Art.Id, "($($Art.Label))", '(no logo)')) {
        if ([string]::IsNullOrWhiteSpace($probe)) { continue }
        if ($joined -eq [string]$probe -or $joined -eq "  $probe") { return $true }
    }
    return $false
}

function Get-FastfetchLogoLines {
    param(
        [string]$Name,
        [string]$Kind = 'builtin'
    )
    $key = "$Kind|$Name"
    if ($script:LogoLineCache.ContainsKey($key)) {
        return $script:LogoLineCache[$key]
    }
    if (-not (Test-CommandExists 'fastfetch')) { return @() }

    $ffArgs = @('--config', 'none', '--structure', 'none', '--pipe')
    switch ($Kind) {
        'small' { $ffArgs += @('--logo-type', 'small') }
        'auto' { $ffArgs += @('--logo-type', 'auto') }
        'none' { return @() }
        default { $ffArgs += @('--logo-type', 'builtin') }
    }
    if (-not [string]::IsNullOrWhiteSpace($Name)) {
        $ffArgs += @('--logo', $Name)
    }

    $out = @()
    try { $out = @(& fastfetch @ffArgs 2>$null) } catch { $out = @() }
    $lines = @(
        $out | ForEach-Object { Strip-AnsiText $_ } | Select-Object -First 22
    )
    while ($lines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($lines[0])) {
        $lines = @($lines | Select-Object -Skip 1)
    }
    while ($lines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($lines[$lines.Count - 1])) {
        $lines = @($lines | Select-Object -First ($lines.Count - 1))
    }
    if ($lines.Count -gt 0) { $script:LogoLineCache[$key] = $lines }
    return $lines
}

function Ensure-ArtLines {
    param($Art)
    if (-not $Art) { return }
    if (-not (Test-PlaceholderArtLines $Art)) { return }

    $name = $null
    if ($Art.Source) { $name = [string]$Art.Source }
    elseif ($Art.Kind -eq 'auto') { $name = '' }
    elseif ($Art.Label) { $name = [string]$Art.Label }
    $kind = [string]$Art.Kind
    if ([string]::IsNullOrWhiteSpace($kind)) { $kind = 'builtin' }
    if ($kind -ne 'builtin' -and $kind -ne 'small' -and $kind -ne 'auto') { return }

    $lines = Get-FastfetchLogoLines -Name $name -Kind $kind
    if ($lines.Count -gt 0) {
        $Art.Lines = $lines
    }
}

function Get-ArtSnippet {
    param($Art)
    if (-not $Art) { return '' }
    $real = @($Art.Lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 2)
    if ($real.Count -eq 0 -or (Test-PlaceholderArtLines $Art)) {
        return 'click to see this picture'
    }
    $snip = ($real -join '  ').Trim()
    $snip = [regex]::Replace($snip, '\s+', ' ')
    if ($snip.Length -gt 42) { $snip = $snip.Substring(0, 40) + '…' }
    return $snip
}

function Get-ArtPreviewText {
    param($Art)
    return (Get-FastfetchFullPreview -Art $Art)
}

function Get-FastfetchFullPreview {
    param($Art)
    if (-not $Art) { return '  Fastfetch will show here.' }
    $key = 'full|{0}|{1}|{2}' -f $Art.Kind, $Art.Id, $Art.Source
    if ($script:FetchPreviewCache -and $script:FetchPreviewCache.ContainsKey($key)) {
        return $script:FetchPreviewCache[$key]
    }
    if (-not $script:FetchPreviewCache) { $script:FetchPreviewCache = @{} }

    $text = $null
    if (Test-CommandExists 'fastfetch') {
        $ffArgs = @('--config', 'none', '--pipe')
        $kind = [string]$Art.Kind
        $name = if ($Art.Source) { [string]$Art.Source } else { [string]$Art.Label }
        if ($Art.Id -eq 'none' -or $kind -eq 'none') {
            $ffArgs += @('--logo', 'none')
        } elseif ($kind -eq 'auto') {
            $ffArgs += @('--logo-type', 'auto')
        } elseif ($kind -eq 'small') {
            $ffArgs += @('--logo-type', 'small')
            if ($name) { $ffArgs += @('--logo', $name) }
        } elseif ($kind -eq 'builtin' -and $name) {
            $ffArgs += @('--logo-type', 'builtin', '--logo', $name)
        } else {
            Ensure-ArtLines $Art
            $tmp = Join-Path $env:TEMP 'better-terminal-preview-logo.txt'
            $logoText = ((@($Art.Lines) -join "`n") + "`n")
            Write-Utf8NoBom -Path $tmp -Text $logoText
            $ffArgs += @('--file', $tmp)
        }
        $out = @()
        try { $out = @(& fastfetch @ffArgs 2>$null) } catch { $out = @() }
        $lines = @($out | ForEach-Object { Strip-AnsiText $_ })
        while ($lines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($lines[$lines.Count - 1])) {
            $lines = @($lines | Select-Object -First ($lines.Count - 1))
        }
        if ($lines.Count -gt 0) { $text = $lines -join [Environment]::NewLine }
    }

    if ([string]::IsNullOrWhiteSpace($text)) {
        Ensure-ArtLines $Art
        $hw = Get-StudioHardwareInfo
        $info = @(
            "$($env:USERNAME)@$($env:COMPUTERNAME)"
            "OS        $($hw.OS)"
            "CPU       $($hw.CPU)"
            "GPU       $($hw.GPU)"
            "Memory    $($hw.Memory)"
            "Disk      $($hw.Disk)"
        )
        $artLines = @($Art.Lines)
        if ($Art.Id -eq 'none' -or $Art.Kind -eq 'none') { $artLines = @() }
        $text = (@($artLines) + @('') + $info) -join [Environment]::NewLine
    }

    $script:FetchPreviewCache[$key] = $text
    return $text
}

function Get-PreferredCatalogItem {
    param($Items, [string[]]$Names, [string]$Property = 'name')
    foreach ($want in $Names) {
        $hit = @($Items | Where-Object { [string]$_.$Property -eq $want } | Select-Object -First 1)
        if ($hit.Count -gt 0 -and $hit[0]) { return $hit[0] }
    }
    if ($Items -and $Items.Count -gt 0) { return $Items[0] }
    return $null
}

function Invoke-DownloadEverything {
    param($Plan)

    Clear-ScreenSoft
    Show-Banner -Title 'Downloading everything first'
    Write-Color '  Tools and full lists download now. The picker opens after this.' '#C0CAF5'
    Write-Host ""
    $failed = @()
    $oldProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    } catch {}

    try {
        if ($Plan.InstallOhMyPosh) {
            if (-not (Install-OhMyPoshPackage)) { $failed += 'Oh My Posh' }
            Write-Host ""
        }
        if ($Plan.InstallFastfetch) {
            if (-not (Install-FastfetchPackage)) { $failed += 'Fastfetch' }
            Write-Host ""
        }
        if ($Plan.InstallTerminalIcons -ne $false) {
            if (-not (Install-TerminalIconsPackage)) { $failed += 'Terminal-Icons' }
            Write-Host ""
        }

        [void](Import-AllNerdFonts)
        Write-Host ""
        if ($Plan.InstallFont) {
            $meslo = Get-PreferredCatalogItem -Items (Get-FontCatalog) -Names @('Meslo') -Property 'Id'
            if ($meslo) {
                if (Test-FontInstalled $meslo) {
                    Write-Color '  Meslo is already installed.' '#A6E3A1'
                } elseif (-not (Install-NerdFontPackage -Font $meslo)) {
                    $failed += 'Nerd Font'
                }
                $script:InstalledFontMap = $null
                $script:TypefaceCache = @{}
            }
            Write-Host ""
        }

        [void](Import-AllColorThemes)
        Write-Host ""
        [void](Import-AllPoshThemes)
        Write-Host ""
        [void](Import-AllFastfetchLogos)
        Write-Host ""
        Write-Color '  All lists are ready. Opening the picker...' '#A6E3A1'
    } finally {
        $ProgressPreference = $oldProgress
    }
    Start-Sleep -Seconds 1
    return $failed
}

function Find-PoshThemeFile {
    param($Posh)
    if (-not $Posh) { return $null }
    if ($Posh.ThemePath -and (Test-Path $Posh.ThemePath)) { return $Posh.ThemePath }
    $name = "$($Posh.Id).omp.json"
    $cache = Join-Path (Get-CatalogRoot) 'posh-themes'
    $candidate = Join-Path $cache $name
    if (Test-Path $candidate) { return $candidate }
    $dir = Get-PoshThemesDirectory
    if ($dir) {
        $candidate = Join-Path $dir $name
        if (Test-Path $candidate) { return $candidate }
    }
    return $null
}

# -----------------------------------------------------------------------------
# Installers
# -----------------------------------------------------------------------------

function Install-OhMyPoshPackage {
    Write-Color '  Downloading the prettier prompt (Oh My Posh)' '#CBA6F7'
    Show-WhatIs -Name 'Oh My Posh' -Plain 'This is the colored line you type commands on.' -Url $script:OhMyPoshSiteUrl

    if (Test-CommandExists 'oh-my-posh') {
        Write-Color '  Oh My Posh is already on PATH.' '#A6E3A1'
        return $true
    }

    $ok = Invoke-WingetInstall -PackageId 'JanDeDobbeleer.OhMyPosh' -DisplayName 'Oh My Posh'
    Update-SessionPath
    if (Test-CommandExists 'oh-my-posh') { return $true }

    Write-Color '  The first download method did not finish. Trying the official website next...' '#F9E2AF'
    Write-Color "  From: $script:OhMyPoshInstallUrl" '#89B4FA'
    try {
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString($script:OhMyPoshInstallUrl))
        Update-SessionPath
    } catch {
        Write-Color "  Official installer failed: $($_.Exception.Message)" '#F38BA8'
        return $false
    }
    return (Test-CommandExists 'oh-my-posh')
}

function Install-NerdFontPackage {
    param($Font)
    if (-not $Font) { return $false }

    $zipName = if ($Font.Zip) { [string]$Font.Zip } else { "$($Font.Id).zip" }
    $zipUrl = "$script:NerdFontsReleaseUrl/$script:NerdFontsVersion/$zipName"
    Write-Color "  Downloading the $($Font.Label) font from Nerd Fonts" '#CBA6F7'
    Show-WhatIs -Name $Font.Label -Plain 'Official Nerd Font files for icons in the prompt and file list.' -Url $zipUrl

    $tempRoot = Join-Path $env:TEMP 'better-terminal-fonts'
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    $zipPath = Join-Path $tempRoot $zipName
    $extract = Join-Path $tempRoot $Font.Id

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Write-Color "  From: $zipUrl" '#89B4FA'
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing -TimeoutSec 120
        if (Test-Path $extract) { Remove-Item $extract -Recurse -Force }
        Expand-Archive -Path $zipPath -DestinationPath $extract -Force
    } catch {
        Write-Color "  Font download failed: $($_.Exception.Message)" '#F38BA8'
        if (Test-CommandExists 'oh-my-posh') {
            Write-Color '  Trying oh-my-posh font install next...' '#F9E2AF'
            try {
                & oh-my-posh font install $Font.OmpName
                if ($LASTEXITCODE -eq 0) { return $true }
            } catch {}
        }
        return $false
    }

    $fontFiles = @(
        Get-ChildItem -Path $extract -Recurse -Include *.ttf, *.otf |
            Where-Object { $_.Name -notmatch 'Windows Compatible' }
    )
    if ($fontFiles.Count -eq 0) {
        $fontFiles = @(Get-ChildItem -Path $extract -Recurse -Include *.ttf, *.otf)
    }

    $userFontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    New-Item -ItemType Directory -Force -Path $userFontDir | Out-Null
    $regPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'

    if (-not ([System.Management.Automation.PSTypeName]'BetterTerminalFonts').Type) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class BetterTerminalFonts {
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode)]
    public static extern int AddFontResourceW(string f);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam, uint fuFlags, uint uTimeout, out IntPtr lpdwResult);
}
'@
    }

    $installed = 0
    foreach ($file in $fontFiles) {
        $dest = Join-Path $userFontDir $file.Name
        Copy-Item $file.FullName $dest -Force
        $display = [IO.Path]::GetFileNameWithoutExtension($file.Name)
        New-ItemProperty -Path $regPath -Name "$display (TrueType)" -Value $dest -PropertyType String -Force | Out-Null
        try { [void][BetterTerminalFonts]::AddFontResourceW($dest) } catch {}
        $installed++
    }
    try {
        $ignored = [IntPtr]::Zero
        [void][BetterTerminalFonts]::SendMessageTimeout([IntPtr]0xFFFF, 0x001D, [IntPtr]::Zero, [IntPtr]::Zero, 2, 1000, [ref]$ignored)
    } catch {}

    Write-Color "  Installed $installed font file(s) from $zipUrl" '#A6E3A1'
    $script:InstalledFontMap = $null
    Sync-InstalledFontFace $Font
    if (-not (Test-FontInstalled $Font)) {
        $hint = $fontFiles | Where-Object { $_.Name -match 'NerdFont(Mono)?-Regular\.(ttf|otf)$' } | Select-Object -First 1
        if ($hint) {
            $base = $hint.BaseName -replace '-Regular$', ''
            $guesses = @(
                ($base -replace 'NerdFontMono', ' Nerd Font Mono' -replace 'NerdFont', ' Nerd Font').Trim()
                ($base -replace 'NerdFontMono$', ' NFM' -replace 'NerdFontPropo$', ' NFP' -replace 'NerdFont$', ' NF').Trim()
            )
            $map = Get-InstalledFontMap
            $found = Find-InstalledFamily -Map $map -Names $guesses
            if ($found) { $Font.Face = $found.Name }
        }
    }
    return ($installed -gt 0)
}

function Install-FastfetchPackage {
    Write-Color '  Downloading the startup picture tool (Fastfetch)' '#CBA6F7'
    Show-WhatIs -Name 'Fastfetch' -Plain 'This shows a small picture of your PC when the terminal opens.' -Url $script:FastfetchRepoUrl

    if (Test-CommandExists 'fastfetch') {
        Write-Color '  Fastfetch is already on PATH.' '#A6E3A1'
        return $true
    }

    $ok = Invoke-WingetInstall -PackageId 'Fastfetch-cli.Fastfetch' -DisplayName 'Fastfetch'
    Update-SessionPath
    if (Test-CommandExists 'fastfetch') { return $true }

    Write-Color '  Trying a direct download from GitHub instead...' '#F9E2AF'
    try {
        $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest' -Headers @{ 'User-Agent' = 'BetterTerminalSetup' }
        $asset = $release.assets | Where-Object { $_.name -match 'windows-amd64\.zip$' } | Select-Object -First 1
        if (-not $asset) {
            Write-Color '  No windows-amd64 zip found on the latest release.' '#F38BA8'
            return $false
        }
        Write-Color "  From: $($asset.browser_download_url)" '#89B4FA'
        $temp = Join-Path $env:TEMP 'better-terminal-fastfetch'
        New-Item -ItemType Directory -Force -Path $temp | Out-Null
        $zip = Join-Path $temp $asset.name
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -UseBasicParsing
        $extract = Join-Path $temp 'extracted'
        if (Test-Path $extract) { Remove-Item $extract -Recurse -Force }
        Expand-Archive -Path $zip -DestinationPath $extract -Force
        $exe = Get-ChildItem -Path $extract -Recurse -Filter 'fastfetch.exe' | Select-Object -First 1
        if (-not $exe) { throw 'fastfetch.exe missing from the archive.' }
        $destDir = Join-Path $env:LOCALAPPDATA 'Programs\fastfetch'
        New-Item -ItemType Directory -Force -Path $destDir | Out-Null
        Copy-Item $exe.FullName (Join-Path $destDir 'fastfetch.exe') -Force
        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
        if ($userPath -notlike "*$destDir*") {
            [Environment]::SetEnvironmentVariable('Path', "$userPath;$destDir", 'User')
        }
        Update-SessionPath
        Write-Color "  Fastfetch $($release.tag_name) installed to $destDir" '#A6E3A1'
        return $true
    } catch {
        Write-Color "  Fastfetch install failed: $($_.Exception.Message)" '#F38BA8'
        return $false
    }
}

function Install-TerminalIconsPackage {
    Write-Color '  Downloading file and folder icons (Terminal-Icons)' '#CBA6F7'
    Show-WhatIs -Name 'Terminal-Icons' -Plain 'Shows icons next to files and folders when you list a directory.' -Url $script:TerminalIconsUrl
    Write-Color "  From: $script:TerminalIconsGallery" '#89B4FA'

    if (Get-Module -ListAvailable -Name Terminal-Icons -ErrorAction SilentlyContinue) {
        Write-Color '  Terminal-Icons is already installed.' '#A6E3A1'
        return $true
    }

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $nuget = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
        if (-not $nuget) {
            Write-Color '  Installing the NuGet package provider (needed for PowerShell Gallery)...' '#89B4FA'
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser -ErrorAction Stop | Out-Null
        }
        Install-Module -Name Terminal-Icons -Repository PSGallery -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck -ErrorAction Stop
        if (Get-Module -ListAvailable -Name Terminal-Icons -ErrorAction SilentlyContinue) {
            Write-Color '  Terminal-Icons installed from the PowerShell Gallery.' '#A6E3A1'
            return $true
        }
    } catch {
        Write-Color "  Terminal-Icons install failed: $($_.Exception.Message)" '#F38BA8'
        return $false
    }
    return $false
}

# -----------------------------------------------------------------------------
# Apply configuration
# -----------------------------------------------------------------------------

function Backup-File {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backup = "$Path.bak.$stamp"
    Copy-Item $Path $backup -Force
    Write-Color "  Backup: $backup" '#A9B1D6'
    return $backup
}

function Set-WtAppearanceMembers {
    param($Target, $State)
    if (-not $Target) { return }
    if ($State.Theme) {
        $Target | Add-Member -NotePropertyName colorScheme -NotePropertyValue ([string]$State.Theme.name) -Force
    }
    $usableFace = Get-UsableFontFace $State.Font
    if ($usableFace) {
        $Target | Add-Member -NotePropertyName font -NotePropertyValue ([pscustomobject]@{ face = $usableFace }) -Force
    }
    if ($State.ApplyTransparency) {
        $Target | Add-Member -NotePropertyName opacity -NotePropertyValue ([int]$State.Opacity) -Force
        $Target | Add-Member -NotePropertyName useAcrylic -NotePropertyValue ([bool]$State.UseAcrylic) -Force
    }
}

function Set-WindowsTerminalLook {
    param(
        $State,
        [switch]$Quiet,
        [switch]$NoBackup
    )

    $settingsPath = Get-WindowsTerminalSettingsPath
    $settingsDir = Split-Path $settingsPath -Parent
    New-Item -ItemType Directory -Force -Path $settingsDir | Out-Null

    if (Test-Path $settingsPath) {
        if (-not $NoBackup) { Backup-File $settingsPath | Out-Null }
        $raw = Get-Content -Path $settingsPath -Raw -Encoding UTF8
        try {
            $settings = ConvertFrom-Jsonc $raw
        } catch {
            Write-Color '  Could not parse settings.json. Opening the file so you can apply the theme by hand.' '#F38BA8'
            Start-Process $settingsPath
            return $false
        }
    } else {
        $settings = [pscustomobject]@{
            '$help'   = 'https://aka.ms/terminal-documentation'
            '$schema' = 'https://aka.ms/terminal-profiles-schema'
            profiles  = [pscustomobject]@{
                defaults = [pscustomobject]@{}
                list     = @()
            }
            schemes   = @()
        }
    }

    if (-not $settings.profiles) {
        $settings | Add-Member -NotePropertyName profiles -NotePropertyValue ([pscustomobject]@{ defaults = [pscustomobject]@{}; list = @() }) -Force
    }
    if ($settings.profiles -is [System.Array]) {
        Write-Color '  Your settings.json uses an older profiles array. Defaults will be added carefully.' '#F9E2AF'
        foreach ($p in @($settings.profiles)) { Set-WtAppearanceMembers -Target $p -State $State }
    } else {
        if (-not $settings.profiles.defaults) {
            $settings.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{}) -Force
        }
        Set-WtAppearanceMembers -Target $settings.profiles.defaults -State $State
        if ($settings.profiles.list) {
            $updated = @()
            foreach ($p in @($settings.profiles.list)) {
                Set-WtAppearanceMembers -Target $p -State $State
                $updated += $p
            }
            $settings.profiles | Add-Member -NotePropertyName list -NotePropertyValue $updated -Force
        }
    }

    if ($State.Theme) {
        $scheme = Convert-ToTerminalScheme $State.Theme
        $existing = @()
        if ($settings.schemes) { $existing = @($settings.schemes) }
        $filtered = @($existing | Where-Object { $_.name -ne $scheme.name })
        $settings | Add-Member -NotePropertyName schemes -NotePropertyValue (@($filtered + $scheme)) -Force
    }

    $json = $settings | ConvertTo-Json -Depth 40
    Write-Utf8NoBom -Path $settingsPath -Text $json
    if (-not $Quiet) {
        Write-Color "  Windows Terminal settings updated: $settingsPath" '#A6E3A1'
    }
    return $true
}

function Set-FastfetchLook {
    param($State)

    $configDir = Join-Path $env:USERPROFILE '.config\fastfetch'
    New-Item -ItemType Directory -Force -Path $configDir | Out-Null
    $logoPath = Join-Path $configDir 'logo.txt'
    $configPath = Join-Path $configDir 'config.jsonc'

    $logoType = 'auto'
    $logoSource = $null
    if ($State.Art) {
        if ($State.Art.Kind -eq 'none' -or $State.Art.Id -eq 'none') {
            $logoType = 'none'
        } elseif ($State.Art.Kind -eq 'auto') {
            $logoType = 'auto'
        } elseif ($State.Art.Kind -eq 'small') {
            $logoType = 'small'
            $logoSource = if ($State.Art.Source) { [string]$State.Art.Source } else { 'Windows' }
        } elseif ($State.Art.Kind -eq 'builtin' -and $State.Art.Source) {
            $logoType = 'builtin'
            $logoSource = [string]$State.Art.Source
        } elseif ($State.Art.Lines) {
            Ensure-ArtLines $State.Art
            $logoText = ((@($State.Art.Lines) -join "`n") + "`n")
            Write-Utf8NoBom -Path $logoPath -Text $logoText
            $logoType = 'file'
            $logoSource = $logoPath.Replace('\', '/')
        }
    }

    $logoJson = if ($logoType -eq 'none') {
        @"
    "logo": {
        "type": "none"
    },
"@
    } elseif (($logoType -eq 'builtin' -or $logoType -eq 'small') -and $logoSource) {
        $safe = $logoSource.Replace('\', '\\').Replace('"', '\"')
        @"
    "logo": {
        "type": "$logoType",
        "source": "$safe"
    },
"@
    } elseif ($logoType -eq 'file' -and $logoSource) {
        @"
    "logo": {
        "type": "file",
        "source": "$logoSource",
        "color": { "1": "cyan", "2": "blue", "3": "magenta" }
    },
"@
    } else {
        @"
    "logo": {
        "type": "auto"
    },
"@
    }

    $jsonc = @"
{
    "`$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
$logoJson
    "display": {
        "separator": "  "
    },
    "modules": [
        "title",
        "separator",
        "os",
        "host",
        "kernel",
        "uptime",
        "shell",
        "terminal",
        "cpu",
        "gpu",
        "memory",
        "disk",
        "break",
        "colors"
    ]
}
"@
    Write-Utf8NoBom -Path $configPath -Text $jsonc
    Write-Color "  Fastfetch config written: $configPath" '#A6E3A1'
}

function Get-PowerShellProfilePaths {
    $docs = [Environment]::GetFolderPath('MyDocuments')
    $paths = @(
        $PROFILE,
        (Join-Path $docs 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1'),
        (Join-Path $docs 'WindowsPowerShell\Microsoft.VSCode_profile.ps1'),
        (Join-Path $docs 'PowerShell\Microsoft.PowerShell_profile.ps1'),
        (Join-Path $docs 'PowerShell\Microsoft.VSCode_profile.ps1')
    )
    $paths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
}

function Set-CursorTerminalFont {
    param($Font)
    $face = Get-UsableFontFace $Font
    $path = Join-Path $env:APPDATA 'Cursor\User\settings.json'
    if (-not (Test-Path $path)) { return }
    try {
        $raw = Get-Content -Path $path -Raw -Encoding UTF8
        $json = $raw | ConvertFrom-Json
        if (-not $face) {
            if ($json.PSObject.Properties.Name -contains 'terminal.integrated.fontFamily') {
                $json.PSObject.Properties.Remove('terminal.integrated.fontFamily')
                Write-Utf8NoBom -Path $path -Text ($json | ConvertTo-Json -Depth 40)
            }
            return
        }
        $json | Add-Member -NotePropertyName 'terminal.integrated.fontFamily' -NotePropertyValue $face -Force
        Write-Utf8NoBom -Path $path -Text ($json | ConvertTo-Json -Depth 40)
        Write-Color '  Cursor terminal font saved. Open a new Cursor terminal to see it.' '#A6E3A1'
    } catch {
        Write-Color "  Could not update Cursor font: $($_.Exception.Message)" '#F9E2AF'
    }
}

function Set-PowerShellProfileLook {
    param($State)

    $poshLine = ''
    if ($State.InstallOhMyPosh -and $State.Posh) {
        $themeFile = Find-PoshThemeFile -Posh $State.Posh
        if ($themeFile) {
            $safe = $themeFile.Replace("'", "''")
            $poshLine = "oh-my-posh init pwsh --config '$safe' | Invoke-Expression"
        } else {
            $poshLine = "oh-my-posh init pwsh --config '$($State.Posh.Id)' | Invoke-Expression"
        }
    }

    $fastfetchLine = ''
    if ($State.InstallFastfetch) {
        $fastfetchLine = @'
if ($Host.Name -eq 'ConsoleHost') {
    if (Get-Command fastfetch -ErrorAction SilentlyContinue) { fastfetch }
}
'@
    }

    $iconsLine = @'
try { Import-Module Terminal-Icons -ErrorAction SilentlyContinue } catch {}
'@

    $block = @"

#region Better Terminal Setup
# Generated by Install-BetterTerminal.ps1
# Prompt docs: $script:OhMyPoshSiteUrl

if (`$Host.Name -eq 'ConsoleHost') {
    try {
        Import-Module PSReadLine -ErrorAction SilentlyContinue
        Set-PSReadLineOption -EditMode Windows
        Set-PSReadLineOption -PredictionSource History
        Set-PSReadLineOption -HistorySearchCursorMovesToEnd
        if (`$PSVersionTable.PSVersion.Major -ge 7) {
            Set-PSReadLineOption -PredictionViewStyle ListView
        }
        Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
        Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
        Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    } catch {}
}

function ll { Get-ChildItem -Force @args }
function la { Get-ChildItem -Force -Hidden @args }
function .. { Set-Location .. }
function ... { Set-Location ..\.. }
Set-Alias grep Select-String -ErrorAction SilentlyContinue
Set-Alias which Get-Command -ErrorAction SilentlyContinue

$poshLine

$iconsLine

$fastfetchLine
#endregion Better Terminal Setup
"@

    foreach ($profilePath in @(Get-PowerShellProfilePaths)) {
        $dir = Split-Path $profilePath -Parent
        if ($dir -and -not (Test-Path $dir)) {
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
        }
        if (-not (Test-Path $profilePath)) {
            New-Item -Path $profilePath -ItemType File -Force | Out-Null
        } else {
            Backup-File $profilePath | Out-Null
        }

        $existing = Get-Content -Path $profilePath -Raw -ErrorAction SilentlyContinue
        if ($null -eq $existing) { $existing = '' }
        $existing = [regex]::Replace($existing, '(?s)#region Better Terminal Setup.*?#endregion Better Terminal Setup\r?\n?', '')
        $existing = [regex]::Replace($existing, '(?m)^oh-my-posh init .+\r?\n?', '')
        $existing = [regex]::Replace($existing, '(?m)^(\s*fastfetch --config \$eagleFastfetchConfig.*)$', '# Better Terminal now draws Fastfetch. Old line: $1')

        Set-Content -Path $profilePath -Value ($existing.TrimEnd() + $block) -Encoding UTF8
        Write-Color "  PowerShell profile updated: $profilePath" '#A6E3A1'
    }
}

# -----------------------------------------------------------------------------
# Interactive screens
# -----------------------------------------------------------------------------

function Show-WelcomeScreen {
    Clear-ScreenSoft
    Show-Banner -Title 'Better Terminal Setup' -Step 1 -Total 3
    Write-Color '  Type Y to download everything first.' '#C0CAF5'
    Write-Color '  Then a window opens with every color theme, prompt, Fastfetch logo, and font.' '#C0CAF5'
    Write-Host ""
    Write-Color '  This download includes:' '#CBA6F7'
    Write-Host ""
    Write-Color '    1. All color themes           (windowsterminalthemes.dev)' '#A6E3A1'
    Write-Color '    2. All Oh My Posh prompts     (ohmyposh.dev/docs/themes)' '#A6E3A1'
    Write-Color '    3. Fastfetch and all logos    (github.com/fastfetch-cli/fastfetch)' '#A6E3A1'
    Write-Color '    4. The full Nerd Fonts list   (nerdfonts.com) + Meslo' '#A6E3A1'
    Write-Color '    5. File and folder icons      (Terminal-Icons)' '#A6E3A1'
    Write-Host ""
    Write-Color '  Type Y and press Enter to download all of it, then pick your look.' '#F9E2AF'
    Write-Color '  Type O if you want to say yes or no to each tool.' '#89B4FA'
    Write-Color '  Type Q to quit. Nothing will change.' '#F38BA8'
    Write-Host ""
}

function Get-InstallPlan {
    $plan = [pscustomobject]@{
        InstallOhMyPosh     = $true
        InstallFont         = $true
        InstallFastfetch    = $true
        ApplyTheme          = $true
        ApplyTransparency   = $true
        ApplyAscii          = $true
        ApplyBetterCli      = $true
        InstallTerminalIcons = $true
        Theme               = $null
        Font                = $null
        Art                 = $null
        Posh                = $null
        Opacity             = 80
        UseAcrylic          = $true
    }

    Show-WelcomeScreen
    $mode = Read-Choice -Prompt 'Type Y, O, or Q' -Default 'Y'

    if ($mode -match '^[Qq]') { return $null }

    if ($mode -match '^[Oo]') {
        Clear-ScreenSoft
        Show-Banner -Title 'Choose what to add' -Step 1 -Total 6
        Write-Color '  Answer Y or N for each one. Press Enter to accept the default (Y).' '#C0CAF5'
        Write-Host ""

        Show-WhatIs -Name 'Oh My Posh' -Plain 'Makes the line you type in look nicer (folder, git, time).' -Url $script:OhMyPoshSiteUrl
        $plan.InstallOhMyPosh = Read-YesNo -Prompt 'Add the prettier prompt?' -Default 'Y'
        Write-Host ""

        Show-WhatIs -Name 'Nerd Font' -Plain 'A font that can show the little icons in that prompt.' -Url $script:NerdFontsSiteUrl
        $plan.InstallFont = Read-YesNo -Prompt 'Add a font with icons?' -Default 'Y'
        Write-Host ""

        Show-WhatIs -Name 'Fastfetch' -Plain 'Shows a small picture of your PC when you open the terminal.' -Url $script:FastfetchRepoUrl
        $plan.InstallFastfetch = Read-YesNo -Prompt 'Add the startup picture?' -Default 'Y'
        Write-Host ""

        Write-Color '  After the download, you still pick colors, prompt, Fastfetch, and transparency in the window.' '#CBA6F7'
        Write-Host ""
        $plan.ApplyTheme = Read-YesNo -Prompt 'Change the terminal colors?' -Default 'Y'
        $plan.ApplyTransparency = Read-YesNo -Prompt 'Add window transparency?' -Default 'Y'
        $plan.ApplyAscii = Read-YesNo -Prompt 'Pick a text picture for Fastfetch?' -Default 'Y'
        $plan.ApplyBetterCli = Read-YesNo -Prompt 'Make typing and history nicer?' -Default 'Y'
    }

    return $plan
}

function Select-FromPagedList {
    param(
        [string]$Title,
        [object[]]$Items,
        [scriptblock]$Labeler,
        [int]$PageSize = 8,
        [scriptblock]$OnPreview,
        [int]$Step = 2
    )

    $page = 0
    $filter = ''
    while ($true) {
        $visible = $Items
        if ($filter) {
            $visible = @($Items | Where-Object { (& $Labeler $_) -like "*$filter*" })
        }
        $pages = [Math]::Max(1, [Math]::Ceiling($visible.Count / $PageSize))
        if ($page -ge $pages) { $page = $pages - 1 }

        Clear-ScreenSoft
        Show-Banner -Title $Title -Step $Step -Total 6
        if ($OnPreview) { & $OnPreview }

        $start = $page * $PageSize
        Write-Host ""
        Write-Color ("  Page $($page + 1) of $pages   ($($visible.Count) themes)") '#6C7086'
        Write-Host ""
        for ($i = 0; $i -lt $PageSize; $i++) {
            $idx = $start + $i
            if ($idx -ge $visible.Count) { break }
            $num = $i + 1
            Write-Color ("    $num) " + (& $Labeler $visible[$idx])) '#C0CAF5'
        }
        Write-Host ""
        Write-Color '  Type a number to preview that theme.' '#F9E2AF'
        Write-Color '  Or type:  N = next page   B = search more themes online' '#89B4FA'
        $choice = Read-Choice -Prompt 'Number, N, or B' -Default '1'

        if ($choice -match '^[Nn]') { $page = ($page + 1) % $pages; continue }
        if ($choice -match '^[Pp]') { $page = ($page - 1 + $pages) % $pages; continue }
        if ($choice -match '^[Ss]') {
            $filter = Read-Choice -Prompt 'Type part of a name to search' -Default ''
            $page = 0
            continue
        }
        if ($choice -match '^[BbMm]') { return '__BROWSE__' }
        if ($choice -eq '0') { return $null }
        if ($choice -match '^\d+$') {
            $n = [int]$choice
            if ($n -ge 1 -and $n -le $PageSize) {
                $idx = $start + $n - 1
                if ($idx -lt $visible.Count) { return $visible[$idx] }
            }
        }
    }
}

function Select-ColorTheme {
    param($Plan)

    $builtIn = @(Get-BuiltInThemes | ForEach-Object { New-ThemeObject $_ })
    $current = $builtIn[0]

    while ($true) {
        $picked = Select-FromPagedList -Title 'Pick your colors' -Items $builtIn -PageSize 8 -Step 2 -Labeler {
            param($t) $t.name
        } -OnPreview {
            Write-Color '  This is a preview. Pick a number below to try another look.' '#A9B1D6'
            Write-Host ""
            Write-PreviewWindow -Theme $current -Art $Plan.Art -Font $Plan.Font -Posh $Plan.Posh -Opacity $Plan.Opacity
        }

        if ($picked -eq '__BROWSE__') {
            $names = Get-RemoteThemeNames
            if (-not $names -or $names.Count -eq 0) {
                Write-Color '  Could not load more themes. Use the list on this screen instead.' '#F38BA8'
                Wait-Continue
                continue
            }
            $query = Read-Choice -Prompt 'Type a word to search (example: tokyo, rose, mocha)' -Default 'tokyo'
            $hits = @($names | Where-Object { $_ -like "*$query*" } | Select-Object -First 20)
            if ($hits.Count -eq 0) {
                Write-Color '  No themes matched. Try a shorter word.' '#F38BA8'
                Wait-Continue
                continue
            }
            Write-Host ""
            Write-Color '  Matching themes:' '#CBA6F7'
            for ($i = 0; $i -lt $hits.Count; $i++) {
                Write-Color ("    {0}) {1}" -f ($i + 1), $hits[$i]) '#C0CAF5'
            }
            $n = Read-Choice -Prompt 'Type the number you want' -Default '1'
            if ($n -match '^\d+$' -and [int]$n -ge 1 -and [int]$n -le $hits.Count) {
                $remote = Get-ThemeFromWeb $hits[[int]$n - 1]
                if ($remote) { $picked = $remote } else { continue }
            } else {
                continue
            }
        }

        if (-not $picked) { return $current }

        Clear-ScreenSoft
        Show-Banner -Title 'Do you like these colors?' -Step 2 -Total 6
        Write-PreviewWindow -Theme $picked -Art $Plan.Art -Font $Plan.Font -Posh $Plan.Posh -Opacity $Plan.Opacity
        Write-Host ""
        Write-Color '  Type Y to keep this look, or N to go back and pick another.' '#F9E2AF'
        if (Read-YesNo -Prompt 'Keep these colors?' -Default 'Y') { return $picked }
        $current = $picked
    }
}

function Select-FontChoice {
    param($Plan)
    $fonts = Get-FontCatalog
    $picked = $null
    while (-not $picked) {
        Clear-ScreenSoft
        Show-Banner -Title 'Pick a font' -Step 3 -Total 6
        Write-Color '  A Nerd Font lets the prompt show little icons.' '#C0CAF5'
        Write-Color "  Download site: $script:NerdFontsSiteUrl" '#6C7086'
        Write-Host ""
        Write-Color '  Not sure? Press Enter to use Meslo (number 1).' '#F9E2AF'
        Write-Host ""
        for ($i = 0; $i -lt $fonts.Count; $i++) {
            $f = $fonts[$i]
            $mark = if ($i -eq 0) { '  <- recommended' } else { '' }
            Write-Color ("    {0,2}) {1}{2}" -f ($i + 1), $f.Label, $mark) '#C0CAF5'
            Write-Color ("        $($f.Note)") '#A9B1D6'
        }
        Write-Host ""
        $n = Read-Choice -Prompt 'Type a font number' -Default '1'
        if ($n -match '^\d+$' -and [int]$n -ge 1 -and [int]$n -le $fonts.Count) {
            $picked = $fonts[[int]$n - 1]
        }
    }

    Clear-ScreenSoft
    Show-Banner -Title 'Your font' -Step 3 -Total 6
    Write-Color "  You picked: $($picked.Label)" '#A6E3A1'
    Write-Color '  The font will switch after you open a new terminal window.' '#F9E2AF'
    Write-Host ""
    if ($Plan.Theme) {
        Write-PreviewWindow -Theme $Plan.Theme -Art $Plan.Art -Font $picked -Posh $Plan.Posh -Opacity $Plan.Opacity
    }
    Wait-Continue
    return $picked
}

function Select-ArtChoice {
    param($Plan)
    $arts = Get-AsciiCatalog
    $picked = $null
    while (-not $picked) {
        Clear-ScreenSoft
        Show-Banner -Title 'Pick a Fastfetch logo' -Step 4 -Total 6
        Write-Color '  Fastfetch shows this logo and your PC info when the terminal opens.' '#C0CAF5'
        Write-Color "  Ideas from: $script:AsciiGalleryUrl" '#6C7086'
        Write-Host ""
        for ($i = 0; $i -lt $arts.Count; $i++) {
            $a = $arts[$i]
            Write-Color ("    {0,2}) {1,-20}  {2}" -f ($i + 1), $a.Label, $a.Category) '#C0CAF5'
        }
        Write-Host ""
        $n = Read-Choice -Prompt 'Type a picture number' -Default '1'
        if ($n -match '^\d+$' -and [int]$n -ge 1 -and [int]$n -le $arts.Count) {
            $picked = $arts[[int]$n - 1]
        }
    }

    Clear-ScreenSoft
    Show-Banner -Title 'Picture preview' -Step 4 -Total 6
    Write-Color "  $($picked.Label)" '#C0CAF5'
    Write-Host ""
    if ($Plan.Theme) {
        Write-PreviewWindow -Theme $Plan.Theme -Art $picked -Font $Plan.Font -Posh $Plan.Posh -Opacity $Plan.Opacity
    } else {
        foreach ($line in $picked.Lines) { Write-Color ('    ' + $line) '#94E2D5' }
    }
    Write-Host ""
    if (-not (Read-YesNo -Prompt 'Keep this picture?' -Default 'Y')) {
        return (Select-ArtChoice -Plan $Plan)
    }
    return $picked
}

function Select-PoshChoice {
    param($Plan)
    $items = Get-PoshCatalog
    $picked = $null
    while (-not $picked) {
        Clear-ScreenSoft
        Show-Banner -Title 'Pick your prompt style' -Step 5 -Total 6
        Write-Color '  This is the line you type commands on.' '#C0CAF5'
        Write-Color '  Not sure? Press Enter to use number 1.' '#F9E2AF'
        Write-Host ""
        for ($i = 0; $i -lt $items.Count; $i++) {
            $p = $items[$i]
            Write-Color ("    {0,2}) {1,-24}  {2}" -f ($i + 1), $p.Label, (Get-PoshPreviewText -Posh $p)) '#C0CAF5'
        }
        $n = Read-Choice -Prompt 'Type a prompt number' -Default '1'
        if ($n -match '^\d+$' -and [int]$n -ge 1 -and [int]$n -le $items.Count) {
            $picked = $items[[int]$n - 1]
        }
    }

    Clear-ScreenSoft
    Show-Banner -Title 'Prompt preview' -Step 5 -Total 6
    if ($Plan.Theme) {
        Write-PreviewWindow -Theme $Plan.Theme -Art $Plan.Art -Font $Plan.Font -Posh $picked -Opacity $Plan.Opacity
    } else {
        Write-Color ('  ' + (Get-PoshPreviewText -Posh $picked)) '#A6E3A1'
    }
    Write-Host ""
    if (Test-CommandExists 'oh-my-posh') {
        Write-Color '  Live preview from Oh My Posh:' '#A9B1D6'
        try { & oh-my-posh print primary --config $picked.Id --shell pwsh } catch {}
    }
    Wait-Continue
    return $picked
}

function Select-TransparencyChoice {
    param($Plan)
    Clear-ScreenSoft
    Show-Banner -Title 'Transparency' -Step 6 -Total 6
    Write-Color '  How transparent should the terminal be?' '#C0CAF5'
    Write-Color '    0   = wallpaper shows through' '#A9B1D6'
    Write-Color '    50  = half glass' '#A9B1D6'
    Write-Color '    80  = a little glass (nice default)' '#A9B1D6'
    Write-Color '    100 = solid, no transparency' '#A9B1D6'
    Write-Host ""
    $raw = Read-Choice -Prompt 'Type a number from 0 to 100' -Default ([string]$Plan.Opacity)
    $value = 80
    if ($raw -match '^\d+$') { $value = [Math]::Min(100, [Math]::Max(0, [int]$raw)) }
    $Plan.Opacity = $value
    $Plan.UseAcrylic = Read-YesNo -Prompt 'Add a soft blur behind the text?' -Default 'Y'
    if ($Plan.Theme) {
        Write-Host ""
        Write-PreviewWindow -Theme $Plan.Theme -Art $Plan.Art -Font $Plan.Font -Posh $Plan.Posh -Opacity $Plan.Opacity
        Wait-Continue
    }
}

function Show-FinalPreview {
    param($Plan)
    Clear-ScreenSoft
    Show-Banner -Title 'Last look before we install' -Step 6 -Total 6
    Write-Color '  This is how your terminal will look.' '#C0CAF5'
    Write-Host ""
    Write-PreviewWindow -Theme $Plan.Theme -Art $Plan.Art -Font $Plan.Font -Posh $Plan.Posh -Opacity $Plan.Opacity
    Write-Host ""
    Write-Color '  This look will be saved (tools are already downloaded):' '#CBA6F7'
    if ($Plan.InstallOhMyPosh) { Write-Color '    - Prettier prompt  (Oh My Posh)' '#A6E3A1' }
    Write-Color '    - File and folder icons  (Terminal-Icons)' '#A6E3A1'
    if ($Plan.InstallFont -and $Plan.Font) { Write-Color ("    - Font: $($Plan.Font.Label)") '#A6E3A1' }
    if ($Plan.InstallFastfetch) { Write-Color '    - Startup picture  (Fastfetch)' '#A6E3A1' }
    if ($Plan.Theme) { Write-Color ("    - Colors: $($Plan.Theme.name)") '#A6E3A1' }
    if ($Plan.Art) { Write-Color ("    - Picture: $($Plan.Art.Label)") '#A6E3A1' }
    if ($Plan.ApplyTransparency) { Write-Color ("    - Transparency: $($Plan.Opacity)%") '#A6E3A1' }
    if ($Plan.ApplyBetterCli) { Write-Color '    - Easier typing and command history' '#A6E3A1' }
    Write-Host ""
    Write-Color '  Type Y to install. Type N to stop with no changes.' '#F9E2AF'
    return (Read-YesNo -Prompt 'Install this look now?' -Default 'Y')
}

function Invoke-InstallPlan {
    param($Plan)
    return Invoke-DownloadEverything -Plan $Plan
}

function Invoke-ApplyPlan {
    param($Plan)

    Clear-ScreenSoft
    Show-Banner -Title 'Saving your look'
    Write-Color '  Saving colors, font, picture, and prompt to your terminal.' '#89B4FA'
    Write-Host ""

    $ok = $true
    if ($Plan.ApplyTheme -or $Plan.ApplyTransparency -or $Plan.Font) {
        if (-not (Set-WindowsTerminalLook -State $Plan)) { $ok = $false }
    }
    if ($Plan.InstallFastfetch -or $Plan.ApplyAscii) {
        Set-FastfetchLook -State $Plan
    }
    if ($Plan.InstallOhMyPosh -or $Plan.ApplyBetterCli -or $Plan.InstallTerminalIcons -ne $false) {
        Set-PowerShellProfileLook -State $Plan
    }
    if ($Plan.Font) {
        Set-CursorTerminalFont -Font $Plan.Font
    }
    return $ok
}

function Show-DoneScreen {
    param($Plan, $Failed)

    Close-PreviewPopup
    if ($script:StudioForm -and -not $script:StudioForm.IsDisposed) {
        try { $script:StudioForm.Close() } catch {}
    }

    Clear-ScreenSoft
    Show-Banner -Title 'You are done'
    Write-Host ""

    if ($Failed -and $Failed.Count -gt 0) {
        Write-Color ('  These did not finish: ' + ($Failed -join ', ')) '#F38BA8'
        Write-Color '  The rest was still saved.' '#F9E2AF'
        Write-Host ""
    } else {
        Write-Color '  Your look was saved. The preview is closed.' '#A6E3A1'
        Write-Host ""
    }

    Write-Color '  Close this terminal, then open it again.' '#F9E2AF'
    Write-Color '  The new window is where you will see the colors, font, prompt, and Fastfetch.' '#C0CAF5'
    Write-Host ""
    Write-Color '  What to do now' '#CBA6F7'
    Write-Color '    1. Close this terminal (this tab or window).' '#C0CAF5'
    Write-Color '    2. Open a new terminal.' '#C0CAF5'
    Write-Color '    3. If the font still looks old, sign out of Windows once, then open Terminal again.' '#C0CAF5'
    Write-Host ""
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        [System.Windows.Forms.MessageBox]::Show(
            'Close your terminal, then open it again to see the new look.',
            'Better Terminal',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    } catch {}
}

function Start-BetterTerminalSetup {
    Enable-VirtualTerminal
    Clear-MissingEditorFonts

    if ($PSVersionTable.PSVersion.Major -lt 7) {
        $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
        if ($pwsh) {
            Write-Color '  Opening in PowerShell 7 so settings save more reliably...' '#89B4FA'
            & $pwsh.Source -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath
            exit $LASTEXITCODE
        }
    }

    try {
        $plan = Get-InstallPlan
        if (-not $plan) {
            Write-Color '  Okay, stopped. Nothing was changed.' '#F9E2AF'
            Close-PreviewPopup
            return
        }

        $failed = Invoke-DownloadEverything -Plan $plan

        $plan.Theme = Get-PreferredCatalogItem -Items (Get-ThemeCatalog) -Names @('Dracula', 'TokyoNight', 'Catppuccin Mocha', 'Nord') -Property 'name'
        $plan.Font = Get-PreferredCatalogItem -Items (Get-FontCatalog) -Names @('Meslo', 'CascadiaCode', 'FiraCode') -Property 'Id'
        $plan.Art = Get-PreferredCatalogItem -Items (Get-AsciiCatalog) -Names @('Windows 11', 'Windows11', 'Windows', 'Auto (detect this PC)') -Property 'Label'
        $plan.Posh = Get-PreferredCatalogItem -Items (Get-PoshCatalog) -Names @('jandedobbeleer', 'M365Princess', 'agnoster') -Property 'Id'

        $picked = Show-ChoiceStudio -Plan $plan
        if (-not $picked) {
            Write-Color '  The clickable window was closed. The downloads are already on this PC.' '#F9E2AF'
            return
        }
        $plan = $picked

        if ($plan.InstallFont -and $plan.Font) {
            Write-Host ""
            Write-Color "  Making sure $($plan.Font.Label) is downloaded from Nerd Fonts..." '#CBA6F7'
            if (-not (Ensure-FontReady -Font $plan.Font)) { $failed += 'Nerd Font' }
        }

        [void](Invoke-ApplyPlan -Plan $plan)
        Show-DoneScreen -Plan $plan -Failed $failed
    } catch {
        Write-Host ""
        Write-Color "  Something went wrong: $($_.Exception.Message)" '#F38BA8'
        Write-Host ""
        Write-Color '  Your old settings were not deleted. You can run this helper again.' '#F9E2AF'
    } finally {
        Close-PreviewPopup
    }
}

Start-BetterTerminalSetup
