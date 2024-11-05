<#
    .SYNOPSIS
    Performs installation/maintenance of various components for running Amazon ECS on customer managed external instances.

    .DESCRIPTION
    This script enables customers to run Amazon ECS on external instances by supporting-
    - Installation of AWS SSM on the instance
    - Registration of the external instance as an AWS SSM managed instance
    - Installation of ECSTools Powershell module to support Amazon ECS
    - Installation of Amazon ECS container runtime on the instance
    - Installation of Amazon ECS Agent on the instance
    - Uninstallation of Amazon ECS Anywhere components from the customer managed instance
    - Updating Amazon ECS container agent running on the instance

    NOTE: Please run this script with Administrator privileges.

    .PARAMETER Region
    [Optional] Specifies the region of Amazon ECS Cluster and AWS SSM activation. It is required unless -Uninstall is specified.

    .PARAMETER ActivationID
    [Optional] Specifies activation id from the create activation command. Not required if -SkipRegistration or -Uninstall is specified.

    .PARAMETER ActivationCode
    [Optional] Specifies activation code from the create activation command. Not required if -SkipRegistration or -Uninstall is specified.

    .PARAMETER Cluster
    [Optional] Specifies the cluster name to which the Amazon ECS agent will connect to. Defaults to 'default'.

    .PARAMETER ECSVersion
    [Optional] Specifies the Amazon ECS agent version which would be installed on the instance. Defaults to 'latest'.

    .PARAMETER SkipRegistration
    [Optional] Specifies that SSM installation and registration of instance to SSM can be skipped.

    .PARAMETER Uninstall
    [Optional] Specifies if the uninstallation needs to be performed on the instance.

    .PARAMETER ECSEndpoint
    [Optional] Specifies the endpoint to which the Amazon ECS agent would connect.

    .PARAMETER OverrideArtifactsS3Bucket
    [Optional] Specifies the S3 endpoint bucket to pull the ECS Anywhere artifacts from.

    .INPUTS
    None. You cannot pipe objects to this script.

    .OUTPUTS
    None. This script does not generate an output object.

    .EXAMPLE
    PS> .\ecs-anywhere-install.ps1 -Region us-west-2 -ActivationID <ID> -ActivationCode <Code> -Cluster ecs-anywhere
    Installs Container runtime, AWS SSM, and Amazon ECS (latest container agent) on the instance. It also registers the instance with AWS SSM and registers the instance to Amazon ECS cluster.

    .EXAMPLE
    PS> .\ecs-anywhere-install.ps1 -Region us-west-2 -ActivationID <ID> -ActivationCode <Code> -Cluster ecs-anywhere -ECSVersion 1.57.0
    Installs a specific version of Amazon ECS agent on the instance along with other dependencies as Example 1.

    .EXAMPLE
    PS> .\ecs-anywhere-install.ps1 -Region us-west-2 -SkipRegistration -Cluster ecs-anywhere
    Installs only container runtime and Amazon ECS on the instance.

    .EXAMPLE
    PS> .\ecs-anywhere-install.ps1 -Region us-west-2 -SkipRegistration -Cluster ecs-anywhere -ECSVersion 1.56.0
    Installs a specific version of Amazon ECS agent on the instance. This can be used for updating the container agent running on the instance.

    .EXAMPLE
    PS> .\ecs-anywhere-install.ps1 -Uninstall
    Stops and removes the AWS SSM and Amazon ECS services from the customer instance.

    .LINK
    Amazon ECS Anywhere documentation: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-anywhere.html

    .NOTES
    Amazon ECS Anywhere on Windows is supported only for the following Windows releases-
    - Windows Server 2022
    - Windows Server 20H2
    - Windows Server 2019
    - Windows Server 2016
#>

#Requires -RunAsAdministrator

Param (
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Region,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$ActivationID,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$ActivationCode,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Cluster = "default",

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$ECSVersion = "latest",

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$SkipRegistration,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$Uninstall,

    [Parameter(Mandatory=$false)]
    [string]$ECSEndpoint,

    [Parameter(Mandatory=$false)]
    [string]$OverrideArtifactsS3Bucket
)

