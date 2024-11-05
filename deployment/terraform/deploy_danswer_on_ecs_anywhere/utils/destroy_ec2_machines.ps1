# Function to check if all instances are in 'terminated' state
function Check-TerminatedState {
    param([string[]]$instanceIdsArray)

    # Loop until all instances are in the 'terminated' state
    $allTerminated = $false

    while (-not $allTerminated) {
        $allTerminated = $true # Assume all are terminated unless proven otherwise

        foreach ($id in $instanceIdsArray) {
            # Fetch the current instance state
            $state = aws ec2 describe-instances --instance-ids $id `
                        --query "Reservations[*].Instances[*].State.Name" --output text

            Write-Host "Instance ID: $id is in state: $state"

            # If any instance is not terminated, set the flag to false
            if ($state -ne "terminated") {
                $allTerminated = $false
            }
        }

        # If not all are terminated, wait for a few seconds before re-checking
        if (-not $allTerminated) {
            Write-Host "Waiting for all instances to reach 'terminated' state..."
            Start-Sleep -Seconds 2  # Adjust the sleep time as needed
        }
    }

    Write-Host "All instances are now in 'terminated' state."
}

function Terminate-Instances {

    # Step 1: Get running EC2 instance IDs with tag Project=Danswer
    $instanceIds = aws ec2 describe-instances `
      --filters "Name=instance-state-name,Values=running" `
               "Name=tag:Project,Values=Danswer" `
      --query "Reservations[*].Instances[*].InstanceId" `
      --output text

    if ($instanceIds) {
        # Split the output by newline or space, depending on how AWS CLI returns it
        $instanceIdsArray = $instanceIds -split "\s+"

        (aws ec2 terminate-instances --instance-ids $instanceIds) -replace "`r`n", ""

        # Terminate each instance
        #    foreach ($id in $instanceIdsArray) {
        #        aws ec2 terminate-instances --instance-ids $id
        #        #Write-Host "Termination command sent to instance: $id"
        #    }

        # Step 3: Wait until all instances reach the 'terminated' state
        Check-TerminatedState -instanceIdsArray $instanceIdsArray
    } else {
        Write-Host "No running instances found with tag Project=Danswer."
    }
}


Terminate-Instances


## Step 1: Get running EC2 instance IDs with tag Project=Danswer
#$instanceIds = aws ec2 describe-instances `
#  --filters "Name=instance-state-name,Values=running" `
#           "Name=tag:Project,Values=Danswer" `
#  --query "Reservations[*].Instances[*].InstanceId" `
#  --output text
#
## Step 2: Terminate each instance
#if ($instanceIds) {
#    foreach ($id in $instanceIds) {
#        aws ec2 terminate-instances --instance-ids $id
#        Write-Host "Terminated instance: $id"
#    }
#} else {
#    Write-Host "No running instances found with tag Project=Danswer."
#}
