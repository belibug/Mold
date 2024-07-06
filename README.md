# Mold

Mold is a fast and powerful templating and cloning engine for PowerShell (and beyond!)

## Pending

- [X] Ask for project details while create template
- [X] Invoke MOLD by name instead of path
- [ ] Build PSData Extension logic just like `plaster`
- [ ] JSON Schema and validation

## Complete

- `New-MoldManifest` : Can generate MoldManifest.json easily
- `Update-MoldManifest` : Can update existing MoldManifest.json
- `Invoke-Mold` : Main command to involke mold template
- `Get-MoldTemplates` : Get all mold templates
- Both Invoke and Get now supports autocompletition by NAME
- Load local Templates using env path (; Semicolon seaparted folder path) - MOLD_TEMPLATES

### In-Progress - Pending