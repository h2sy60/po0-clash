$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted' -or $env:OS -ne 'Windows_NT') {
    throw 'Run this test only on an ephemeral Windows GitHub Actions runner.'
}
if (-not $env:WINDOWS_SIGNING_PFX_BASE64 -or -not $env:WINDOWS_SIGNING_PASSWORD) {
    throw 'Windows signing secrets are required for this validation.'
}

function Assert-That([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Assert-Fails([scriptblock]$Action, [string]$MessagePattern) {
    try { & $Action | Out-Null } catch {
        if ($_.Exception.Message -match $MessagePattern) { return }
        throw
    }
    throw "Expected failure matching: $MessagePattern"
}

function Assert-Signed([string]$Path) {
    & $signer -Path $Path -VerifyOnly
    Assert-That ($null -ne (Get-AuthenticodeSignature -LiteralPath $Path).TimeStamperCertificate) "Missing timestamp: $Path"
}

$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$originalLocation = Get-Location
$sandbox = Join-Path $env:RUNNER_TEMP "po0 signing test $([guid]::NewGuid())"
$script:fixtureRoot = Join-Path $sandbox 'project with spaces'
$script:fixtureExe = Join-Path $sandbox 'fixture.exe'
$pfx = Join-Path $sandbox 'signing.pfx'
$installDir = Join-Path $sandbox 'installed app'
$temporaryRoot = $false
$certificate = $null
$uninstaller = $null
New-Item -ItemType Directory -Force $script:fixtureRoot | Out-Null

try {
    foreach ($relative in @(
        'scripts/windows/package.ps1', 'scripts/windows/sign.ps1',
        'windows/packaging/exe/inno_setup.iss', 'windows/packaging/exe/ChineseSimplified.isl',
        'windows/runner/resources/app_icon.ico', 'windows/po0-clash-signing.cer',
        'docs/windows-security.txt', 'pubspec.yaml'
    )) {
        $destination = Join-Path $script:fixtureRoot $relative
        New-Item -ItemType Directory -Force (Split-Path $destination) | Out-Null
        Copy-Item (Join-Path $sourceRoot $relative) $destination
    }
    $certificate = [Security.Cryptography.X509Certificates.X509Certificate2]::new((Join-Path $script:fixtureRoot 'windows/po0-clash-signing.cer'))
    $thumbprint = $certificate.Thumbprint
    $hadMy = Test-Path "Cert:\CurrentUser\My\$thumbprint"
    $hadRoot = (Test-Path "Cert:\CurrentUser\Root\$thumbprint") -or (Test-Path "Cert:\LocalMachine\Root\$thumbprint")
    Assert-That (-not $hadMy -and -not $hadRoot) 'The runner already contains the signing identity.'

    $source = Join-Path $sandbox 'fixture.cs'
    [IO.File]::WriteAllText($source, 'class Fixture { static void Main() { System.Console.WriteLine("PO0_SIGNATURE_FIXTURE"); } }')
    $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    & $csc /nologo /target:exe "/out:$script:fixtureExe" $source
    Assert-That ($LASTEXITCODE -eq 0) 'Cannot compile the signing fixture.'
    $script:vendorFile = (Get-Command powershell.exe).Source
    $script:vendorHash = (Get-FileHash $script:vendorFile -Algorithm SHA256).Hash
    $env:PO0_SIGNING_FIXTURE_ROOT = $script:fixtureRoot
    $env:PO0_SIGNING_FIXTURE_EXE = $script:fixtureExe

    # The real package and signing scripts run; only Flutter's binary production is replaced.
    function flutter {
        $bundle = Join-Path $env:PO0_SIGNING_FIXTURE_ROOT 'build/windows/x64/runner/Release'
        New-Item -ItemType Directory -Force $bundle | Out-Null
        foreach ($name in @('po0-clash.exe', 'Po0ClashCore.exe', 'Po0ClashHelperService.exe', 'native.dll')) {
            Copy-Item $env:PO0_SIGNING_FIXTURE_EXE (Join-Path $bundle $name)
        }
        Copy-Item (Get-Command powershell.exe).Source (Join-Path $bundle 'vendor.exe')
        $signer = Join-Path $env:PO0_SIGNING_FIXTURE_ROOT 'scripts/windows/sign.ps1'
        & $signer -Path (Join-Path $bundle 'Po0ClashCore.exe')
        & $signer -Path (Join-Path $bundle 'Po0ClashHelperService.exe')
        $hash = (Get-FileHash (Join-Path $bundle 'Po0ClashCore.exe') -Algorithm SHA256).Hash.ToLowerInvariant()
        @{coreSha256 = $hash} | ConvertTo-Json | Set-Content (Join-Path $bundle 'manifest.json')
        $global:LASTEXITCODE = 0
    }

    $packager = Join-Path $script:fixtureRoot 'scripts/windows/package.ps1'
    Assert-Fails { & $packager -AppEnvironment stable } 'Stable Windows packages require'
    [IO.File]::WriteAllBytes($pfx, [Convert]::FromBase64String($env:WINDOWS_SIGNING_PFX_BASE64))
    $env:PO0_WINDOWS_PFX_PATH = $pfx
    $env:PO0_WINDOWS_PFX_PASSWORD = $env:WINDOWS_SIGNING_PASSWORD
    & $packager -AppEnvironment dev
    Assert-That (-not (Test-Path "Cert:\CurrentUser\My\$thumbprint")) 'Packaging left a private signing certificate behind.'
    Assert-That (-not (Test-Path "Cert:\LocalMachine\Root\$thumbprint")) 'Packaging left temporary root trust behind.'
    $config = Get-Content (Join-Path $script:fixtureRoot '.dart_tool/windows-signing.json') -Raw | ConvertFrom-Json
    Assert-That (-not $config.thumbprint) 'Packaging left a signing configuration behind.'

    Import-Certificate -FilePath (Join-Path $script:fixtureRoot 'windows/po0-clash-signing.cer') -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
    $temporaryRoot = $true
    $env:PO0_WINDOWS_SIGN_CERT_SHA1 = $thumbprint
    $signer = Join-Path $script:fixtureRoot 'scripts/windows/sign.ps1'
    $bundle = Join-Path $script:fixtureRoot 'build/windows/x64/runner/Release'
    foreach ($name in @('po0-clash.exe', 'Po0ClashCore.exe', 'Po0ClashHelperService.exe', 'native.dll')) {
        Assert-Signed (Join-Path $bundle $name)
    }
    Assert-That ((Get-FileHash (Join-Path $bundle 'vendor.exe') -Algorithm SHA256).Hash -eq $script:vendorHash) 'The package changed a valid vendor signature.'
    Assert-Fails { & $signer -Path $script:fixtureExe -VerifyOnly } 'Missing or invalid signing certificate'
    $tampered = Join-Path $sandbox 'tampered.exe'
    $bytes = [IO.File]::ReadAllBytes((Join-Path $bundle 'po0-clash.exe'))
    $marker = [Text.Encoding]::Unicode.GetBytes('PO0_SIGNATURE_FIXTURE')
    $offset = -1
    for ($index = 0; $index -le $bytes.Length - $marker.Length; $index++) {
        if ($bytes[$index] -ne $marker[0]) { continue }
        $matches = $true
        for ($part = 1; $part -lt $marker.Length; $part++) {
            if ($bytes[$index + $part] -ne $marker[$part]) { $matches = $false; break }
        }
        if ($matches) {
            $offset = $index
            break
        }
    }
    Assert-That ($offset -ge 0) 'Cannot locate the fixture payload for the tamper test.'
    $bytes[$offset] = $bytes[$offset] -bxor 1
    [IO.File]::WriteAllBytes($tampered, $bytes)
    Assert-Fails { & $signer -Path $tampered -VerifyOnly } 'Signature integrity check failed'

    $dist = Join-Path $script:fixtureRoot 'dist'
    $installers = @(Get-ChildItem "$dist/*-setup.exe")
    Assert-That ($installers.Count -eq 1) 'Expected one fixture installer.'
    $installer = $installers[0]
    Assert-Signed $installer.FullName
    $zips = @(Get-ChildItem "$dist/*.zip")
    Assert-That ($zips.Count -eq 1) 'Expected one fixture ZIP.'
    $zip = $zips[0]
    $expanded = Join-Path $sandbox 'expanded zip'
    Expand-Archive -LiteralPath $zip.FullName -DestinationPath $expanded
    $manifest = Get-Content (Join-Path $expanded 'manifest.json') -Raw | ConvertFrom-Json
    Assert-That ((Get-FileHash (Join-Path $expanded 'Po0ClashCore.exe') -Algorithm SHA256).Hash.ToLowerInvariant() -eq $manifest.coreSha256) 'ZIP Core hash differs from the Helper manifest.'
    foreach ($line in (Get-Content (Get-ChildItem "$dist/*-sha256.txt").FullName)) {
        $hash, $name = $line -split '  ', 2
        Assert-That ((Get-FileHash (Join-Path $dist $name) -Algorithm SHA256).Hash.ToLowerInvariant() -eq $hash) "Incorrect checksum: $name"
    }
    $installed = Start-Process -FilePath $installer.FullName -ArgumentList @('/SP-', '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', "/DIR=`"$installDir`"") -Wait -PassThru
    Assert-That ($installed.ExitCode -eq 0) 'Fixture installation failed.'
    $uninstaller = Join-Path $installDir 'unins000.exe'
    Assert-Signed $uninstaller
    $message = & (Join-Path $installDir 'Po0ClashCore.exe')
    Assert-That ($LASTEXITCODE -eq 0 -and $message -eq 'PO0_SIGNATURE_FIXTURE') 'The signed installed executable did not run.'
    $removed = Start-Process -FilePath $uninstaller -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART') -Wait -PassThru
    Assert-That ($removed.ExitCode -eq 0 -and -not (Test-Path (Join-Path $installDir 'po0-clash.exe'))) 'Fixture uninstallation failed.'
    Write-Output 'Windows signing, timestamp, tamper rejection, Core hash, ZIP, install and uninstall validation passed.'
} finally {
    Set-Location $originalLocation
    if ($temporaryRoot) { Remove-Item "Cert:\LocalMachine\Root\$($certificate.Thumbprint)" -ErrorAction Continue }
    Remove-Item Env:\PO0_WINDOWS_PFX_PATH, Env:\PO0_WINDOWS_PFX_PASSWORD, Env:\PO0_WINDOWS_SIGN_CERT_SHA1 -ErrorAction SilentlyContinue
    Remove-Item Env:\PO0_SIGNING_FIXTURE_ROOT, Env:\PO0_SIGNING_FIXTURE_EXE -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $pfx -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction Continue
}
