#!/bin/bash
# ============================================================================
# Azure Synapse CDC POC - Deployment Script (Bash)
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

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
DEFAULT_LOCATION="eastus"

# Print banner
echo -e "${BLUE}"
echo "============================================================================"
echo "  Azure Synapse CDC POC - Deployment Script"
echo "============================================================================"
echo -e "${NC}"

# Function to print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to sanitize project name for Azure resources
sanitize_name() {
    local name="$1"
    # Convert to lowercase and replace underscores with dashes
    echo "$name" | tr '[:upper:]' '[:lower:]' | tr '_' '-' | sed 's/[^a-z0-9-]//g'
}

# Function to generate storage account name (no dashes, max 24 chars)
generate_storage_name() {
    local project="$1"
    local suffix="$2"
    local clean_name=$(echo "$project" | tr -d '-')
    local storage_name="${clean_name}st${suffix}"
    echo "${storage_name:0:24}"
}

# Function to check if resource group exists
check_resource_group_exists() {
    local rg_name="$1"
    az group show --name "$rg_name" &>/dev/null
    return $?
}

# Function to check if storage account name is available
check_storage_available() {
    local storage_name="$1"
    local result=$(az storage account check-name --name "$storage_name" --query "nameAvailable" -o tsv 2>/dev/null)
    [[ "$result" == "true" ]]
    return $?
}

# Function to check if Synapse workspace name is available
check_synapse_available() {
    local synapse_name="$1"
    # Synapse names are globally unique - check by trying to resolve
    ! az synapse workspace show --name "$synapse_name" --resource-group "nonexistent-rg-check" &>/dev/null
    return $?
}

# Function to find available names with suffix
find_available_names() {
    local project_name="$1"
    local suffix=""
    local counter=0
    local max_attempts=10
    
    while [[ $counter -lt $max_attempts ]]; do
        local rg_name="rg-${project_name}${suffix}"
        local storage_name=$(generate_storage_name "$project_name" "$suffix")
        local synapse_name="${project_name}${suffix}-syn"
        
        print_info "Checking availability for: $project_name${suffix}..."
        
        # Check storage account availability (most restrictive)
        if check_storage_available "$storage_name"; then
            # Storage is available, return the names
            echo "$rg_name|$storage_name|$synapse_name|${project_name}${suffix}"
            return 0
        else
            print_warning "Name conflict detected. Trying with suffix..."
            counter=$((counter + 1))
            suffix="$counter"
        fi
    done
    
    # If we exhausted attempts, generate a random suffix
    local random_suffix=$(head /dev/urandom | tr -dc 'a-z0-9' | head -c 4)
    local rg_name="rg-${project_name}-${random_suffix}"
    local storage_name=$(generate_storage_name "$project_name" "$random_suffix")
    local synapse_name="${project_name}-${random_suffix}-syn"
    echo "$rg_name|$storage_name|$synapse_name|${project_name}-${random_suffix}"
}

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed. Please install it first."
    echo "Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    print_warning "jq is not installed. Installing..."
    sudo apt-get update && sudo apt-get install -y jq || {
        print_error "Failed to install jq. Please install it manually."
        exit 1
    }
fi

# Check if logged in to Azure
print_info "Checking Azure login status..."
if ! az account show &> /dev/null; then
    print_error "Not logged in to Azure. Please run 'az login' first."
    exit 1
fi

