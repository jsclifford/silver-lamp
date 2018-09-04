. $PSScriptRoot\build.settings.1.ps1

Properties {
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    $ModuleOutDir = "$OutDir\$ModuleName"

    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    $UpdatableHelpOutDir = "$OutDir\UpdatableHelp"

    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    $SharedProperties = @{}

    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    $LineSep = "-" * 78
}

Task default -depends Build

Task Init -requiredVariables OutDir {
    if (!(Test-Path -LiteralPath $OutDir)) {
        New-Item $OutDir -ItemType Directory -Verbose:$VerbosePreference > $null
    }
    else {
        Write-Verbose "$($psake.context.currentTaskName) - directory already exists '$OutDir'."
    }
}

Task Clean -depends Init -requiredVariables OutDir {
    # Maybe a bit paranoid but this task nuked \ on my laptop. Good thing I was not running as admin.
    if ($OutDir.Length -gt 3) {
        Get-ChildItem $OutDir | Remove-Item -Recurse -Force -Verbose:$VerbosePreference
    }
    else {
        Write-Verbose "$($psake.context.currentTaskName) - `$OutDir '$OutDir' must be longer than 3 characters."
    }
}

Task StageFiles -depends Init, Clean, BeforeStageFiles, CoreStageFiles {
    #Create resources folder and generate CSV file
    if(Test-Path("$SolutionDir\resources")){
        Write-Verbose "Resources folder already created."
    }else{
        mkdir "$SolutionDir\resources"
    }

    $CSVList = @(
        [PSCustomObject]@{
            "TeamProjectName" = "VSTeamBuilderDemo"
            "TeamName" = "MyTestTeam"
            "TeamCode" = "MTT"
            "TeamPath" = ""
            "TeamDescription" = "Best Test Team"
            "isCoded" = "y"
            "ProcessOrder" = 1
        },
        [PSCustomObject]@{
            "TeamProjectName" = "VSTeamBuilderDemo"
            "TeamName" = "MyTestTeam2"
            "TeamCode" = "MTT2"
            "TeamPath" = "MTT"
            "TeamDescription" = "Best Test Team2"
            "isCoded" = "n"
            "ProcessOrder" = 2
        }
    )

    $CSVList | Export-Csv -NoTypeInformation -Path "$SolutionDir\resources\VSTBImportFile.csv" -Force
}

Task CoreStageFiles -requiredVariables ModuleOutDir, SrcRootDir {
    if (!(Test-Path -LiteralPath $ModuleOutDir)) {
        New-Item $ModuleOutDir -ItemType Directory -Verbose:$VerbosePreference > $null
    }
    else {
        Write-Verbose "$($psake.context.currentTaskName) - directory already exists '$ModuleOutDir'."
    }

    Copy-Item -Path $SrcRootDir\* -Destination $ModuleOutDir -Recurse -Exclude $Exclude -Verbose:$VerbosePreference
    # Copy-Item -Path $SolutionDir\README.md -Destination $ModuleOutDir -Exclude $Exclude -Verbose:$VerbosePreference
    # Copy-Item -Path $SolutionDir\LICENSE -Destination $ModuleOutDir -Exclude $Exclude -Verbose:$VerbosePreference
}

Task Build -depends Init, Clean, BeforeBuild, StageFiles, AfterStageFiles, Analyze, Sign, AfterBuild {
}

Task BuildSimple -depends Init, Clean, BeforeBuild, StageFiles, AfterStageFiles, AfterBuild {
}

