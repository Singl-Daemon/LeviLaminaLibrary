class File {
    static [void] CleanWorkspace() {
        $cleanItems = [System.Collections.Generic.List[string]]@(
            "LeviLamina.zip", "LeviLamina", 
            "LeviLamina.def", "LeviLamina.lib", "SDK", 
            "llvm.zip", "LeviLamina-src.zip"
        )

        $cleanItems | ForEach-Object {
            if (Test-Path $_) {
                $ProgressPreference = 'SilentlyContinue'
                Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host ("[File] Removed: {0}" -f $_)
            }
        }
    }

    static [void] EnsureDirectory([string]$path) {
        if (-not (Test-Path $path)) {
            New-Item -ItemType Directory -Path $path | Out-Null
        }
    }

    static [void] CopyHeaders(
        [string]$sourceRoot,
        [string]$sourceSubDir,
        [string]$targetSubDir
    ) {
        $ProgressPreference = 'SilentlyContinue'
        $sourcePath = Join-Path $sourceRoot $sourceSubDir
        [File]::EnsureDirectory("./SDK")
        $targetBase = Join-Path (Get-Item "./SDK").FullName "include"
        [File]::EnsureDirectory($targetBase)
        $allDirs = Get-ChildItem $sourcePath -Recurse -Directory | ForEach-Object {
            $_.FullName.Substring($sourceRoot.Length + $sourceSubDir.Length)
        }
        $allDirs | ForEach-Object {
            [File]::EnsureDirectory((Join-Path $targetBase $_))
        }
        Get-ChildItem $sourcePath -Recurse -Filter *.h | ForEach-Object -Parallel {
            $targetDir = Join-Path $using:targetBase $_.DirectoryName.Substring($using:sourceRoot.Length + $using:sourceSubDir.Length)
            Copy-Item $_.FullName $targetDir -ErrorAction Stop
        } -ThrottleLimit 8
    }
}

class Network {
    static [bool] DownloadFile(
        [string]$url,
        [string]$outputPath,
        [int]$retries
    ) {
        for ($i = 1; $i -le $retries; $i++) {
            try {
                Invoke-WebRequest -Uri $url -OutFile $outputPath -UseBasicParsing
                Write-Host "[Network] Downloaded: $outputPath"
                return $true
            }
            catch {
                Write-Warning "[Network] Attempt $i failed: $($_.Exception.Message)"
                if ($i -eq $retries) { return $false }
                Start-Sleep -Seconds (5 * $i)
            }
        }
        return $false
    }
}

class Archive {
    static [void] Extract(
        [string]$zipPath,
        [string]$destination
    ) {
        Add-Type -Assembly System.IO.Compression.FileSystem
        [File]::EnsureDirectory($destination)
        try {
            if (Test-Path $destination) {
                Remove-Item "$destination\*" -Recurse -Force
            }
            [System.IO.Compression.ZipFile]::ExtractToDirectory(
                (Resolve-Path $zipPath).Path,
                (Resolve-Path $destination).Path
            )
            Write-Host "[Archive] Extracted: $zipPath => $destination"
        }
        catch {
            Write-Error "[Archive] Extraction failed: $_"
            throw
        }
    }
}
class Build {
    static [void] GenerateLibraryDefinitions() {
        $llvmBinPath = Join-Path (Get-Item "./llvm").FullName "llvm-mingw-20250114-ucrt-x86_64/bin"
        $dllPath = Join-Path (Get-Item "./LeviLamina").FullName "LeviLamina/LeviLamina.dll"

        $genDef = Join-Path $llvmBinPath "gendef.exe"
        & $genDef $dllPath | Out-Null

        $dllTool = Join-Path $llvmBinPath "dlltool.exe"
        & $dllTool -D $dllPath -d "LeviLamina.def" -l "LeviLamina.lib" | Out-Null
    }

    static [void] CopyLib() {
        $libDir = Join-Path (Get-Item "./SDK").FullName "lib"
        [File]::EnsureDirectory($libDir)
        Move-Item "./LeviLamina.lib" $libDir -Force
    }
    static [void] generateDepsList() {
        $srcSubDir = (Get-ChildItem -Path "./LeviLamina/src" -Directory | Select-Object -First 1)
        $xmakePath = Join-Path $srcSubDir.FullName "xmake.lua"
        Write-Host $srcSubDir
        lua genDeps.lua $xmakePath > "./SDK/deps.list"
    }
}

function Main {
    param(
        [switch]$CleanOnly = $false
    )
    begin {
        [File]::CleanWorkspace()
        if ($CleanOnly) { return }
    }
    process {
        try {
            # prepare llvm
            if (-not (Test-Path "llvm/.download_success")) {
                $llvmUrl = "https://github.com/mstorsjo/llvm-mingw/releases/download/20250114/llvm-mingw-20250114-ucrt-x86_64.zip"
                Write-Host "[Build] Downloading LLVM"
                if (-not [Network]::DownloadFile($llvmUrl, "llvm.zip", 3)) {
                    throw "Failed to download LLVM"
                }
                [Archive]::Extract("llvm.zip", "llvm")
                New-Item llvm/.download_success -ItemType File -Force | Out-Null
            }
            # get info from gh api
            $releases = Invoke-RestMethod "https://api.github.com/repos/LiteLDev/LeviLamina/releases"
            $latest = $releases[0]
            $releaseUrl = "" 
            foreach ($url in $latest[0].assets.browser_download_url) {
                if ($url.EndsWith("levilamina-release-windows-x64.zip")) {
                    $releaseUrl = $url
                    break
                }
            }
            # download LeviLamina
            Write-Host "[Build] Downloading LeviLamina"
            [Network]::DownloadFile($releaseUrl, "levilamina.zip", 3) | Out-Null
            [Archive]::Extract("levilamina.zip", "LeviLamina")

            # download LeviLamina-src
            Write-Host "[Build] Downloading LeviLamina source code"
            [Network]::DownloadFile($latest.zipball_url, "LeviLamina-src.zip", 3) | Out-Null
            [Archive]::Extract("LeviLamina-src.zip", "LeviLamina/src")

            # generate library definitions
            Write-Host "[Build] Generating library definitions"
            [Build]::GenerateLibraryDefinitions()

            # copy headers
            $srcRoot = (Get-Item (Join-Path (Get-Item "./LeviLamina/src").FullName "*")).FullName
            Write-Host "[Build] Copying headers"
            [File]::CopyHeaders($srcRoot, "\src", "")
            [File]::CopyHeaders($srcRoot, "\src-server", "")

            Write-Host "[Build] Copying LeviLamina.lib"
            [Build]::CopyLib()
            Write-Host "[Build] Generating dependencies list"
            [Build]::generateDepsList()
        }
        catch {
            Write-Error "[FATAL] $_"
            exit 1
        }
    }
    end {
        Write-Host "`n[SUCCESS] Build completed" -ForegroundColor Green
    }
}

Main