Function Initialize-ScriptDependencies {
    # AllowedOSBuildNumberToRelease corresponds to the map of build number of allowed Windows releases to the release name.
    # Reference- https://docs.microsoft.com/en-us/windows-server/get-started/windows-server-release-info
    [HashTable]$Script:AllowedOSBuildNumberToRelease = @{
        "20348"="2022";
        "17763"="2019";
        "14393"="2016";
    }

    # TempDirectory is the temporary directory created to store the artifacts.
    [String]$Script:TempDirectory = Join-Path $env:TEMP (New-Guid)

    # Remove the contents of temp directory if it exists. Otherwise, create a new folder.
    if (Test-Path -Path $Script:TempDirectory) {
        Remove-Item -Path $Script:TempDirectory/* -Recurse -Force
    } else {
        New-Item -Path $Script:TempDirectory -ItemType Directory
    }

    # ECSProgramData is the Amazon ECS ProgramData directory.
    [String]$Script:ECSProgramData = Join-Path $ENV:ProgramData "Amazon\ECS"
    # ECSCache is the cache location for ECS artifacts.
    [String]$Script:ECSCache = Join-Path $ENV:ProgramData "Amazon\ECS\cache"
    # ECSModulePath is the path of ECSTools powershell module.
    [String]$Script:ECSModulePath = Join-Path $ENV:ProgramFiles "WindowsPowerShell\Modules\ECSTools"
    # ECSInstallationPath is the path of Amazon ECS artifacts on the instance.
    [String]$Script:ECSInstallationPath = Join-Path $ENV:ProgramFiles "Amazon\ECS"
    # SSMInstallationPath is the path on host where Amazon SSM will be installed.
    [String]$Script:SSMInstallationPath = Join-Path $ENV:ProgramFiles "Amazon\SSM"

    # SSMAgentInstaller is the name of the Amazon SSM agent installer.
    [String]$Script:SSMAgentInstaller = "AmazonSSMAgentSetup.exe"
    # SSMAgentS3Bucket is the S3 bucket which holds the AWS SSM Agent installer.
    [String]$Script:SSMAgentS3Bucket = "amazon-ssm-$($Region)"
    # SSMAgentS3FilePath is the S3 path for the AWS SSM Agent installer.
    [String]$Script:SSMAgentS3FilePath = "latest/windows_amd64/$($Script:SSMAgentInstaller)"
    # SSMAgentInstallerFullPath is the absolute path of the location of SSM agent installer.
    [String]$Script:SSMAgentInstallerFullPath = Join-Path $Script:TempDirectory $Script:SSMAgentInstaller

    # DockerInstallationPath is the path of docker installation on the instance.
    [String]$Script:DockerInstallationPath = Join-Path $ENV:ProgramFiles "Docker"
    # DockerCredSpecsPath is the path of docker credential specs on the instance.
    [String]$Script:DockerCredSpecsPath = Join-Path $Script:DockerInstallationPath "CredentialSpecs"
    # DockerDaemonFileName is the name of the docker daemon binary.
    [String]$Script:DockerDaemonFileName = "dockerd.exe"
    # DockerCLIFileName is the name of the docker CLI binary.
    [String]$Script:DockerCLIFileName = "docker.exe"
    # DockerInstallationScriptFileName is the script for installing docker.
    [String]$Script:DockerInstallationScriptFileName = "Add-DockerdRuntime.ps1"

    # ECSAgentSourceBucket is the source bucket for the agent artifacts.
    [String]$Script:ECSAgentSourceBucket = "amazon-ecs-agent-$($Region)"
    # ECSAnywhereArtifactsS3Bucket is the source bucket for the ECS Anywhere artifacts.
    [String]$Script:ECSAnywhereArtifactsS3Bucket = $Script:ECSAgentSourceBucket
    # If "OverrideArtifactsS3Bucket" parameter was passed to the script, use that for "ECSAnywhereArtifactsS3Bucket".
    if (-not([string]::IsNullOrEmpty($OverrideArtifactsS3Bucket)))
    {
        $Script:ECSAnywhereArtifactsS3Bucket = $OverrideArtifactsS3Bucket
    }

    # ECSAnywhereWindowsArtifactsFileName is the name of the artifact archive for ECS Anywhere Windows.
    [String]$Script:ECSAnywhereWindowsArtifactsFileName = "ECSAnywhereWindowsArtifacts.zip"
    # ECSAnywhereWindowsArtifactsHashFileName is the name of the file containing hash for the ECS Anywhere Windows artifacts archive.
    [String]$Script:ECSAnywhereWindowsArtifactsHashFileName = "ECSAnywhereWindowsArtifacts.zip.sha256"
    # ECSAnywhereWindowsArtifactsS3Path is the full S3 url for the ECS Anywhere Windows artifacts.
    [String]$Script:ECSAnywhereWindowsArtifactsS3FilePath = $ECSAnywhereWindowsArtifactsFileName
    # ECSAnywhereWindowsArtifactsHashS3URL is the full S3 url for the ECS Anywhere Windows artifacts hash.
    [String]$Script:ECSAnywhereWindowsArtifactsHashS3FilePath = $ECSAnywhereWindowsArtifactsHashFileName
    # ECSAnywhereWindowsArtifactsHostPath is the host path where the ECS Anywhere Windows artifacts archive needs to be unarchived.
    [String]$Script:ECSAnywhereWindowsArtifactsHostPath = Join-Path $Script:TempDirectory "ECSAnywhereWindowsArtifacts"

    # ECSToolsPSM1 is the name for the file ECSTools.psm1.
    [String]$Script:ECSToolsPSM1 = "ECSTools.psm1"
    # ECSToolsPSD1 is the name for the file ECSTools.psd1.
    [String]$Script:ECSToolsPSD1 = "ECSTools.psd1"

    # ECSExecArtifactsArchiveName is the name of the ECS Exec artifacts archive.
    [string]$Script:ECSExecArtifactsArchiveName = "execute-command-binaries.zip"
    # ExecInstallationScriptFileName is the script for installing ECS Exec dependencies.
    [string]$Script:ExecInstallationScriptFileName = "Add-ECSExecArtifacts.ps1"

    # SSMAgentServiceName is the name of the Amazon SSM Agent service.
    [String]$Script:SSMAgentServiceName = "AmazonSSMAgent"
    # AmazonECSServiceName is the name of the Amazon ECS Agent service.
    [String]$Script:AmazonECSServiceName = "AmazonECS"
    # ECSContainerRuntimeName is the name of the ECS container runtime.
    [String]$Script:ECSContainerRuntimeName = "Docker"

    # Install AWSPowershell module if not installed.
    if (-Not (Get-Module -ListAvailable -Name AWSPowershell)) {
        # Install AWSPowershell module
        Install-Module AWSPowershell -AllowClobber -Force
    }
}

Function Write-Log {
    <#
    .SYNOPSIS
    This is a helper method for writing the output logs to stdout.
    #>
    [cmdletbinding()]
    Param (
        $Message
    )

    $fullMessage = "$(((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))) - $($message)"
    Write-Host $fullMessage
}

Function Test-OSRelease {
    <#
    .SYNOPSIS
    This method tests if the current OS release is supported by Amazon ECS Anywhere.
    #>

    [String]$CurrentOSBuildNumber = $PSVersionTable.PSVersion.Build
    if (-not $Script:AllowedOSBuildNumberToRelease.ContainsKey($CurrentOSBuildNumber)) {
        throw "The current Windows release with build number {0} is not supported." -f $CurrentOSBuildNumber
    }
    Write-Log ("OS release {0} is supported" -f $Script:AllowedOSBuildNumberToRelease[$CurrentOSBuildNumber])
}

Function Test-ScriptParameters {
    <#
    .SYNOPSIS
    This method performs validation of the parameters for the script.
    #>

    if (-not $Uninstall)
    {
        if (-not $Cluster) {
            throw "Cluster is required unless -Uninstall was specified"
        }

        if ((-not $SkipRegistration) -and ((-not $ActivationCode) -or (-not $ActivationID)))
        {
            throw "Activation Code and ID are required if -SkipRegistration is not used."
        }

        if ($SkipRegistration) {
            # If the registration is skipped then the SSM Agent service must be running.
            Test-ServiceStatus -ServiceName $Script:SSMAgentServiceName
        }
    }
}

Function Enable-ContainersFeature {
    <#
    .SYNOPSIS
    This method enables the Windows feature of containers.
    #>
    # In order to run Windows containers, containers feature needs to be enabled.
    # The host needs to be restarted as well.
    $result = Enable-WindowsOptionalFeature -Online -FeatureName containers -All -NoRestart
    if ($result.RestartNeeded -eq $true) {
        Write-Log "Restart the system to complete installation of Windows feature: Containers"
        exit 0
    } else {
        Write-Log "Restart is not needed while enabling Windows feature: Containers"
    }
}

Function Get-FileFromS3 {
    <#
    .SYNOPSIS
    This method downloads a file from Amazon S3 at the specified path.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$S3Bucket,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$S3FilePath,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputFilePath
    )

    Begin {
        if (Test-Path -Path $OutputFilePath) {
            Write-Log ("Existing file found at {0}. Deleting it." -f $OutputFilePath)
            Remove-Item -Recurse -Force $OutputFilePath
        }
    } Process {
            try {
                Write-Log ("Downloading file from S3: {0}/{1}" -f $S3Bucket,$S3FilePath)
                Read-S3Object -Bucket $S3Bucket -Key $S3FilePath -File $OutputFilePath
            } catch {
                throw "Error downloading file from S3: {0}/{1} at {2}. Message: {3}" -f $S3Bucket,$S3FilePath,$OutputFilePath,$_.Exception.Message
            }
    } End {
        if (-not (Test-Path -Path $OutputFilePath)) {
            throw "Failed to download file from S3: {0}/{1} at {2}. Message: {3}" -f $S3Bucket,$S3FilePath,$OutputFilePath,$_.Exception.Message
        }
    }
}

Function Test-ServiceStatus {
    <#
    .SYNOPSIS
    This method tests if the specified service is in running status.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ServiceName,

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [int]$SleepTime = 5
    )

    if (-not (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue)) {
        throw "{0} service not found" -f $ServiceName
    }

    Write-Log ("Validating if the {0} service is running..." -f $ServiceName)
    for ($iteration=1; $iteration -le 10; $iteration++) {
        if ((Get-Service -Name $ServiceName).Status -eq "Running") {
            Write-Log ("{0} service is running!" -f $ServiceName)
            return
        } else {
            Write-Log ("{0} service is not running. Waiting for it to move into running status after {1} retry." -f $ServiceName,$iteration)
            Start-Sleep $SleepTime
        }
    }

    throw "{0} service failed to start" -f $ServiceName
}

Function Install-SSMAgent {
    <#
    .SYNOPSIS
    This method downloads and installs the AWS SSM agent.
    It also registers the external instance with AWS SSM using the provided activation code and ID.
    #>

    try {
        # Download SSM Agent installer from S3.
        Get-FileFromS3 -S3Bucket $Script:SSMAgentS3Bucket -S3FilePath $Script:SSMAgentS3FilePath -OutputFilePath $Script:SSMAgentInstallerFullPath
        # TODO: Currently, SSM Agent does not publish hash for their artifacts and therefore, we are not validating the hash for now.
        # In the future, when hash is published along with the agent artifacts, we need to start validating the hash as well.

        # Remove any existing SSM artifacts before starting a fresh install.
        Remove-SSMArtifacts

        # Install latest SSM agent on the instance.
        Write-Log "Starting installation of Amazon SSM agent..."
        Start-Process $Script:SSMAgentInstallerFullPath -ArgumentList @("/q", "/log", "install.log", "CODE=$($ActivationCode)", "ID=$($ActivationID)", "REGION=$($Region)") -Wait
        Test-ServiceStatus -ServiceName $Script:SSMAgentServiceName
    } catch {
        throw "Failed to install SSM agent on the instance: {0}" -f $_.Exception.Message
    }
}

Function Get-ECSAnywhereArtifacts {
    <#
    .SYNOPSIS
    This method downloads and unarchives the ECS Anywhere Windows artifacts archive.
    #>

    Write-Log "Downloading the artifacts used for ECS Anywhere installation..."

    $ArtifactsFullPath = Join-Path $Script:TempDirectory $Script:ECSAnywhereWindowsArtifactsFileName
    Get-FileFromS3 -S3Bucket $Script:ECSAnywhereArtifactsS3Bucket -S3FilePath $Script:ECSAnywhereWindowsArtifactsS3FilePath -OutputFilePath $ArtifactsFullPath

    $ArtifactsHashFullPath = Join-Path $Script:TempDirectory $Script:ECSAnywhereWindowsArtifactsHashFileName
    Get-FileFromS3 -S3Bucket $Script:ECSAnywhereArtifactsS3Bucket -S3FilePath $Script:ECSAnywhereWindowsArtifactsHashS3FilePath -OutputFilePath $ArtifactsHashFullPath

    # Compare the SHA-256 hash of the downloaded archive with the value present in the file.
    $calculatedHash = (Get-FileHash -Path $ArtifactsFullPath).Hash
    $downloadedHash = Get-Content -Path $ArtifactsHashFullPath

    if ($calculatedHash -ne $downloadedHash) {
        throw "Mismatch between calculated and downloaded hash for ECS Anywhere artifacts. Calculated hash: $calculatedHash. Downloaded hash: $downloadedHash"
    }
    Write-Log "SHA256 Hash of the downloaded archive matches the expected hash. Continuing..."

    # Expand the archive inside the staging folder.
    Expand-Archive -Path $ArtifactsFullPath -DestinationPath $Script:ECSAnywhereWindowsArtifactsHostPath
}

Function Install-ContainerRuntime {
    <#
    .SYNOPSIS
    This method downloads and installs container runtime for Amazon ECS.
    #>

    try {
        Write-Log "Starting installation of ECS container runtime..."

        # If the path for Docker already exists, then remove it.
        if (Test-Path -Path $Script:DockerInstallationPath) {
            Stop-Service $Script:ECSContainerRuntimeName
            Remove-Item -Recurse -Force -Path $Script:DockerInstallationPath
        }
        # Create the directory for Docker installation.
        New-Item -Path $Script:DockerInstallationPath -ItemType directory
        New-Item -Path $Script:DockerCredSpecsPath -ItemType directory

        # Copy all the binaries to the installation folder.
        $installationScriptRootPath = Join-Path $Script:ECSAnywhereWindowsArtifactsHostPath "DockerCE"
        Copy-Item $(Join-Path $installationScriptRootPath $Script:DockerDaemonFileName) -Destination $Script:DockerInstallationPath
        Copy-Item $(Join-Path $installationScriptRootPath "$Script:DockerDaemonFileName.sha256") -Destination $Script:DockerInstallationPath
        Copy-Item $(Join-Path $installationScriptRootPath $Script:DockerCLIFileName) -Destination $Script:DockerInstallationPath
        Copy-Item $(Join-Path $installationScriptRootPath "$Script:DockerCLIFileName.sha256") -Destination $Script:DockerInstallationPath

        # Invoke the installation script.
        $result = Invoke-Expression -Command "$(Join-Path $installationScriptRootPath $Script:DockerInstallationScriptFileName)"
        # Start the docker service.
        Start-Service $Script:ECSContainerRuntimeName
        # Test the installation.
        Invoke-Expression -Command "$(Join-Path $installationScriptRootPath $Script:DockerInstallationScriptFileName) -Validate"
    } catch {
        throw "Failed to install container runtime on the instance: {0}" -f $_.Exception.Message
    }
}

Function Install-ECSToolsModule {
    <#
    .SYNOPSIS
    This method installs the ECSTools Powershell module.
    #>

    try {
        Write-Log "Starting installation of ECSTools powershell module..."

        # If module exists in the current session, then remove it.
        Get-Module -Name ECSTools | Remove-Module

        # Remove the module itself from Powershell.
        if (Test-Path -Path $Script:ECSModulePath) {
            Remove-Item -Recurse -Force -Path $Script:ECSModulePath
        }

        # Add the downloaded module to the Powershell.
        Write-Log "Setting up ECSTools inside powershell modules."
        New-Item -ItemType "directory" -Path $Script:ECSModulePath
        $ECSToolsArtifactsPath = Join-Path $Script:ECSAnywhereWindowsArtifactsHostPath "ECSTools"
        Copy-Item $(Join-Path $ECSToolsArtifactsPath $Script:ECSToolsPSM1) -Destination $(Join-Path $Script:ECSModulePath $Script:ECSToolsPSM1)
        Copy-Item $(Join-Path $ECSToolsArtifactsPath $Script:ECSToolsPSD1) -Destination $(Join-Path $Script:ECSModulePath $Script:ECSToolsPSD1)

        if ((-not (Test-Path $Script:ECSModulePath)) -or ((Get-ChildItem $Script:ECSModulePath | Measure-Object).Count -ne 2)) {
            throw "Expected files for ECSTools not found."
        }

        if (-not (Get-Module -ListAvailable -Name ECSTools)) {
            throw "ECSTools not found among installed powershell modules."
        }
    } catch {
        throw "Failed to install ECSTools module on the instance: {0}" -f $_.Exception.Message
    }
}

Function Add-ECSExecDependencies {
    <#
    .SYNOPSIS
    This method creates the artifact archive required for ECS Exec initialization.
    #>

    try {
        Write-Log "Starting creation of ECS Exec artifacts archive..."

        $archivePath = "$Script:ECSProgramData\$Script:ECSExecArtifactsArchiveName"
        # If the archive exists, then delete the archive.
        if (Test-Path -Path $archivePath) {
            Write-Log "ECS Exec artifacts archive already exists. Removing the existing archive."
            Remove-Item -Recurse -Force -Path $archivePath
        }

        $installationScriptRootPath = Join-Path $Script:ECSAnywhereWindowsArtifactsHostPath "Exec"
        $installationScriptPath = Join-Path $installationScriptRootPath $Script:ExecInstallationScriptFileName

        # Invoke the installation script.
        Invoke-Expression -Command "$installationScriptPath -SourcePath '$Script:SSMInstallationPath'-DestinationDirectory '$Script:ECSProgramData' -Compress -IncludeVersion -ArchiveName '$Script:ECSExecArtifactsArchiveName'"
    } catch {
        throw "Failed to create ECS Exec artifacts archive : {0}" -f $_.Exception.Message
    }
}

Function Install-ECSAgent {
    <#
    .SYNOPSIS
    This method downloads and installs the Amazon ECS Agent on the instance along with all the prerequisites.

    .DESCRIPTION
    This method performs the following actions-
    - Downloads the required version of Amazon ECS agent
    - Sets up various environment variables required for Amazon ECS agent to run on the external instance
    - Starts Amazon ECS Agent as a Windows service
    #>

    try {
        Write-Log "Starting installation of ECS Agent..."
        Import-Module ECSTools

        $InitializeAgentArgs = @{
            AWSDefaultRegion = $Region;
            OverrideSourceRegion = $Region;
            OverrideSourceBucket = $Script:ECSAgentSourceBucket;
            Version = $ECSVersion;
            Cluster = $Cluster;
            ECSEndpoint = $ECSEndpoint;
            LoggingDrivers = '["json-file","awslogs"]';
        }
        Initialize-ECSAgent @InitializeAgentArgs -ExternalInstance -EnableTaskIAMRole
        Test-ServiceStatus -ServiceName $Script:AmazonECSServiceName
    } catch {
        throw "Failed to install ECS Agent on the instance: {0}" -f $_.Exception.Message
    }
}

Function Remove-SSMArtifacts {
    <#
    .SYNOPSIS
    This method stops and uninstalls AWS SSM from the customer instance.

    .DESCRIPTION
    This method stop the AmazonSSM service and uninstalls AWS SSM from the customer instance.
    #>

    try {
        Write-Log "Starting uninstallation of any existing SSM agent version..."
        # Check and remove the SSM Agent service, if it exists.
        $existingSvc = Get-WmiObject -Class Win32_Service -Filter "Name='$Script:SSMAgentServiceName'"
        if ($existingSvc -ne $null) {
            Write-Log "Existing SSM agent installation found. Stopping and deleting the service."
            $existingSvc.StopService()
            $existingSvc.Delete()
            # Wait few seconds for the service to be deleted.
            Start-Sleep 1
        }

        Write-Log "Uninstalling any existing SSM agent installation"
        if (-not (Test-Path $Script:SSMAgentInstallerFullPath)) {
            Get-FileFromS3 -S3Bucket $Script:SSMAgentS3Bucket -S3FilePath $Script:SSMAgentS3FilePath -OutputFilePath $Script:SSMAgentInstallerFullPath
            # TODO: Currently, SSM Agent does not publish hash for their artifacts and therefore, we are not validating the hash for now.
            # In the future, when hash is published along with the agent artifacts, we need to start validating the hash as well.
        }
        Start-Process $Script:SSMAgentInstallerFullPath -ArgumentList @('/uninstall', '/q', '/norestart') -Wait
    } catch {
        throw "Failed to uninstall SSM on the instance: {0}" -f $_.Exception.Message
    }
    Write-Log "Uninstallation of SSM agent succeeded."
}

Function Remove-ECSArtifacts {
    <#
    .SYNOPSIS
    This method stops and uninstalls Amazon ECS along with other components from the customer instance.

    .DESCRIPTION
    This method stops the AmazonECS service and removes the service along with ECSTools from the external instance.
    #>

    try {
        Write-Log "Starting uninstallation of any existing ECS artifacts..."
        # Remove Amazon ECS service.
        Import-Module ECSTools
        Remove-ECSAgentInstallation

        # Remove the installation folder for Amazon ECS.
        Remove-Item -Recurse -Force $Script:ECSInstallationPath

        # Remove the cache folder for Amazon ECS.
        Remove-Item -Recurse -Force $Script:ECSCache

        # If ECSTools module exists in the current session, then remove it.
        Get-Module -Name ECSTools | Remove-Module

        # Remove the module from Powershell.
        if (Test-Path $Script:ECSModulePath)
        {
            Remove-Item -Recurse -Force $Script:ECSModulePath
        }
        Write-Log "Uninstallation of ECS artifacts succeeded."
    } catch {
        throw "Failed to uninstall ECS Agent on the instance: {0}" -f $_.Exception.Message
    }
}

try {
    # Initialize all the dependencies for running this script.
    Initialize-ScriptDependencies
    # Validate if the current OS release is supported for running Amazon ECS Anywhere.
    Test-OSRelease
    # Validate the parameters with which the script was invoked.
    Test-ScriptParameters
    # Enable the containers feature.
    Enable-ContainersFeature
    # Download the ECS Anywhere Windows artifacts.
    Get-ECSAnywhereArtifacts
    # Install the helper Amazon ECS Powershell module.
    Install-ECSToolsModule

    if (-not $Uninstall)
    {
        # Install container runtime before installing AWS SSM or Amazon ECS.
        Install-ContainerRuntime

        if (-not $SkipRegistration)
        {
            Install-SSMAgent
        }

        Add-ECSExecDependencies

        Install-ECSAgent

        Write-Log "Installation of Amazon ECS on this instance was successful."
    }
    else
    {
        # Uninstallation order is opposite of installation order.
        Remove-ECSArtifacts
        Remove-SSMArtifacts

        Write-Log "Uninstallation of AWS SSM and Amazon ECS on this instance was successful."
    }
} catch {
    Write-Log ("[ERROR] Failed to setup Amazon ECS Anywhere on this instance. Exception: {0}" -f $_.Exception.Message)
    Exit 1
} finally {
    Remove-Item -Recurse -Force $Script:TempDirectory
}

# SIG # Begin signature block
# MIIueQYJKoZIhvcNAQcCoIIuajCCLmYCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAgXtWAmzpbHDxz
# 1ijzyrxBTpBloabtfo94H46MBCo556CCE+YwggXAMIIEqKADAgECAhAP0bvKeWvX
# +N1MguEKmpYxMA0GCSqGSIb3DQEBCwUAMGwxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xKzApBgNV
# BAMTIkRpZ2lDZXJ0IEhpZ2ggQXNzdXJhbmNlIEVWIFJvb3QgQ0EwHhcNMjIwMTEz
# MDAwMDAwWhcNMzExMTA5MjM1OTU5WjBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMM
# RGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQD
# ExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQwggIiMA0GCSqGSIb3DQEBAQUAA4IC
# DwAwggIKAoICAQC/5pBzaN675F1KPDAiMGkz7MKnJS7JIT3yithZwuEppz1Yq3aa
# za57G4QNxDAf8xukOBbrVsaXbR2rsnnyyhHS5F/WBTxSD1Ifxp4VpX6+n6lXFllV
# cq9ok3DCsrp1mWpzMpTREEQQLt+C8weE5nQ7bXHiLQwb7iDVySAdYyktzuxeTsiT
# +CFhmzTrBcZe7FsavOvJz82sNEBfsXpm7nfISKhmV1efVFiODCu3T6cw2Vbuyntd
# 463JT17lNecxy9qTXtyOj4DatpGYQJB5w3jHtrHEtWoYOAMQjdjUN6QuBX2I9YI+
# EJFwq1WCQTLX2wRzKm6RAXwhTNS8rhsDdV14Ztk6MUSaM0C/CNdaSaTC5qmgZ92k
# J7yhTzm1EVgX9yRcRo9k98FpiHaYdj1ZXUJ2h4mXaXpI8OCiEhtmmnTK3kse5w5j
# rubU75KSOp493ADkRSWJtppEGSt+wJS00mFt6zPZxd9LBADMfRyVw4/3IbKyEbe7
# f/LVjHAsQWCqsWMYRJUadmJ+9oCw++hkpjPRiQfhvbfmQ6QYuKZ3AeEPlAwhHbJU
# KSWJbOUOUlFHdL4mrLZBdd56rF+NP8m800ERElvlEFDrMcXKchYiCd98THU/Y+wh
# X8QgUWtvsauGi0/C1kVfnSD8oR7FwI+isX4KJpn15GkvmB0t9dmpsh3lGwIDAQAB
# o4IBZjCCAWIwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQU7NfjgtJxXWRM3y5n
# P+e6mK4cD08wHwYDVR0jBBgwFoAUsT7DaQP4v0cB1JgmGggC72NkK8MwDgYDVR0P
# AQH/BAQDAgGGMBMGA1UdJQQMMAoGCCsGAQUFBwMDMH8GCCsGAQUFBwEBBHMwcTAk
# BggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEkGCCsGAQUFBzAC
# hj1odHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRIaWdoQXNzdXJh
# bmNlRVZSb290Q0EuY3J0MEsGA1UdHwREMEIwQKA+oDyGOmh0dHA6Ly9jcmwzLmRp
# Z2ljZXJ0LmNvbS9EaWdpQ2VydEhpZ2hBc3N1cmFuY2VFVlJvb3RDQS5jcmwwHAYD
# VR0gBBUwEzAHBgVngQwBAzAIBgZngQwBBAEwDQYJKoZIhvcNAQELBQADggEBAEHx
# qRH0DxNHecllao3A7pgEpMbjDPKisedfYk/ak1k2zfIe4R7sD+EbP5HU5A/C5pg0
# /xkPZigfT2IxpCrhKhO61z7H0ZL+q93fqpgzRh9Onr3g7QdG64AupP2uU7SkwaT1
# IY1rzAGt9Rnu15ClMlIr28xzDxj4+87eg3Gn77tRWwR2L62t0+od/P1Tk+WMieNg
# GbngLyOOLFxJy34riDkruQZhiPOuAnZ2dMFkkbiJUZflhX0901emWG4f7vtpYeJa
# 3Cgh6GO6Ps9W7Zrk9wXqyvPsEt84zdp7PiuTUy9cUQBY3pBIowrHC/Q7bVUx8ALM
# R3eWUaNetbxcyEMRoacwggawMIIEmKADAgECAhAIrUCyYNKcTJ9ezam9k67ZMA0G
# CSqGSIb3DQEBDAUAMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJ
# bmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0
# IFRydXN0ZWQgUm9vdCBHNDAeFw0yMTA0MjkwMDAwMDBaFw0zNjA0MjgyMzU5NTla
# MGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8GA1UE
# AxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBDb2RlIFNpZ25pbmcgUlNBNDA5NiBTSEEz
# ODQgMjAyMSBDQTEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDVtC9C
# 0CiteLdd1TlZG7GIQvUzjOs9gZdwxbvEhSYwn6SOaNhc9es0JAfhS0/TeEP0F9ce
# 2vnS1WcaUk8OoVf8iJnBkcyBAz5NcCRks43iCH00fUyAVxJrQ5qZ8sU7H/Lvy0da
# E6ZMswEgJfMQ04uy+wjwiuCdCcBlp/qYgEk1hz1RGeiQIXhFLqGfLOEYwhrMxe6T
# SXBCMo/7xuoc82VokaJNTIIRSFJo3hC9FFdd6BgTZcV/sk+FLEikVoQ11vkunKoA
# FdE3/hoGlMJ8yOobMubKwvSnowMOdKWvObarYBLj6Na59zHh3K3kGKDYwSNHR7Oh
# D26jq22YBoMbt2pnLdK9RBqSEIGPsDsJ18ebMlrC/2pgVItJwZPt4bRc4G/rJvmM
# 1bL5OBDm6s6R9b7T+2+TYTRcvJNFKIM2KmYoX7BzzosmJQayg9Rc9hUZTO1i4F4z
# 8ujo7AqnsAMrkbI2eb73rQgedaZlzLvjSFDzd5Ea/ttQokbIYViY9XwCFjyDKK05
# huzUtw1T0PhH5nUwjewwk3YUpltLXXRhTT8SkXbev1jLchApQfDVxW0mdmgRQRNY
# mtwmKwH0iU1Z23jPgUo+QEdfyYFQc4UQIyFZYIpkVMHMIRroOBl8ZhzNeDhFMJlP
# /2NPTLuqDQhTQXxYPUez+rbsjDIJAsxsPAxWEQIDAQABo4IBWTCCAVUwEgYDVR0T
# AQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQUaDfg67Y7+F8Rhvv+YXsIiGX0TkIwHwYD
# VR0jBBgwFoAU7NfjgtJxXWRM3y5nP+e6mK4cD08wDgYDVR0PAQH/BAQDAgGGMBMG
# A1UdJQQMMAoGCCsGAQUFBwMDMHcGCCsGAQUFBwEBBGswaTAkBggrBgEFBQcwAYYY
# aHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEEGCCsGAQUFBzAChjVodHRwOi8vY2Fj
# ZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNydDBDBgNV
# HR8EPDA6MDigNqA0hjJodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRU
# cnVzdGVkUm9vdEc0LmNybDAcBgNVHSAEFTATMAcGBWeBDAEDMAgGBmeBDAEEATAN
# BgkqhkiG9w0BAQwFAAOCAgEAOiNEPY0Idu6PvDqZ01bgAhql+Eg08yy25nRm95Ry
# sQDKr2wwJxMSnpBEn0v9nqN8JtU3vDpdSG2V1T9J9Ce7FoFFUP2cvbaF4HZ+N3HL
# IvdaqpDP9ZNq4+sg0dVQeYiaiorBtr2hSBh+3NiAGhEZGM1hmYFW9snjdufE5Btf
# Q/g+lP92OT2e1JnPSt0o618moZVYSNUa/tcnP/2Q0XaG3RywYFzzDaju4ImhvTnh
# OE7abrs2nfvlIVNaw8rpavGiPttDuDPITzgUkpn13c5UbdldAhQfQDN8A+KVssIh
# dXNSy0bYxDQcoqVLjc1vdjcshT8azibpGL6QB7BDf5WIIIJw8MzK7/0pNVwfiThV
# 9zeKiwmhywvpMRr/LhlcOXHhvpynCgbWJme3kuZOX956rEnPLqR0kq3bPKSchh/j
# wVYbKyP/j7XqiHtwa+aguv06P0WmxOgWkVKLQcBIhEuWTatEQOON8BUozu3xGFYH
# Ki8QxAwIZDwzj64ojDzLj4gLDb879M4ee47vtevLt/B3E+bnKD+sEq6lLyJsQfmC
# XBVmzGwOysWGw/YmMwwHS6DTBwJqakAwSEs0qFEgu60bhQjiWQ1tygVQK+pKHJ6l
# /aCnHwZ05/LWUpD9r4VIIflXO7ScA+2GRfS0YW6/aOImYIbqyK+p/pQd52MbOoZW
# eE4wggdqMIIFUqADAgECAhAGDMSTaXGZ7mhO3wylAhXMMA0GCSqGSIb3DQEBCwUA
# MGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8GA1UE
# AxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBDb2RlIFNpZ25pbmcgUlNBNDA5NiBTSEEz
# ODQgMjAyMSBDQTEwHhcNMjMxMDA5MDAwMDAwWhcNMjQxMDA4MjM1OTU5WjCB8jET
# MBEGCysGAQQBgjc8AgEDEwJVUzEZMBcGCysGAQQBgjc8AgECEwhEZWxhd2FyZTEd
# MBsGA1UEDwwUUHJpdmF0ZSBPcmdhbml6YXRpb24xEDAOBgNVBAUTBzQxNTI5NTQx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdTZWF0
# dGxlMSIwIAYDVQQKExlBbWF6b24gV2ViIFNlcnZpY2VzLCBJbmMuMRMwEQYDVQQL
# EwpBbWF6b24gRUNTMSIwIAYDVQQDExlBbWF6b24gV2ViIFNlcnZpY2VzLCBJbmMu
# MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEAyJOLJMwvUynSp8T5A7o6
# PzaEwIj0rh3fAxReFqVXC3RpL95E2WDNHslWKQXetbwsLs5q+9l+t0h8+WMcBFIO
# 5wy5NUKkW4YPalD+fU0TNRVA5JDUV74YJPyShfJ/ShqRkPB7L+hIgFrtSvtLo2+H
# PGUpc2ctQ+lRyEc+jNvEeAKTOlbNsjrsyUwOGCwcWxi4MzbvbVRZreFrolMDOEoA
# mwoX0dJ0w4/4jDdcL3NOjADeVe6+OTUTcyqWbAHPGRg4OY1YYnnNAyA6Rzkt4kgg
# iF95X/dMfo0wXQ+FgzZMKddogCknmtjn59w2+FEYgcCKeaydzGOLbkFw3X3Hq4pr
# /ZO/TkMJZ1Vv6b7iVq621EvDRSC+sPSMkZKwHw8CQCmqw3PB97ouAPX2IsSgFeTy
# eNL1jiWmjNAy52bOJrNCUXquFDihedpJC6MxIeafDrw7rPmbLP5hhnRZAdxWwT5D
# N9xCfOt1fhpK8KTwXZP/KI2z4pQ2wbTmqVvAt1Eep9lnAgMBAAGjggICMIIB/jAf
# BgNVHSMEGDAWgBRoN+Drtjv4XxGG+/5hewiIZfROQjAdBgNVHQ4EFgQUZ/vppOZY
# +0aQ9Sr3JVjPoUpPV0YwPQYDVR0gBDYwNDAyBgVngQwBAzApMCcGCCsGAQUFBwIB
# FhtodHRwOi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMwDgYDVR0PAQH/BAQDAgeAMBMG
# A1UdJQQMMAoGCCsGAQUFBwMDMIG1BgNVHR8Ega0wgaowU6BRoE+GTWh0dHA6Ly9j
# cmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNENvZGVTaWduaW5nUlNB
# NDA5NlNIQTM4NDIwMjFDQTEuY3JsMFOgUaBPhk1odHRwOi8vY3JsNC5kaWdpY2Vy
# dC5jb20vRGlnaUNlcnRUcnVzdGVkRzRDb2RlU2lnbmluZ1JTQTQwOTZTSEEzODQy
# MDIxQ0ExLmNybDCBlAYIKwYBBQUHAQEEgYcwgYQwJAYIKwYBBQUHMAGGGGh0dHA6
# Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBcBggrBgEFBQcwAoZQaHR0cDovL2NhY2VydHMu
# ZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0Q29kZVNpZ25pbmdSU0E0MDk2
# U0hBMzg0MjAyMUNBMS5jcnQwCQYDVR0TBAIwADANBgkqhkiG9w0BAQsFAAOCAgEA
# kc5eQBiYle6lFyvjV4HOdOAzqB16nr9F1wMqJzAV1/hP22D5PdPQfCg9Chi7D81r
# gLHe48Jujp5hADhoyldBENmLQpXZjXEhUDH/TJBAjqtPdBsVNI/SCUcU007yaeOe
# MNielYtyJd80vuadjNfHfI8CdbSucVdv9Z2ZhR/YX1RGTAxD8cYoFISnYzNoWr5m
# FPyPlYXeHnUyRiCezgif6xM42EH+N4n6fc8dd2ETTUyRuWJeBNPq/PwAhyhEQLcK
# 2y3TJBnjsCsmDO5+q6Inoo8nYrzVyhpJArt8DulZK0tH0uN+jj3mc1ndqBDhw/mh
# jl162UJ1vlvvzLqQ3gghMXjWxi9E4apEMZGnMRP7QP41Fupjn8emH/XxjinyVLAO
# i+YCYjqJZhl83gH/NLLlrOYWtes/T99Z6EfZ5aS2F6OIOuE25VjdJNDWHs/MBEEl
# Ke4AYyX+NQY759DqZ68cbj+w4HnThUXFc9eGc3zjlKAVc3peIjSE2E7fOrsYMX49
# fMVu+rVHKoZtFE6ndepKF1rKwPNLrDk8lxctydylga6ypSZrSp1nysquN2M0sDc5
# SFDpAeB+h2APXsUSv36HjFreNz+XWEcm+vMEYAGH5p16FX9WlVZkl530yTCautuh
# MrvqhtgVUkILH0FjasozepCYsLvB7UZsmTjqewiQGxMxghnpMIIZ5QIBATB9MGkx
# CzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4
# RGlnaUNlcnQgVHJ1c3RlZCBHNCBDb2RlIFNpZ25pbmcgUlNBNDA5NiBTSEEzODQg
# MjAyMSBDQTECEAYMxJNpcZnuaE7fDKUCFcwwDQYJYIZIAWUDBAIBBQCgfDAQBgor
# BgEEAYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEE
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgB3kZJ66nBol5
# hbDeD9Wij0B6wZebmWrWtOcrL7ekahQwDQYJKoZIhvcNAQEBBQAEggGAOKphTsFR
# x0Ttv6jZq4/pDkWB9EHl2rz/+vxjW3WkTgPsUP3gL+M9udiB0TVYGm8bFHhljVea
# mYNwBBgvXr38vIMmgxZ+JvmqR2mtt2AEvEMa0Q1pUr9al/eKLTnyPzRRoOsjHmAv
# QwMjT54dm34zChpW79G/Gsx6SiBPDx0W+S3quDNIt5ela/MMWS1Xn9BboO55dRWk
# izNLhExb8sRUnM4WMfbASDkTpATm+st5hw8SR6ACmjOUIqDtN4/6wXWcMvPOc+mN
# p96HC68HWJU5Su0YjBBOksBeev1+RT1I1mArTT6f4mc2ckBrpIWA1ouqerMGiRlc
# AfGPfhV2m/Acv4pb5mqCk2qThEB9QBvIb758KFIU9DughijUlsFRQCBnzT9E99Hw
# WNAF/AFJXN0ka7Bzwm+PVlHIjZpdqW3CiOtOzRRklMTwcx/tQdd+EbyhFJjC7FTc
# YS6JsqtptWL9GYMW11dC+w0afWRJzichk63koKIfHFp5CUoV7+WXmim5oYIXPzCC
# FzsGCisGAQQBgjcDAwExghcrMIIXJwYJKoZIhvcNAQcCoIIXGDCCFxQCAQMxDzAN
# BglghkgBZQMEAgEFADB3BgsqhkiG9w0BCRABBKBoBGYwZAIBAQYJYIZIAYb9bAcB
# MDEwDQYJYIZIAWUDBAIBBQAEIMjMdYdNrRss/pJBVxzefvZqI2QdLDf92r1EgKuQ
# O4cDAhA6N5C4eVFIJirNv/eMmRa4GA8yMDIzMTEwNzIyMzE1MlqgghMJMIIGwjCC
# BKqgAwIBAgIQBUSv85SdCDmmv9s/X+VhFjANBgkqhkiG9w0BAQsFADBjMQswCQYD
# VQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lD
# ZXJ0IFRydXN0ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5nIENBMB4X
# DTIzMDcxNDAwMDAwMFoXDTM0MTAxMzIzNTk1OVowSDELMAkGA1UEBhMCVVMxFzAV
# BgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMSAwHgYDVQQDExdEaWdpQ2VydCBUaW1lc3Rh
# bXAgMjAyMzCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAKNTRYcdg45b
# rD5UsyPgz5/X5dLnXaEOCdwvSKOXejsqnGfcYhVYwamTEafNqrJq3RApih5iY2nT
# WJw1cb86l+uUUI8cIOrHmjsvlmbjaedp/lvD1isgHMGXlLSlUIHyz8sHpjBoyoNC
# 2vx/CSSUpIIa2mq62DvKXd4ZGIX7ReoNYWyd/nFexAaaPPDFLnkPG2ZS48jWPl/a
# Q9OE9dDH9kgtXkV1lnX+3RChG4PBuOZSlbVH13gpOWvgeFmX40QrStWVzu8IF+qC
# ZE3/I+PKhu60pCFkcOvV5aDaY7Mu6QXuqvYk9R28mxyyt1/f8O52fTGZZUdVnUok
# L6wrl76f5P17cz4y7lI0+9S769SgLDSb495uZBkHNwGRDxy1Uc2qTGaDiGhiu7xB
# G3gZbeTZD+BYQfvYsSzhUa+0rRUGFOpiCBPTaR58ZE2dD9/O0V6MqqtQFcmzyrzX
# xDtoRKOlO0L9c33u3Qr/eTQQfqZcClhMAD6FaXXHg2TWdc2PEnZWpST618RrIbro
# HzSYLzrqawGw9/sqhux7UjipmAmhcbJsca8+uG+W1eEQE/5hRwqM/vC2x9XH3mwk
# 8L9CgsqgcT2ckpMEtGlwJw1Pt7U20clfCKRwo+wK8REuZODLIivK8SgTIUlRfgZm
# 0zu++uuRONhRB8qUt+JQofM604qDy0B7AgMBAAGjggGLMIIBhzAOBgNVHQ8BAf8E
# BAMCB4AwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAgBgNV
# HSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwHwYDVR0jBBgwFoAUuhbZbU2F
# L3MpdpovdYxqII+eyG8wHQYDVR0OBBYEFKW27xPn783QZKHVVqllMaPe1eNJMFoG
# A1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2Vy
# dFRydXN0ZWRHNFJTQTQwOTZTSEEyNTZUaW1lU3RhbXBpbmdDQS5jcmwwgZAGCCsG
# AQUFBwEBBIGDMIGAMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5j
# b20wWAYIKwYBBQUHMAKGTGh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdp
# Q2VydFRydXN0ZWRHNFJTQTQwOTZTSEEyNTZUaW1lU3RhbXBpbmdDQS5jcnQwDQYJ
# KoZIhvcNAQELBQADggIBAIEa1t6gqbWYF7xwjU+KPGic2CX/yyzkzepdIpLsjCIC
# qbjPgKjZ5+PF7SaCinEvGN1Ott5s1+FgnCvt7T1IjrhrunxdvcJhN2hJd6PrkKoS
# 1yeF844ektrCQDifXcigLiV4JZ0qBXqEKZi2V3mP2yZWK7Dzp703DNiYdk9WuVLC
# tp04qYHnbUFcjGnRuSvExnvPnPp44pMadqJpddNQ5EQSviANnqlE0PjlSXcIWiHF
# tM+YlRpUurm8wWkZus8W8oM3NG6wQSbd3lqXTzON1I13fXVFoaVYJmoDRd7ZULVQ
# jK9WvUzF4UbFKNOt50MAcN7MmJ4ZiQPq1JE3701S88lgIcRWR+3aEUuMMsOI5lji
# tts++V+wQtaP4xeR0arAVeOGv6wnLEHQmjNKqDbUuXKWfpd5OEhfysLcPTLfddY2
# Z1qJ+Panx+VPNTwAvb6cKmx5AdzaROY63jg7B145WPR8czFVoIARyxQMfq68/qTr
# eWWqaNYiyjvrmoI1VygWy2nyMpqy0tg6uLFGhmu6F/3Ed2wVbK6rr3M66ElGt9V/
# zLY4wNjsHPW2obhDLN9OTH0eaHDAdwrUAuBcYLso/zjlUlrWrBciI0707NMX+1Br
# /wd3H3GXREHJuEbTbDJ8WC9nR2XlG3O2mflrLAZG70Ee8PBf4NvZrZCARK+AEEGK
# MIIGrjCCBJagAwIBAgIQBzY3tyRUfNhHrP0oZipeWzANBgkqhkiG9w0BAQsFADBi
# MQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3
# d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3Qg
# RzQwHhcNMjIwMzIzMDAwMDAwWhcNMzcwMzIyMjM1OTU5WjBjMQswCQYDVQQGEwJV
# UzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFRy
# dXN0ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5nIENBMIICIjANBgkq
# hkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAxoY1BkmzwT1ySVFVxyUDxPKRN6mXUaHW
# 0oPRnkyibaCwzIP5WvYRoUQVQl+kiPNo+n3znIkLf50fng8zH1ATCyZzlm34V6gC
# ff1DtITaEfFzsbPuK4CEiiIY3+vaPcQXf6sZKz5C3GeO6lE98NZW1OcoLevTsbV1
# 5x8GZY2UKdPZ7Gnf2ZCHRgB720RBidx8ald68Dd5n12sy+iEZLRS8nZH92GDGd1f
# tFQLIWhuNyG7QKxfst5Kfc71ORJn7w6lY2zkpsUdzTYNXNXmG6jBZHRAp8ByxbpO
# H7G1WE15/tePc5OsLDnipUjW8LAxE6lXKZYnLvWHpo9OdhVVJnCYJn+gGkcgQ+ND
# Y4B7dW4nJZCYOjgRs/b2nuY7W+yB3iIU2YIqx5K/oN7jPqJz+ucfWmyU8lKVEStY
# dEAoq3NDzt9KoRxrOMUp88qqlnNCaJ+2RrOdOqPVA+C/8KI8ykLcGEh/FDTP0kyr
# 75s9/g64ZCr6dSgkQe1CvwWcZklSUPRR8zZJTYsg0ixXNXkrqPNFYLwjjVj33GHe
# k/45wPmyMKVM1+mYSlg+0wOI/rOP015LdhJRk8mMDDtbiiKowSYI+RQQEgN9XyO7
# ZONj4KbhPvbCdLI/Hgl27KtdRnXiYKNYCQEoAA6EVO7O6V3IXjASvUaetdN2udIO
# a5kM0jO0zbECAwEAAaOCAV0wggFZMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYDVR0O
# BBYEFLoW2W1NhS9zKXaaL3WMaiCPnshvMB8GA1UdIwQYMBaAFOzX44LScV1kTN8u
# Zz/nupiuHA9PMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcDCDB3
# BggrBgEFBQcBAQRrMGkwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0
# LmNvbTBBBggrBgEFBQcwAoY1aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0Rp
# Z2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcnQwQwYDVR0fBDwwOjA4oDagNIYyaHR0cDov
# L2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcmwwIAYD
# VR0gBBkwFzAIBgZngQwBBAIwCwYJYIZIAYb9bAcBMA0GCSqGSIb3DQEBCwUAA4IC
# AQB9WY7Ak7ZvmKlEIgF+ZtbYIULhsBguEE0TzzBTzr8Y+8dQXeJLKftwig2qKWn8
# acHPHQfpPmDI2AvlXFvXbYf6hCAlNDFnzbYSlm/EUExiHQwIgqgWvalWzxVzjQEi
# Jc6VaT9Hd/tydBTX/6tPiix6q4XNQ1/tYLaqT5Fmniye4Iqs5f2MvGQmh2ySvZ18
# 0HAKfO+ovHVPulr3qRCyXen/KFSJ8NWKcXZl2szwcqMj+sAngkSumScbqyQeJsG3
# 3irr9p6xeZmBo1aGqwpFyd/EjaDnmPv7pp1yr8THwcFqcdnGE4AJxLafzYeHJLtP
# o0m5d2aR8XKc6UsCUqc3fpNTrDsdCEkPlM05et3/JWOZJyw9P2un8WbDQc1PtkCb
# ISFA0LcTJM3cHXg65J6t5TRxktcma+Q4c6umAU+9Pzt4rUyt+8SVe+0KXzM5h0F4
# ejjpnOHdI/0dKNPH+ejxmF/7K9h+8kaddSweJywm228Vex4Ziza4k9Tm8heZWcpw
# 8De/mADfIBZPJ/tgZxahZrrdVcA6KYawmKAr7ZVBtzrVFZgxtGIJDwq9gdkT/r+k
# 0fNX2bwE+oLeMt8EifAAzV3C+dAjfwAL5HYCJtnwZXZCpimHCUcr5n8apIUP/JiW
# 9lVUKx+A+sDyDivl1vupL0QVSucTDh3bNzgaoSv27dZ8/DCCBY0wggR1oAMCAQIC
# EA6bGI750C3n79tQ4ghAGFowDQYJKoZIhvcNAQEMBQAwZTELMAkGA1UEBhMCVVMx
# FTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNv
# bTEkMCIGA1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENBMB4XDTIyMDgw
# MTAwMDAwMFoXDTMxMTEwOTIzNTk1OVowYjELMAkGA1UEBhMCVVMxFTATBgNVBAoT
# DERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEhMB8GA1UE
# AxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0MIICIjANBgkqhkiG9w0BAQEFAAOC
# Ag8AMIICCgKCAgEAv+aQc2jeu+RdSjwwIjBpM+zCpyUuySE98orYWcLhKac9WKt2
# ms2uexuEDcQwH/MbpDgW61bGl20dq7J58soR0uRf1gU8Ug9SH8aeFaV+vp+pVxZZ
# VXKvaJNwwrK6dZlqczKU0RBEEC7fgvMHhOZ0O21x4i0MG+4g1ckgHWMpLc7sXk7I
# k/ghYZs06wXGXuxbGrzryc/NrDRAX7F6Zu53yEioZldXn1RYjgwrt0+nMNlW7sp7
# XeOtyU9e5TXnMcvak17cjo+A2raRmECQecN4x7axxLVqGDgDEI3Y1DekLgV9iPWC
# PhCRcKtVgkEy19sEcypukQF8IUzUvK4bA3VdeGbZOjFEmjNAvwjXWkmkwuapoGfd
# pCe8oU85tRFYF/ckXEaPZPfBaYh2mHY9WV1CdoeJl2l6SPDgohIbZpp0yt5LHucO
# Y67m1O+SkjqePdwA5EUlibaaRBkrfsCUtNJhbesz2cXfSwQAzH0clcOP9yGyshG3
# u3/y1YxwLEFgqrFjGESVGnZifvaAsPvoZKYz0YkH4b235kOkGLimdwHhD5QMIR2y
# VCkliWzlDlJRR3S+Jqy2QXXeeqxfjT/JvNNBERJb5RBQ6zHFynIWIgnffEx1P2Ps
# IV/EIFFrb7GrhotPwtZFX50g/KEexcCPorF+CiaZ9eRpL5gdLfXZqbId5RsCAwEA
# AaOCATowggE2MA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFOzX44LScV1kTN8u
# Zz/nupiuHA9PMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6enIZ3zbcgPMA4GA1Ud
# DwEB/wQEAwIBhjB5BggrBgEFBQcBAQRtMGswJAYIKwYBBQUHMAGGGGh0dHA6Ly9v
# Y3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcwAoY3aHR0cDovL2NhY2VydHMuZGln
# aWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNydDBFBgNVHR8EPjA8
# MDqgOKA2hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVk
# SURSb290Q0EuY3JsMBEGA1UdIAQKMAgwBgYEVR0gADANBgkqhkiG9w0BAQwFAAOC
# AQEAcKC/Q1xV5zhfoKN0Gz22Ftf3v1cHvZqsoYcs7IVeqRq7IviHGmlUIu2kiHdt
# vRoU9BNKei8ttzjv9P+Aufih9/Jy3iS8UgPITtAq3votVs/59PesMHqai7Je1M/R
# Q0SbQyHrlnKhSLSZy51PpwYDE3cnRNTnf+hZqPC/Lwum6fI0POz3A8eHqNJMQBk1
# RmppVLC4oVaO7KTVPeix3P0c2PR3WlxUjG/voVA9/HYJaISfb8rbII01YBwCA8sg
# sKxYoA5AY8WYIsGyWfVVa88nq2x2zm8jLfR+cWojayL/ErhULSd+2DrZ8LaHlv1b
# 0VysGMNNn3O3AamfV6peKOK5lDGCA3YwggNyAgEBMHcwYzELMAkGA1UEBhMCVVMx
# FzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVz
# dGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQQIQBUSv85SdCDmm
# v9s/X+VhFjANBglghkgBZQMEAgEFAKCB0TAaBgkqhkiG9w0BCQMxDQYLKoZIhvcN
# AQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTIzMTEwNzIyMzE1MlowKwYLKoZIhvcNAQkQ
# AgwxHDAaMBgwFgQUZvArMsLCyQ+CXc6qisnGTxmcz0AwLwYJKoZIhvcNAQkEMSIE
# IJGO/Qmvk1wUqWRlbAIVvPm9vuf6lihvEE/uc+EgyxPmMDcGCyqGSIb3DQEJEAIv
# MSgwJjAkMCIEINL25G3tdCLM0dRAV2hBNm+CitpVmq4zFq9NGprUDHgoMA0GCSqG
# SIb3DQEBAQUABIICACG1qOhlV/I4x+uN4CFnHEQNpRzPU5fM9HLH1G/cJTr6rsWC
# zPz1JgIjYT6NBIAn6HLAYq/00mXJCcTKgM/snwUSvWmdjS9lMA+qhfdnU+35EwkP
# lnbelnTnRYIUmEyYipE4OYq0Ji8bEsxapziTMpp79t/7qhdjhBs4VKUjpNwrM948
# EEviznssT7kJ3HtyUUoJTz375F7lyW0D9D3jTSE0+zoNoQ1ax5KdRBA4pPaU9ci/
# Bq7XrGTuj9ibaipFy2OxvfOvX/3NC5kOUGdb9iY6rpStgowBjBBBAFZgEsVkIOAn
# cTaQVCIGdi+66DegAaUtGmRSSp3eIW1njrSnmzitQ3WierY23wiX0IkvAptaVHpo
# /p9TTBwFm7VzGH8eo2119hutRc6Ku2CG2QfVsZ7eJY38uPCjHBAyzxpOSG9L/jdx
# 7/Qt14CklvnyzU7UQBHZY2zIL2v6iBc4ziySQuXUldb3PvnJlz65vs8+p3ot1b8a
# o3mJebn6gGxLHpOC8rKgROB+k+JlANNhAv7AC5MPgUlR3mYQO043WCKgKBRnWJew
# FSAMfDAmjndyfUK1bz352ixCnzWx+DfeRj8KvC4Eg8J35ZDezFRjyzhoDL1xHTSo
# c93GK2eqXIRz9p06qxLNnV3TGJD6O3JZkPb+M92RSPtN6jXiZVnOIEsV8lZ0
# SIG # End signature block
