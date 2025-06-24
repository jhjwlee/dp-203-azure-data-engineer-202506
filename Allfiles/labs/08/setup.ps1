Clear-Host
Write-Host "Starting script at $(Get-Date)"

# Ensure Az.Synapse module is available
Write-Host "Checking for Az.Synapse module and installing if necessary..."
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name Az.Synapse -Force -Scope CurrentUser

# Connect to Azure and select subscription
Try {
    Connect-AzAccount -ErrorAction Stop
} Catch {
    Write-Error "Failed to connect to Azure. Please ensure you are logged in via Connect-AzAccount."
    Exit
}

$subs = Get-AzSubscription | Select-Object Name, Id
if ($null -eq $subs) {
    Write-Error "No Azure subscriptions found. Please check your Azure account."
    Exit
}

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
                Write-Warning "Please enter a valid subscription number."
            }
        } else {
            Write-Warning "Please enter a valid subscription number."
        }
    }
    $selectedSub = $subs[$selectedIndex].Id
    Select-AzSubscription -SubscriptionId $selectedSub
    # az account set --subscription $selectedSub # For Azure CLI commands if used elsewhere
} elseif ($subs) {
    # Only one subscription
    $selectedSub = $subs.Id
    Select-AzSubscription -SubscriptionId $selectedSub
    # az account set --subscription $selectedSub
    Write-Host "Using subscription: $($subs.Name) (ID = $selectedSub)"
}
Write-Host "Using Azure Context: $((Get-AzContext).Name)"


# 1. Prompt user for Resource Group name
$resourceGroupName = ""
while ([string]::IsNullOrWhiteSpace($resourceGroupName)) {
    $resourceGroupNameInput = Read-Host "Enter the name of your existing Azure Resource Group"
    if (-not [string]::IsNullOrWhiteSpace($resourceGroupNameInput)) {
        if (Get-AzResourceGroup -Name $resourceGroupNameInput -ErrorAction SilentlyContinue) {
            $resourceGroupName = $resourceGroupNameInput
            Write-Host "Using Resource Group: $resourceGroupName"
        } else {
            Write-Warning "Resource Group '$resourceGroupNameInput' not found. Please check the name and try again."
        }
    } else {
        Write-Warning "Resource Group name cannot be empty."
    }
}

# 2. Find Synapse Workspace in the specified Resource Group
Write-Host "Searching for Synapse Workspaces in Resource Group '$resourceGroupName'..."
$synapseWorkspaces = Get-AzSynapseWorkspace -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue

if (-not $synapseWorkspaces -or $synapseWorkspaces.Count -eq 0) {
    Write-Error "No Synapse Workspace found in Resource Group '$resourceGroupName'."
    Exit
}

$synapseWorkspaceName = $null
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
$dedicatedServerName = "$($synapseWorkspaceName).sql.azuresynapse.net" # Endpoint for Dedicated SQL Pool

# 3. Find Dedicated SQL Pool in the selected Synapse Workspace
Write-Host "Searching for Dedicated SQL Pools in Synapse Workspace '$synapseWorkspaceName'..."
$sqlPools = Get-AzSynapseSqlPool -ResourceGroupName $resourceGroupName -WorkspaceName $synapseWorkspaceName -ErrorAction SilentlyContinue

if (-not $sqlPools -or $sqlPools.Count -eq 0) {
    Write-Error "No Dedicated SQL Pool found in Synapse Workspace '$synapseWorkspaceName'."
    Exit
}

$sqlPoolName = $null
$selectedSqlPool = $null
if ($sqlPools.Count -eq 1) {
    $selectedSqlPool = $sqlPools[0]
    $sqlPoolName = $selectedSqlPool.Name
    Write-Host "Found Dedicated SQL Pool: $sqlPoolName (Status: $($selectedSqlPool.Status))"
} else {
    Write-Host "Multiple Dedicated SQL Pools found. Please select one:"
    for ($i = 0; $i -lt $sqlPools.Count; $i++) {
        Write-Host "[$i] $($sqlPools[$i].Name) (Status: $($sqlPools[$i].Status))"
    }
    $poolIndexInput = Read-Host "Enter the number of the Dedicated SQL Pool to use"
    if ($poolIndexInput -match "^\d+$" -and [int]$poolIndexInput -ge 0 -and [int]$poolIndexInput -lt $sqlPools.Count) {
        $selectedSqlPool = $sqlPools[[int]$poolIndexInput]
        $sqlPoolName = $selectedSqlPool.Name
        Write-Host "Using Dedicated SQL Pool: $sqlPoolName (Status: $($selectedSqlPool.Status))"
    } else {
        Write-Error "Invalid selection for Dedicated SQL Pool."
        Exit
    }
}

