# Do not compile anything in this folder

These files carry a `.template` suffix on purpose.

DataFlex resolves a project name against the **workspace's own** `AppSrc` path only, never
against a library's — so no file inside this package can be added as a project, wherever in
the package it sits. Add one anyway and the Studio reports no error at all: it simply does
nothing. (`df-cli` at least says *"Project ... could not be found in any AppSrc paths"*.)

They are the starter files your **own** workspace owns. Copy them out first:

```
SetupUnitTests.bat
```

in this folder's parent, with your workspace folder as the working directory — or, if you
would rather not go looking for it (the package lives under the workspace's `DfPkg\` or in
`%ProgramData%\DataFlex\Packages\Cache\`, depending on how it was installed):

```
powershell -NoProfile -ExecutionPolicy Bypass -Command "& (Get-ChildItem 'DfPkg', (Join-Path $env:ProgramData 'DataFlex\Packages\Cache') -Directory -Filter '*DFUnit*' -EA 0 | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | ForEach-Object { Join-Path $_.FullName 'SetupUnitTests.ps1' })"
```

That drops them into your workspace's `AppSrc` with the `.template` suffix stripped and
the read-only attribute cleared (a package checkout is read-only — the package manager
owns it and replaces it on every update, so nothing you write may live here).

Then add `AppSrc\UnitTests.src` to your workspace's project list and compile *that*.

| Template | Becomes | What it is |
|---|---|---|
| `UnitTests.src.template` | `AppSrc\UnitTests.src` | The test program. Compile and run this one. |
| `UnitTests.cfg.template` | `AppSrc\UnitTests.cfg` | Its project settings — 64-bit, manifests off for build servers. |
| `oUnit_Tests.pkg.template` | `AppSrc\oUnit_Tests.pkg` | The root fixture — the only file you edit to add tests. |
| `oExample-Tests.pkg.template` | `AppSrc\oExample-Tests.pkg` | A worked example to copy, rename, and eventually delete. |
