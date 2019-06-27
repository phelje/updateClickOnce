function Get-BinariesFolder($appFolder){
    $folders = Get-ChildItem -Path:$appFolder -Recurse -Directory | Where-Object { $_.Name -match "[a-zA-Z\.]+(_\d+){4}$" } | Sort-Object -Property LastWriteTime
    if ($folders.Length -gt 1) {
        Write-Warning "Found multiple Binaries folders!!"
    }
    if ($folders.Length -lt 1) {
        Write-Error "Binaries folder not found: $appFolder"
        exit;
    }
	Write-Host "Application binaries folder : $($folders[0].FullName)"
	return $folders[0].FullName
}

function Rename-BinariesFolder{
    param(
        $folder,
        $version
    )
    if ([string]::IsNullOrEmpty($version)) {
        return $folder
    }
	$versionName = $version -replace "\.", "_"
	$newName = $folder -replace "(_(\d)+){4}", "_$versionName"
	
	if($folder -eq $newName){
		return $newName
	}
	Rename-Item $folder -NewName $newName
	Write-Host "Binaries folder renamed to $newName"
	return $newName
}

function Get-MageFolder {
    $mageFolder = Get-ChildItem -Path .\ -Directory -Filter MSBuild.Mage*
    if ($mageFolder.Length -lt 1) {
        Write-Error "Mage.exe folder not found!!";
        exit;
    }
    Write-Debug "Mage.exe found: $($mageFolder.FullName)"
    return $mageFolder.FullName
}

function Get-ApplicationName($folder){
	$pattern = [regex]"(([a-zA-Z\.])+)(_\d+){4}"
	$result = $pattern.Match($folder)
	$name = $result.Groups[1].value
	Write-Host "Assembly name : $name";
	return "$name"
}

function Remove-DeployExtensions{
    param(
        [string]$folder
    )
        Write-Host "Removing .deploy extension";
        $renamedFiles = Get-ChildItem -Path:$folder -File -Recurse -Include @("*.deploy") | Rename-Item -NewName { $_.Name -replace '.deploy','' } -PassThru
        if($renamedFiles.Exists){
            Write-Host "$($renamedFiles.count) .deploy extensions removed!";
        }
        else{
            Write-Host "No .deploy extensions found";
        }
    return $renamedFiles;
}

function Restore-DeployExtensions{
    param(
        $files
    )
    if($files.Exists){
        Write-Host "Adding .deploy extension";
        $files | Rename-Item -NewName { $_.Name + ".deploy" }
        Write-Host ".deploy extensions added to $($files.count) files";    
    }
}

