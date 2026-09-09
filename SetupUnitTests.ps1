<#
.SYNOPSIS
    Copies the DFUnit unit-test scaffold into a DataFlex workspace.

.DESCRIPTION
    DFUnit installs as a DataFlex 26 package, which means its files live under the
    consuming workspace's DfPkg folder and are read-only - the package manager owns
    them and overwrites them on every update.

    The test program and the test files, though, belong to your workspace and have to
    be writable - and the program in particular MUST live in your own AppSrc, because
    DataFlex resolves a project name against the workspace's own AppSrc path only,
    never against a library's. So this script copies all four out of the package and
    clears the read-only attribute they inherit from it:

        UnitTests.src       the test program - add it to the workspace's projects
        UnitTests.cfg       its project settings: 64-bit, manifests off
        oUnit_Tests.pkg     the root fixture - one Use line per test file
        oExample-Tests.pkg  a worked example to copy for your own tests

    Existing files are never overwritten unless -Force is given.

.PARAMETER Workspace
    The workspace folder to scaffold. Defaults to the current directory.

.PARAMETER AppSrc
    Where to put the files. Defaults to the workspace's AppSrc folder, read from
    Config.ws when it is not simply <Workspace>\AppSrc.

.PARAMETER AddProject
    Also add "UnitTests.src" to the projects array of the workspace's .sws file.
    Only for a DataFlex 26 (JSON) workspace; the edit is a textual insert, so the
    rest of the file keeps its formatting. Without this switch the script just
    prints what to add.

.PARAMETER Force
    Overwrite scaffold files that already exist.

.EXAMPLE
    # From the workspace folder, with DFUnit already installed as a package:
    powershell -NoProfile -ExecutionPolicy Bypass -File (Resolve-Path .\DfPkg\*DFUnit*\SetupUnitTests.ps1)[0]

.EXAMPLE
    & "C:\Projects\DF26\MyApp\DfPkg\NilsSve_DFUnit-abc123\SetupUnitTests.ps1" -Workspace "C:\Projects\DF26\MyApp" -AddProject
#>
[CmdletBinding()]
param(
    [string] $Workspace = (Get-Location).Path,
    [string] $AppSrc,
    [switch] $AddProject,
    [switch] $Force
)

$ErrorActionPreference = 'Stop'

