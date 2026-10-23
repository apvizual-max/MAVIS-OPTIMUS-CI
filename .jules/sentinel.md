## 2024-05-24 - Path Traversal Risk in meta-prompt.ps1
**Vulnerability:** The script `meta-prompt.ps1` accepts an `-Output` parameter that is combined with `$BASE` using `Join-Path`. `Join-Path` in PowerShell doesn't inherently prevent path traversal if the user provides a path containing multiple `..`, which could write the output file to arbitrary locations on the system.
**Learning:** `Join-Path` and file creation functions in powershell are vulnerable to directory traversal via `$Output`.
**Prevention:** Sanitize the input path or resolve the absolute path and ensure it starts with the intended base directory.
