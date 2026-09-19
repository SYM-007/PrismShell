# Better Terminal Setup

A simple Windows helper that makes your terminal look nicer.

Type **Y**. The helper **downloads everything first**. Then a **small window pops up** with the full lists. Pick a look. The terminal at the top of that window shows it.

---

## Start here

1. Keep these files together:
   - `Install-BetterTerminal.ps1`
   - `Start-BetterTerminal.cmd`
2. Double-click **`Start-BetterTerminal.cmd`**.

Or type this in PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-BetterTerminal.ps1
```

If Windows asks about running a script, choose **Yes**.

---

## How to use it

1. Type **Y** and press Enter.
2. Wait while it downloads the tools **and the full lists**:
   - Every color theme
   - Every official Oh My Posh prompt
   - Fastfetch and every built-in logo
   - The full Nerd Fonts list, plus the Meslo font
   - File and folder icons
3. The picker window opens after the download. Choose from the lists:
   - **Colors** — every theme from [Windows Terminal Themes](https://windowsterminalthemes.dev/)
   - **Fonts** — every official [Nerd Font](https://www.nerdfonts.com/) (Meslo is recommended)
   - **Fastfetch** — every official Fastfetch logo, plus extra pictures
   - **Prompt** — every official [Oh My Posh theme](https://ohmyposh.dev/docs/themes)
   - **Transparency** — drag 0 to 100. Each tick has a number under it (0, 10, 20 … 100)
4. Watch the **small terminal at the top** change as you click.
5. Click **Use this look** to save. If you picked a font other than Meslo, that font is installed then.

Use **Search** on the tab you are on. It stays on that tab. Example: on **Fonts**, type `meslo`. On **Transparency**, type `80` to move the slider.

File and folder icons from [Terminal-Icons](https://github.com/devblackops/terminal-icons) are added automatically. You do not pick them in the window.

---

## What you can add

| What you click | What it does | Where it comes from |
| --- | --- | --- |
| Colors | Changes terminal background and text | [Windows Terminal Themes](https://windowsterminalthemes.dev/) |
| Fonts | Adds a font that can show icons | [Nerd Fonts](https://www.nerdfonts.com/) |
| Fastfetch | Logo and PC info when the terminal opens | [Fastfetch](https://github.com/fastfetch-cli/fastfetch) |
| Prompt | Makes the command line look nicer | [Oh My Posh themes](https://ohmyposh.dev/docs/themes) |
| Transparency | Lets your wallpaper show through | Windows Terminal |
| File icons (automatic) | Icons next to files and folders | [Terminal-Icons](https://github.com/devblackops/terminal-icons) |

If Windows Terminal is open, its colors update while you click so you can see the real window change too.

---

## After you finish

1. Click **Use this look**. The preview window closes.
2. **Close this terminal**, then **open it again**.
3. If the font did not change, sign out of Windows once, then open Terminal again.

Your old settings are copied first, so you can go back if you want.

---

## If something goes wrong

| Problem | What to try |
| --- | --- |
| Script will not run | Right-click `Start-BetterTerminal.cmd` and choose **Run** |
| No clickable window | Windows blocked the popup. Allow it, then run again |
| Icons are empty boxes | Open a new tab, or sign out so Windows can see the new font |
| You want to stop | Click **Cancel**, or type **Q** at the start |

---

## Files in this folder

| File | What it is |
| --- | --- |
| `Start-BetterTerminal.cmd` | Double-click this to start |
| `Install-BetterTerminal.ps1` | The helper |
| `README.md` | This guide |
# PrismShell
