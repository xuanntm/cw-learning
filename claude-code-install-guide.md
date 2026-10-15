# Claude Code CLI — Windows Install Guide

How Claude Code was installed for the terminal on this machine (Windows 11 Enterprise, x64) on 2026-10-15. Installed version: **2.1.300**.

> The Claude desktop app does **not** add the `claude` command to the terminal. The CLI is installed separately.

## 1. Prerequisites

| Requirement | How to check | Notes |
|---|---|---|
| Windows 10/11, 64-bit | `(Get-CimInstance Win32_OperatingSystem).Caption` | |
| Git for Windows (includes Git Bash) | `git --version` | Required on Windows. Install from <https://git-scm.com/download/win> or `winget install Git.Git` |
| Network access to `claude.ai`, `downloads.claude.ai`, `storage.googleapis.com`, `api.anthropic.com` | `Invoke-WebRequest https://claude.ai/install.ps1 -UseBasicParsing -Method Head` | Any HTTP response counts as reachable; a timeout means a proxy or firewall is blocking it |
| Node.js / npm | — | **Not needed.** The native installer ships a standalone `.exe` |
| Admin rights | — | **Not needed.** It installs per user |

## 2. Install

Open **PowerShell** (not cmd) and run:

```powershell
irm https://claude.ai/install.ps1 | iex
```

The installer puts the program at `%USERPROFILE%\.local\bin\claude.exe`.

## 3. Add to PATH (if the installer warns about it)

If you see *"…\.local\bin is not in your PATH"*, add it to the **user** PATH. Run this in PowerShell; it appends and keeps your existing entries:

```powershell
$bin = "$env:USERPROFILE\.local\bin"
$p = [Environment]::GetEnvironmentVariable('Path', 'User')
if (($p -split ';') -notcontains $bin) {
    [Environment]::SetEnvironmentVariable('Path', ($p.TrimEnd(';') + ';' + $bin), 'User')
}
```

Alternatively, use the GUI: *System Properties → Environment Variables → User variables → Path → Edit → New* and add `%USERPROFILE%\.local\bin`.

> Don't use `setx PATH ...`: it truncates long PATH values.

**Close and reopen the terminal** afterwards. Windows that are already open won't see the change.

## 4. Verify

```powershell
claude --version     # expect: 2.1.300 (Claude Code) or newer
claude doctor        # expect: "No installation issues found."
```

## 5. First run and sign-in

```powershell
cd C:\Users\SpencerNGUYEN\Documents\WS\cw-learning
claude
```

The first time, a browser window opens so you can sign in with your Claude account (or run `claude auth login`). Inside a session, `/doctor` runs a fuller setup check.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `claude : The term 'claude' is not recognized` | PATH isn't set, or the terminal predates the change. Redo step 3 and open a **new** terminal |
| Claude Code says it can't find Git Bash | Git is installed per user here (`%LOCALAPPDATA%\Programs\Git`). Point to it once, then reopen the terminal: `setx CLAUDE_CODE_GIT_BASH_PATH "%LOCALAPPDATA%\Programs\Git\bin\bash.exe"` |
| `claude doctor` shows *Auto-updates: disabled (set by env: DISABLE_AUTOUPDATER)* | Only happens when run from inside the Claude desktop app. A normal terminal auto-updates |
| Download fails or times out | The company proxy or firewall is blocking it. Ask IT to allow the hosts in section 1 |

## Update / uninstall

```powershell
claude update                                        # manual update
Remove-Item "$env:USERPROFILE\.local\bin\claude.exe"  # uninstall (then remove the PATH entry)
```

Settings and sign-in are kept in `%USERPROFILE%\.claude\` and `%USERPROFILE%\.claude.json`. Delete them only for a full reset.
