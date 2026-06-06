param(
    [switch]$DryRun,
    [Alias("n")]
    [switch]$Preview,
    [string]$Folder
)

$ErrorActionPreference = "Stop"

$rules = @{
    ".jpg" = "Images"; ".jpeg" = "Images"; ".png" = "Images"; ".gif" = "Images"
    ".bmp" = "Images"; ".webp" = "Images"; ".svg" = "Images"; ".heic" = "Images"

    ".txt" = "Documents"; ".pdf" = "Documents"; ".doc" = "Documents"; ".docx" = "Documents"
    ".xls" = "Documents"; ".xlsx" = "Documents"; ".ppt" = "Documents"; ".pptx" = "Documents"
    ".md" = "Documents"; ".rtf" = "Documents"; ".csv" = "Documents"
    ".html" = "Documents"; ".htm" = "Documents"

    ".mp4" = "Videos"; ".mkv" = "Videos"; ".mov" = "Videos"; ".avi" = "Videos"
    ".webm" = "Videos"; ".wmv" = "Videos"; ".flv" = "Videos"

    ".mp3" = "Music"; ".wav" = "Music"; ".flac" = "Music"; ".aac" = "Music"
    ".ogg" = "Music"; ".m4a" = "Music"

    ".zip" = "Archives"; ".rar" = "Archives"; ".7z" = "Archives"; ".tar" = "Archives"
    ".gz" = "Archives"; ".xz" = "Archives"; ".bz2" = "Archives"

    ".exe" = "Installers"; ".msi" = "Installers"; ".pkg" = "Installers"
    ".dmg" = "Installers"; ".deb" = "Installers"; ".rpm" = "Installers"
    ".apk" = "Installers"; ".appimage" = "Installers"; ".msixbundle" = "Installers"

    ".torrent" = "Torrents"

    ".c" = "Code"; ".h" = "Code"; ".cpp" = "Code"; ".hpp" = "Code"
    ".py" = "Code"; ".js" = "Code"; ".ts" = "Code"; ".java" = "Code"
    ".cs" = "Code"; ".go" = "Code"; ".rs" = "Code"; ".swift" = "Code"
    ".json" = "Code"; ".xml" = "Code"; ".ini" = "Code"; ".yaml" = "Code"; ".yml" = "Code"
}

function Get-DefaultDownloadsFolder {
    $homeDir = [Environment]::GetFolderPath("UserProfile")
    if ([string]::IsNullOrWhiteSpace($homeDir)) {
        throw "Could not find your home folder. Pass a folder path explicitly."
    }
    return Join-Path $homeDir "Downloads"
}

function Get-Category {
    param([string]$Extension)

    if ([string]::IsNullOrWhiteSpace($Extension)) {
        return "Others"
    }

    $key = $Extension.ToLowerInvariant()
    if ($rules.ContainsKey($key)) {
        return $rules[$key]
    }

    return "Others"
}

function Get-UniqueDestination {
    param(
        [string]$Directory,
        [string]$Name
    )

    $destination = Join-Path $Directory $Name
    if (-not (Test-Path -LiteralPath $destination)) {
        return $destination
    }

    $baseName = [IO.Path]::GetFileNameWithoutExtension($Name)
    $extension = [IO.Path]::GetExtension($Name)

    for ($i = 1; $i -lt 10000; $i++) {
        $candidateName = "{0} ({1}){2}" -f $baseName, $i, $extension
        $candidate = Join-Path $Directory $candidateName
        if (-not (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }

    throw "Could not find a free filename for $Name"
}

$isDryRun = $DryRun -or $Preview
if ([string]::IsNullOrWhiteSpace($Folder)) {
    $Folder = Get-DefaultDownloadsFolder
}

$targetDir = (Resolve-Path -LiteralPath $Folder).Path
$moved = 0
$skipped = 0
$errors = 0

Write-Host ("{0} {1}" -f ($(if ($isDryRun) { "Previewing" } else { "Sorting" }), $targetDir))

Get-ChildItem -LiteralPath $targetDir -Force | ForEach-Object {
    if (-not $_.PSIsContainer -and $_.LinkType -eq $null) {
        $fileName = $_.Name
        try {
            $category = Get-Category $_.Extension
            $categoryDir = Join-Path $targetDir $category

            if (-not $isDryRun -and -not (Test-Path -LiteralPath $categoryDir)) {
                New-Item -ItemType Directory -Path $categoryDir | Out-Null
            }

            $destination = Get-UniqueDestination -Directory $categoryDir -Name $_.Name
            Write-Host ("{0} {1} -> {2}" -f ($(if ($isDryRun) { "Would move" } else { "Moving" }), $_.Name, $category))

            if (-not $isDryRun) {
                Move-Item -LiteralPath $_.FullName -Destination $destination
            }

            $script:moved++
        } catch {
            [Console]::Error.WriteLine(("Could not move '{0}': {1}" -f $fileName, $_.Exception.Message))
            $script:errors++
        }
    } else {
        $script:skipped++
    }
}

Write-Host ""
Write-Host ("Done. {0}: {1}, skipped: {2}, errors: {3}" -f ($(if ($isDryRun) { "would move" } else { "moved" }), $moved, $skipped, $errors))

if ($errors -gt 0) {
    exit 1
}
