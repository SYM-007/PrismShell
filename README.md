# Better Terminal Setup

A Windows helper that downloads official terminal tools and lists, lets you click a look, then saves it to Windows Terminal and PowerShell.

This file explains **what the helper does**, **where every piece of data comes from**, **what gets written on your PC**, and **how to do the same setup by hand**.

| File | What it is |
| --- | --- |
| `Start-BetterTerminal.cmd` | Double-click this to start |
| `Install-BetterTerminal.ps1` | The helper (PowerShell) |
| `README.md` | This guide |
| `CATALOG.md` | Every color name, font zip, prompt theme, and Fastfetch logo the helper currently has |

---

## Start with the helper

1. Keep `Install-BetterTerminal.ps1` and `Start-BetterTerminal.cmd` in the same folder.
2. Double-click **`Start-BetterTerminal.cmd`**.

Or in PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-BetterTerminal.ps1
```

If Windows asks about running a script, choose **Yes**.

At the first screen:

| Type | What happens |
| --- | --- |
| **Y** | Download every tool and every official list, then open the picker |
| **O** | Ask yes/no for each tool, then still download the lists you kept |
| **Q** | Quit. Nothing is changed |

---

## What happens, in order

### 1. The helper starts

`Start-BetterTerminal.cmd` runs:

```bat
powershell.exe -NoProfile -ExecutionPolicy Bypass -File Install-BetterTerminal.ps1
```

The script then:

1. Turns on color output in the console.
2. Removes a Cursor/VS Code terminal font if that font is **not** installed (this stops the “Unable to find the following fonts” warning).
3. Stays in the same PowerShell window (no restart), and still writes both the PowerShell 5.1 and PowerShell 7 profiles.

### 2. You type Y (or O)

The helper builds a plan. With **Y**, that plan is:

- Install Oh My Posh
- Install a Nerd Font (Meslo now; another font only when you click **Use this look**)
- Install Fastfetch
- Install Terminal-Icons
- Later apply colors, transparency, art, a Fastfetch look, and a nicer command line

### 3. Everything downloads first

`Invoke-DownloadEverything` runs these steps. The picker does **not** open until this finishes.

| Step | What is installed or downloaded | Official source |
| --- | --- | --- |
| Oh My Posh | The prompt program | winget `JanDeDobbeleer.OhMyPosh`, or [ohmyposh.dev/install.ps1](https://ohmyposh.dev/install.ps1) |
| Fastfetch | The startup logo + PC info tool | winget `Fastfetch-cli.Fastfetch`, or the latest `windows-amd64.zip` from [fastfetch-cli/fastfetch](https://github.com/fastfetch-cli/fastfetch) |
| Terminal-Icons | File and folder icons in `Get-ChildItem` | [PowerShell Gallery: Terminal-Icons](https://www.powershellgallery.com/packages/Terminal-Icons) |
| Nerd Fonts **list** | Every official zip name | [Nerd Fonts v3.5.1 release](https://github.com/ryanoasis/nerd-fonts/releases/tag/v3.5.1) |
| Meslo | The recommended icon font | `https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/Meslo.zip` |
| Color themes | Every Windows Terminal JSON scheme | [windowsterminalthemes.dev](https://windowsterminalthemes.dev/) via [mbadolato/iTerm2-Color-Schemes](https://github.com/mbadolato/iTerm2-Color-Schemes) |
| Oh My Posh themes | Every official `.omp.json` | [ohmyposh.dev/docs/themes](https://ohmyposh.dev/docs/themes) via [JanDeDobbeleer/oh-my-posh/themes](https://github.com/JanDeDobbeleer/oh-my-posh/tree/main/themes) |
| Fastfetch logos | Every built-in logo name | `fastfetch --list-logos` after Fastfetch is installed |

Lists are cached under `%LOCALAPPDATA%\BetterTerminal` so the next run does not re-download hundreds of files.

**Fonts are not downloaded while you browse the list.** Only Meslo is installed during the first download. Any other font is installed only when you click **Use this look**.

### 4. The picker window opens

A dark picker window opens. The live preview is at the top. Under it, a hint tells you what the current tab does, then six tabs:

| Tab | What you pick | Preview |
| --- | --- | --- |
| **Colors** | One scheme from the full iTerm2 / Windows Terminal Themes pack | Live colors in the mini terminal, and in Windows Terminal if it is open |
| **Fonts** | One official Nerd Font name | Sample text. The zip is **not** downloaded yet |
| **Art** | One official Fastfetch logo, Auto, No logo, a small extra picture, or **your own named ASCII art** | Shown on the left of the Fastfetch preview |
| **Fastfetch** | Turn each info line on or off with its own tick box, pick a **Quick set** (Default, Graphics, Neofetch, Small, All, Logo only), and choose a picture color and an info text color | Real `fastfetch --pipe` output that redraws every time you tick a line |
| **Prompt** | One official Oh My Posh theme | Colored chips built from that theme’s JSON |
| **Transparency** | Drag the slider, or click a number (0, 10, 20 … 100) under it to jump straight there | Windows Terminal opacity + acrylic |

**Search** only filters the tab you are on, and clears when you change tabs. Example: on Fonts, type `meslo`. On Fastfetch, type `memory`. On Transparency, type `80`.

If you already saved a look, that look is **already selected**. Change only the tab you want, then click **Use this look**.

Terminal-Icons is automatic. There is no icon picker.

### 5. You click Use this look

The helper then:

1. Downloads the chosen Nerd Font zip **if that font is not already installed**.
2. Writes colors, font, and transparency to **Windows Terminal defaults and every profile**.
3. Writes Fastfetch config to `%USERPROFILE%\.config\fastfetch\`.
4. Writes a `Better Terminal Setup` block into **both** PowerShell profiles (5.1 and 7).
5. Writes Cursor’s terminal font only if that exact Windows family name is installed.
6. Closes the picker and the preview.
7. Tells you to **close the terminal and open it again**.
8. Remembers this look in `%LOCALAPPDATA%\BetterTerminal\last-look.json` so the next run can open with the same colors, font, art, Fastfetch lines, prompt, and transparency already selected.

Old files are copied first as `filename.bak.yyyyMMdd-HHmmss`.

---

## Where the data comes from

Nothing here is invented as a private theme pack. The helper reads public official lists.

### Color themes

| What | URL |
| --- | --- |
| Browse / preview site | https://windowsterminalthemes.dev/ |
| Source repo | https://github.com/mbadolato/iTerm2-Color-Schemes |
| Folder listing (API) | https://api.github.com/repos/mbadolato/iTerm2-Color-Schemes/contents/windowsterminal |
| One theme JSON | `https://raw.githubusercontent.com/mbadolato/iTerm2-Color-Schemes/master/windowsterminal/<Name>.json` |
| Full pack (preferred) | Latest GitHub release asset `windowsterminal-themes.tgz` |
| Fallback zip | https://github.com/mbadolato/iTerm2-Color-Schemes/archive/refs/heads/master.zip |
| Cached on disk | `%LOCALAPPDATA%\BetterTerminal\themes\windowsterminal\*.json` |

