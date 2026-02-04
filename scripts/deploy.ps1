# ============================================================================
# Azure Synapse CDC POC - Deployment Script (PowerShell)
# ============================================================================
# This script deploys all required Azure infrastructure for the CDC POC lab.
#
# Naming Convention:
# All resource names are derived from your project name:
#   - Resource Group: rg-{projectName}
#   - Storage Account: {projectName}st (lowercase, no dashes)
#   - Synapse Workspace: {projectName}-syn
#
# Prerequisites:
#   - Azure CLI installed and logged in (az login)
#   - Sufficient permissions to create resources
# ============================================================================

param(
    [string]$ProjectName,
    [string]$Location = "eastus",
    [SecureString]$SqlAdminPassword
)

$ErrorActionPreference = "Stop"

# Print banner
Write-Host ""
Write-Host "============================================================================" -ForegroundColor Blue
Write-Host "  Azure Synapse CDC POC - Deployment Script" -ForegroundColor Blue
Write-Host "============================================================================" -ForegroundColor Blue
Write-Host ""

# Function to print colored messages
function Write-Info($message) {
    Write-Host "[INFO] " -ForegroundColor Blue -NoNewline
    Write-Host $message
}

function Write-Success($message) {
    Write-Host "[SUCCESS] " -ForegroundColor Green -NoNewline
    Write-Host $message
}

function Write-Warning($message) {
    Write-Host "[WARNING] " -ForegroundColor Yellow -NoNewline
    Write-Host $message
}

function Write-Error($message) {
    Write-Host "[ERROR] " -ForegroundColor Red -NoNewline
    Write-Host $message
}

# Function to sanitize project name
function Get-SanitizedName {
    param([string]$Name)
    $sanitized = $Name.ToLower() -replace '_', '-' -replace '[^a-z0-9-]', ''
    return $sanitized
}

# Function to generate storage account name
function Get-StorageAccountName {
    param([string]$ProjectName, [string]$Suffix = "")
    $cleanName = $ProjectName -replace '-', ''
    $storageName = "${cleanName}st${Suffix}"
    return $storageName.Substring(0, [Math]::Min($storageName.Length, 24))
}

# Function to check if storage account name is available
function Test-StorageAccountAvailable {
    param([string]$StorageName)
    try {
        $result = az storage account check-name --name $StorageName --query "nameAvailable" -o tsv 2>$null
        return $result -eq "true"
    } catch {
        return $false
    }
}

# Function to find available names with conflict handling
function Find-AvailableNames {
    param([string]$ProjectName)
    
    $suffix = ""
    $counter = 0
    $maxAttempts = 10
    
    while ($counter -lt $maxAttempts) {
        $rgName = "rg-${ProjectName}${suffix}"
        $storageName = Get-StorageAccountName -ProjectName $ProjectName -Suffix $suffix
        $synapseName = "${ProjectName}${suffix}-syn"
        
        Write-Info "Checking availability for: ${ProjectName}${suffix}..."
        
        if (Test-StorageAccountAvailable -StorageName $storageName) {
            return @{
                ResourceGroup = $rgName
                StorageAccount = $storageName
                SynapseWorkspace = $synapseName
                FinalProjectName = "${ProjectName}${suffix}"
            }
        } else {
            Write-Warning "Name conflict detected. Trying with suffix..."
            $counter++
            $suffix = "$counter"
        }
    }
    
    # Generate random suffix if all attempts failed
    $randomSuffix = -join ((97..122) + (48..57) | Get-Random -Count 4 | ForEach-Object { [char]$_ })
    return @{
        ResourceGroup = "rg-${ProjectName}-${randomSuffix}"
        StorageAccount = Get-StorageAccountName -ProjectName $ProjectName -Suffix $randomSuffix
        SynapseWorkspace = "${ProjectName}-${randomSuffix}-syn"
        FinalProjectName = "${ProjectName}-${randomSuffix}"
    }
}

# Check if Azure CLI is installed
try {
    $null = az version 2>$null
} catch {
    Write-Error "Azure CLI is not installed. Please install it first."
    Write-Host "Visit: https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
}

# Check if logged in to Azure
Write-Info "Checking Azure login status..."
try {
    $account = az account show 2>$null | ConvertFrom-Json
    $subscriptionId = $account.id
    Write-Success "Logged in to Azure subscription: $($account.name)"
} catch {
    Write-Error "Not logged in to Azure. Please run 'az login' first."
    exit 1
}

# Display naming convention info
Write-Host ""
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "  Configuration" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "All resource names will be automatically generated from your project name:"
Write-Host "  - Resource Group:    rg-{project-name}"
Write-Host "  - Storage Account:   {projectname}st"
Write-Host "  - Synapse Workspace: {project-name}-syn"
Write-Host ""

