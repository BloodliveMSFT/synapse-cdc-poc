# Azure Synapse CDC POC Lab: Incremental Ingestion from Files

This repository contains a complete, end-to-end Proof of Concept (POC) lab that demonstrates Change Data Capture (CDC)-style incremental ingestion from files using Azure Synapse Analytics Python notebooks.

This lab is designed to be fully runnable, repository-ready, and deployable via easy-button automation. It provides a simple, transparent, and reproducible solution for ingesting only new or changed data from CSV files dropped into Azure Storage.

## 🎯 Objective

The primary goal of this lab is to demonstrate two common real-world incremental ingestion scenarios using only Azure Synapse Analytics and Azure Storage:

1.  **Timestamp-Based Incremental Ingestion**: Processing source files that contain a `last_updated_ts` column to identify new records.
2.  **Hash-Based Incremental Ingestion**: Processing source files that **do not** have a timestamp by using row hashing to detect new or modified records.

## ✨ Features

-   **Project-Based Naming**: All resource names are automatically and predictably generated from a single project name you provide.
-   **End-to-End Automation**: Deploy the entire infrastructure with a single click or command.
-   **Bicep IaC**: All Azure resources are defined in Bicep for transparent and repeatable deployments.
-   **Synapse Notebooks**: Data processing logic is implemented in easy-to-understand Python notebooks.
-   **Two CDC Scenarios**: Covers both timestamp and non-timestamp-based source data.
-   **No External Services**: The solution uses only Azure Storage and Azure Synapse, with no dependency on Azure Data Factory, Event Grid, or other services.

## 🏗️ Naming Convention

All Azure resource names are derived from the **Project Name** you provide during deployment (e.g., `fantastic-demo`). This ensures that all components are easily identifiable and grouped together.

| Resource          | Naming Pattern                  | Example (`fantastic-demo`)      |
|-------------------|---------------------------------|---------------------------------|
| Resource Group    | `rg-{project-name}`             | `rg-fantastic-demo`             |
| Storage Account   | `{projectname}st` (no dashes)   | `fantasticdemost`               |
| Synapse Workspace | `{project-name}-syn`            | `fantastic-demo-syn`            |

> **Note on Conflicts**: The deployment scripts automatically handle naming conflicts. If a storage account name is already taken, the script will append a number (e.g., `fantasticdemost1`) to find an available name and use that unique suffix for all other resources.

## 🚀 Deployment

You can deploy the required Azure infrastructure using one of the two automated methods below. Both options deploy the same resources defined in the `/infra/main.bicep` file.

### Prerequisites

-   An active **Azure Subscription**. If you don't have one, [create a free account](https://azure.microsoft.com/free/).
-   **Sufficient permissions** to create resources, including Resource Groups, Storage Accounts, Synapse Workspaces, and Role Assignments.

---

### ✅ Option A: One-Click Deployment

This is the easiest way to deploy the lab environment. Click the button below to launch the deployment in the Azure Portal.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fcdn.jsdelivr.net%2Fgh%2F<YOUR_GITHUB_USERNAME>%2F<YOUR_REPOSITORY_NAME>%40main%2Finfra%2Fazuredeploy.json)

*Note: You will need to update the link above to point to the `azuredeploy.json` file in your own public GitHub repository after you fork or clone this project. The `cdn.jsdelivr.net` URL avoids common CORS download errors seen with `raw.githubusercontent.com` in the Azure Portal.*

#### Steps:

1.  Click the **Deploy to Azure** button.
2.  You will be redirected to the Azure Portal with a custom deployment screen.
3.  Select your **Subscription** and choose a **Region**.
4.  **Create a new Resource Group**. The name you choose for the resource group here is temporary; a new, permanent resource group will be created based on your project name (e.g., `rg-fantastic-demo`).
5.  Provide the required parameters:
    -   **Project Name**: A unique, descriptive name for your project (e.g., `fantastic-demo`). This is used to generate all other resource names.
    -   **Sql Admin Password**: A secure password for the Synapse workspace.
6.  Click **Review + create**, and then **Create** to start the deployment. The deployment typically takes 5-10 minutes.

---

### ✅ Option B: Single-Command Deployment

This option is for users who prefer to deploy from their local command line using the Azure CLI.

#### Additional Prerequisites:

