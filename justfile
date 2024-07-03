set shell := ["pwsh", "-NoProfile", "-Command"]

default: build run_once

@build:
	'Buildilng Module' | Write-Host -ForegroundColor DarkMagenta
	Invoke-MTBuild 
	
@pester_test:
	'Pester tests' | Write-Host -ForegroundColor DarkMagenta
	Invoke-MTTest

@run_once:
	'Quick run Script' | Write-Host -ForegroundColor DarkMagenta
	.\run.ps1
	
@final_Step:
	'just workflow completed' | Write-Host -ForegroundColor DarkMagenta
