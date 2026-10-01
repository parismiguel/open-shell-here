# Changelog

All notable changes to this extension are documented here.
This project adheres to [Semantic Versioning](https://semver.org/).

## [0.1.0]

### Added

- Explorer context menu commands to open PowerShell, Command Prompt, or Git Bash
  in the right-clicked folder.
- The same commands available from the Command Palette, falling back to the first
  workspace folder when nothing is selected.
- Automatic detection of installed shells, including PowerShell 7 (`pwsh.exe`)
  and Windows PowerShell 5.1.
- `openShellHere.profiles` setting for defining custom shell executables and
  arguments. Commands re-register when the setting changes.
- An `Open Shell Here` output channel logging the resolved executable, arguments,
  working directory, spawn errors, and launcher exit codes.