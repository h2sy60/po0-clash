param(
    [ValidateSet('dev', 'pre', 'stable')][string]$AppEnvironment = 'pre',
    [string]$Targets = 'exe,zip',
    [ValidateSet('amd64', 'arm64')][string]$Architecture = 'amd64',
    [switch]$VerboseBuild
)

$ErrorActionPreference = 'Stop'
$modulePath = $env:PSModulePath
$env:PSModulePath = [IO.Path]::Combine($PSHOME, 'Modules') + [IO.Path]::PathSeparator + $modulePath
try {
    $root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    Set-Location $root
    $formats = $Targets.Split(',')
    if ($formats | Where-Object { $_ -notin @('exe', 'zip') }) {
        throw 'Windows package targets must be exe and/or zip.'
    }
    $version = [regex]::Match((Get-Content pubspec.yaml -Raw), '(?m)^version:\s*([^+\s]+)').Groups[1].Value
    if (-not $version) { throw 'pubspec.yaml has no version.' }
    $signed = [bool]$env:PO0_WINDOWS_PFX_PATH
    if ($AppEnvironment -eq 'stable' -and -not $signed) {
        throw 'Stable Windows packages require PO0_WINDOWS_PFX_PATH and PO0_WINDOWS_PFX_PASSWORD. See docs/development/windows-signing.md.'
    }

    $importedMy = $false
    $importedRoot = $false
    $thumbprint = $null
    $configPath = Join-Path $root '.dart_tool/windows-signing.json'
    New-Item -ItemType Directory -Force (Split-Path $configPath) | Out-Null
    try {
        if ($signed) {
            Write-Output 'Preparing Windows signing identity.'
            if (-not $env:PO0_WINDOWS_PFX_PASSWORD) { throw 'The PFX password is missing.' }
            $password = ConvertTo-SecureString $env:PO0_WINDOWS_PFX_PASSWORD -AsPlainText -Force
            $data = Get-PfxData -FilePath $env:PO0_WINDOWS_PFX_PATH -Password $password
            $certificates = @($data.EndEntityCertificates)
            if ($certificates.Count -ne 1) { throw 'The PFX must contain exactly one signing certificate.' }
            $certificate = $certificates[0]
            $thumbprint = $certificate.Thumbprint
            $pinned = [Security.Cryptography.X509Certificates.X509Certificate2]::new((Join-Path $root 'windows/po0-clash-signing.cer'))
            if ($thumbprint -ne $pinned.Thumbprint) { throw 'The signing key does not match windows/po0-clash-signing.cer.' }
            $importedMy = -not (Test-Path "Cert:\CurrentUser\My\$thumbprint")
            Import-PfxCertificate -FilePath $env:PO0_WINDOWS_PFX_PATH -Password $password -CertStoreLocation Cert:\CurrentUser\My | Out-Null
            $trusted = (Test-Path "Cert:\CurrentUser\Root\$thumbprint") -or
                (Test-Path "Cert:\LocalMachine\Root\$thumbprint")
            if ($certificate.Subject -eq $certificate.Issuer -and -not $trusted) {
                if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted') {
                    throw 'A self-signed certificate must already be trusted on the build machine. Automatic temporary trust is limited to GitHub-hosted runners.'
                }
                $publicCertificate = Join-Path $root '.dart_tool/windows-signing.cer'
                Export-Certificate -Cert $certificate -FilePath $publicCertificate | Out-Null
                Write-Output 'Preparing temporary trust on the hosted build runner.'
                Import-Certificate -FilePath $publicCertificate -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
                $importedRoot = $true
            }
            $env:PO0_WINDOWS_SIGN_CERT_SHA1 = $thumbprint
            $config = @{ thumbprint = $thumbprint } | ConvertTo-Json -Compress
        } else {
            Write-Warning 'This development package is unsigned.'
            $config = '{}'
        }
        [IO.File]::WriteAllText($configPath, "$config`n")
        Write-Output 'Building Windows binaries.'
        $flutterArgs = @('build', 'windows', '--release', '--dart-define-from-file=env.json')
        if ($VerboseBuild) { $flutterArgs += '-v' }
        & flutter @flutterArgs
        if ($LASTEXITCODE -ne 0) { throw 'Flutter Windows build failed.' }

        $flutterArch = if ($Architecture -eq 'amd64') { 'x64' } else { 'arm64' }
        $bundle = Join-Path $root "build/windows/$flutterArch/runner/Release"
        $core = Join-Path $bundle 'Po0ClashCore.exe'
        $helper = Join-Path $bundle 'Po0ClashHelperService.exe'
        $manifestPath = Join-Path $bundle 'manifest.json'
        foreach ($file in @($core, $helper, $manifestPath, (Join-Path $bundle 'po0-clash.exe'))) {
            if (-not (Test-Path -LiteralPath $file)) { throw "Missing build output: $file" }
        }
        if ($signed) {
            Write-Output 'Verifying Core and Helper, then signing application binaries.'
            & "$PSScriptRoot/sign.ps1" -Path $core -VerifyOnly
            & "$PSScriptRoot/sign.ps1" -Path $helper -VerifyOnly
            Get-ChildItem -LiteralPath $bundle -Recurse -File |
                Where-Object { $_.Extension -in @('.exe', '.dll') } |
                ForEach-Object { & "$PSScriptRoot/sign.ps1" -Path $_.FullName -PreserveExisting }
            Export-Certificate -Cert $certificate -FilePath (Join-Path $bundle 'po0-clash-signing.cer') | Out-Null
        }
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        if ((Get-FileHash -LiteralPath $core -Algorithm SHA256).Hash.ToLowerInvariant() -ne $manifest.coreSha256) {
            throw 'The packaged Core no longer matches the hash embedded in the Helper.'
        }
        Copy-Item (Join-Path $root 'docs/windows-security.txt') (Join-Path $bundle 'WINDOWS-SECURITY.txt')
        $output = Join-Path $root 'dist'
        New-Item -ItemType Directory -Force $output | Out-Null
        $baseName = "po0-clash-$version-windows-$Architecture"
        $artifacts = @()
        if ('exe' -in $formats) {
            Write-Output 'Building the signed installer and uninstaller.'
            $inno = if ($env:INNO_SETUP_PATH) { Join-Path $env:INNO_SETUP_PATH 'ISCC.exe' } else { 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe' }
            if (-not (Test-Path -LiteralPath $inno)) { $inno = (Get-Command ISCC.exe -ErrorAction Stop).Source }
            $innoArgs = @("/DAppVersion=$version", "/DSourceDir=$bundle", "/DProjectDir=$root", "/DOutputDir=$output", "/DOutputName=$baseName-setup", "/DTargetArch=$flutterArch")
            if ($signed) {
                $signCommand = 'powershell.exe -NoProfile -NonInteractive -File $q' + (Join-Path $PSScriptRoot 'sign.ps1') + '$q -Path $f'
                $innoArgs += @('/DSignBuild=1', "/Spo0=$signCommand")
            }
            & $inno @innoArgs (Join-Path $root 'windows/packaging/exe/inno_setup.iss')
            if ($LASTEXITCODE -ne 0) { throw 'Inno Setup packaging failed.' }
            $installer = Join-Path $output "$baseName-setup.exe"
            if ($signed) { & "$PSScriptRoot/sign.ps1" -Path $installer -VerifyOnly }
            $artifacts += $installer
        }
        if ('zip' -in $formats) {
            $zip = Join-Path $output "$baseName.zip"
            Compress-Archive -Path "$bundle/*" -DestinationPath $zip -Force
            $artifacts += $zip
        }
        if ($signed) {
            $publicCertificate = Join-Path $output 'po0-clash-signing.cer'
            Copy-Item (Join-Path $bundle 'po0-clash-signing.cer') $publicCertificate -Force
            $artifacts += $publicCertificate
        }
        $checksums = foreach ($artifact in $artifacts) {
            $hash = (Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash.ToLowerInvariant()
            "$hash  $([IO.Path]::GetFileName($artifact))"
        }
        [IO.File]::WriteAllLines((Join-Path $output "$baseName-sha256.txt"), $checksums)
    } finally {
        if ($importedRoot) { Remove-Item "Cert:\LocalMachine\Root\$thumbprint" -ErrorAction Continue }
        if ($importedMy) { Remove-Item "Cert:\CurrentUser\My\$thumbprint" -ErrorAction Continue }
        Remove-Item Env:\PO0_WINDOWS_SIGN_CERT_SHA1 -ErrorAction SilentlyContinue
        [IO.File]::WriteAllText($configPath, "{}`n")
    }
} finally {
    $env:PSModulePath = $modulePath
}
