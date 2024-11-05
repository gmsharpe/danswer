# ------------------------------
# Parameter Definitions
# ------------------------------
param (
    [string]$ecsCluster,                  # ECS Cluster Name
    [string]$awsRegion = "us-west-1",     # AWS Region (default to 'us-west-1')
    [string]$activationId,                # ECS Activation ID (required for ECS Anywhere)
    [string]$activationCode               # ECS Activation Code (required for ECS Anywhere)
)

# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-anywhere-registration.html

Invoke-RestMethod -URI "https://amazon-ecs-agent.s3.amazonaws.com/ecs-anywhere-install.ps1" -OutFile “ecs-anywhere-install.ps1”
Get-AuthenticodeSignature -FilePath .\ecs-anywhere-install.ps1
.\ecs-anywhere-install.ps1 -Region $awsRegion -Cluster $ecsCluster -ActivationID $activationID -ActivationCode $activationCode
Get-Service AmazonECS