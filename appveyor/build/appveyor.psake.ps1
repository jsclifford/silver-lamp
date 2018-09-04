Import-Module PSake

if($env:default_tests -eq 'y'){
    # Builds the module by invoking psake on the build.psake.ps1 script.
    Invoke-Pester -Script "$(Split-Path $PSScriptRoot -Parent )\test"
    Write-Verbose "Running Psake task TestDefault.  Psake script: $PSScriptRoot\build.psake.ps1" -Verbose
    Invoke-Psake "$PSScriptRoot\build.psake.ps1" -taskList "Build"
}else{
    # Builds the module by invoking psake on the build.psake.ps1 script.
    Write-Verbose "Running Psake task Test" -Verbose
    Invoke-Psake "$PSScriptRoot\build.psake.ps1" -taskList "Build"
}


if ($psake.build_success -eq $false){
    if($null -ne $env:APPVEYOR_BUILD_FOLDER){
        Add-AppveyorMessage -Message "Unit Test Failed."
        Update-AppveyorTest -Name "PSake Unitest" -Outcome Failed -ErrorMessage $psake.error_message -Framework NUnit
    }else{
        Write-Host "Psake Task failed. Unit Test Failed."
    }
    throw "Psake Build Failed"
}else{
    if($null -ne $env:APPVEYOR_BUILD_FOLDER){
        Update-AppveyorTest -Name "PSake Unitest" -Outcome Passed -Framework NUnit
    }else{
        Write-Host "Psake Unit Test Passed."
    }
}