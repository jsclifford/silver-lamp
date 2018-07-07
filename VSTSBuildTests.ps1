Write-Host "Checking environment variables for VSTS Builds."
Write-Host "Working Directory"
$env:workingdirectory

Write-Host "Common.TestResultsDirectory"
$env:COMMON_TESTRESULTSDIRECTORY


Write-Host "Build.StagingDirectory"
$env:BUILD_STAGINGDIRECTORY

Write-Host "Build.SourcesDirectory"
$env:BUILD_SOURCESDIRECTORY

Write-Host "System.DefaultWorkingDirectory"
$env:SYSTEM_DEFAULTWORKINGDIRECTORY

Write-Host "Getting current directory"
pwd

Write-Host "Getting file contents"
ls

Write-Host "PSScriptroot"
$PSScriptRoot
