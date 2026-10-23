param(
    [Parameter(Mandatory = $true)][string]$Path,
    [switch]$VerifyOnly,
    [switch]$PreserveExisting
)

$ErrorActionPreference = 'Stop'
$modulePath = $env:PSModulePath
$env:PSModulePath = [IO.Path]::Combine($PSHOME, 'Modules') + [IO.Path]::PathSeparator + $modulePath
try {
    $thumbprint = $env:PO0_WINDOWS_SIGN_CERT_SHA1
    if ($thumbprint -notmatch '^[0-9A-F]{40}$') {
        throw 'PO0_WINDOWS_SIGN_CERT_SHA1 must identify the build signing certificate.'
    }
    $file = (Resolve-Path -LiteralPath $Path).Path
    $signature = Get-AuthenticodeSignature -LiteralPath $file
    if ($signature.Status -eq 'HashMismatch') {
        throw "Signature integrity check failed: $file"
    }
    if ($signature.Status -eq 'Valid' -and
        ($PreserveExisting -or $signature.SignerCertificate.Thumbprint -eq $thumbprint)) {
        return
    }
    if ($VerifyOnly) {
        throw "Missing or invalid signing certificate: $file ($($signature.Status))"
    }

    $signtool = $env:PO0_WINDOWS_SIGNTOOL
    if (-not $signtool) {
        $programFilesX86 = [Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFilesX86)
        if (-not $programFilesX86) { throw 'The Windows SDK installation directory could not be located.' }
        $sdk = Join-Path $programFilesX86 'Windows Kits\10\bin'
        $signtool = Get-ChildItem -Path "$sdk\*\x64\signtool.exe" |
            Sort-Object { [version]$_.Directory.Parent.Name } -Descending |
            Select-Object -First 1 -ExpandProperty FullName
    }
    if (-not $signtool -or -not (Test-Path -LiteralPath $signtool)) {
        throw 'Windows SDK SignTool is required; set PO0_WINDOWS_SIGNTOOL if it is installed elsewhere.'
    }
    $timestamp = $env:PO0_WINDOWS_TIMESTAMP_URL
    if (-not $timestamp) { $timestamp = 'http://timestamp.digicert.com' }
    & $signtool sign /sha1 $thumbprint /s My /fd SHA256 /tr $timestamp /td SHA256 $file
    if ($LASTEXITCODE -ne 0) { throw "SignTool failed: $file" }
    & $signtool verify /pa /all $file
    if ($LASTEXITCODE -ne 0) { throw "Signature verification failed: $file" }
    $signature = Get-AuthenticodeSignature -LiteralPath $file
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Thumbprint -ne $thumbprint) {
        throw "Unexpected signer: $file"
    }
} finally {
    $env:PSModulePath = $modulePath
}
