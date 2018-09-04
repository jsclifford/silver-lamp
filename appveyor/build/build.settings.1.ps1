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

    # ------------------ Script analysis properties ---------------------------

    # Enable/disable use of PSScriptAnalyzer to perform script analysis.
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    $ScriptAnalysisEnabled = $true

    # When PSScriptAnalyzer is enabled, control which severity level will generate a build failure.
    # Valid values are Error, Warning, Information and None.  "None" will report errors but will not
    # cause a build failure.  "Error" will fail the build only on diagnostic records that are of
    # severity error.  "Warning" will fail the build on Warning and Error diagnostic records.
    # "Any" will fail the build on any diagnostic record, regardless of severity.
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    [ValidateSet('Error', 'Warning', 'Any', 'None')]
    $ScriptAnalysisFailBuildOnSeverityLevel = 'Error'

    # Path to the PSScriptAnalyzer settings file.
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    $ScriptAnalyzerSettingsPath = "$BuildRootDir\ScriptAnalyzerSettings.psd1"

    # ------------------- Script signing properties ---------------------------

    # Set to $true if you want to sign your scripts. You will need to have a code-signing certificate.
    # You can specify the certificate's subject name below. If not specified, you will be prompted to
    # provide either a subject name or path to a PFX file.  After this one time prompt, the value will
    # saved for future use and you will no longer be prompted.
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    $ScriptSigningEnabled = $false

    # Specify the Subject Name of the certificate used to sign your scripts.  Leave it as $null and the
    # first time you build, you will be prompted to enter your code-signing certificate's Subject Name.
    # This variable is used only if $SignScripts is set to $true.
    #
    # This does require the code-signing certificate to be installed to your certificate store.  If you
    # have a code-signing certificate in a PFX file, install the certificate to your certificate store
    # with the command below. You may be prompted for the certificate's password.
    #
    # Import-PfxCertificate -FilePath .\myCodeSigingCert.pfx -CertStoreLocation Cert:\CurrentUser\My
    #
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    $CertSubjectName = $null

    # Certificate store path.
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    $CertPath = "Cert:\"

    # -------------------- File catalog properties ----------------------------

    # Enable/disable generation of a catalog (.cat) file for the module.
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    $CatalogGenerationEnabled = $false

    # Select the hash version to use for the catalog file: 1 for SHA1 (compat with Windows 7 and
    # Windows Server 2008 R2), 2 for SHA2 to support only newer Windows versions.
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    $CatalogVersion = 2
}

Task BeforeStageFiles {

}

# Executes after the StageFiles task.
Task AfterStageFiles {

}

# Executes before the BeforeStageFiles phase of the Build task.
Task BeforeBuild {
    
}

# Executes after the Build task.
Task AfterBuild {

}

###############################################################################
# Customize these tasks for performing operations before and/or after BuildHelp.
###############################################################################

# Executes before the BuildHelp task.
Task BeforeBuildHelp {
}

# Executes after the BuildHelp task.
Task AfterBuildHelp {
}

###############################################################################
# Customize these tasks for performing operations before and/or after BuildUpdatableHelp.
###############################################################################

# Executes before the BuildUpdatableHelp task.
Task BeforeBuildUpdatableHelp {
}

# Executes after the BuildUpdatableHelp task.
Task AfterBuildUpdatableHelp {
}

###############################################################################
# Customize these tasks for performing operations before and/or after GenerateFileCatalog.
###############################################################################

# Executes before the GenerateFileCatalog task.
Task BeforeGenerateFileCatalog {
}

# Executes after the GenerateFileCatalog task.
Task AfterGenerateFileCatalog {
}

###############################################################################
# Customize these tasks for performing operations before and/or after Install.
###############################################################################

# Executes before the Install task.
Task BeforeInstall {
}

# Executes after the Install task.
Task AfterInstall {
}

###############################################################################
# Customize these tasks for performing operations before and/or after Publish.
###############################################################################

# Executes before the Publish task.
Task BeforePublish {
}

# Executes after the Publish task.
Task AfterPublish {
}