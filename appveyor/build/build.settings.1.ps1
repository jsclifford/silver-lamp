###############################################################################
# Customize these properties and tasks for your module.
###############################################################################

Properties {
    # ----------------------- Basic properties --------------------------------

    # The root directories for the module's docs, src and test.
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    $SolutionDir = Split-Path $PSScriptRoot -Parent
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    $DocsRootDir = "$SolutionDir\docs"
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    $SrcRootDir  = "$SolutionDir\src"
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    $TestRootDir = "$SolutionDir\test"
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    $BuildRootDir = "$SolutionDir\build"

    # The name of your module should match the basename of the PSD1 file.
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    $ModuleName = Get-Item $SrcRootDir/*.psd1 |
                      Where-Object { $null -ne (Test-ModuleManifest -Path $_ -ErrorAction SilentlyContinue) } |
                      Select-Object -First 1 | Foreach-Object BaseName

    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    $OutDir = "$SolutionDir\release"

     # ---------------------- Testing properties -------------------------------

    # Enable/disable Pester code coverage reporting.
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    $CodeCoverageEnabled = $true

    # CodeCoverageFiles specifies the files to perform code coverage analysis on. This property
    # acts as a direct input to the Pester -CodeCoverage parameter, so will support constructions
    # like the ones found here: https://github.com/pester/Pester/wiki/Code-Coverage.
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    $CodeCoverageFiles = "$SrcRootDir\*.ps1", "$SrcRootDir\*.psm1"

    # PesterReportFolder,
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    $PesterReportFolder = "$OutDir\PesterReport"

    # CodeCoverageOutPutFile,
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    $CodeCoverageOutPutFile = "$PesterReportFolder\CodeCoverage.xml"

    #CodeCoverageOutputFileFormat
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    $CodeCoverageOutputFileFormat = "JaCoCo"

    # Specifies an output file path to send to Invoke-Pester's -OutputFile parameter.
    # This is typically used to write out test results so that they can be sent to a CI
    # system like AppVeyor.
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    $TestOutputFile = "$PesterReportFolder\Unit.TEST.xml"

    # Specifies the test output format to use when the TestOutputFile property is given
    # a path.  This parameter is passed through to Invoke-Pester's -OutputFormat parameter.
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    $TestOutputFormat = "NUnitXml"
}
