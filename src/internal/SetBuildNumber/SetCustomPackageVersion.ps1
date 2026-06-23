param(
    [Parameter(Mandatory = $true)]
    [string]$Root,

    [string]$Prefix = 'cl'
)

$ErrorActionPreference = 'Stop'

$rootPath = [System.IO.Path]::GetFullPath($Root)
$tag = (& git -C $rootPath describe --tags --abbrev=0).Trim()
$baseVersion = $tag -replace '^v', ''
$height = (& git -C $rootPath rev-list --count "$tag..HEAD").Trim()
$sha = (& git -C $rootPath rev-parse HEAD).Trim()
$shortSha = (& git -C $rootPath rev-parse --short HEAD).Trim()

if ($baseVersion -notmatch '^(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)$') {
    throw "Unsupported base version '$baseVersion'. Expected major.minor.patch."
}

$major = $Matches['major']
$minor = $Matches['minor']
$patch = $Matches['patch']
$packagePatch = [int]$patch + 1
$packageBaseVersion = "$major.$minor.$packagePatch"
$packageVersion = "$packageBaseVersion-$Prefix.$height"
$dashLabel = "-$Prefix.$height"

function Update-XmlElementText([string]$Path, [hashtable]$Values) {
    $content = [System.IO.File]::ReadAllText($Path)

    foreach ($name in $Values.Keys) {
        $escapedName = [regex]::Escape($name)
        $escapedValue = [System.Security.SecurityElement]::Escape([string]$Values[$name])
        $content = [regex]::Replace($content, "<$escapedName>.*?</$escapedName>", "<$name>$escapedValue</$name>")
    }

    [System.IO.File]::WriteAllText($Path, $content)
}

$someVerProps = Join-Path $rootPath 'build\SomeVerInfo.props'
$directoryPackages = Join-Path $rootPath 'Directory.Packages.props'
$globalJson = Join-Path $rootPath 'global.json'

Update-XmlElementText $someVerProps @{
    SomeVerInfoMajor = $major
    SomeVerInfoMinor = $minor
    SomeVerInfoPatch = $patch
    SomeVerInfoHeight = $height
    SomeVerInfoFullHeight = $height
    SomeVerInfoLabel = "$Prefix.$height"
    SomeVerInfoDashLabel = $dashLabel
    SomeVerInfoSha = $sha
    SomeVerInfoShortSha = $shortSha
    SomeVerInfoVersion = $packageVersion
    FileVersion = "$major.$minor.$patch.$height"
    InformationalVersion = $packageVersion
    PackageVersion = $packageVersion
}

$packagesContent = [System.IO.File]::ReadAllText($directoryPackages)
$packagesContent = [regex]::Replace(
    $packagesContent,
    '(<PackageVersion Include="(?:WixToolset|WixInternal)\.[^"]+" Version=")[^"]+("\s*/>)',
    "`${1}$packageVersion`${2}")
[System.IO.File]::WriteAllText($directoryPackages, $packagesContent)

$globalJsonContent = [System.IO.File]::ReadAllText($globalJson)
$globalJsonContent = [regex]::Replace(
    $globalJsonContent,
    '("WixToolset\.Sdk"\s*:\s*")[^"]+(")',
    "`${1}$packageVersion`${2}")
[System.IO.File]::WriteAllText($globalJson, $globalJsonContent)

Write-Host "CustomPackageVersion=$packageVersion"
