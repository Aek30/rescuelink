param(
    [string]$Source = 'assets/maps/rmutt-source.osm',
    [string]$Destination = 'assets/maps/rmutt.json'
)
$ErrorActionPreference = 'Stop'
[xml]$osm = Get-Content -Raw -LiteralPath $Source
$nodes = @{}
foreach ($node in $osm.osm.node) {
    $nodes[[string]$node.id] = @([double]$node.lon, [double]$node.lat)
}
$features = @()
foreach ($way in $osm.osm.way) {
    $tags = @{}
    foreach ($tag in $way.tag) { $tags[[string]$tag.k] = [string]$tag.v }
    $kind = if ($tags.ContainsKey('highway')) { 'road' }
        elseif ($tags.ContainsKey('building')) { 'building' }
        elseif ($tags['natural'] -eq 'water' -or $tags.ContainsKey('waterway')) { 'water' }
        elseif ($tags['amenity'] -eq 'university') { 'campus' }
        elseif ($tags.ContainsKey('leisure') -or $tags.ContainsKey('landuse')) { 'land' }
        else { $null }
    if (-not $kind) { continue }
    $points = @()
    foreach ($ref in $way.nd) {
        if ($nodes.ContainsKey([string]$ref.ref)) { $points += ,$nodes[[string]$ref.ref] }
    }
    if ($points.Count -lt 2) { continue }
    $name = if ($tags['name:th']) { $tags['name:th'] } else { $tags['name'] }
    $features += @{
        id = [string]$way.id; kind = $kind; name = $name
        roadClass = $tags['highway']; points = $points
        closed = ([string]$way.nd[0].ref -eq [string]$way.nd[-1].ref)
    }
}
$map = @{
    name = 'มทร.ธัญบุรี • คลองหก'; bounds = @(100.719,14.026,100.738,14.045)
    attribution = '© OpenStreetMap contributors • ODbL 1.0'
    source = 'https://api.openstreetmap.org/api/0.6/map?bbox=100.719,14.026,100.738,14.045'
    license = 'https://opendatacommons.org/licenses/odbl/1-0/'
    extractedAt = '2026-10-18'; features = $features
}
$map | ConvertTo-Json -Depth 8 -Compress | Set-Content -LiteralPath $Destination -Encoding utf8
Write-Output "Prepared $($features.Count) map features."