Task Analyze -depends StageFiles `
             -requiredVariables ModuleOutDir, ScriptAnalysisEnabled, ScriptAnalysisFailBuildOnSeverityLevel, ScriptAnalyzerSettingsPath {
    if (!$ScriptAnalysisEnabled) {
        "Script analysis is not enabled. Skipping $($psake.context.currentTaskName) task."
        return
    }

    if (!(Get-Module PSScriptAnalyzer -ListAvailable)) {
        "PSScriptAnalyzer module is not installed. Skipping $($psake.context.currentTaskName) task."
        return
    }

    "ScriptAnalysisFailBuildOnSeverityLevel set to: $ScriptAnalysisFailBuildOnSeverityLevel"

    $analysisResult = Invoke-ScriptAnalyzer -Path $ModuleOutDir -Settings $ScriptAnalyzerSettingsPath -Recurse -Verbose:$VerbosePreference
    $analysisResult | Format-Table
    switch ($ScriptAnalysisFailBuildOnSeverityLevel) {
        'None' {
            return
        }
        'Error' {
            Assert -conditionToCheck (
                ($analysisResult | Where-Object Severity -eq 'Error').Count -eq 0
                ) -failureMessage 'One or more ScriptAnalyzer errors were found. Build cannot continue!'
        }
        'Warning' {
            Assert -conditionToCheck (
                ($analysisResult | Where-Object {
                    $_.Severity -eq 'Warning' -or $_.Severity -eq 'Error'
                }).Count -eq 0) -failureMessage 'One or more ScriptAnalyzer warnings were found. Build cannot continue!'
        }
        default {
            Assert -conditionToCheck (
                $analysisResult.Count -eq 0
                ) -failureMessage 'One or more ScriptAnalyzer issues were found. Build cannot continue!'
        }
    }
}

Task Sign -depends StageFiles -requiredVariables CertPath, SettingsPath, ScriptSigningEnabled {
    if (!$ScriptSigningEnabled) {
        "Script signing is not enabled. Skipping $($psake.context.currentTaskName) task."
        return
    }

    $validCodeSigningCerts = Get-ChildItem -Path $CertPath -CodeSigningCert -Recurse | Where-Object NotAfter -ge (Get-Date)
    if (!$validCodeSigningCerts) {
        throw "There are no non-expired code-signing certificates in $CertPath. You can either install " +
              "a code-signing certificate into the certificate store or disable script analysis in build.settings.ps1."
    }

    $certSubjectNameKey = "CertSubjectName"
    $storeCertSubjectName = $true

    # Get the subject name of the code-signing certificate to be used for script signing.
    if (!$CertSubjectName -and ($CertSubjectName = GetSetting -Key $certSubjectNameKey -Path $SettingsPath)) {
        $storeCertSubjectName = $false
    }
    elseif (!$CertSubjectName) {
        "A code-signing certificate has not been specified."
        "The following non-expired, code-signing certificates are available in your certificate store:"
        $validCodeSigningCerts | Format-List Subject,Issuer,Thumbprint,NotBefore,NotAfter

        $CertSubjectName = Read-Host -Prompt 'Enter the subject name (case-sensitive) of the certificate to use for script signing'
    }

    # Find a code-signing certificate that matches the specified subject name.
    $certificate = $validCodeSigningCerts |
                       Where-Object { $_.SubjectName.Name -cmatch [regex]::Escape($CertSubjectName) } |
                       Sort-Object NotAfter -Descending | Select-Object -First 1

    if ($certificate) {
        $SharedProperties.CodeSigningCertificate = $certificate

        if ($storeCertSubjectName) {
            SetSetting -Key $certSubjectNameKey -Value $certificate.SubjectName.Name -Path $SettingsPath
            "The new certificate subject name has been stored in ${SettingsPath}."
        }
        else {
            "Using stored certificate subject name $CertSubjectName from ${SettingsPath}."
        }

        $LineSep
        "Using code-signing certificate: $certificate"
        $LineSep

        $files = @(Get-ChildItem -Path $ModuleOutDir\* -Recurse -Include *.ps1,*.psm1)
        foreach ($file in $files) {
            $setAuthSigParams = @{
                FilePath = $file.FullName
                Certificate = $certificate
                Verbose = $VerbosePreference
            }

            $result = Microsoft.PowerShell.Security\Set-AuthenticodeSignature @setAuthSigParams
            if ($result.Status -ne 'Valid') {
                throw "Failed to sign script: $($file.FullName)."
            }

            "Successfully signed script: $($file.Name)"
        }
    }
    else {
        $expiredCert = Get-ChildItem -Path $CertPath -CodeSigningCert -Recurse |
                           Where-Object { ($_.SubjectName.Name -cmatch [regex]::Escape($CertSubjectName)) -and
                                          ($_.NotAfter -lt (Get-Date)) }
                           Sort-Object NotAfter -Descending | Select-Object -First 1

        if ($expiredCert) {
            throw "The code-signing certificate `"$($expiredCert.SubjectName.Name)`" EXPIRED on $($expiredCert.NotAfter)."
        }

        throw 'No valid certificate subject name supplied or stored.'
    }
}

Task BuildHelp -depends Build, BeforeBuildHelp, GenerateMarkdown, GenerateHelpFiles, AfterBuildHelp {
}

