## 2026-10-12 - Path Traversal Prevention in PowerShell Scripts
**Vulnerability:** Found a potential path traversal vulnerability in `scripts/meta-prompt.ps1` where the `-Output` parameter could be manipulated to write files outside of the intended directory tree.
**Learning:** This existed because `Join-Path` directly concatenated user input without validating if the resolved path remained within the intended base directory limits. PowerShell scripts taking user input for file paths need strict validation.
**Prevention:** Avoid path traversal by resolving both the base directory and the target directory using `[System.IO.Path]::GetFullPath()`, ensuring the base directory ends with a separator, and then validating that the resolved target path starts with the base path.