function Update-ClickOnce{
    param(
        [Parameter(Mandatory=$true)][string] $mageFolder,
        [Parameter(Mandatory=$true)][string] $appManifest,
        [Parameter(Mandatory=$true)][string] $packageManifest,
        [Parameter(Mandatory=$true)][string] $manifestName,
        [Parameter(Mandatory=$true)][string] $applicationName,
        [Parameter(Mandatory=$false)][string] $version,
        [Parameter(Mandatory=$true)][string] $certFile,
        [Parameter(Mandatory=$false)][string] $certPwd,
        [Parameter(Mandatory=$false)][string] $publisher,
        [Parameter(Mandatory=$false)][string] $providerUrl,
        [Parameter(Mandatory=$false)][string] $minVersion,
        [Parameter(Mandatory=$false)][string] $advanced
    )
    
    #Add pwd if provided
    $passwd =""
    if(! ([string]::IsNullOrEmpty($certPwd))){
        $passwd = " -pwd ""$certPwd""";
    }
    #Add aditional parameters
    $addConfig="";
    if(!([string]::IsNullOrEmpty($version))){
        $addConfig = " -Version ""$version""";
    }

    #Update application manifest
    try {
        Exit-OnMageError $(Invoke-Expression "$mageFolder\mage -Update ""$appManifest"" -Name ""$manifestName.exe"" -CertFile ""$certFile""$addConfig$passwd")
    }
    catch {
        Write-Error "Mage error: $_"
        exit;
    }

    #Add aditional parameters
    if(!([string]::IsNullOrEmpty($publisher))){
        $addConfig += " -Publisher ""$publisher""";
    }
    if(!([string]::IsNullOrEmpty($providerUrl))){
        $addConfig += " -ProviderUrl ""$providerUrl""";
    }
    if(!([string]::IsNullOrEmpty($minVersion))){
        #ToDo: Get current version if $version is empty and %version% is specified
        if ($minVersion -eq "%version%" -and [string]::IsNullOrEmpty($version)) {
            $currentversion = Get-CurrentVersionFromManifest -packageManifestPath:$packageManifest
        }
        else{
            $currentversion = $version
        }
        $minVersion = $minVersion -replace '%version%', $currentversion
        if (![string]::IsNullOrEmpty($minVersion)) {
            $addConfig += " -MinVersion ""$minVersion""";
        }
    }
	
    #Update deployment manifest
    try {
        Exit-OnMageError $(Invoke-Expression "$mageFolder\mage -Update ""$packageManifest"" -AppManifest ""$appManifest"" -Name ""$applicationName"" -CertFile ""$certFile""$addConfig$passwd")
    }
    catch {
        Write-Error "Mage error: $_"
        exit;
    }

    #If advanced config is specified modify the XML and resign.
    if([bool]$advanced){
        Set-AdvancedChanges -advanced:$advanced -packageManifest:$packageManifest -mageFolder:$mageFolder -certFile:$certFile -password:$passwd
    }
}

function Set-AdvancedChanges {
    param (
        $advanced,
        $packageManifest,
        $mageFolder,
        $certFile,
        $password
    )
    Write-Host "Advanced config enabled";
    
    try {
        $advJson= ConvertFrom-Json -InputObject $advanced
    }
    catch {
        Write-Error "The advanced Json config is not propperly formated!"
        exit;
    }
    # Load XML functions
    . ./XMLFunctions.ps1
    [xml]$xmlFile = Get-Content -Path $packageManifest
    $advJson.advanced | ForEach-Object {
        if([bool]$_.ElementPath -and [bool]$_.AttributeName -and [bool]$_.AttributeValue){
            Write-Host "ElementPath:$($_.ElementPath) AttributeName:$($_.AttributeName) AttributeValue:$($_.AttributeValue)"
            Write-Host "Current value: $(Get-XmlElementsAttributeValue -XmlDocument $xmlFile -ElementPath:$_.ElementPath -AttributeName:$_.AttributeName)"
            Set-XmlElementsAttributeValue -XmlDocument $xmlFile -ElementPath:$_.ElementPath -AttributeName:$_.AttributeName -AttributeValue:$_.AttributeValue
            Write-Host "New value: $(Get-XmlElementsAttributeValue -XmlDocument $xmlFile -ElementPath:$_.ElementPath -AttributeName:$_.AttributeName)"
        }
        else{
            Write-Error "The advanced config is not propperly formated! `n Required fields not found, verify that ElementPath, AttributeName, AttributeValue are specified"
            Write-Host $advanced
            return
        }
        
    }
    $xmlFile.Save("$(Resolve-Path $packageManifest)");
    try {
        Exit-OnMageError $(Invoke-Expression "$mageFolder\mage -Sign ""$packageManifest"" -CertFile ""$certFile""$password")
    }
    catch {
        Write-Error "Mage error: $_"
        exit;
    }   
}

function Get-CurrentVersionFromManifest {
    param (
        $packageManifestPath
    )
    [xml]$currentManifest = Get-Content -Path $packageManifestPath
    return $currentManifest.assembly.dependency.dependentAssembly.assemblyIdentity.version
}

function Exit-OnMageError {
    param (
        $result
    )
    if (!$result.Contains("successfully signed")) {
        Write-Error "Mage error: $result";
        exit;
    }
    Write-Host $result
}