CURRENT_SUBSCRIPTION=$(az account show --query name -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
print_success "Logged in to Azure subscription: $CURRENT_SUBSCRIPTION"

# Get deployment parameters
echo ""
echo -e "${CYAN}============================================================================${NC}"
echo -e "${CYAN}  Configuration${NC}"
echo -e "${CYAN}============================================================================${NC}"
echo ""
echo "All resource names will be automatically generated from your project name:"
echo "  - Resource Group:    rg-{project-name}"
echo "  - Storage Account:   {projectname}st"
echo "  - Synapse Workspace: {project-name}-syn"
echo ""

# Prompt for project name (REQUIRED)
while true; do
    read -p "$(echo -e ${YELLOW}Enter Project Name \(required, e.g., fantastic-demo\): ${NC})" PROJECT_NAME_INPUT
    
    if [[ -z "$PROJECT_NAME_INPUT" ]]; then
        print_error "Project name is required. Please enter a name."
        continue
    fi
    
    # Sanitize the input
    PROJECT_NAME=$(sanitize_name "$PROJECT_NAME_INPUT")
    
    # Validate length
    if [[ ${#PROJECT_NAME} -lt 3 ]]; then
        print_error "Project name must be at least 3 characters long."
        continue
    fi
    
    if [[ ${#PROJECT_NAME} -gt 20 ]]; then
        print_error "Project name must be 20 characters or less."
        continue
    fi
    
    # Validate format
    if ! [[ "$PROJECT_NAME" =~ ^[a-z][a-z0-9-]*[a-z0-9]$ ]]; then
        print_error "Project name must start with a letter, end with a letter or number, and contain only lowercase letters, numbers, and dashes."
        continue
    fi
    
    break
done

print_info "Using project name: $PROJECT_NAME"

# Prompt for location
read -p "$(echo -e ${YELLOW}Enter Azure Location \[${DEFAULT_LOCATION}\]: ${NC})" LOCATION_INPUT
LOCATION="${LOCATION_INPUT:-$DEFAULT_LOCATION}"

# Prompt for SQL Admin Password (hidden input)
echo ""
while true; do
    read -sp "$(echo -e ${YELLOW}Enter SQL Admin Password \(min 8 chars, uppercase, lowercase, number, special char\): ${NC})" SQL_PASSWORD
    echo ""
    
    if [[ ${#SQL_PASSWORD} -lt 8 ]]; then
        print_warning "Password must be at least 8 characters long."
        continue
    fi
    
    # Basic password complexity check
    if ! [[ "$SQL_PASSWORD" =~ [A-Z] ]]; then
        print_warning "Password must contain at least one uppercase letter."
        continue
    fi
    
    if ! [[ "$SQL_PASSWORD" =~ [a-z] ]]; then
        print_warning "Password must contain at least one lowercase letter."
        continue
    fi
    
    if ! [[ "$SQL_PASSWORD" =~ [0-9] ]]; then
        print_warning "Password must contain at least one number."
        continue
    fi
    
    break
done

# Find available names (handles conflicts)
echo ""
print_info "Checking resource name availability..."
NAMES_RESULT=$(find_available_names "$PROJECT_NAME")
IFS='|' read -r RESOURCE_GROUP STORAGE_ACCOUNT SYNAPSE_WORKSPACE FINAL_PROJECT_NAME <<< "$NAMES_RESULT"

# Show configuration summary
echo ""
echo -e "${CYAN}============================================================================${NC}"
echo -e "${CYAN}  Deployment Configuration${NC}"
echo -e "${CYAN}============================================================================${NC}"
echo ""
echo -e "  ${BLUE}Project Name:${NC}      $FINAL_PROJECT_NAME"
echo -e "  ${BLUE}Location:${NC}          $LOCATION"
echo -e "  ${BLUE}Resource Group:${NC}    $RESOURCE_GROUP"
echo -e "  ${BLUE}Storage Account:${NC}   $STORAGE_ACCOUNT"
echo -e "  ${BLUE}Synapse Workspace:${NC} $SYNAPSE_WORKSPACE"
echo ""

read -p "$(echo -e ${YELLOW}Proceed with deployment? \(y/N\): ${NC})" CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    print_warning "Deployment cancelled."
    exit 0
fi

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")/infra"

# Create Resource Group
echo ""
print_info "Creating Resource Group: $RESOURCE_GROUP..."
az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --tags "project=$FINAL_PROJECT_NAME" "purpose=synapse-cdc-poc" \
    --output none

print_success "Resource Group created."

# Deploy Bicep template
print_info "Deploying infrastructure (this may take 5-10 minutes)..."
echo ""

DEPLOYMENT_OUTPUT=$(az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$INFRA_DIR/main.bicep" \
    --parameters \
        location="$LOCATION" \
        projectName="$FINAL_PROJECT_NAME" \
        sqlAdminPassword="$SQL_PASSWORD" \
    --query "properties.outputs" \
    --output json)

print_success "Infrastructure deployment completed!"

# Parse and display outputs
STORAGE_ACCOUNT=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.storageAccountName.value')
SYNAPSE_WORKSPACE=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.synapseWorkspaceName.value')
SYNAPSE_WEB=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.synapseWebEndpoint.value')
DATA_PATH=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.dataContainerPath.value')

echo ""
echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN}  Deployment Successful!${NC}"
echo -e "${GREEN}============================================================================${NC}"
echo ""
echo -e "${BLUE}Project:${NC} $FINAL_PROJECT_NAME"
echo ""
echo -e "${BLUE}Resource Details:${NC}"
echo "  Resource Group:    $RESOURCE_GROUP"
echo "  Storage Account:   $STORAGE_ACCOUNT"
echo "  Synapse Workspace: $SYNAPSE_WORKSPACE"
echo ""
echo -e "${BLUE}Important URLs:${NC}"
echo "  Synapse Studio: $SYNAPSE_WEB"
echo ""
echo -e "${BLUE}Data Lake Paths:${NC}"
echo "  Base Path:    $DATA_PATH"
echo "  Source:       $DATA_PATH/source/"
echo "  Destination:  $DATA_PATH/destination/"
echo "  Metadata:     $DATA_PATH/metadata/"
echo ""

# Create folder structure in storage
print_info "Creating folder structure in storage account..."

# Get storage account key
STORAGE_KEY=$(az storage account keys list \
    --resource-group "$RESOURCE_GROUP" \
    --account-name "$STORAGE_ACCOUNT" \
    --query "[0].value" \
    --output tsv)

# Create folders by uploading placeholder files
for folder in "source" "destination" "metadata"; do
    echo "placeholder" | az storage blob upload \
        --account-name "$STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --container-name "data" \
        --name "${folder}/.keep" \
        --data @- \
        --overwrite \
        --output none 2>/dev/null || true
done

print_success "Folder structure created."

echo ""
echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN}  Next Steps${NC}"
echo -e "${GREEN}============================================================================${NC}"
echo ""
echo "1. Upload sample CSV files to the storage account:"
echo ""
echo "   # For timestamp-based scenario:"
echo "   az storage blob upload-batch \\"
echo "     --account-name $STORAGE_ACCOUNT \\"
echo "     --destination data/source \\"
echo "     --source ./sample-data/scenario_with_timestamp"
echo ""
echo "   # For hash-based scenario:"
echo "   az storage blob upload-batch \\"
echo "     --account-name $STORAGE_ACCOUNT \\"
echo "     --destination data/source \\"
echo "     --source ./sample-data/scenario_without_timestamp"
echo ""
echo "2. Open Synapse Studio:"
echo "   $SYNAPSE_WEB"
echo ""
echo "3. Import and run the notebooks from the /notebooks folder"
echo "   (Remember to update STORAGE_ACCOUNT = \"$STORAGE_ACCOUNT\" in the notebooks)"
echo ""

# Save deployment info to file
DEPLOY_INFO_FILE="$SCRIPT_DIR/deployment-info-${FINAL_PROJECT_NAME}.txt"
cat > "$DEPLOY_INFO_FILE" << EOF
# ============================================================================
# Azure Synapse CDC POC - Deployment Information
# ============================================================================
# Project: $FINAL_PROJECT_NAME
# Generated: $(date)
# ============================================================================

PROJECT_NAME=$FINAL_PROJECT_NAME
LOCATION=$LOCATION
RESOURCE_GROUP=$RESOURCE_GROUP
STORAGE_ACCOUNT=$STORAGE_ACCOUNT
SYNAPSE_WORKSPACE=$SYNAPSE_WORKSPACE
SYNAPSE_WEB_URL=$SYNAPSE_WEB
DATA_PATH=$DATA_PATH

# Azure Portal Links
RESOURCE_GROUP_URL=https://portal.azure.com/#@/resource/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}
STORAGE_ACCOUNT_URL=https://portal.azure.com/#@/resource/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Storage/storageAccounts/${STORAGE_ACCOUNT}

# Upload Commands
# az storage blob upload-batch --account-name $STORAGE_ACCOUNT --destination data/source --source ./sample-data/scenario_with_timestamp
EOF

print_success "Deployment info saved to: $DEPLOY_INFO_FILE"
echo ""
echo -e "${YELLOW}Tip: Keep this file for reference!${NC}"
echo ""