Each JSON has the Windows Terminal fields: `name`, `background`, `foreground`, `black`…`white`, `brightBlack`…`brightWhite`, `cursorColor`, `selectionBackground`.

If the download fails, the helper uses the 25 built-in schemes in `Get-BuiltInThemes` (same hex values as the official files). Those 25 are listed below.

**Current full list: 606 names in [CATALOG.md](CATALOG.md).**

### Fonts (Nerd Fonts)

| What | URL |
| --- | --- |
| Site | https://www.nerdfonts.com/ |
| Release used by the helper | **v3.5.1** |
| Release page | https://github.com/ryanoasis/nerd-fonts/releases/tag/v3.5.1 |
| Zip pattern | `https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/<Id>.zip` |
| Name list API | https://api.github.com/repos/ryanoasis/nerd-fonts/releases/tags/v3.5.1 |
| Cached on disk | `%LOCALAPPDATA%\BetterTerminal\nerd-fonts.json` |

Skipped zips: `FontPatcher.zip`, `NerdFontsSymbolsOnly.zip`.

Windows often registers a **short family name**, not the marketing name. Examples:

| Zip / picker name | Name Windows usually installs |
| --- | --- |
| CascadiaCode | `CaskaydiaCove NF` (also `NFM`, `NFP`) |
| CascadiaMono | `CaskaydiaMono NF` (if that zip is installed) |
| JetBrainsMono | `JetBrainsMono NF` |
| Meslo | `MesloLGM Nerd Font` (also LGS / LGL) |

