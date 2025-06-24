Clear-Host
write-host "Starting script at $(Get-Date)"

Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name Az.Synapse -Force

# Handle cases where the user has multiple subscriptions
$subs = Get-AzSubscription | Select-Object
if($subs.GetType().IsArray -and $subs.length -gt 1){
        Write-Host "You have multiple Azure subscriptions - please select the one you want to use:"
        for($i = 0; $i -lt $subs.length; $i++)
        {
                Write-Host "[$($i)]: $($subs[$i].Name) (ID = $($subs[$i].Id))"
        }
        $selectedIndex = -1
        $selectedValidIndex = 0
        while ($selectedValidIndex -ne 1)
        {
                $enteredValue = Read-Host("Enter 0 to $($subs.Length - 1)")
                if (-not ([string]::IsNullOrEmpty($enteredValue)))
                {
                    if ([int]$enteredValue -in (0..$($subs.Length - 1)))
                    {
                        $selectedIndex = [int]$enteredValue
                        $selectedValidIndex = 1
                    }
                    else
                    {
                        Write-Output "Please enter a valid subscription number."
                    }
                }
                else
                {
                    Write-Output "Please enter a valid subscription number."
                }
        }
        $selectedSub = $subs[$selectedIndex].Id
        Select-AzSubscription -SubscriptionId $selectedSub
        az account set --subscription $selectedSub
}

# Prompt user for resource group name
write-host ""
$resourceGroupName = ""
while ([string]::IsNullOrWhiteSpace($resourceGroupName))
{
    $resourceGroupName = Read-Host "Enter the resource group name"
    if ([string]::IsNullOrWhiteSpace($resourceGroupName))
    {
        Write-Output "Resource group name cannot be empty. Please enter a valid name."
    }
}

# Check if resource group exists
$resourceGroup = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if (-not $resourceGroup) {
    Write-Host "Resource group '$resourceGroupName' not found. Please check the name and try again."
    Exit
}
Write-Host "Found resource group: $resourceGroupName"

# Find Synapse workspaces in the resource group
Write-Host "Searching for Synapse workspaces in resource group '$resourceGroupName'..."
$synapseWorkspaces = Get-AzSynapseWorkspace -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue

if (-not $synapseWorkspaces -or $synapseWorkspaces.Count -eq 0) {
    Write-Host "No Synapse workspaces found in resource group '$resourceGroupName'."
    Exit
}

# Select Synapse workspace if multiple exist
$selectedWorkspace = $null
if ($synapseWorkspaces.GetType().IsArray -and $synapseWorkspaces.Count -gt 1) {
    Write-Host "Multiple Synapse workspaces found. Please select one:"
    for($i = 0; $i -lt $synapseWorkspaces.Count; $i++) {
        Write-Host "[$($i)]: $($synapseWorkspaces[$i].Name)"
    }
    
    $selectedIndex = -1
    $selectedValidIndex = 0
    while ($selectedValidIndex -ne 1) {
        $enteredValue = Read-Host("Enter 0 to $($synapseWorkspaces.Count - 1)")
        if (-not ([string]::IsNullOrEmpty($enteredValue))) {
            if ([int]$enteredValue -in (0..$($synapseWorkspaces.Count - 1))) {
                $selectedIndex = [int]$enteredValue
                $selectedValidIndex = 1
            }
            else {
                Write-Output "Please enter a valid workspace number."
            }
        }
        else {
            Write-Output "Please enter a valid workspace number."
        }
    }
    $selectedWorkspace = $synapseWorkspaces[$selectedIndex]
}
else {
    $selectedWorkspace = $synapseWorkspaces[0]
}

$synapseWorkspaceName = $selectedWorkspace.Name
Write-Host "Selected Synapse workspace: $synapseWorkspaceName"

# Find dedicated SQL pools in the workspace
Write-Host "Searching for dedicated SQL pools in workspace '$synapseWorkspaceName'..."
$sqlPools = Get-AzSynapseSqlPool -WorkspaceName $synapseWorkspaceName -ErrorAction SilentlyContinue

if (-not $sqlPools -or $sqlPools.Count -eq 0) {
    Write-Host "No dedicated SQL pools found in workspace '$synapseWorkspaceName'."
    Exit
}

# Select SQL pool if multiple exist
$selectedSqlPool = $null
if ($sqlPools.GetType().IsArray -and $sqlPools.Count -gt 1) {
    Write-Host "Multiple dedicated SQL pools found. Please select one:"
    for($i = 0; $i -lt $sqlPools.Count; $i++) {
        Write-Host "[$($i)]: $($sqlPools[$i].Name) (Status: $($sqlPools[$i].Status))"
    }
    
    $selectedIndex = -1
    $selectedValidIndex = 0
    while ($selectedValidIndex -ne 1) {
        $enteredValue = Read-Host("Enter 0 to $($sqlPools.Count - 1)")
        if (-not ([string]::IsNullOrEmpty($enteredValue))) {
            if ([int]$enteredValue -in (0..$($sqlPools.Count - 1))) {
                $selectedIndex = [int]$enteredValue
                $selectedValidIndex = 1
            }
            else {
                Write-Output "Please enter a valid SQL pool number."
            }
        }
        else {
            Write-Output "Please enter a valid SQL pool number."
        }
    }
    $selectedSqlPool = $sqlPools[$selectedIndex]
}
else {
    $selectedSqlPool = $sqlPools[0]
}

