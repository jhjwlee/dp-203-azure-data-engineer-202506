Clear-Host
Write-Host "Starting script at $(Get-Date)"

# Ensure Az.Accounts and Az.Synapse modules are imported
# Attempt to import modules silently, install if missing might require admin rights and user consent.
# For simplicity, this script assumes modules are present or will be installed/imported by the user separately if issues arise.
# Consider adding robust module checking and installation if needed for wider distribution.
# Import-Module Az.Accounts -ErrorAction SilentlyContinue
# Import-Module Az.Synapse -ErrorAction SilentlyContinue

# The original script had module installation. Keeping it as per original.
# However, running Install-Module within a script might require elevated privileges and can be slow.
# Consider pre-requisite instructions for users to install these modules.
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name Az.Synapse -Force -Scope CurrentUser # Added -Scope CurrentUser to avoid admin rights requirement where possible

# Connect to Azure and select subscription
Try {
    Connect-AzAccount -ErrorAction Stop
} Catch {
    Write-Error "Failed to connect to Azure. Please ensure you are logged in via Connect-AzAccount."
    Exit
}

# Handle cases where the user has multiple subscriptions
$subs = Get-AzSubscription | Select-Object Name, Id
if ($subs.GetType().IsArray -and $subs.length -gt 1) {
    Write-Host "You have multiple Azure subscriptions - please select the one you want to use:"
    for ($i = 0; $i -lt $subs.length; $i++) {
        Write-Host "[$($i)]: $($subs[$i].Name) (ID = $($subs[$i].Id))"
    }
    $selectedIndex = -1
    $selectedValidIndex = 0
    while ($selectedValidIndex -ne 1) {
        $enteredValue = Read-Host ("Enter 0 to $($subs.Length - 1)")
        if (-not ([string]::IsNullOrEmpty($enteredValue))) {
            if ($enteredValue -match "^\d+$" -and [int]$enteredValue -ge 0 -and [int]$enteredValue -lt $subs.Length) {
                $selectedIndex = [int]$enteredValue
                $selectedValidIndex = 1
            } else {
                Write-Output "Please enter a valid subscription number."
            }
        } else {
            Write-Output "Please enter a valid subscription number."
        }
    }
    $selectedSub = $subs[$selectedIndex].Id
    Select-AzSubscription -SubscriptionId $selectedSub
    az account set --subscription $selectedSub # For Azure CLI commands if any
} elseif ($subs) {
    # Only one subscription
    $selectedSub = $subs.Id
    Select-AzSubscription -SubscriptionId $selectedSub
    az account set --subscription $selectedSub
    Write-Host "Using subscription: $($subs.Name) (ID = $selectedSub)"
} else {
    Write-Error "No Azure subscriptions found. Please check your Azure account."
    Exit
}

# --- USER INPUT FOR EXISTING RESOURCES ---

# 1. Prompt user for Resource Group name
while (-not $resourceGroupName) {
    $resourceGroupNameInput = Read-Host "Enter the name of your existing Azure Resource Group"
    if (Get-AzResourceGroup -Name $resourceGroupNameInput -ErrorAction SilentlyContinue) {
        $resourceGroupName = $resourceGroupNameInput
        Write-Host "Using Resource Group: $resourceGroupName"
    } else {
        Write-Warning "Resource Group '$resourceGroupNameInput' not found. Please check the name and try again."
    }
}

# 2. Find Synapse Workspace in the specified Resource Group
Write-Host "Searching for Synapse Workspaces in Resource Group '$resourceGroupName'..."
$synapseWorkspaces = Get-AzSynapseWorkspace -ResourceGroupName $resourceGroupName
if ($null -eq $synapseWorkspaces -or $synapseWorkspaces.Count -eq 0) {
    Write-Error "No Synapse Workspace found in Resource Group '$resourceGroupName'."
    Exit
}