function Fail([string] $message) {
    Write-Host "ERROR: $message" -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------- the workspace
if (-not (Test-Path -LiteralPath $Workspace -PathType Container)) {
    Fail "Workspace folder not found: $Workspace"
}
$Workspace = (Resolve-Path -LiteralPath $Workspace).Path

# A folder is the DFUnit package only if it holds the templates themselves. Testing for a
# folder called Templates is not enough - a workspace may well have one of its own.
function Test-IsPackage([string] $folder) {
    if (-not $folder) { return $false }
    return (Test-Path -LiteralPath (Join-Path $folder 'Templates\UnitTests.src.template') -PathType Leaf)
}

function Test-Within([string] $path, [string] $root) {
    if (-not $root) { return $false }
    $r = $root.TrimEnd('\')
    return ($path.TrimEnd('\') -eq $r -or
            $path.StartsWith($r + '\', [StringComparison]::OrdinalIgnoreCase))
}

# ---------------------------------------------------------------- find the package
# The package declares SetupUnitTests.bat/.ps1 in its manifest's "install" list, so a copy
# of this script also lands in the consuming workspace's own folder - which is where it is
# actually easy to find. That copy has no Templates beside it, so look for the package:
# under the workspace's DfPkg first, then the machine-wide package cache. Newest wins.
$pkgRoot = $null
if (Test-IsPackage $PSScriptRoot) {
    $pkgRoot = $PSScriptRoot
}
else {
    $searchIn = @((Join-Path $Workspace 'DfPkg'),
                  (Join-Path $env:ProgramData 'DataFlex\Packages\Cache'))
    $pkgRoot = Get-ChildItem -LiteralPath $searchIn -Directory -Filter '*DFUnit*' -ErrorAction SilentlyContinue |
               Sort-Object LastWriteTime -Descending |
               Where-Object { Test-IsPackage $_.FullName } |
               Select-Object -First 1 -ExpandProperty FullName
    if ($pkgRoot) {
        Write-Host ""
        Write-Host "Using the DFUnit package at:" -ForegroundColor Yellow
        Write-Host "  $pkgRoot"
    }
}
if (-not $pkgRoot) {
    Fail ("Could not find the DFUnit package.`nLooked beside this script, in " +
          "$Workspace\DfPkg and in $env:ProgramData\DataFlex\Packages\Cache.`n" +
          "Is the package installed in this workspace?")
}

# Double-clicked inside the package folder, the working directory IS the package, and the
# default would scaffold into it - read-only, and owned by the package manager. The
# workspace is knowable there: a checkout lives at <workspace>\DfPkg\<name>\, so two
# levels up is the workspace. Use it when it looks like one, and complain only when there
# is nothing above (a package resolved into the machine-wide cache has no workspace).
if ((-not $PSBoundParameters.ContainsKey('Workspace')) -and (Test-Within $Workspace $pkgRoot)) {
    $guess = Split-Path -Parent (Split-Path -Parent $pkgRoot)
    if ($guess -and (Test-Path -LiteralPath $guess -PathType Container) -and
        (Get-ChildItem -LiteralPath $guess -Filter '*.sws' -File -ErrorAction SilentlyContinue)) {
        $Workspace = (Resolve-Path -LiteralPath $guess).Path
        Write-Host ""
        Write-Host "Run from inside the package, so using the workspace above it:" -ForegroundColor Yellow
        Write-Host "  $Workspace"
    }
}

if (Test-Within $Workspace $pkgRoot) {
    Fail ("That is the DFUnit package folder, not a workspace:`n  $Workspace`n" +
          "Run this from your own workspace folder, or pass -Workspace <folder>.")
}

# A DataFlex workspace has a .sws file. Without one we are almost certainly pointed at
# the wrong folder, and copying source files there would just make a mess.
if (-not (Get-ChildItem -LiteralPath $Workspace -Filter '*.sws' -File)) {
    Fail ("No .sws file in:`n  $Workspace`n" +
          "That does not look like a DataFlex workspace. Run this from your workspace" +
          " folder, or pass -Workspace <folder>.")
}

$templates = Join-Path $pkgRoot 'Templates'

# ---------------------------------------------------------------- the AppSrc folder
if (-not $AppSrc) {
    $AppSrc = Join-Path $Workspace 'AppSrc'
    if (-not (Test-Path -LiteralPath $AppSrc -PathType Container)) {
        # Not the conventional folder - ask Config.ws where AppSrc actually is.
        $config = @(Get-ChildItem -LiteralPath $Workspace -Filter 'Config.ws' -Recurse -Depth 1 -File -ErrorAction SilentlyContinue) |
                  Select-Object -First 1
        if ($config) {
            $line = Select-String -LiteralPath $config.FullName -Pattern '^\s*AppSrcPath\s*=\s*(.+?)\s*$' |
                    Select-Object -First 1
            if ($line) {
                # AppSrcPath may list several folders separated by ';' - the first is ours.
                $first = ($line.Matches[0].Groups[1].Value -split ';')[0].Trim()
                $AppSrc = [System.IO.Path]::GetFullPath((Join-Path $Workspace $first))
            }
        }
    }
}
if (-not (Test-Path -LiteralPath $AppSrc -PathType Container)) {
    Fail "AppSrc folder not found: $AppSrc`nPass -AppSrc <folder> to say where the workspace's source files live."
}
$AppSrc = (Resolve-Path -LiteralPath $AppSrc).Path

Write-Host ""
Write-Host "DFUnit scaffold" -ForegroundColor Cyan
Write-Host "  from : $templates"
Write-Host "  into : $AppSrc"
Write-Host ""

# ---------------------------------------------------------------- copy
$copied  = 0
$skipped = @()
# The templates carry a .template suffix inside the package, so that nothing in the
# read-only package folder looks like a source file you could add as a project. The
# suffix is stripped on the way out.
$sources = @(Get-ChildItem -LiteralPath $templates -File -Filter '*.template')
if ($sources.Count -eq 0) {
    Fail "No *.template files found in $templates"
}
foreach ($file in $sources) {
    $name   = $file.Name -replace '\.template$', ''
    $target = Join-Path $AppSrc $name
    if ((Test-Path -LiteralPath $target) -and (-not $Force)) {
        $skipped += $name
        Write-Host ("  skipped  {0}  (already exists - pass -Force to overwrite)" -f $name) -ForegroundColor Yellow
        continue
    }
    Copy-Item -LiteralPath $file.FullName -Destination $target -Force
    # The package folder is read-only, and Copy-Item carries that attribute across.
    Set-ItemProperty -LiteralPath $target -Name IsReadOnly -Value $false
    $copied++
    Write-Host ("  copied   {0}" -f $name) -ForegroundColor Green
}

# ---------------------------------------------------------------- the .sws project entry
$swsFiles = @(Get-ChildItem -LiteralPath $Workspace -Filter '*.sws' -File)
$sws = $null
if ($swsFiles.Count -eq 1) { $sws = $swsFiles[0] }

if ($AddProject) {
    if (-not $sws) {
        Write-Host ""
        if ($swsFiles.Count -eq 0) {
            Write-Host "  -AddProject skipped: no .sws file in $Workspace" -ForegroundColor Yellow
        } else {
            Write-Host ("  -AddProject skipped: {0} .sws files in {1} - add the project in the Studio instead." -f $swsFiles.Count, $Workspace) -ForegroundColor Yellow
        }
    } else {
        $text = [System.IO.File]::ReadAllText($sws.FullName)
        if ($text -notmatch '"projects"\s*:\s*\[') {
            Write-Host ""
            Write-Host ("  -AddProject skipped: {0} has no JSON `"projects`" array (a DataFlex 25 INI workspace?)." -f $sws.Name) -ForegroundColor Yellow
        }
        elseif ($text -match '"UnitTests\.src"') {
            Write-Host ""
            Write-Host ("  {0} already lists UnitTests.src" -f $sws.Name) -ForegroundColor Green
        }
        else {
            # Textual insert before the array's closing bracket, so the rest of the
            # file - key order, indentation, the dependency list - is untouched.
            $pattern = '(?s)("projects"\s*:\s*\[)(.*?)(\r?\n?[ \t]*\])'
            $updated = [System.Text.RegularExpressions.Regex]::Replace($text, $pattern, {
                param($m)
                $body = $m.Groups[2].Value
                if ($body.Trim().Length -eq 0) {
                    # Empty array.
                    # An empty array has no existing entry to copy indentation from,
                    # and no newline before its bracket either - supply both.
                    return $m.Groups[1].Value + "`n        `"UnitTests.src`"`n    " + $m.Groups[3].Value.TrimStart("`r", "`n", " ", "`t")
                }
                # Reuse the indentation of the last existing entry.
                $indent = '        '
                if ($body -match '(?m)^([ \t]+)"') { $indent = $matches[1] }
                return $m.Groups[1].Value + $body.TrimEnd() + ",`n" + $indent + "`"UnitTests.src`"" + $m.Groups[3].Value
            }, 1)
            [System.IO.File]::WriteAllText($sws.FullName, $updated)
            Write-Host ""
            Write-Host ("  added UnitTests.src to {0}" -f $sws.Name) -ForegroundColor Green
        }
    }
}

# ---------------------------------------------------------------- what next
$alreadyAProject = $false
if ($sws) {
    $alreadyAProject = ([System.IO.File]::ReadAllText($sws.FullName) -match '"UnitTests\.src"')
}

Write-Host ""
Write-Host "Next:" -ForegroundColor Cyan
if ($alreadyAProject) {
    Write-Host ("  1. {0} already lists UnitTests.src as a project - reopen the workspace in" -f $sws.Name)
    Write-Host "     the Studio if it is open, so it picks the project up."
} elseif ($sws) {
    Write-Host ("  1. Add UnitTests.src to the projects of {0}" -f $sws.Name)
    Write-Host "     (Studio: right-click the workspace > Add > Add Project, or re-run this"
    Write-Host "      script with -AddProject to have it edited for you.)"
} else {
    Write-Host "  1. Add UnitTests.src to the workspace's project list."
}
Write-Host "  2. Compile and run UnitTests - the four example tests should pass."
Write-Host "  3. Write your own: copy oExample-Tests.pkg to o<Subject>-Tests.pkg and add"
Write-Host "     a Use line for it in oUnit_Tests.pkg. That is the only file you edit."
Write-Host ""
Write-Host "  Unattended run (for a build server):"
Write-Host "     Programs\UnitTests64.exe -c -o test_results.xml"
Write-Host "     exit code 0 = all passed, -1 = at least one test failed."
Write-Host ""

if ($skipped.Count -gt 0) {
    Write-Host ("Left alone: {0}" -f ($skipped -join ', ')) -ForegroundColor Yellow
    Write-Host ""
}
if ($copied -eq 0 -and $skipped.Count -eq 0) {
    Fail "No template files were found to copy."
}