# Resume SQL pool if it's paused
if ($selectedSqlPool.Status -eq "Paused") {
    Write-Host "SQL pool '$sqlPoolName' is paused. Resuming..."
    Resume-AzSynapseSqlPool -WorkspaceName $synapseWorkspaceName -Name $sqlPoolName -ResourceGroupName $resourceGroupName
    Write-Host "Waiting for SQL pool to resume..."
    $currentStatusCheck = $null
    do {
        Start-Sleep -Seconds 15 # Check more frequently
        $currentStatusCheck = (Get-AzSynapseSqlPool -WorkspaceName $synapseWorkspaceName -Name $sqlPoolName -ResourceGroupName $resourceGroupName).Status
        Write-Host "Current status of '$sqlPoolName': $currentStatusCheck"
    } while ($currentStatusCheck -ne "Online")
    Write-Host "SQL pool '$sqlPoolName' is now online."
}

# 4. Prompt for SQL credentials
Write-Host ""
$sqlUser = ""
while ([string]::IsNullOrWhiteSpace($sqlUser)) {
    $sqlUser = Read-Host "Enter the SQL admin username for the dedicated SQL pool '$sqlPoolName'"
    if ([string]::IsNullOrWhiteSpace($sqlUser)) {
        Write-Warning "SQL username cannot be empty. Please enter a valid username."
    }
}

$sqlPassword = ""
while ([string]::IsNullOrWhiteSpace($sqlPassword)) {
    # Password will be visible during input
    $sqlPassword = Read-Host "Enter the password for user '$sqlUser' (password will be visible)"
    if ([string]::IsNullOrWhiteSpace($sqlPassword)) {
        Write-Warning "Password cannot be empty. Please enter a valid password."
    }
}
Write-Output "Credentials for user '$sqlUser' accepted."

# Test connection to SQL pool
Write-Host "Testing connection to SQL pool '$sqlPoolName' on server '$dedicatedServerName'..."
try {
    $testQuery = "SELECT GETDATE() as CurrentTime;" # A simple query
    # Use -b to ensure sqlcmd exits on error, -t for timeout
    sqlcmd -S $dedicatedServerName -U $sqlUser -P $sqlPassword -d $sqlPoolName -Q $testQuery -h -1 -b -t 60 -I
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Connection to SQL pool '$sqlPoolName' successful!"
    } else {
        Write-Error "Connection to SQL pool '$sqlPoolName' failed. SQLCMD Exit Code: $LASTEXITCODE. Please check credentials, server name, database name, and ensure the SQL pool is online and accessible."
        Exit
    }
} catch {
    Write-Error "Error testing connection to SQL pool '$sqlPoolName': $($_.Exception.Message)"
    Exit
}

# THE DATABASE NAME IS THE SQL POOL NAME FOR DEDICATED SQL POOLS
# No separate database name input needed. We use $sqlPoolName.

# Create/setup database schema using setup.sql if it exists
# The "database" for a dedicated SQL pool is the pool itself.
$setupSqlPath = "./setup.sql"
if (Test-Path $setupSqlPath) {
    Write-Host "Running setup script '$setupSqlPath' on database (SQL Pool) '$sqlPoolName'..."
    try {
        # -d $sqlPoolName targets the dedicated SQL pool
        sqlcmd -S $dedicatedServerName -U $sqlUser -P $sqlPassword -d $sqlPoolName -i $setupSqlPath -b -t 300 -I
        Write-Host "Database setup script '$setupSqlPath' completed successfully on '$sqlPoolName'."
    } catch {
        Write-Error "Error running setup script '$setupSqlPath' on '$sqlPoolName': $($_.Exception.Message). SQLCMD Exit Code: $LASTEXITCODE"
    }
} else {
    Write-Warning "Setup script '$setupSqlPath' not found. Skipping database schema setup."
}

