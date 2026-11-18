# Copies every Seekers screenshot into this site, rebuilds manifest.json and pushes to GitHub Pages.
# Usage:  & "C:\Users\manny\Documents\SeekersGallery\SyncGallery.ps1"            # sync + commit + push
#         & "C:\Users\manny\Documents\SeekersGallery\SyncGallery.ps1" -NoPush    # sync + commit only
# Tabs: maps (default), characters, history. Same split as Docs/Gallery/BuildGallery.ps1.
# To retire an old map shot from the site (e.g. after a recheck tour), add its project path
# to hidden.txt (one per line); the file stays in the project.
param([switch]$NoPush)

$src  = "C:\Users\manny\Documents\Seekers"
$site = "C:\Users\manny\Documents\SeekersGallery"
$imgRoot = Join-Path $site "img"

function Get-Tab([string]$p) {
  if ($p -match '^Docs/Screens/Chats/Build_chat/|^Docs/Previews/Phase\d|^Blender/_prev/|^Art/Icons/|^Docs/PassIcons/|^Docs/ShenWheel|^Docs/Screens/Archive/') { return "history" }
  if ($p -match 'punch_onion|/Bear/|/Beasts/|/Wildlife/|/Onion/|/Characters/|^Docs/Screens/(beasts|BossIntros|shenrelease)/|^Docs/Screens/Chats/(ShenRelease|CombatAnimation|BeastAnimations|BossIntros)_chat/') { return "characters" }
  return "maps"
}

$hidden = @(); $hiddenFile = Join-Path $site "hidden.txt"
if (Test-Path $hiddenFile) { $hidden = @(Get-Content $hiddenFile | Where-Object { $_ -and -not $_.StartsWith("#") } | ForEach-Object { $_.Trim() }) }

# Only images of Seekers itself: reference/inspiration folders are skipped.
$files = Get-ChildItem -Path $src -Recurse -Include *.png,*.jpg,*.jpeg,*.webp -File |
  Where-Object { $_.FullName -notmatch '\\node_modules\\|\\.git\\|\\Docs\\Gallery\\|\\lihfolk-tiktok\\|\\momentumcash\\|\\References\\' } |
  Sort-Object LastWriteTime -Descending

$items = @(); $keep = @{}
foreach ($f in $files) {
  $rel = $f.FullName.Substring($src.Length + 1) -replace '\\', '/'
  if ($hidden -contains $rel) { continue }
  $dest = Join-Path $imgRoot ($rel -replace '/', '\')
  $keep[$dest.ToLower()] = $true
  if (-not (Test-Path $dest) -or (Get-Item $dest).Length -ne $f.Length) {
    New-Item -ItemType Directory -Force (Split-Path $dest -Parent) | Out-Null
    Copy-Item $f.FullName $dest -Force
  }
  $items += [pscustomobject]@{ p = $rel; g = ((Split-Path $rel -Parent) -replace '\\', '/'); n = $f.BaseName; t = $f.LastWriteTime.ToString('yyyy-MM-ddTHH:mm'); k = (Get-Tab $rel) }
}
# Remove site copies of images that were hidden or deleted.
if (Test-Path $imgRoot) { Get-ChildItem $imgRoot -Recurse -File | Where-Object { -not $keep.ContainsKey($_.FullName.ToLower()) } | Remove-Item -Force }

$manifest = [pscustomobject]@{ updated = (Get-Date).ToString('yyyy-MM-ddTHH:mm'); items = $items }
[IO.File]::WriteAllText((Join-Path $site "manifest.json"), (ConvertTo-Json -InputObject $manifest -Depth 4 -Compress))

Push-Location $site
git add -A | Out-Null
$changes = git status --porcelain
if ($changes) {
  git commit -q -m "Gallery update: $($items.Count) images"
  if (-not $NoPush) { git push -q }
  "Synced $($items.Count) images ($(@($items | Where-Object k -eq 'maps').Count) maps, $(@($items | Where-Object k -eq 'characters').Count) characters, $(@($items | Where-Object k -eq 'history').Count) history)$(if ($NoPush) { ', not pushed' } else { ' and pushed' })."
} else { "No changes; $($items.Count) images already on the site." }
Pop-Location
