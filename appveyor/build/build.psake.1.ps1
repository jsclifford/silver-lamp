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