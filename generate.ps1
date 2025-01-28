if (Test-Path -Path .\LeviLamina.zip) { 
    $null = Remove-Item -Path .\LeviLamina.zip
}
if (Test-Path -Path .\LeviLamina) { 
    $null = Remove-Item -Path .\LeviLamina -Recurse -Force
}
if (Test-Path -Path .\LeviLamina.def) { 
    $null = Remove-Item -Path .\LeviLamina.def
}
if (Test-Path -Path .\LeviLamina.lib) { 
    $null = Remove-Item -Path .\LeviLamina.lib
}
if (Test-Path -Path .\dll) { 
    $null = Remove-Item -Path .\dll -Recurse -Force
}
if (Test-Path -Path .\dll.zip) { 
    $null = Remove-Item -Path .\dll.zip -Recurse -Force
}
if (Test-Path -Path .\SDK) {
    $null = Remove-Item -Path .\SDK -Recurse -Force
}
if (Test-Path -Path .\llvm) {
    $null = Remove-Item -Path .\llvm -Recurse -Force
}
if (Test-Path -Path .\llvm.zip) {
    $null = Remove-Item -Path .\llvm.zip
}
$llvmUrl = "https://github.com/mstorsjo/llvm-mingw/releases/download/20250114/llvm-mingw-20250114-ucrt-x86_64.zip"
# $null = Invoke-WebRequest -Uri $llvmUrl -OutFile llvm.zip
curl.exe -L -o llvm.zip $llvmUrl
Write-Output ("Downloaded " + $llvmUrl + " to llvm.zip")
# Expand-Archive llvm.zip -DestinationPath llvm
7z.exe x llvm.zip -ollvm
$url = "https://api.github.com/repos/LiteLDev/LeviLamina/releases"
$response = Invoke-WebRequest -Uri $url -Method Get
$json = ConvertFrom-Json $response.Content
$releaseUrl = "" 
foreach ($url in $json[0].assets.browser_download_url) {
    if ($url.EndsWith("levilamina-release-windows-x64.zip")) {
        $releaseUrl = $url
        break
    }
}
# $null = Invoke-WebRequest -Uri $releaseUrl -OutFile dll.zip
curl.exe -L -o dll.zip $releaseUrl
Write-Output ("Downloaded " + $releaseUrl + " to dll.zip")
# Expand-Archive dll.zip -DestinationPath dll
7z.exe x dll.zip -odll
."./llvm/llvm-mingw-20250114-ucrt-x86_64/bin/gendef.exe" .\dll\LeviLamina\LeviLamina.dll
."./llvm/llvm-mingw-20250114-ucrt-x86_64/bin/dlltool.exe" -D .\dll\LeviLamina\LeviLamina.dll -d .\LeviLamina.def -l LeviLamina.lib
$srcUrl = $json[0].zipball_url
# Invoke-WebRequest -Uri $srcUrl -OutFile LeviLamina.zip
curl.exe -L -o LeviLamina.zip $srcUrl
Write-Output ("Downloaded " + $srcUrl + " to LeviLamina.zip")
# Expand-Archive .\LeviLamina.zip -DestinationPath src
7z.exe x LeviLamina.zip -osrc
$llPath = Get-ChildItem .\src
$srcPath = $llPath[0].FullName
$srcPath += "\"
$filePaths = Get-ChildItem -Path ($srcPath + "\src") -Recurse -Filter *.h
foreach ($filePath in $filePaths) {
    $fullName = $filePath.DirectoryName
    $targetName = "SDK\include\" + $fullName.Substring( $srcPath.Length + "\src".Length)
    if (!((Test-Path -Path $targetName))) {
        $null = mkdir $targetName
        Write-Output ("Mkdir " + $targetName)
    }
    Copy-Item $filePath.FullName $targetName
    Write-Output ("Copy " + $filePath.FullName + " to " + $targetName + $filePath.Name)
}
$filePaths = Get-ChildItem -Path ($srcPath + "\src-server") -Recurse -Filter *.h
foreach ($filePath in $filePaths) {
    $fullName = $filePath.DirectoryName
    $targetName = "SDK\include\" + $fullName.Substring( $srcPath.Length + "\src-server".Length)
    if (!((Test-Path -Path $targetName))) {
        $null = mkdir $targetName
        Write-Output ("Mkdir " + $targetName)
    }
    Copy-Item $filePath.FullName $targetName
    Write-Output ("Copy " + $filePath.FullName + " to " + $targetName + $filePath.Name)
}
$null = Remove-Item ".\SDK\include\ll\core" -Recurse -Force
$null = mkdir .\SDK\lib
$null = Move-Item .\LeviLamina.lib .\SDK\lib
