# Open Shell Here

[![Visual Studio Marketplace](https://img.shields.io/badge/Marketplace-open--shell--here-blue)](https://marketplace.visualstudio.com/items?itemName=REPLACE_WITH_YOUR_PUBLISHER_ID.open-shell-here)

Open **PowerShell**, **Command Prompt**, or **Git Bash** in any folder — straight from
the VS Code Explorer context menu.

![icon](icon.png)

## Why this exists

The built-in VS Code terminal depends on **ConPTY**, a Windows feature introduced in
Windows 10 1809 / Windows Server 2019 (build 17763). On older systems the terminal
panel fails to start with:

```
The terminal process failed to launch: A native exception occurred during launch
(Cannot launch conpty). Winpty has been removed.
```

This affects **Windows Server 2016 (build 14393)** and **Windows 10 1607**. VS Code
1.109 removed the Winpty fallback, so on those systems the built-in terminal does not
work at all.

Other terminal extensions do **not** solve this, because they still spawn the shell
through [`node-pty`](https://github.com/microsoft/node-pty) — the same library that
needs ConPTY. The same limitation applies to extensions that render a webview
terminal: the *display* is replaced, but the *process creation* path is identical.

This extension takes a different approach: it calls `child_process.spawn` on the
shell executable directly. No PTY is involved, so it works regardless of the OS age.

## Features

- Context menu entries in the Explorer for PowerShell, Command Prompt, and Git Bash
- Automatic detection of installed shells, including PowerShell 7 (`pwsh`)
- Custom shell profiles through a single setting
- Diagnostics in an Output channel, for machines where the terminal is the thing that is broken
- No telemetry, no network access, Windows-only

## Requirements

- Windows
- VS Code 1.90.0 or later
- At least one of: PowerShell 7, Windows PowerShell 5.1, Command Prompt, or Git for Windows

## Usage

### Explorer context menu

Right-click any folder in the Explorer and choose one of:

- **Open Shell Here: PowerShell**
- **Open Shell Here: Git Bash**
- **Open Shell Here: Command Prompt**

The new window opens with that folder as its working directory.

### Command Palette

The same commands are available from the Command Palette (`Ctrl+Shift+P`). With no
Explorer selection, they fall back to the first workspace folder.

## Configuration

### Custom profiles

Add this to your `settings.json` to launch your own shells:

```jsonc
{
    "openShellHere.profiles": {
        "My pwsh": {
            "path": "C:\\Program Files\\PowerShell\\7\\pwsh.exe",
            "args": ["-NoLogo", "-NoExit"]
        },
        "WSL": {
            "path": "C:\\Windows\\System32\\wsl.exe",
            "args": ["--cd", "${workspaceFolder}"]
        }
    }
}
```

Each key becomes its own `Open Shell Here: <name>` command. When this setting is
non-empty it **replaces** the built-in defaults.

## Diagnostics

If a shell fails to launch, open the **Output** panel (`Ctrl+Shift+Y`) and select
**Open Shell Here**. It logs the resolved executable, arguments, working directory,
any spawn error, and the launcher's exit code.

## Differences from the integrated terminal

This opens a separate OS window rather than a panel inside VS Code. So there is no
terminal tab bar, no split panes, no shell integration, and no in-editor
path detection. It is a workaround for an OS limitation, not a replacement for a
working integrated terminal.

If your OS supports ConPTY (Windows 10 1809+ or Server 2019+), you do not need this
extension — the built-in terminal works fine.

## Development

```powershell
git clone https://github.com/REPLACE_WITH_YOUR_GITHUB_USER/open-shell-here.git
cd open-shell-here
node --check extension.js     # syntax check
.\install.ps1                # install into the local VS Code
```

Then run **Developer: Reload Window** in VS Code.

### Project layout

| File | Purpose |
| --- | --- |
| `extension.js` | All extension logic |
| `package.json` | Extension manifest |
| `install.ps1` | Dev helper: verifies shells and installs locally |
| `register.ps1` | Dev helper: registers the extension without the Marketplace |
| `generate-icon.ps1` | Dev helper: regenerates the Marketplace icon |

## License

MIT — see [LICENSE](LICENSE).