-   **Azure CLI**: [Install the Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli).
-   **Git**: [Install Git](https://git-scm.com/downloads).
-   A shell environment like **Bash** (for `deploy.sh`) or **PowerShell** (for `deploy.ps1`).

#### Steps:

1.  **Clone the repository:**

    ```bash
    git clone https://github.com/<YOUR_GITHUB_USERNAME>/<YOUR_REPOSITORY_NAME>.git
    cd <YOUR_REPOSITORY_NAME>
    ```

2.  **Log in to Azure:**

    ```bash
    az login
    ```

3.  **Run the deployment script:**

    You can use either the Bash or PowerShell script located in the `/scripts` directory.

    **Using Bash (`deploy.sh`):**

    ```bash
    ./scripts/deploy.sh
    ```

    **Using PowerShell (`deploy.ps1`):**

    ```powershell
    ./scripts/deploy.ps1
    ```

4.  The script will prompt you for the **Project Name**, **Location**, and **SQL Admin Password**. Follow the prompts to complete the deployment. The script will automatically generate all resource names and handle any naming conflicts.

## 🧪 Lab Instructions

After the deployment is complete, follow these steps to run the incremental ingestion notebooks.

### Step 1: Get Deployment Outputs

After a successful deployment, the script or the Azure Portal will provide several important output values. A `deployment-info-{project-name}.txt` file will also be created in the `/scripts` directory with all the key details.

Key outputs include:

-   `projectName`: The final project name used for deployment (including any suffixes for uniqueness).
-   `resourceGroup`: The name of the deployed resource group.
-   `storageAccountName`: The name of your ADLS Gen2 storage account.
-   `synapseWorkspaceName`: The name of your Synapse workspace.
-   `synapseWebEndpoint`: The URL to access your Synapse Studio.

### Step 2: Upload Sample Data

This lab uses sample CSV files located in the `/sample-data` directory. You need to upload these files to the `source` folder in your newly created storage account.

1.  Navigate to the Azure Portal and find your deployed resource group (`rg-{project-name}`).
2.  Open the **Storage Account**.
3.  In the left navigation, go to **Storage browser** > **Blob containers**.
4.  Click on the **data** container.
5.  You will see three folders: `source`, `destination`, and `metadata`.
6.  Click on the **source** folder.
7.  Click the **Upload** button and upload the sample data files from the `/sample-data` directory of this repository.

    -   For the timestamp scenario, upload the files from `/sample-data/scenario_with_timestamp`.
    -   For the no-timestamp scenario, upload the files from `/sample-data/scenario_without_timestamp`.

    **Upload Order for Testing:** To properly test the incremental logic, upload the files one by one in the following order, running the corresponding notebook after each upload:
    1.  `..._initial.csv`
    2.  `..._delta1.csv`
    3.  `..._delta2.csv`

### Step 3: Configure and Run the Synapse Notebooks

1.  Open your **Synapse Studio** using the `synapseWebEndpoint` URL from the deployment outputs.
2.  In Synapse Studio, go to the **Develop** hub.
3.  Click the `+` icon and select **Import** to import the notebooks from the `/notebooks` directory of this repository:
    -   `incremental_with_timestamp.ipynb`
    -   `incremental_without_timestamp.ipynb`
4.  Open the imported notebook.
5.  **Attach** the notebook to a Spark pool (a default pool is created with the workspace).
6.  **Update the Configuration Cell**: In the first code cell of each notebook, replace `<your-storage-account-name>` with your actual `storageAccountName` from the deployment outputs.

    ```python
    # CONFIGURATION - Update these values for your environment
    STORAGE_ACCOUNT = "<your-storage-account-name>"
    ```

7.  Run the notebook cells sequentially by clicking **Run all**.

### Step 4: Validate Incremental Behavior

As you run the notebooks, observe the output of each step.

-   **First Run (with `_initial.csv` file):** The notebook will process all records from the initial file.
-   **Second Run (after uploading `_delta1.csv`):** The notebook will identify and process **only the new or changed records** from the delta file.
-   **Third Run (after uploading `_delta2.csv`):** The process repeats, again processing only the latest incremental changes.

#### How to Verify:

-   **Check the Notebook Output**: The logs in the notebook cells will explicitly state how many records were found, how many were filtered as incremental, and how many were written to the destination.
-   **Inspect the Destination Folder**: Navigate to the `/data/destination/` folder in your storage account. You will see the processed data stored in partitioned folders. The number of records should match the incremental count from the notebook.
-   **Examine the Metadata**: 
    -   For the timestamp scenario, inspect the `watermark_timestamp.json` file in `/data/metadata/`. Its value will update to the latest timestamp processed.
    -   For the hash-based scenario, inspect the Parquet files in the `/data/metadata/hash_registry/` folder. This registry will be updated with the hashes of all processed records.

## 📁 Repository Structure

```
/
├── /infra/                    # Bicep and ARM templates for infrastructure
│   ├── main.bicep             # Main Bicep file for all Azure resources
│   └── azuredeploy.json       # ARM template for the "Deploy to Azure" button
├── /notebooks/                # Synapse Python notebooks
│   ├── incremental_with_timestamp.ipynb
│   └── incremental_without_timestamp.ipynb
├── /sample-data/              # Sample CSV files for both scenarios
│   ├── scenario_with_timestamp/
│   └── scenario_without_timestamp/
├── /scripts/                  # Deployment scripts
│   ├── deploy.sh              # Bash script for deployment
│   └── deploy.ps1             # PowerShell script for deployment
└── README.md                  # This file
```

## 🧹 Cleaning Up

To avoid ongoing costs, delete the resource group created during deployment (`rg-{project-name}`). This will remove all the resources deployed in this lab.

1.  Go to the Azure Portal.
2.  Find the resource group you created.
3.  Click **Delete resource group**.

## 🤝 Contributing

Contributions, issues, and feature requests are welcome. Feel free to check the [issues page](https://github.com/<YOUR_GITHUB_USERNAME>/<YOUR_REPOSITORY_NAME>/issues) if you want to contribute.
