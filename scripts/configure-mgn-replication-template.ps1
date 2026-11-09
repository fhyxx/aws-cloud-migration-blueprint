[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern("^subnet-[0-9a-fA-F]{8,}$")]
    [string]$StagingSubnetId,

    [Parameter(Mandatory = $true)]
    [ValidatePattern("^sg-[0-9a-fA-F]{8,}$")]
    [string]$ReplicationSecurityGroupId,

    [Parameter(Mandatory = $true)]
    [string]$ReplicationServerInstanceType,

    [string]$Region = "us-east-1",
    [string]$Profile = "portfolio",
    [ValidateSet("GP3", "GP2", "ST1")]
    [string]$LargeStagingDiskType = "GP3",
    [long]$BandwidthThrottling = 0,

    [switch]$Execute
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    throw "AWS CLI v2 is required."
}

$payload = @{
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

$json = $payload | ConvertTo-Json -Depth 8
$tempFile = Join-Path $env:TEMP ("mgn-replication-template-" + [guid]::NewGuid().ToString("N") + ".json")

try {
    Set-Content -Path $tempFile -Value $json -Encoding utf8
    Write-Host "MGN replication configuration template request:"
    Write-Host $json

    if (-not $Execute) {
        Write-Host "Dry run only. No AWS API call was made."
        Write-Host "Re-run with -Execute only after confirming account, Region, subnet, SG and instance type."
        return
    }

    $identity = aws sts get-caller-identity --profile $Profile --region $Region --output json | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to verify AWS identity. Check the selected profile."
    }

    Write-Host "Target AWS account: $($identity.Account)"
    Write-Host "Target principal: $($identity.Arn)"
    if (-not $PSCmdlet.ShouldProcess("AWS MGN in $Region account $($identity.Account)", "Create replication configuration template")) {
        return
    }

    aws mgn create-replication-configuration-template --profile $Profile --region $Region --cli-input-json "file://$tempFile"
    if ($LASTEXITCODE -ne 0) {
        throw "MGN template creation failed. Review AWS CLI output."
    }
}
finally {
    Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
}