The helper only saves a font name that `InstalledFontCollection` can see. That is why `CaskaydiaMono Nerd Font` must not be written unless that exact family exists.

**Current full list: 71 zips in [CATALOG.md](CATALOG.md).** Download URL for each is `…/download/v3.5.1/<Id>.zip`.

### Prompt (Oh My Posh)

| What | URL |
| --- | --- |
| Theme gallery | https://ohmyposh.dev/docs/themes |
| Prompt install docs | https://ohmyposh.dev/docs/installation/prompt |
| Official installer | https://ohmyposh.dev/install.ps1 |
| Theme files | https://github.com/JanDeDobbeleer/oh-my-posh/tree/main/themes |
| Theme API | https://api.github.com/repos/JanDeDobbeleer/oh-my-posh/contents/themes |
| One file | `https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/<id>.omp.json` |
| After winget install | `%LOCALAPPDATA%\Programs\oh-my-posh\themes\` |
| Helper cache | `%LOCALAPPDATA%\BetterTerminal\posh-themes\` |

**Current full list: 123 official themes in [CATALOG.md](CATALOG.md).**

### Fastfetch

| What | URL |
| --- | --- |
| Project | https://github.com/fastfetch-cli/fastfetch |
| Latest Windows zip | GitHub latest release, asset matching `windows-amd64.zip` |
| Logo list | `fastfetch --list-logos` (built into the program, not a website scrape) |
| Preview command | `fastfetch --config <temp>.jsonc --pipe` using your **Art**, your ticked info lines, and your two picture colors plus the info text color |
| Ideas for extra pictures | https://www.asciiart.eu/gallery (the extras in the picker are original small drawings, not copied from that site) |

**Current full list: 639 built-in logo names in [CATALOG.md](CATALOG.md).** On Windows the useful ones are `Windows 11`, `Windows`, `Windows 11_small`, `Windows 10`, `Windows 8`, and `Auto (detect this PC)`.

### File and folder icons

| What | URL |
| --- | --- |
| Project | https://github.com/devblackops/terminal-icons |
| Install | `Install-Module Terminal-Icons -Scope CurrentUser` from [PowerShell Gallery](https://www.powershellgallery.com/packages/Terminal-Icons) |

### Transparency

No download. The helper writes Windows Terminal `opacity` (0–100) and `useAcrylic` (`true`). Docs: https://aka.ms/terminal-documentation and schema https://aka.ms/terminal-profiles-schema

---

## What the helper writes on your PC

### Downloaded cache

```
%LOCALAPPDATA%\BetterTerminal\
  last-look.json          (includes FetchLook, LogoColor1, LogoColor2)
  nerd-fonts.json
  custom-ascii\index.json
  custom-ascii\custom-*.txt
  themes\windowsterminal\*.json
  posh-themes\*.omp.json
