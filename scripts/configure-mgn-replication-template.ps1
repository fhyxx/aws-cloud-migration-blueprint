[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern("^subnet-[0-9a-fA-F]{8,}$")]
    [string]$StagingSubnetId,
    [Parameter(Mandatory = $true)]
    [ValidatePattern("^sg-[0-9a-fA-F]{8,}$")]
    [string]$ReplicationSecurityGroupId,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ReplicationServerInstanceType,
    [string]$Region = "us-east-1",
    [string]$Profile = "portfolio",
    [ValidateSet("GP3", "GP2", "ST1")]
    [string]$LargeStagingDiskType = "GP3",
    [long]$BandwidthThrottling = 0,
    [switch]$InitializeService,
    [switch]$Execute
)

$ErrorActionPreference = "Stop"
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    throw "AWS CLI v2 is required."
}

$replicationPayload = @{
    stagingAreaSubnetId                 = $StagingSubnetId
    associateDefaultSecurityGroup       = $false
    replicationServersSecurityGroupsIDs = @($ReplicationSecurityGroupId)
    replicationServerInstanceType       = $ReplicationServerInstanceType
    useDedicatedReplicationServer       = $false
    defaultLargeStagingDiskType          = $LargeStagingDiskType
    ebsEncryption                       = "DEFAULT"
    bandwidthThrottling                 = $BandwidthThrottling
    dataPlaneRouting                    = "PRIVATE_IP"
    createPublicIP                      = $false
    stagingAreaTags                     = @{
        Project     = "Clafoke-Portfolio"
        Environment = "Synthetic"
        ManagedBy   = "AWS-MGN"
    }
    tags = @{
        Project     = "Clafoke-Portfolio"
        Environment = "Synthetic"
        ManagedBy   = "PowerShell"
    }
}

$launchPayload = @{
    launchDisposition                   = "STOPPED"
    targetInstanceTypeRightSizingMethod = "NONE"
    copyPrivateIp                       = $false
    associatePublicIpAddress             = $false
    copyTags                             = $true
    tags = @{
        Project     = "Clafoke-Portfolio"
        Environment = "Synthetic"
        ManagedBy   = "PowerShell"
    }
}

$tempFile = Join-Path $env:TEMP ("mgn-template-" + [guid]::NewGuid().ToString("N") + ".json")
try {
    Write-Host "MGN initialization request:"
    if ($InitializeService) {
        Write-Host "aws mgn initialize-service --profile $Profile --region $Region"
    }
    Write-Host "MGN replication configuration template:"
    Write-Host ($replicationPayload | ConvertTo-Json -Depth 8)
    Write-Host "MGN launch configuration template:"
    Write-Host ($launchPayload | ConvertTo-Json -Depth 8)

    if (-not $Execute) {
        Write-Host "Dry run only. No AWS API call was made."
        Write-Host "Run Terraform first with enable_mgn_resources=true so the required IAM roles and policy attachments exist."
        Write-Host "Use -InitializeService only for the first initialization in this account/Region."
        Write-Host "Re-run with -Execute only after reviewing the account, Region, subnet, SG and instance type."
        return
    }

    $identity = aws sts get-caller-identity --profile $Profile --region $Region --output json | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to verify AWS identity. Check the selected profile."
    }
    Write-Host "Target AWS account: $($identity.Account)"
    Write-Host "Target principal: $($identity.Arn)"

    if ($InitializeService) {
        if ($PSCmdlet.ShouldProcess("AWS MGN in $Region account $($identity.Account)", "Initialize MGN service")) {
            aws mgn initialize-service --profile $Profile --region $Region
            if ($LASTEXITCODE -ne 0) {
                throw "MGN service initialization failed. Check required IAM roles, policies and account permissions."
            }
        }
        else {
            return
        }
    }

    if (-not $PSCmdlet.ShouldProcess("AWS MGN in $Region account $($identity.Account)", "Create replication and launch configuration templates")) {
        return
    }

    $existingReplication = aws mgn describe-replication-configuration-templates --profile $Profile --region $Region --query "items[].replicationConfigurationTemplateID" --output json | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect MGN replication templates. Confirm service initialization and IAM permissions."
    }
    $existingLaunch = aws mgn describe-launch-configuration-templates --profile $Profile --region $Region --query "items[].launchConfigurationTemplateID" --output json | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect MGN launch templates. Confirm service initialization and IAM permissions."
    }
    if (($existingReplication | Measure-Object).Count -gt 0 -or ($existingLaunch | Measure-Object).Count -gt 0) {
        throw "An MGN template already exists. Inspect and update the existing template rather than creating a duplicate."
    }

    [System.IO.File]::WriteAllText($tempFile, ($replicationPayload | ConvertTo-Json -Depth 8), [System.Text.UTF8Encoding]::new($false))
    $replicationResult = aws mgn create-replication-configuration-template --profile $Profile --region $Region --cli-input-json "file://$tempFile" | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) {
        throw "MGN replication configuration template creation failed. Review AWS CLI output."
    }

    [System.IO.File]::WriteAllText($tempFile, ($launchPayload | ConvertTo-Json -Depth 8), [System.Text.UTF8Encoding]::new($false))
    $launchResult = aws mgn create-launch-configuration-template --profile $Profile --region $Region --cli-input-json "file://$tempFile" | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) {
        throw "MGN launch configuration template creation failed. Review AWS CLI output."
    }

    Write-Host "Created replication template: $($replicationResult.replicationConfigurationTemplateID)"
    Write-Host "Created launch template: $($launchResult.launchConfigurationTemplateID)"
    Write-Host "Both templates keep launchDisposition STOPPED and disable public IP assignment."
}
finally {
    Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
}
