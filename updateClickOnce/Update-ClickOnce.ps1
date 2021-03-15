Import-VstsLocStrings "$PSScriptRoot\Task.json"

$ApplicationName = Get-VstsInput -Name ApplicationName -Require
$Publisher = Get-VstsInput -Name Publisher
$Certificate = Get-VstsInput -Name Certificate -Require
$CertificatePassword = Get-VstsInput -Name CertificatePassword
$ProviderUrl = Get-VstsInput -Name ProviderUrl
$ApplicationFolder = Get-VstsInput -Name ApplicationFolder -Require
$Version = Get-VstsInput -Name Version
$MinVersion = Get-VstsInput -Name MinVersion
$Advanced = Get-VstsInput -Name Advanced

# Load helper functions
. ./HelperFunctions.ps1

#Verify that ApplicationFolder exists!
if (!(Test-Path -Path:$ApplicationFolder)) {
    Write-Error "ApplicationFolder: $ApplicationFolder is missing";
    exit;
}

# Init variables
$mageFolder = Get-MageFolder;
$binaryFolder = Get-BinariesFolder $ApplicationFolder
$appName = Get-ApplicationName $binaryFolder
$packageManifestPath = "$ApplicationFolder\$appName.application"

#If url ends on .application dont add it again
if (!($ProviderUrl -match ".+\.application$")) {
    $ProviderUrl = "$($ProviderUrl.TrimEnd('/'))/$appName.application" 
}

#Remove comment lines from Advanced string
$Advanced = $Advanced -replace "(?m)^\#.*$";

#Verify version and minversion format N.N.N.N
if (!($Version -match "\d+(\.(\d)+){3}") -and ![string]::IsNullOrEmpty($Version)) {
    Write-Error "Version number don´t contain N.N.N.N"
    exit;
}
elseif ($Matches) {
    $Version = $Matches[0]
}
if (![string]::IsNullOrEmpty($MinVersion) -and !($MinVersion -match "(\d+(\.(\d)+){3}|\%version\%)")) {
    Write-Error "MinVersion number don´t contain N.N.N.N or %version%"
    exit;
}
elseif ($Matches) {
    $MinVersion = $Matches[0]
}

# Rename binary folder to version
$binaryFolder = Rename-BinariesFolder $binaryFolder $Version
$appManifestPath = "$binaryFolder\$appName.exe.manifest"

# Remove .deploy extensions
$deployFiles = Remove-DeployExtensions $binaryFolder -RemoveExtension

# Sign package
Update-ClickOnce -mageFolder:$mageFolder -appManifest:$appManifestPath -packageManifest:$packageManifestPath -manifestName:$appName -applicationName:$ApplicationName -version:$Version -certFile:$Certificate -certPwd:$CertificatePassword -publisher:$Publisher -providerUrl:$ProviderUrl -minVersion:$MinVersion -advanced:$Advanced

# Restore .deploy extensions
Restore-DeployExtensions -files:$deployFiles

## tfx extension create --manifest-globs vss-extension.json --rev-version