```

### Windows Terminal

First existing path wins:

1. `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`
2. `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json`
3. `%LOCALAPPDATA%\Microsoft\Windows Terminal\settings.json`

Written into **defaults and every profile** in `profiles.list`:

- `colorScheme` — the theme name
- `font.face` — only an installed family, for example `CaskaydiaCove NF` or `MesloLGM Nerd Font`
- `opacity` and `useAcrylic`

The chosen theme object is also added to the `schemes` array.

### Fastfetch

```
%USERPROFILE%\.config\fastfetch\config.jsonc
%USERPROFILE%\.config\fastfetch\logo.txt    (only if you pick an extra / file logo)
```

`config.jsonc` is UTF-8 **without a BOM** (Fastfetch rejects a BOM). The helper writes the official Fastfetch style:

```jsonc
{
    "logo": {
        "type": "auto",
        "color": { "1": "cyan", "2": "blue" }
    },
    "display": {
        "separator": ": ",
        "color": { "keys": "blue" }
    },
    "modules": [ "title", "separator", "os", "host" ]
}
```

The three color rows on the **Fastfetch** tab map to Fastfetch settings like this:

| Row in the picker | Fastfetch setting | What it paints |
| --- | --- | --- |
| Picture color | `logo.color.1` (same as `fastfetch --logo-color-1`) | The drawing on the left |
| Picture 2nd color | `logo.color.2` (same as `fastfetch --logo-color-2`) | The second shade of that drawing |
| Info text color | `display.color.keys` | The `OS:`, `CPU:`, `Memory:` labels on the right |

Every tick box on that tab is one entry in `modules`. Ticking a line adds it, unticking removes it, and the list is always written in the official Fastfetch order no matter what order you clicked. **Quick sets** just tick a whole group at once: Default, Graphics (adds Vulkan / OpenGL / OpenCL), Neofetch, Small, All, or Logo only (no info lines at all).

### PowerShell profiles

Both of these (and the VS Code-named copies if they exist):

- `%USERPROFILE%\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1` (Windows PowerShell 5.1)
- `%USERPROFILE%\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` (PowerShell 7)

The helper replaces the `#region Better Terminal Setup` block. That block:

- Turns on PSReadLine history search, Tab menu complete, and (in PS7) list predictions
- Adds `ll`, `la`, `..`, `...`, `grep`, `which`
- Runs `oh-my-posh init pwsh --config '<theme>.omp.json'`
- Imports `Terminal-Icons`
- Runs `fastfetch` when the host is `ConsoleHost`

It also comments out leftover `fastfetch --config $eagleFastfetchConfig` lines so an older Fastfetch setup does not fight the new one.

### Cursor (only if the font is really installed)

`%APPDATA%\Cursor\User\settings.json` → `terminal.integrated.fontFamily`

If that family is missing, the key is removed so Cursor does not warn on every new terminal.

### Fonts

Nerd Font files are copied to `%LOCALAPPDATA%\Microsoft\Windows\Fonts` and registered under `HKCU\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts`.

---

## Built-in color data (offline fallback)

These 25 schemes are stored in the script. They match the official iTerm2 / Windows Terminal Themes files.

| Name | Background | Foreground | Cursor | Selection |
| --- | --- | --- | --- | --- |
| Dracula | `#282a36` | `#f8f8f2` | `#f8f8f2` | `#44475a` |
| Nord | `#2e3440` | `#d8dee9` | `#eceff4` | `#434c5e` |
| TokyoNight | `#1a1b26` | `#c0caf5` | `#c0caf5` | `#33467c` |
| TokyoNight Storm | `#24283b` | `#c0caf5` | `#c0caf5` | `#364a82` |
| Catppuccin Mocha | `#1e1e2e` | `#cdd6f4` | `#f5e0dc` | `#585b70` |
| Catppuccin Macchiato | `#24273a` | `#cad3f5` | `#f4dbd6` | `#5b6078` |
| Catppuccin Frappe | `#303446` | `#c6d0f5` | `#f2d5cf` | `#626880` |
| Catppuccin Latte | `#eff1f5` | `#4c4f69` | `#dc8a78` | `#acb0be` |
| Gruvbox Dark | `#282828` | `#ebdbb2` | `#ebdbb2` | `#665c54` |
| One Half Dark | `#282c34` | `#dcdfe4` | `#dcdfe4` | `#474e5d` |
| Kanagawa | `#1F1F28` | `#DCD7BA` | `#DCD7BA` | `#2A2A37` |
| Horizon | `#1c1e26` | `#bdc0c2` | `#e5e5e5` | `#2e303e` |
| CyberPunk2077 | `#272932` | `#E455AE` | `#FDF500` | `#742D8B` |
| Night Owl | `#011627` | `#d6deeb` | `#80a4c2` | `#1d3b53` |
| GitHub Dark | `#0d1117` | `#e6edf3` | `#e6edf3` | `#163356` |
| Atom One Dark | `#21252b` | `#abb2bf` | `#abb2bf` | `#323842` |
| Rose Pine | `#191724` | `#e0def4` | `#e0def4` | `#403d52` |
| Cobalt2 | `#132738` | `#ffffff` | `#f0cc09` | `#183c66` |
| Ayu | `#0f1419` | `#e6e1cf` | `#f29718` | `#253340` |
| Snazzy | `#282a36` | `#eff0eb` | `#97979b` | `#3e4149` |
| Everforest Dark Med | `#2d353b` | `#d3c6aa` | `#d3c6aa` | `#543a48` |
| Material Dark | `#232322` | `#ece4d5` | `#16afca` | `#4e4e4e` |
| Afterglow | `#212121` | `#d0d0d0` | `#d0d0d0` | `#303030` |
| Adventure Time | `#1f1d45` | `#f8dcc0` | `#efbf38` | `#706b4e` |
| Ubuntu | `#300a24` | `#eeeeec` | `#bbbbbb` | `#b5d5ff` |

