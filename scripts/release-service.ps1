param(
  [string]$Version = "",
  [ValidateSet("major","minor","patch","none")][string]$Bump = "patch",
  [switch]$DryRun,
  [switch]$SkipRepoCreate,
  [switch]$ForceReplace,
  [switch]$NoTagPush
)

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\.." )).Path
$releaseScript = Join-Path $repoRoot "release-service.ps1"

$params = @{
  Service = "dataset_thailand"
  Bump    = $Bump
}
if ($Version -and $Version.Trim().Length -gt 0) {
  $params.Version = $Version.Trim()
}
if ($DryRun) { $params.DryRun = $true }
if ($SkipRepoCreate) { $params.SkipRepoCreate = $true }
if ($ForceReplace) { $params.ForceReplace = $true }
if ($NoTagPush) { $params.NoTagPush = $true }

& $releaseScript @params