if ($synapseWorkspaces.Count -eq 1) {
    $synapseWorkspaceName = $synapseWorkspaces[0].Name
    Write-Host "Found Synapse Workspace: $synapseWorkspaceName"
} else {
    Write-Host "Multiple Synapse Workspaces found. Please select one:"
    for ($i = 0; $i -lt $synapseWorkspaces.Count; $i++) {
        Write-Host "[$i] $($synapseWorkspaces[$i].Name)"
    }
    $wsIndexInput = Read-Host "Enter the number of the Synapse Workspace to use"
    if ($wsIndexInput -match "^\d+$" -and [int]$wsIndexInput -ge 0 -and [int]$wsIndexInput -lt $synapseWorkspaces.Count) {
        $synapseWorkspaceName = $synapseWorkspaces[[int]$wsIndexInput].Name
        Write-Host "Using Synapse Workspace: $synapseWorkspaceName"
    } else {
        Write-Error "Invalid selection for Synapse Workspace."
        Exit
    }
}
$synapseWorkspaceDetails = Get-AzSynapseWorkspace -ResourceGroupName $resourceGroupName -Name $synapseWorkspaceName
$sqlEndpoint = $synapseWorkspaceDetails.ConnectivityEndpoints.Sql # This is the SQL On-Demand and Dedicated SQL endpoint
$devSqlEndpoint = $synapseWorkspaceDetails.ConnectivityEndpoints.Dev # Used for script publishing

# Attempt to get Data Lake storage account name
$dataLakeAccountName = $null
if ($synapseWorkspaceDetails.DefaultDataLakeStorage) {
    $dataLakeAccountUrl = $synapseWorkspaceDetails.DefaultDataLakeStorage.AccountUrl
    if ($dataLakeAccountUrl) {
        # Extracts "datalakename" from "https://datalakename.dfs.core.windows.net/"
        $dataLakeAccountName = $dataLakeAccountUrl.Split('/')[2].Split('.')[0]
        Write-Host "Associated Data Lake Storage Account (from default configuration): $dataLakeAccountName"
    }
}

if (-not $dataLakeAccountName) {
    Write-Warning "Could not automatically determine the Data Lake Storage Account name from Synapse Workspace '$synapseWorkspaceName'."
    $dataLakeAccountName = Read-Host "Enter the name of the Data Lake Storage Account associated with '$synapseWorkspaceName' (used for permission granting)"
    if ([string]::IsNullOrWhiteSpace($dataLakeAccountName)) {
        Write-Error "Data Lake Storage Account name is required for permission assignment. Exiting."
        Exit
    }
}


# 3. Find Dedicated SQL Pool in the selected Synapse Workspace
Write-Host "Searching for Dedicated SQL Pools in Synapse Workspace '$synapseWorkspaceName'..."
$sqlPools = Get-AzSynapseSqlPool -ResourceGroupName $resourceGroupName -WorkspaceName $synapseWorkspaceName
if ($null -eq $sqlPools -or $sqlPools.Count -eq 0) {
    Write-Error "No Dedicated SQL Pool found in Synapse Workspace '$synapseWorkspaceName'."
    Exit
}

if ($sqlPools.Count -eq 1) {
    $sqlPoolName = $sqlPools[0].Name # This is the SQL Pool (formerly SQL DW) name, often used as the database name
    Write-Host "Found Dedicated SQL Pool: $sqlPoolName"
} else {
    Write-Host "Multiple Dedicated SQL Pools found. Please select one:"
    for ($i = 0; $i -lt $sqlPools.Count; $i++) {
        Write-Host "[$i] $($sqlPools[$i].Name) ($($sqlPools[$i].Sku.Name))"
    }
    $poolIndexInput = Read-Host "Enter the number of the Dedicated SQL Pool to use"
    if ($poolIndexInput -match "^\d+$" -and [int]$poolIndexInput -ge 0 -and [int]$poolIndexInput -lt $sqlPools.Count) {
        $sqlPoolName = $sqlPools[[int]$poolIndexInput].Name
        Write-Host "Using Dedicated SQL Pool: $sqlPoolName"
    } else {
        Write-Error "Invalid selection for Dedicated SQL Pool."
        Exit
    }
}
# For dedicated SQL pools, the pool name is often used as the database name in connection strings.
$sqlDatabaseName = $sqlPoolName


# --- SQL ADMIN USERNAME AND PASSWORD INPUT ---
Write-Host ""
$sqlUser = Read-Host "Enter the SQL admin username for '$sqlPoolName'"
$sqlPassword = ""
$complexPassword = 0