ANSI colors for Dracula (example of a full scheme). Every other theme has the same 16 + bright 8 fields in its JSON:

| Slot | Hex | Bright | Hex |
| --- | --- | --- | --- |
| black | `#21222c` | brightBlack | `#6272a4` |
| red | `#ff5555` | brightRed | `#ff6e6e` |
| green | `#50fa7b` | brightGreen | `#69ff94` |
| yellow | `#f1fa8c` | brightYellow | `#ffffa5` |
| blue | `#bd93f9` | brightBlue | `#d6acff` |
| purple | `#ff79c6` | brightPurple | `#ff92df` |
| cyan | `#8be9fd` | brightCyan | `#a4ffff` |
| white | `#f8f8f2` | brightWhite | `#ffffff` |

To get **every** hex value for the other 581 themes, open the matching file in `%LOCALAPPDATA%\BetterTerminal\themes\windowsterminal\` or the raw GitHub URL above.

### Extra Fastfetch pictures (not official logos)

These small drawings ship in the script. Category names follow [asciiart.eu/gallery](https://www.asciiart.eu/gallery). The pictures themselves are original.

You can also add your own. On the **Art** tab click **Add my art**, type a name, paste or load a `.txt` picture, then **Save art**. Those stay in `%LOCALAPPDATA%\BetterTerminal\custom-ascii\` and show at the top of the list. **Remove** deletes only a picture you added.

| Id | Label | Category |
| --- | --- | --- |
| terminal | Retro terminal | Computers |
| robot | Robot | Computers |
| owl | Night owl | Animals |
| cat | Sitting cat | Animals |
| fish | Fish | Animals |
| rocket | Rocket | Space |
| planet | Planet ring | Space |
| tree | Pine tree | Nature |
| mountain | Mountains | Nature |
| coffee | Coffee mug | Food and drinks |
| castle | Castle | Buildings |
| car | Little car | Vehicles |
| ghost | Friendly ghost | Miscellaneous |

---

## Do it yourself (no helper)

Do these in order. Skip a section if you do not want that part.

### 0. Open an elevated-enough PowerShell

A normal user PowerShell 7 window is enough. Admin is not required.

```powershell
winget --version
```

If `winget` is missing, install [App Installer](https://aka.ms/getwinget) from Microsoft.

### 1. Install Windows Terminal (if you do not have it)

```powershell
winget install --id Microsoft.WindowsTerminal -e
```

Open it once so it creates `settings.json`.

### 2. Install Oh My Posh

```powershell
winget install --id JanDeDobbeleer.OhMyPosh -e --accept-package-agreements --accept-source-agreements
```

Close and reopen the terminal, then check:

```powershell
oh-my-posh --version
echo $env:POSH_THEMES_PATH
```

Official themes are already in that folder, or download any file from:

https://github.com/JanDeDobbeleer/oh-my-posh/tree/main/themes

Browse previews at https://ohmyposh.dev/docs/themes

### 3. Install a Nerd Font

1. Open https://www.nerdfonts.com/font-downloads or the v3.5.1 release: https://github.com/ryanoasis/nerd-fonts/releases/tag/v3.5.1
2. Download one zip. **Meslo** is the usual choice for Oh My Posh icons.
3. Unzip it.
4. Select the Regular (and optionally Mono) `.ttf` files, right-click, **Install for current user**.
5. In Windows Terminal: **Settings → Defaults → Appearance → Font face**.
6. Pick the **installed Windows name**, not the zip name. After Meslo that is usually `MesloLGM Nerd Font`. After Cascadia Code Nerd Font that is usually `CaskaydiaCove NF`.

Direct Meslo download:

```
https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/Meslo.zip
```

If Cursor shows “Unable to find the following fonts”, open Cursor Settings and remove `terminal.integrated.fontFamily`, or set it to a name that appears in Windows Fonts.

### 4. Install Fastfetch

```powershell
winget install --id Fastfetch-cli.Fastfetch -e --accept-package-agreements --accept-source-agreements
```

Or download `fastfetch-windows-amd64.zip` from https://github.com/fastfetch-cli/fastfetch/releases

List every logo:

```powershell
fastfetch --list-logos
```

Create a config:

```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.config\fastfetch" | Out-Null
```

Save this as `%USERPROFILE%\.config\fastfetch\config.jsonc` with **UTF-8 no BOM** (in VS Code / Cursor: Save with Encoding → UTF-8).

```jsonc
{
    "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
    "logo": {
        "type": "builtin",
        "source": "Windows 11"
    },
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
```

Other logo choices:

| Goal | `logo.type` | `logo.source` |
| --- | --- | --- |
| Detect this PC | `auto` | omit `source` |
| Official picture | `builtin` | a name from `fastfetch --list-logos`, for example `Windows 11` |
| Small picture | `small` | `Windows` |
| No picture | `none` | omit `source` |
| Your own text file | `file` | full path to a `.txt` file |

To add named pictures by hand, save a UTF-8 `.txt` file and a row in `%LOCALAPPDATA%\BetterTerminal\custom-ascii\index.json`, or use **Add my art** in the picker.

Test it:

```powershell
fastfetch
```

### 5. Install Terminal-Icons

```powershell
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser
Install-Module -Name Terminal-Icons -Repository PSGallery -Scope CurrentUser -Force
Import-Module Terminal-Icons
Get-ChildItem
```

You should see icons next to files **after** a Nerd Font is the active terminal font.

### 6. Add a color theme to Windows Terminal

1. Open https://windowsterminalthemes.dev/ and click a theme, **or** download a JSON from:

   `https://raw.githubusercontent.com/mbadolato/iTerm2-Color-Schemes/master/windowsterminal/Dracula.json`

2. Open Windows Terminal **Settings** (Ctrl+,) → Open JSON file.

3. Paste the theme object into the `"schemes"` array.

4. In `"profiles"` → `"defaults"` set:

```json
"colorScheme": "Dracula",
"font": { "face": "MesloLGM Nerd Font" },
"opacity": 80,
"useAcrylic": true
```

5. Save. Open a **new** tab.

Example scheme object (Dracula):

```json
{
    "name": "Dracula",
    "background": "#282a36",
    "foreground": "#f8f8f2",
    "black": "#21222c",
    "red": "#ff5555",
    "green": "#50fa7b",
    "yellow": "#f1fa8c",
    "blue": "#bd93f9",
    "purple": "#ff79c6",
    "cyan": "#8be9fd",
    "white": "#f8f8f2",
    "brightBlack": "#6272a4",
    "brightRed": "#ff6e6e",
    "brightGreen": "#69ff94",
    "brightYellow": "#ffffa5",
    "brightBlue": "#d6acff",
    "brightPurple": "#ff92df",
    "brightCyan": "#a4ffff",
    "brightWhite": "#ffffff",
    "cursorColor": "#f8f8f2",
    "selectionBackground": "#44475a"
}
```

### 7. Make PowerShell use the prompt, icons, and Fastfetch

Edit **both** profile files if you use both hosts:

```powershell
notepad $PROFILE
# and, from Windows PowerShell 5.1:
notepad "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
```

Add this block. Change the Oh My Posh path to a real `.omp.json` on your PC (`$env:POSH_THEMES_PATH` is the usual folder).

```powershell
#region Better Terminal Setup
if ($Host.Name -eq 'ConsoleHost') {
    try {
        Import-Module PSReadLine -ErrorAction SilentlyContinue
        Set-PSReadLineOption -EditMode Windows
        Set-PSReadLineOption -PredictionSource History
        Set-PSReadLineOption -HistorySearchCursorMovesToEnd
        if ($PSVersionTable.PSVersion.Major -ge 7) {
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

oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\jandedobbeleer.omp.json" | Invoke-Expression

try { Import-Module Terminal-Icons -ErrorAction SilentlyContinue } catch {}

if ($Host.Name -eq 'ConsoleHost') {
    if (Get-Command fastfetch -ErrorAction SilentlyContinue) { fastfetch }
}
#endregion Better Terminal Setup
```

Close the terminal and open a new one.

### 8. Optional: Cursor integrated terminal font

In Cursor Settings JSON, set a family that **Windows Fonts** actually lists:

```json
"terminal.integrated.fontFamily": "MesloLGM Nerd Font"
```

If the warning comes back, delete that line.

---

## After you finish

1. Close the terminal you used for setup.
2. Open a new Windows Terminal (or Cursor) tab.
3. You should see Fastfetch, the Oh My Posh prompt, the color scheme, and the font.
4. If icons are empty boxes, the font did not load yet: sign out of Windows once, or pick the installed family name again in Terminal settings.

---

## If something goes wrong

| Problem | What to try |
| --- | --- |
| Script will not run | Right-click `Start-BetterTerminal.cmd` and choose **Run**, or unblock the `.ps1` file |
| No picker window | Windows blocked WinForms. Allow it, then run again |
| Icons are empty boxes | New tab, or sign out so Windows sees the new font |
| Cursor font warning | The saved family is not installed. Remove `terminal.integrated.fontFamily` or pick `CaskaydiaCove NF` / `MesloLGM Nerd Font` |
| Fastfetch says the config is invalid | The file has a UTF-8 BOM. Re-save as UTF-8 no BOM |
| Prompt missing in PowerShell 5.1 | The helper writes both profiles; if you did it by hand, edit the WindowsPowerShell profile too |
| You want the old look | Restore the `.bak.yyyyMMdd-HHmmss` copy next to `settings.json` or your profile |
| You want to stop the helper | Click **Cancel**, or type **Q** at the start |

---

## Refresh the lists yourself

```powershell
# Color theme names
Invoke-RestMethod -Uri 'https://api.github.com/repos/mbadolato/iTerm2-Color-Schemes/contents/windowsterminal' -Headers @{ 'User-Agent' = 'BetterTerminalDocs' } |
    Where-Object { $_.name -like '*.json' } |
    ForEach-Object { $_.name -replace '\.json$','' }

# Nerd Font zip names (v3.5.1)
(Invoke-RestMethod -Uri 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases/tags/v3.5.1' -Headers @{ 'User-Agent' = 'BetterTerminalDocs' }).assets |
    Where-Object { $_.name -like '*.zip' } |
    ForEach-Object { $_.name }

# Oh My Posh theme names
Invoke-RestMethod -Uri 'https://api.github.com/repos/JanDeDobbeleer/oh-my-posh/contents/themes' -Headers @{ 'User-Agent' = 'BetterTerminalDocs' } |
    Where-Object { $_.name -like '*.omp.json' } |
    ForEach-Object { $_.name -replace '\.omp\.json$','' }

# Fastfetch logos
fastfetch --list-logos
```

The complete dump from this PC (606 colors, 71 fonts, 123 prompts, 639 logos) is in **[CATALOG.md](CATALOG.md)**.
