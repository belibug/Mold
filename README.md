# Mold

Mold is a fast and powerful templating and cloning engine for PowerShell (and beyond!)

## Pending

- [ ] Build PSData Extension logic just like `plaster`
- [ ] Handle config file so user can keep extensions in custom path, since not everyone uses `powershell gallery`
- [ ] Invoke MOLD by name instead of path
- [ ] JSON Schema and validation

## Complete

- `New-MoldManifest` : Can generate MoldManifest.json easily
- `Update-MoldManifest` : Can update existing MoldManifest.json
- `Invoke-Mold` : Main command to involke mold template