$sqlPoolName = $selectedSqlPool.Name
$sqlPoolStatus = $selectedSqlPool.Status
Write-Host "Selected dedicated SQL pool: $sqlPoolName (Status: $sqlPoolStatus)"

# Resume SQL pool if it's paused
if ($sqlPoolStatus -eq "Paused") {
    Write-Host "SQL pool is paused. Resuming..."
    Resume-AzSynapseSqlPool -WorkspaceName $synapseWorkspaceName -Name $sqlPoolName
    Write-Host "Waiting for SQL pool to resume..."
    do {
        Start-Sleep -Seconds 30
        $poolStatus = Get-AzSynapseSqlPool -WorkspaceName $synapseWorkspaceName -Name $sqlPoolName
        Write-Host "Current status: $($poolStatus.Status)"
    } while ($poolStatus.Status -ne "Online")
    Write-Host "SQL pool is now online."
}

# Prompt for SQL credentials
write-host ""
$sqlUser = ""
while ([string]::IsNullOrWhiteSpace($sqlUser)) {
    $sqlUser = Read-Host "Enter the SQL username for the dedicated SQL pool"
    if ([string]::IsNullOrWhiteSpace($sqlUser)) {
        Write-Output "SQL username cannot be empty. Please enter a valid username."
    }
}

$sqlPassword = ""
while ([string]::IsNullOrWhiteSpace($sqlPassword)) {
    $sqlPassword = Read-Host "Enter the password for user '$sqlUser'"
    if ([string]::IsNullOrWhiteSpace($sqlPassword)) {
        Write-Output "Password cannot be empty. Please enter a valid password."
    }
}

# Test connection to SQL pool
Write-Host "Testing connection to SQL pool..."
$serverName = "$synapseWorkspaceName-ondemand.sql.azuresynapse.net"
$dedicatedServerName = "$synapseWorkspaceName.sql.azuresynapse.net"

try {
    # Test connection using sqlcmd
    $testQuery = "SELECT 1 as TestConnection"
    $result = sqlcmd -S $dedicatedServerName -U $sqlUser -P $sqlPassword -d $sqlPoolName -Q $testQuery -h -1 -W
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Connection successful!"
    }
    else {
        Write-Host "Connection failed. Please check your credentials."
        Exit
    }
}
catch {
    Write-Host "Error testing connection: $($_.Exception.Message)"
    Exit
}

# Prompt for database name
write-host ""
$databaseName = ""
while ([string]::IsNullOrWhiteSpace($databaseName)) {
    $databaseName = Read-Host "Enter the name for the new database (or existing database to use)"
    if ([string]::IsNullOrWhiteSpace($databaseName)) {
        Write-Output "Database name cannot be empty. Please enter a valid name."
    }
}

# Create database if setup.sql exists
if (Test-Path "setup.sql") {
    Write-Host "Creating/setting up database '$databaseName'..."
    sqlcmd -S $dedicatedServerName -U $sqlUser -P $sqlPassword -d $sqlPoolName -Q "IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = '$databaseName') CREATE DATABASE [$databaseName]"
    sqlcmd -S $dedicatedServerName -U $sqlUser -P $sqlPassword -d $databaseName -I -i setup.sql
    Write-Host "Database setup completed."
}
else {
    Write-Host "setup.sql file not found. Skipping database schema setup."
    # Create database anyway
    sqlcmd -S $dedicatedServerName -U $sqlUser -P $sqlPassword -d $sqlPoolName -Q "IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = '$databaseName') CREATE DATABASE [$databaseName]"
    Write-Host "Database '$databaseName' created."
}

# Load data if data files exist
if (Test-Path "./data/*.txt") {
    Write-Host "Loading data into database '$databaseName'..."
    Get-ChildItem "./data/*.txt" -File | Foreach-Object {
        write-host ""
        $file = $_.FullName
        Write-Host "Loading file: $file"
        $table = $_.Name.Replace(".txt","")
        
        # Check if format file exists
        $formatFile = $file.Replace("txt", "fmt")
        if (Test-Path $formatFile) {
            bcp dbo.$table in $file -S $dedicatedServerName -U $sqlUser -P $sqlPassword -d $databaseName -f $formatFile -q -k -E -b 5000
        }
        else {
            Write-Host "Format file not found for $table. Using default format."
            bcp dbo.$table in $file -S $dedicatedServerName -U $sqlUser -P $sqlPassword -d $databaseName -c -t"," -q -k -E -b 5000
        }
    }
    Write-Host "Data loading completed."
}
else {
    Write-Host "No data files found in ./data/ directory. Skipping data loading."
}

# Upload solution script if it exists
if (Test-Path "Solution.sql") {
    Write-Host "Uploading solution script..."
    try {
        Set-AzSynapseSqlScript -WorkspaceName $synapseWorkspaceName -DefinitionFile "Solution.sql" -sqlPoolName $sqlPoolName -sqlDatabaseName $databaseName
        Write-Host "Solution script uploaded successfully."
    }
    catch {
        Write-Host "Warning: Could not upload solution script. Error: $($_.Exception.Message)"
    }
}
else {
    Write-Host "Solution.sql file not found. Skipping script upload."
}

Write-Host ""
Write-Host "=== Summary ==="
Write-Host "Resource Group: $resourceGroupName"
Write-Host "Synapse Workspace: $synapseWorkspaceName"
Write-Host "SQL Pool: $sqlPoolName"
Write-Host "Database: $databaseName"
Write-Host "Server: $dedicatedServerName"
Write-Host ""
write-host "Script completed at $(Get-Date)"