while ($complexPassword -ne 1) {
    $SqlPasswordCandidate = Read-Host -AsSecureString "Enter the password for the SQL admin user '$sqlUser'.
    `nThe password must meet complexity requirements:
    `n - Minimum 8 characters. 
    `n - At least one upper case English letter [A-Z]
    `n - At least one lower case English letter [a-z]
    `n - At least one digit [0-9]
    `n - At least one special character (e.g., !,@,#,%,^,&,$)
    `n "
    $SqlPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SqlPasswordCandidate))

    if (($SqlPassword -cmatch '[a-z]') -and `
        ($SqlPassword -cmatch '[A-Z]') -and `
        ($SqlPassword -match '\d') -and `
        ($SqlPassword.Length -ge 8) -and `
        ($SqlPassword -match '[!@#%^&$]')) { # Ensure your regex matches desired special characters
        $complexPassword = 1
        Write-Output "Password for user '$sqlUser' accepted. Make sure you remember this!"
    } else {
        Write-Output "Password does not meet the complexity requirements. Please try again."
    }
}

# Register resource providers (keeping this as it's good practice, though existing resources imply they are registered)
Write-Host "Registering resource providers (if not already registered)...";
$provider_list = "Microsoft.Synapse", "Microsoft.Sql", "Microsoft.Storage", "Microsoft.Compute"
foreach ($provider in $provider_list) {
    if ((Get-AzResourceProvider -ProviderNamespace $provider).RegistrationState -ne "Registered") {
        Register-AzResourceProvider -ProviderNamespace $provider
        Write-Host "$provider : Registered" # Simplified status
    } else {
        Write-Host "$provider : Already Registered"
    }
}

# --- RESOURCE CREATION SECTION IS REMOVED as resources are expected to exist ---
# The original script created a new resource group, Synapse workspace, Data Lake, and SQL pool.
# This modified script assumes these already exist and were selected by the user.

# Make the current user and the Synapse service principal owners of the data lake blob store
write-host "Granting 'Storage Blob Data Owner' role on the '$dataLakeAccountName' storage account..."
write-host "(You can ignore 'role assignment already exists' warnings if permissions are already set)"
$subscriptionId = (Get-AzContext).Subscription.Id
$currentUserPrincipalName = (Get-AzAccessToken -ResourceTypeName AadGraph).UserId # More robust way to get current user UPN

# Granting to Synapse Workspace Managed Identity
$synapseWorkspaceMIPrincipalId = $synapseWorkspaceDetails.Identity.PrincipalId
if ($synapseWorkspaceMIPrincipalId) {
    Write-Host "Assigning 'Storage Blob Data Owner' to Synapse Workspace MSI ($synapseWorkspaceMIPrincipalId) on '$dataLakeAccountName'"
    New-AzRoleAssignment -ObjectId $synapseWorkspaceMIPrincipalId -RoleDefinitionName "Storage Blob Data Owner" -Scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$dataLakeAccountName" -ErrorAction SilentlyContinue
} else {
    Write-Warning "Could not retrieve Managed Identity Principal ID for Synapse Workspace '$synapseWorkspaceName'. Skipping role assignment for Synapse MSI."
    Write-Warning "You may need to manually assign 'Storage Blob Data Owner' on '$dataLakeAccountName' to the Synapse workspace's Managed Identity."
}

# Granting to current user
if ($currentUserPrincipalName) {
    Write-Host "Assigning 'Storage Blob Data Owner' to current user ($currentUserPrincipalName) on '$dataLakeAccountName'"
    New-AzRoleAssignment -SignInName $currentUserPrincipalName -RoleDefinitionName "Storage Blob Data Owner" -Scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$dataLakeAccountName" -ErrorAction SilentlyContinue
} else {
    Write-Warning "Could not determine current user's Principal Name. Skipping role assignment for current user."
}


# Setup Database (run setup.sql) - Assuming setup.sql contains table creations etc.
# Ensure 'setup.sql' is in the same directory as this script, or provide a full path.
$setupSqlPath = "./setup.sql"
if (Test-Path $setupSqlPath) {
    write-host "Running setup script ($setupSqlPath) on the '$sqlDatabaseName' database via SQLCMD..."
    # Note: SQLCMD requires being installed and in PATH.
    # The SQL endpoint for dedicated pool is like: yourworkspacename.sql.azuresynapse.net
    try {
        sqlcmd -S "$sqlEndpoint" -U $sqlUser -P $sqlPassword -d "$sqlDatabaseName" -I -i "$setupSqlPath" -b -t 300 # Added -b for error termination and -t for timeout
        Write-Host "SQL setup script executed successfully."
    } catch {
        Write-Error "Error executing SQL setup script with SQLCMD. Please check SQLCMD installation, PATH, credentials, and script content."
        # $_.Exception.Message
    }
} else {
    Write-Warning "Setup script '$setupSqlPath' not found. Skipping database setup."
}


# Load data using BCP
# Ensure BCP utility is installed and in PATH.
# Ensure format files (.fmt) are present alongside data files (.txt) in the ./data directory.
$dataPath = "./data"
if (Test-Path $dataPath) {
    write-host "Loading data into '$sqlDatabaseName' using BCP..."
    Get-ChildItem -Path "$dataPath/*.txt" -File | Foreach-Object {
        $file = $_.FullName
        $tableName = $_.Name.Replace(".txt", "")
        $formatFile = $file.Replace(".txt", ".fmt")

        if (Test-Path $formatFile) {
            Write-Host "Loading data from '$file' into table 'dbo.$tableName'..."
            try {
                bcp "dbo.$tableName" in "$file" -S "$sqlEndpoint" -U $sqlUser -P "$sqlPassword" -d "$sqlDatabaseName" -f "$formatFile" -q -k -E -b 5000
                Write-Host "Successfully loaded data into 'dbo.$tableName'."
            } catch {
                Write-Error "Error loading data into 'dbo.$tableName' using BCP. Check BCP installation, credentials, file paths, and table schema."
                # $_.Exception.Message
            }
        } else {
            Write-Warning "Format file '$formatFile' not found for data file '$file'. Skipping table 'dbo.$tableName'."
        }
    }
} else {
    Write-Warning "Data directory '$dataPath' not found. Skipping data loading."
}

# Pause SQL Pool (using the identified SQL Pool name)
write-host "Pausing the '$sqlPoolName' SQL Pool in workspace '$synapseWorkspaceName'..."
Suspend-AzSynapseSqlPool -WorkspaceName $synapseWorkspaceName -Name $sqlPoolName -ResourceGroupName $resourceGroupName -PassThru # Removed -AsJob for simplicity, can be re-added if background task is preferred

# Upload solution script
# Ensure 'Solution.sql' is in the same directory as this script, or provide a full path.
$solutionScriptPath = "./Solution.sql"
$solutionScriptNameInSynapse = "SolutionUploadedByScript_$(Get-Date -Format 'yyyyMMddHHmmss')" # Make script name unique in Synapse

if (Test-Path $solutionScriptPath) {
    write-host "Uploading solution script '$solutionScriptPath' to Synapse workspace '$synapseWorkspaceName' associated with SQL Pool '$sqlPoolName'..."
    try {
        # Set-AzSynapseSqlScript expects the script to be associated with a SQL pool or serverless.
        # The endpoint for publishing (-Endpoint $devSqlEndpoint) might be different.
        # Using -SqlPoolObject might be more robust if you have the pool object.
        $sqlPoolObject = Get-AzSynapseSqlPool -ResourceGroupName $resourceGroupName -WorkspaceName $synapseWorkspaceName -Name $sqlPoolName
        Set-AzSynapseSqlScript -WorkspaceName $synapseWorkspaceName -Name $solutionScriptNameInSynapse -DefinitionFile $solutionScriptPath -SqlPool $sqlPoolObject -ErrorAction Stop
        Write-Host "Solution script '$solutionScriptNameInSynapse' uploaded successfully."
    } catch {
        Write-Error "Failed to upload solution script to Synapse."
        Write-Error $_.Exception.Message
    }
} else {
    Write-Warning "Solution script '$solutionScriptPath' not found. Skipping upload."
}

write-host "Script completed at $(Get-Date)"
