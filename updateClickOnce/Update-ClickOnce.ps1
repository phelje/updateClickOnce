Param(  
    [Parameter(Mandatory=$true)][string] $ApplicationName,
    [Parameter(Mandatory=$false)][string] $Publisher,
    [Parameter(Mandatory=$true)][string] $Certificate,
    [Parameter(Mandatory=$false)][string] $CertificatePassword,
    [Parameter(Mandatory=$false)][string] $ProviderUrl,
    [Parameter(Mandatory=$true)][string] $ApplicationFolder,
    [Parameter(Mandatory=$false)][string] $Version,
    [Parameter(Mandatory=$false)][string] $MinVersion,
    [Parameter(Mandatory=$false)][string] $Advanced
)

# Load helper functions
. ./HelperFunctions.ps1

#Verify that ApplicationFolder exists!
if(!(Test-Path -Path:$ApplicationFolder)){
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
$Advanced = $Advanced.Split("`r`n") | Select-String -Pattern "#" -NotMatch | Where-Object -Property "line"

#Verify version and minversion format N.N.N.N
if (!($Version -match "\d+(\.(\d)+){3}") -and ![string]::IsNullOrEmpty($Version)){
    Write-Error "Version number dont match N.N.N.N format"
    exit;
}
if (![string]::IsNullOrEmpty($MinVersion) -and $MinVersion -ne "%version%" -and !($MinVersion -match "\d+(\.(\d)+){3}")) {
    Write-Error "MinVersion number dont match N.N.N.N format"
    exit;
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