# Load data if data files exist
$dataPath = "./data"
if (Get-ChildItem -Path "$dataPath/*.txt" -File -ErrorAction SilentlyContinue) {
    Write-Host "Loading data into database (SQL Pool) '$sqlPoolName'..."
    Get-ChildItem -Path "$dataPath/*.txt" -File | ForEach-Object {
        $file = $_.FullName
        $tableName = $_.Name.Replace(".txt", "")
        $formatFile = $file.Replace(".txt", ".fmt")

        Write-Host ""
        Write-Host "Attempting to load data from '$file' into table 'dbo.$tableName'..."
        try {
            if (Test-Path $formatFile) {
                Write-Host "Using format file: $formatFile"
                bcp "dbo.$tableName" in "$file" -S $dedicatedServerName -U $sqlUser -P "$sqlPassword" -d "$sqlPoolName" -f "$formatFile" -q -k -E -b 5000 -t # Added -t for timeout
            } else {
                Write-Warning "Format file '$formatFile' not found for '$file'. Using default comma-separated format (-c -t,)."
                bcp "dbo.$tableName" in "$file" -S $dedicatedServerName -U $sqlUser -P "$sqlPassword" -d "$sqlPoolName" -c -t"," -q -k -E -b 5000 -t # Added -t for timeout
            }
             if ($LASTEXITCODE -eq 0) {
                Write-Host "Successfully loaded data into 'dbo.$tableName'."
            } else {
                Write-Error "BCP command failed for table 'dbo.$tableName' with exit code $LASTEXITCODE."
            }
        } catch {
            Write-Error "Error loading data into 'dbo.$tableName' using BCP: $($_.Exception.Message)"
        }
    }
    Write-Host "Data loading process completed."
} else {
    Write-Warning "No data files (*.txt) found in '$dataPath' directory. Skipping data loading."
}

# Upload solution script if it exists
$solutionScriptPath = "./Solution.sql"
$solutionScriptNameInSynapse = "SolutionUploaded_$(Get-Date -Format 'yyyyMMddHHmmss')" # Make script name unique in Synapse

if (Test-Path $solutionScriptPath) {
    Write-Host "Uploading solution script '$solutionScriptPath' as '$solutionScriptNameInSynapse' to Synapse workspace '$synapseWorkspaceName' associated with SQL Pool '$sqlPoolName'..."
    try {
        # For dedicated SQL pools, you associate the script with the pool.
        # The -SqlDatabaseName parameter for Set-AzSynapseSqlScript might be more relevant for serverless SQL.
        # However, if it's required for dedicated as well, using $sqlPoolName is appropriate.
        $sqlPoolObject = Get-AzSynapseSqlPool -ResourceGroupName $resourceGroupName -WorkspaceName $synapseWorkspaceName -Name $sqlPoolName
        Set-AzSynapseSqlScript -WorkspaceName $synapseWorkspaceName -Name $solutionScriptNameInSynapse -DefinitionFile $solutionScriptPath -SqlPool $sqlPoolObject -ErrorAction Stop
        Write-Host "Solution script '$solutionScriptNameInSynapse' uploaded successfully."
    } catch {
        Write-Error "Failed to upload solution script '$solutionScriptPath'."
        Write-Error $_.Exception.Message
    }
} else {
    Write-Warning "Solution script '$solutionScriptPath' not found. Skipping script upload."
}

Write-Host ""
Write-Host "=== Summary ==="
Write-Host "Resource Group: $resourceGroupName"
Write-Host "Synapse Workspace: $synapseWorkspaceName"
Write-Host "Dedicated SQL Pool (Database): $sqlPoolName"
Write-Host "SQL Server Endpoint: $dedicatedServerName"
Write-Host "SQL User: $sqlUser"
Write-Host ""
Write-Host "Script completed at $(Get-Date)"