Task GenerateMarkdown -requiredVariables DefaultLocale, DocsRootDir, ModuleName, ModuleOutDir {
    if (!(Get-Module platyPS -ListAvailable)) {
        "platyPS module is not installed. Skipping $($psake.context.currentTaskName) task."
        return
    }

    $moduleInfo = Import-Module $ModuleOutDir\$ModuleName.psd1 -Global -Force -PassThru
    #$moduleInfo = Import-PowerShellDataFile $ModuleOutDir\$ModuleName.psd1
    try {
        if ($moduleInfo.ExportedCommands.Count -eq 0) {
            "No commands have been exported. Skipping $($psake.context.currentTaskName) task."
            return
        }

        if (!(Test-Path -LiteralPath $DocsRootDir)) {
            New-Item $DocsRootDir -ItemType Directory > $null
        }

        if (Get-ChildItem -LiteralPath $DocsRootDir -Filter *.md -Recurse) {
            Get-ChildItem -LiteralPath $DocsRootDir -Directory | ForEach-Object {
                Update-MarkdownHelp -Path $_.FullName -Verbose:$VerbosePreference > $null
            }
        }

        # ErrorAction set to SilentlyContinue so this command will not overwrite an existing MD file.
        New-MarkdownHelp -Module $ModuleName -Locale $DefaultLocale -OutputFolder $DocsRootDir\$DefaultLocale `
                         -WithModulePage -ErrorAction SilentlyContinue -Verbose:$VerbosePreference > $null
    }
    finally {
        Remove-Module $ModuleName
    }
}

Task GenerateHelpFiles -requiredVariables DocsRootDir, ModuleName, ModuleOutDir, OutDir {
    if (!(Get-Module platyPS -ListAvailable)) {
        "platyPS module is not installed. Skipping $($psake.context.currentTaskName) task."
        return
    }

    if (!(Get-ChildItem -LiteralPath $DocsRootDir -Filter *.md -Recurse -ErrorAction SilentlyContinue)) {
        "No markdown help files to process. Skipping $($psake.context.currentTaskName) task."
        return
    }

    $helpLocales = (Get-ChildItem -Path $DocsRootDir -Directory).Name

    # Generate the module's primary MAML help file.
    foreach ($locale in $helpLocales) {
        New-ExternalHelp -Path $DocsRootDir\$locale -OutputPath $ModuleOutDir\$locale -Force `
                         -ErrorAction SilentlyContinue -Verbose:$VerbosePreference > $null
    }
}

Task BuildUpdatableHelp -depends BuildHelp, BeforeBuildUpdatableHelp, CoreBuildUpdatableHelp, AfterBuildUpdatableHelp {
}