# Prompt for project name (REQUIRED)
if (-not $PSBoundParameters.ContainsKey('ProjectName') -or [string]::IsNullOrWhiteSpace($ProjectName)) {
    while ($true) {
        $ProjectNameInput = Read-Host "Enter Project Name (required, e.g., fantastic-demo)"
        
        if ([string]::IsNullOrWhiteSpace($ProjectNameInput)) {
            Write-Error "Project name is required. Please enter a name."
            continue
        }
        
        $ProjectName = Get-SanitizedName -Name $ProjectNameInput
        
        if ($ProjectName.Length -lt 3) {
            Write-Error "Project name must be at least 3 characters long."
            continue
        }
        
        if ($ProjectName.Length -gt 20) {
            Write-Error "Project name must be 20 characters or less."
            continue
        }
        
        if ($ProjectName -notmatch "^[a-z][a-z0-9-]*[a-z0-9]$") {
            Write-Error "Project name must start with a letter, end with a letter or number, and contain only lowercase letters, numbers, and dashes."
            continue
        }
        
        break
    }
}

Write-Info "Using project name: $ProjectName"

# Prompt for location if not provided
if (-not $PSBoundParameters.ContainsKey('Location')) {
    $locationInput = Read-Host "Enter Azure Location [eastus]"
    if (-not [string]::IsNullOrWhiteSpace($locationInput)) {
        $Location = $locationInput
    }
}

# Prompt for SQL Admin Password if not provided
if (-not $PSBoundParameters.ContainsKey('SqlAdminPassword')) {
    while ($true) {
        $SqlAdminPassword = Read-Host "Enter SQL Admin Password (min 8 chars, uppercase, lowercase, number, special char)" -AsSecureString
        
        # Convert to plain text for validation
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SqlAdminPassword)
        $SqlPasswordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
        
        if ($SqlPasswordPlain.Length -lt 8) {
            Write-Warning "Password must be at least 8 characters long."
            continue
        }
        
        if ($SqlPasswordPlain -cnotmatch "[A-Z]") {
            Write-Warning "Password must contain at least one uppercase letter."
            continue
        }
        
        if ($SqlPasswordPlain -cnotmatch "[a-z]") {
            Write-Warning "Password must contain at least one lowercase letter."
            continue
        }
        
        if ($SqlPasswordPlain -notmatch "[0-9]") {
            Write-Warning "Password must contain at least one number."
            continue
        }
        
        break
    }
} else {
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SqlAdminPassword)
    $SqlPasswordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
}

# Find available names (handles conflicts)
Write-Host ""
Write-Info "Checking resource name availability..."
$names = Find-AvailableNames -ProjectName $ProjectName

$ResourceGroup = $names.ResourceGroup
$StorageAccount = $names.StorageAccount
$SynapseWorkspace = $names.SynapseWorkspace
$FinalProjectName = $names.FinalProjectName

# Show configuration summary
Write-Host ""
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "  Deployment Configuration" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Project Name:      " -ForegroundColor Blue -NoNewline
Write-Host $FinalProjectName
Write-Host "  Location:          " -ForegroundColor Blue -NoNewline
Write-Host $Location
Write-Host "  Resource Group:    " -ForegroundColor Blue -NoNewline
Write-Host $ResourceGroup
Write-Host "  Storage Account:   " -ForegroundColor Blue -NoNewline
Write-Host $StorageAccount
Write-Host "  Synapse Workspace: " -ForegroundColor Blue -NoNewline
Write-Host $SynapseWorkspace
Write-Host ""

$confirm = Read-Host "Proceed with deployment? (y/N)"
if ($confirm -notmatch "^[Yy]$") {
    Write-Warning "Deployment cancelled."
    exit 0
}

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InfraDir = Join-Path (Split-Path -Parent $ScriptDir) "infra"

# Create Resource Group
Write-Host ""
Write-Info "Creating Resource Group: $ResourceGroup..."
az group create `
    --name $ResourceGroup `
    --location $Location `
    --tags "project=$FinalProjectName" "purpose=synapse-cdc-poc" `
    --output none

Write-Success "Resource Group created."

# Deploy Bicep template
Write-Info "Deploying infrastructure (this may take 5-10 minutes)..."
Write-Host ""

$deploymentOutput = az deployment group create `
    --resource-group $ResourceGroup `
    --template-file "$InfraDir\main.bicep" `
    --parameters `
        location=$Location `
        projectName=$FinalProjectName `
        sqlAdminPassword=$SqlPasswordPlain `
    --query "properties.outputs" `
    --output json | ConvertFrom-Json

