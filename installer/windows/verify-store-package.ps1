param(
    [string]$PackagePath,
    [string]$ExpectedVersion = '2.6.3.0'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $PackagePath) {
    $PackagePath = Join-Path $projectRoot "dist/store/Fumic-$ExpectedVersion-windows-x64.msix"
}
$PackagePath = (Resolve-Path -LiteralPath $PackagePath).Path

# This checks the contents without installing the app or trusting a certificate.
# Partner Center validation and Windows App Certification Kit are separate checks.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$package = [IO.Compression.ZipFile]::OpenRead($PackagePath)
try {
    $entryNames = @($package.Entries | ForEach-Object { $_.FullName.Replace('\', '/') })
    foreach ($required in @('AppxManifest.xml', 'AppxBlockMap.xml', '[Content_Types].xml')) {
        if ($entryNames -cnotcontains $required) {
            throw "Package is missing $required."
        }
    }

    $reader = [IO.StreamReader]::new($package.GetEntry('AppxManifest.xml').Open())
    try {
        $manifestText = $reader.ReadToEnd()
    } finally {
        $reader.Dispose()
    }
    $xmlSettings = [Xml.XmlReaderSettings]::new()
    $xmlSettings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
    $xmlSettings.XmlResolver = $null
    $stringReader = [IO.StringReader]::new($manifestText)
    $xmlReader = [Xml.XmlReader]::Create($stringReader, $xmlSettings)
    try {
        $manifest = [Xml.XmlDocument]::new()
        $manifest.XmlResolver = $null
        $manifest.Load($xmlReader)
    } finally {
        $xmlReader.Dispose()
        $stringReader.Dispose()
    }

    $ns = [Xml.XmlNamespaceManager]::new($manifest.NameTable)
    $ns.AddNamespace('m', $manifest.DocumentElement.NamespaceURI)
    $identity = $manifest.SelectSingleNode('/m:Package/m:Identity', $ns)
    if (-not $identity) { throw 'Package manifest has no Identity element.' }
    $expected = @{
        Name = 'TheIdealDev52.Fumic'
        Publisher = 'CN=53B47373-7933-42A9-AF08-A830D467B5E3'
        Version = $ExpectedVersion
        ProcessorArchitecture = 'x64'
    }
    foreach ($key in $expected.Keys) {
        if ($identity.GetAttribute($key) -cne $expected[$key]) {
            throw "Identity/$key mismatch: expected '$($expected[$key])', got '$($identity.GetAttribute($key))'."
        }
    }
    $version = [version]::Parse($identity.GetAttribute('Version'))
    if ($version.Major -lt 1 -or $version.Major -gt 65535 -or
        $version.Minor -gt 65535 -or $version.Build -gt 65535 -or $version.Revision -ne 0) {
        throw 'Store version must be major.minor.build.0, with major 1..65535 and minor/build 0..65535.'
    }
    foreach ($property in @{ DisplayName = 'Fumic'; PublisherDisplayName = 'TheIdealDev52' }.GetEnumerator()) {
        $node = $manifest.SelectSingleNode("/m:Package/m:Properties/m:$($property.Key)", $ns)
        if (-not $node -or $node.InnerText -cne $property.Value) {
            throw "Properties/$($property.Key) does not match the agreed Store value."
        }
    }
    $deviceFamilies = @($manifest.SelectNodes('/m:Package/m:Dependencies/m:TargetDeviceFamily', $ns))
    if ($deviceFamilies.Count -ne 1 -or $deviceFamilies[0].GetAttribute('Name') -cne 'Windows.Desktop') {
        throw 'This release must target Windows.Desktop only.'
    }
    $capabilities = @($manifest.SelectNodes('/m:Package/m:Capabilities/*', $ns) | ForEach-Object { $_.GetAttribute('Name') })
    if ($capabilities -cnotcontains 'runFullTrust' -or @($capabilities | Where-Object { $_ -cne 'runFullTrust' }).Count -gt 0) {
        throw "Unexpected capabilities: $($capabilities -join ', '). Review the manifest before uploading."
    }
    foreach ($required in @('fumic.exe', 'flutter_windows.dll', 'libmpv-2.dll', 'data/app.so',
        'data/icudtl.dat', 'data/flutter_assets/NOTICES.Z', 'LICENSE')) {
        if ($entryNames -cnotcontains $required) { throw "Package is missing runtime/license file $required." }
    }
    $vcFrameworks = @($manifest.SelectNodes('/m:Package/m:Dependencies/m:PackageDependency', $ns) |
        Where-Object { $_.GetAttribute('Name') -like 'Microsoft.VCLibs*' })
    if ($vcFrameworks.Count -eq 0) {
        foreach ($runtime in @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
            if ($entryNames -cnotcontains $runtime) { throw "Missing Visual C++ runtime $runtime (and no VCLibs framework dependency)." }
        }
    }
    $applications = @($manifest.SelectNodes('/m:Package/m:Applications/m:Application', $ns))
    if ($applications.Count -ne 1 -or $applications[0].GetAttribute('Executable') -cne 'fumic.exe') {
        throw 'Expected one application with executable fumic.exe.'
    }

    Write-Output "PASS: Store identity, version, desktop target, capabilities, required files, and VC runtime declaration."
    Write-Output "Package: $PackagePath"
    Write-Output "Version: $version"
    Write-Output "Capabilities: $($capabilities -join ', ')"
    Write-Output "Signed: $($entryNames -contains 'AppxSignature.p7x') (the Store submission is intentionally unsigned)"
} finally {
    $package.Dispose()
}
Get-FileHash -LiteralPath $PackagePath -Algorithm SHA256
