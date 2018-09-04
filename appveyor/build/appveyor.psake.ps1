Import-Module PSake

$buildRoot = "$PSScriptRoot"
if($env:default_tests -eq 'y'){
    # Builds the module by invoking psake on the build.psake.ps1 script.
    Write-Verbose "Running Psake task TestDefault" -Verbose
    Invoke-psake -buildFile "$buildRoot\build.psake.ps1" -taskList "TestDefault"
}else{
    # Builds the module by invoking psake on the build.psake.ps1 script.
    Write-Verbose "Running Psake task Test" -Verbose
    Invoke-psake -buildFile "$buildRoot\build.psake.ps1" -taskList "Test"
}


if ($psake.build_success -eq $false){
    $error_message = @"
Unit Test Failed. Error: 
$($psake.error_message)   
"@
    if($null -ne $env:APPVEYOR_BUILD_FOLDER){
        Add-AppveyorMessage -Message $error_message
        Update-AppveyorTest -Name "PSake Unitest" -Outcome Failed -ErrorMessage $psake.error_message -Framework NUnit
        
    }else{
        Write-Host "Psake Task failed. $($error_message)"
    }
    throw "Psake Build Failed"
}else{
    if($null -ne $env:APPVEYOR_BUILD_FOLDER){
        Update-AppveyorTest -Name "PSake Unitest" -Outcome Passed -Framework NUnit
    }else{
        Write-Host "Psake Unit Test Passed."
    }
}