Write-Success "Infrastructure deployment completed!"

# Parse outputs
$StorageAccount = $deploymentOutput.storageAccountName.value
$SynapseWorkspace = $deploymentOutput.synapseWorkspaceName.value
$SynapseWeb = $deploymentOutput.synapseWebEndpoint.value
$DataPath = $deploymentOutput.dataContainerPath.value

Write-Host ""
Write-Host "============================================================================" -ForegroundColor Green
Write-Host "  Deployment Successful!" -ForegroundColor Green
Write-Host "============================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Project: " -ForegroundColor Blue -NoNewline
Write-Host $FinalProjectName
Write-Host ""
Write-Host "Resource Details:" -ForegroundColor Blue
Write-Host "  Resource Group:    $ResourceGroup"
Write-Host "  Storage Account:   $StorageAccount"
Write-Host "  Synapse Workspace: $SynapseWorkspace"
Write-Host ""
Write-Host "Important URLs:" -ForegroundColor Blue
Write-Host "  Synapse Studio: $SynapseWeb"
Write-Host ""
Write-Host "Data Lake Paths:" -ForegroundColor Blue
Write-Host "  Base Path:    $DataPath"
Write-Host "  Source:       $DataPath/source/"
Write-Host "  Destination:  $DataPath/destination/"
Write-Host "  Metadata:     $DataPath/metadata/"
Write-Host ""

# Create folder structure in storage
Write-Info "Creating folder structure in storage account..."

$StorageKey = az storage account keys list `
    --resource-group $ResourceGroup `
    --account-name $StorageAccount `
    --query "[0].value" `
    --output tsv

foreach ($folder in @("source", "destination", "metadata")) {
    try {
        "placeholder" | az storage blob upload `
            --account-name $StorageAccount `
            --account-key $StorageKey `
            --container-name "data" `
            --name "$folder/.keep" `
            --data "@-" `
            --overwrite `
            --output none 2>$null
    } catch {}
}

Write-Success "Folder structure created."

Write-Host ""
Write-Host "============================================================================" -ForegroundColor Green
Write-Host "  Next Steps" -ForegroundColor Green
Write-Host "============================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "1. Upload sample CSV files to the storage account:"
Write-Host ""
Write-Host "   # For timestamp-based scenario:"
Write-Host "   az storage blob upload-batch ```"
Write-Host "     --account-name $StorageAccount ```"
Write-Host "     --destination data/source ```"
Write-Host "     --source .\sample-data\scenario_with_timestamp"
Write-Host ""
Write-Host "   # For hash-based scenario:"
Write-Host "   az storage blob upload-batch ```"
Write-Host "     --account-name $StorageAccount ```"
Write-Host "     --destination data/source ```"
Write-Host "     --source .\sample-data\scenario_without_timestamp"
Write-Host ""
Write-Host "2. Open Synapse Studio:"
Write-Host "   $SynapseWeb"
Write-Host ""
Write-Host "3. Import and run the notebooks from the /notebooks folder"
Write-Host "   (Remember to update STORAGE_ACCOUNT = `"$StorageAccount`" in the notebooks)"
Write-Host ""

# Save deployment info to file
$deployInfoFile = Join-Path $ScriptDir "deployment-info-${FinalProjectName}.txt"
@"
# ============================================================================
# Azure Synapse CDC POC - Deployment Information
# ============================================================================
# Project: $FinalProjectName
# Generated: $(Get-Date)
# ============================================================================

PROJECT_NAME=$FinalProjectName
LOCATION=$Location
RESOURCE_GROUP=$ResourceGroup
STORAGE_ACCOUNT=$StorageAccount
SYNAPSE_WORKSPACE=$SynapseWorkspace
SYNAPSE_WEB_URL=$SynapseWeb
DATA_PATH=$DataPath

# Azure Portal Links
RESOURCE_GROUP_URL=https://portal.azure.com/#@/resource/subscriptions/${subscriptionId}/resourceGroups/${ResourceGroup}
STORAGE_ACCOUNT_URL=https://portal.azure.com/#@/resource/subscriptions/${subscriptionId}/resourceGroups/${ResourceGroup}/providers/Microsoft.Storage/storageAccounts/${StorageAccount}

# Upload Commands
# az storage blob upload-batch --account-name $StorageAccount --destination data/source --source .\sample-data\scenario_with_timestamp
"@ | Out-File -FilePath $deployInfoFile -Encoding UTF8

Write-Success "Deployment info saved to: $deployInfoFile"
Write-Host ""
Write-Host "Tip: Keep this file for reference!" -ForegroundColor Yellow
Write-Host ""
