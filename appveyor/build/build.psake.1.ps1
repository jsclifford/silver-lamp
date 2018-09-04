. $PSScriptRoot\build.settings.1.ps1

Task default -depends Build

Task Test -requiredVariables TestRootDir, CodeCoverageEnabled, CodeCoverageFiles,CodeCoverageOutPutFile,CodeCoverageOutputFileFormat,PesterReportFolder  {
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
        #Microsoft.PowerShell.Management\Push-Location -LiteralPath "$TestRootDir\default"

        if ($TestOutputFile) {
            $testing = @{
                OutputFile   = $TestOutputFile
                OutputFormat = $TestOutputFormat
                PassThru     = $true
                Verbose      = $VerbosePreference
                Script       = "$TestRootDir\default"
            }
        }
        else {
            $testing = @{
                PassThru     = $true
                Verbose      = $VerbosePreference
                Script       = "$TestRootDir\default"
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