Task CoreBuildUpdatableHelp -requiredVariables DocsRootDir, ModuleName, UpdatableHelpOutDir {
    if (!(Get-Module platyPS -ListAvailable)) {
        "platyPS module is not installed. Skipping $($psake.context.currentTaskName) task."
        return
    }

    $helpLocales = (Get-ChildItem -Path $DocsRootDir -Directory).Name

    # Create updatable help output directory.
    if (!(Test-Path -LiteralPath $UpdatableHelpOutDir)) {
        New-Item $UpdatableHelpOutDir -ItemType Directory -Verbose:$VerbosePreference > $null
    }
    else {
        Write-Verbose "$($psake.context.currentTaskName) - directory already exists '$UpdatableHelpOutDir'."
        Get-ChildItem $UpdatableHelpOutDir | Remove-Item -Recurse -Force -Verbose:$VerbosePreference
    }

    # Generate updatable help files.  Note: this will currently update the version number in the module's MD
    # file in the metadata.
    foreach ($locale in $helpLocales) {
        New-ExternalHelpCab -CabFilesFolder $ModuleOutDir\$locale -LandingPagePath $DocsRootDir\$locale\$ModuleName.md `
                            -OutputFolder $UpdatableHelpOutDir -Verbose:$VerbosePreference > $null
    }
}

Task GenerateFileCatalog -depends Build, BuildHelp, BeforeGenerateFileCatalog, CoreGenerateFileCatalog, AfterGenerateFileCatalog {
}

Task CoreGenerateFileCatalog -requiredVariables CatalogGenerationEnabled, CatalogVersion, ModuleName, ModuleOutDir, OutDir {
    if (!$CatalogGenerationEnabled) {
        "FileCatalog generation is not enabled. Skipping $($psake.context.currentTaskName) task."
        return
    }

    if (!(Get-Command Microsoft.PowerShell.Security\New-FileCatalog -ErrorAction SilentlyContinue)) {
        "FileCatalog commands not available on this version of PowerShell. Skipping $($psake.context.currentTaskName) task."
        return
    }

    $catalogFilePath = "$OutDir\$ModuleName.cat"

    $newFileCatalogParams = @{
        Path = $ModuleOutDir
        CatalogFilePath = $catalogFilePath
        CatalogVersion = $CatalogVersion
        Verbose = $VerbosePreference
    }

    Microsoft.PowerShell.Security\New-FileCatalog @newFileCatalogParams > $null

    if ($ScriptSigningEnabled) {
        if ($SharedProperties.CodeSigningCertificate) {
            $setAuthSigParams = @{
                FilePath = $catalogFilePath
                Certificate = $SharedProperties.CodeSigningCertificate
                Verbose = $VerbosePreference
            }

            $result = Microsoft.PowerShell.Security\Set-AuthenticodeSignature @setAuthSigParams
            if ($result.Status -ne 'Valid') {
                throw "Failed to sign file catalog: $($catalogFilePath)."
            }

            "Successfully signed file catalog: $($catalogFilePath)"
        }
        else {
            "No code-signing certificate was found to sign the file catalog."
        }
    }
    else {
        "Script signing is not enabled. Skipping signing of file catalog."
    }

    Move-Item -LiteralPath $newFileCatalogParams.CatalogFilePath -Destination $ModuleOutDir
}

Task Install -depends Build, BuildHelp, GenerateFileCatalog, BeforeInstall, CoreInstall, AfterInstall {
}

Task CoreInstall -requiredVariables ModuleOutDir {
    if (!(Test-Path -LiteralPath $InstallPath)) {
        Write-Verbose 'Creating install directory'
        New-Item -Path $InstallPath -ItemType Directory -Verbose:$VerbosePreference > $null
    }

    Copy-Item -Path $ModuleOutDir\* -Destination $InstallPath -Verbose:$VerbosePreference -Recurse -Force
    "Module installed into $InstallPath"
}

Task Test -requiredVariables TestRootDir, ModuleName, CodeCoverageEnabled, CodeCoverageFiles,CodeCoverageOutPutFile,CodeCoverageOutputFileFormat,PesterReportFolder  {
    if (!(Get-Module Pester -ListAvailable)) {
        "Pester module is not installed. Skipping $($psake.context.currentTaskName) task."
        return
    }

    Import-Module Pester

    try {
        Microsoft.PowerShell.Management\Push-Location -LiteralPath "$TestRootDir\unit"

        if ($TestOutputFile) {
            $testing = @{
                OutputFile   = $TestOutputFile
                OutputFormat = $TestOutputFormat
                PassThru     = $true
                Verbose      = $VerbosePreference
            }
        }
        else {
            $testing = @{
                PassThru     = $true
                Verbose      = $VerbosePreference
            }
        }

        if(-not (Test-Path($PesterReportFolder))){
            mkdir $PesterReportFolder
        }

        # To control the Pester code coverage, a boolean $CodeCoverageEnabled is used.
        if ($CodeCoverageEnabled) {
            $testing.CodeCoverage = $CodeCoverageFiles
            $testing.CodeCoverageOutPutFile = $CodeCoverageOutPutFile
            $testing.CodeCoverageOutputFileFormat = $CodeCoverageOutputFileFormat
        }

        $testResult = Invoke-Pester @testing

        Assert -conditionToCheck (
            $testResult.FailedCount -eq 0
        ) -failureMessage "One or more Pester tests failed, build cannot continue."

        if ($CodeCoverageEnabled) {
            $testCoverage = [int]($testResult.CodeCoverage.NumberOfCommandsExecuted /
                                  $testResult.CodeCoverage.NumberOfCommandsAnalyzed * 100)
            "Pester code coverage on specified files: ${testCoverage}%"
        }
    }
    finally {
        Microsoft.PowerShell.Management\Pop-Location
        Remove-Module $ModuleName -ErrorAction SilentlyContinue
    }
}

Task TestDefault <#-depends BuildSimple #> -requiredVariables TestRootDir, ModuleName, CodeCoverageEnabled, CodeCoverageFiles,CodeCoverageOutPutFile,CodeCoverageOutputFileFormat,PesterReportFolder  {
    if (!(Get-Module Pester -ListAvailable)) {
        "Pester module is not installed. Skipping $($psake.context.currentTaskName) task."
        return
    }

    Import-Module Pester
    Write-Host "Running Test Default Task."
    try {
        Microsoft.PowerShell.Management\Push-Location -LiteralPath "$TestRootDir\default"

        if ($TestOutputFile) {
            $testing = @{
                OutputFile   = $TestOutputFile
                OutputFormat = $TestOutputFormat
                PassThru     = $true
                Verbose      = $VerbosePreference
            }
        }
        else {
            $testing = @{
                PassThru     = $true
                Verbose      = $VerbosePreference
            }
        }

        if(-not (Test-Path($PesterReportFolder))){
            mkdir $PesterReportFolder
        }

        # To control the Pester code coverage, a boolean $CodeCoverageEnabled is used.
        if ($CodeCoverageEnabled) {
            $testing.CodeCoverage = $CodeCoverageFiles
            $testing.CodeCoverageOutPutFile = $CodeCoverageOutPutFile
            $testing.CodeCoverageOutputFileFormat = $CodeCoverageOutputFileFormat
        }

        $testResult = Invoke-Pester @testing

        Assert -conditionToCheck (
            $testResult.FailedCount -eq 0
        ) -failureMessage "One or more Pester tests failed, build cannot continue."

        if ($CodeCoverageEnabled) {
            $testCoverage = [int]($testResult.CodeCoverage.NumberOfCommandsExecuted /
                                  $testResult.CodeCoverage.NumberOfCommandsAnalyzed * 100)
            "Pester code coverage on specified files: ${testCoverage}%"
        }
    }
    finally {
        Microsoft.PowerShell.Management\Pop-Location
        Remove-Module $ModuleName -ErrorAction SilentlyContinue
    }
}

Task Publish -depends Build, Test, BuildHelp, GenerateFileCatalog, BeforePublish, CorePublish, AfterPublish {
}

Task CorePublish -requiredVariables SettingsPath, ModuleOutDir {
    $publishParams = @{
        Path        = $ModuleOutDir
        NuGetApiKey = $NuGetApiKey
    }

    # Publishing to the PSGallery requires an API key, so get it.
    if ($NuGetApiKey) {
        "Using script embedded NuGetApiKey"
    }
    elseif ($NuGetApiKey = GetSetting -Path $SettingsPath -Key NuGetApiKey) {
        "Using stored NuGetApiKey"
    }
    else {
        $promptForKeyCredParams = @{
            DestinationPath = $SettingsPath
            Message         = 'Enter your NuGet API key in the password field'
            Key             = 'NuGetApiKey'
        }

        $cred = PromptUserForCredentialAndStorePassword @promptForKeyCredParams
        $NuGetApiKey = $cred.GetNetworkCredential().Password
        "The NuGetApiKey has been stored in $SettingsPath"
    }

    $publishParams = @{
        Path        = $ModuleOutDir
        NuGetApiKey = $NuGetApiKey
    }

    # If an alternate repository is specified, set the appropriate parameter.
    if ($PublishRepository) {
        $publishParams['Repository'] = $PublishRepository
    }

    # Consider not using -ReleaseNotes parameter when Update-ModuleManifest has been fixed.
    if ($ReleaseNotesPath) {
        $publishParams['ReleaseNotes'] = @(Get-Content $ReleaseNotesPath)
    }

    "Calling Publish-Module..."
    Publish-Module @publishParams
}

Task StageNuget -requiredVariables NugetPackagesDir, NugetExePath {
    # Restore/install Nuget

    Write-Verbose "Restoring Nuget client (if needed)"

    Write-Verbose "PackagesDir: $NugetPackagesDir"
    Write-Verbose "NugetExePath: $NugetExePath"

    if (-not (Test-Path $NugetPackagesDir -PathType Container))
    {
        Write-Verbose "Folder $NugetPackagesDir not found. Creating folder."
        md $NugetPackagesDir -Force | Write-Verbose
    }

    if (-not (Test-Path $NugetExePath -PathType Leaf))
    {
        Write-Verbose "Nuget.exe not found. Downloading from https://dist.nuget.org"
        Invoke-WebRequest -Uri https://dist.nuget.org/win-x86-commandline/latest/nuget.exe -OutFile $NugetExePath | Write-Verbose
    }
}

Task CleanTFSNugetPackages -requiredVariables NugetPackagesDir {
    if (Test-Path $NugetPackagesDir -PathType Container)
    {
        Write-Verbose "Removing $NugetPackagesDir..."
        Remove-Item $NugetPackagesDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
Task DownloadTfsNugetPackage -depends CleanTFSNugetPackages -requiredVariables NugetExePath, NugetPackagesDir {
    
    Write-Verbose "Restoring Microsoft.TeamFoundationServer.ExtendedClient Nuget package (if needed)"

    if (-not (Test-Path (Join-Path $NugetPackagesDir 'Microsoft.TeamFoundationServer.ExtendedClient') -PathType Container))
    {
        Write-Verbose "Microsoft.TeamFoundationServer.ExtendedClient not found. Downloading from Nuget.org"
        & $NugetExePath Install Microsoft.TeamFoundationServer.ExtendedClient -ExcludeVersion -OutputDirectory packages -Verbosity Detailed *>&1 | Write-Verbose
    }
    else
    {
        Write-Verbose "FOUND! Skipping..."
    }

    $TargetDir = (Join-Path $ModuleDir 'Lib\')

    if (-not (Test-Path $TargetDir -PathType Container)) { New-Item $TargetDir -ItemType Directory -Force | Out-Null }

    Write-Verbose "Copying TFS Client Object Model assemblies to output folder"

    foreach($d in (Get-ChildItem net4*, native -Directory -Recurse))
    {
        try
        {
            foreach ($f in (Get-ChildItem $d\*.dll -Recurse -Exclude *.resources.dll))
            {
                $SrcPath = $f.FullName
                $DstPath = Join-Path $TargetDir $f.Name

                if (-not (Test-Path $DstPath))
                {
                    Write-Verbose $DstPath
                    Copy-Item $SrcPath $DstPath
                }
            }
        }
        finally
        {}
    }
}

###############################################################################
# Secondary/utility tasks - typically used to manage stored build settings.
###############################################################################

Task ? -description 'Lists the available tasks' {
    "Available tasks:"
    $psake.context.Peek().Tasks.Keys | Sort-Object
}

Task RemoveApiKey -requiredVariables SettingsPath {
    if (GetSetting -Path $SettingsPath -Key NuGetApiKey) {
        RemoveSetting -Path $SettingsPath -Key NuGetApiKey
    }
}

Task StoreApiKey -requiredVariables SettingsPath {
    $promptForKeyCredParams = @{
        DestinationPath = $SettingsPath
        Message         = 'Enter your NuGet API key in the password field'
        Key             = 'NuGetApiKey'
    }

    PromptUserForCredentialAndStorePassword @promptForKeyCredParams
    "The NuGetApiKey has been stored in $SettingsPath"
}

Task ShowApiKey -requiredVariables SettingsPath {
    $OFS = ""
    if ($NuGetApiKey) {
        "The embedded (partial) NuGetApiKey is: $($NuGetApiKey[0..7])"
    }
    elseif ($NuGetApiKey = GetSetting -Path $SettingsPath -Key NuGetApiKey) {
        "The stored (partial) NuGetApiKey is: $($NuGetApiKey[0..7])"
    }
    else {
        "The NuGetApiKey has not been provided or stored."
        return
    }

    "To see the full key, use the task 'ShowFullApiKey'"
}

Task ShowFullApiKey -requiredVariables SettingsPath {
    if ($NuGetApiKey) {
        "The embedded NuGetApiKey is: $NuGetApiKey"
    }
    elseif ($NuGetApiKey = GetSetting -Path $SettingsPath -Key NuGetApiKey) {
        "The stored NuGetApiKey is: $NuGetApiKey"
    }
    else {
        "The NuGetApiKey has not been provided or stored."
    }
}

Task RemoveCertSubjectName -requiredVariables SettingsPath {
    if (GetSetting -Path $SettingsPath -Key CertSubjectName) {
        RemoveSetting -Path $SettingsPath -Key CertSubjectName
    }
}

Task StoreCertSubjectName -requiredVariables SettingsPath {
    $certSubjectName = 'CN='
    $certSubjectName += Read-Host -Prompt 'Enter the certificate subject name for script signing. Use exact casing, CN= prefix will be added'
    SetSetting -Key CertSubjectName -Value $certSubjectName -Path $SettingsPath
    "The new certificate subject name '$certSubjectName' has been stored in ${SettingsPath}."
}

Task ShowCertSubjectName -requiredVariables SettingsPath {
    $CertSubjectName = GetSetting -Path $SettingsPath -Key CertSubjectName
    "The stored certificate is: $CertSubjectName"

    $cert = Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert |
            Where-Object { $_.Subject -eq $CertSubjectName -and $_.NotAfter -gt (Get-Date) } |
            Sort-Object -Property NotAfter -Descending | Select-Object -First 1

    if ($cert) {
        "A valid certificate for the subject $CertSubjectName has been found"
    }
    else {
        'A valid certificate has not been found'
    }
}
