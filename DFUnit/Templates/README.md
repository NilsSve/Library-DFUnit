# Do not compile anything in this folder

These files carry a `.template` suffix on purpose. They are **not** part of the DFUnit
library and they are **not** on any AppSrc search path, so adding one as a project does
nothing at all — the Studio simply has nothing to compile and reports no error.

They are the starter files your **own** workspace owns. Copy them out first:

```
SetupUnitTests.cmd
```

in the package folder — or, from your workspace folder:

```
powershell -NoProfile -ExecutionPolicy Bypass -File (Resolve-Path .\DfPkg\*DFUnit*\SetupUnitTests.ps1)[0]
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
