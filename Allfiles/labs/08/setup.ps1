# Create database if setup.sql exists
if (Test-Path "setup.sql") {
    Write-Host "Setting up database objects in SQL pool '$sqlPoolName'..."
    # In Synapse dedicated SQL pools, we work directly with the SQL pool, not separate databases
    # The SQL pool itself is the database
    sqlcmd -S $dedicatedServerName -U $sqlUser -P $sqlPassword -d $sqlPoolName -i setup.sql -C
    Write-Host "Database setup completed."
}
else {
    Write-Host "setup.sql file not found. Skipping database schema setup."
    Write-Host "Using SQL pool '$sqlPoolName' as the target database."
}

# Load data if data files exist
if (Test-Path "./data/*.txt") {
    Write-Host "Loading data into SQL pool '$sqlPoolName'..."
    Get-ChildItem "./data/*.txt" -File | Foreach-Object {
        write-host ""
        $file = $_.FullName
        Write-Host "Loading file: $file"
        $table = $_.Name.Replace(".txt","")
        
        # Check if format file exists
        $formatFile = $file.Replace("txt", "fmt")
        if (Test-Path $formatFile) {
            bcp dbo.$table in $file -S $dedicatedServerName -U $sqlUser -P $sqlPassword -d $sqlPoolName -f $formatFile -q -k -E -b 5000
        }
        else {
            Write-Host "Format file not found for $table. Using default format."
            bcp dbo.$table in $file -S $dedicatedServerName -U $sqlUser -P $sqlPassword -d $sqlPoolName -c -t"," -q -k -E -b 5000
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
        Set-AzSynapseSqlScript -WorkspaceName $synapseWorkspaceName -DefinitionFile "Solution.sql" -sqlPoolName $sqlPoolName -sqlDatabaseName $sqlPoolName
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
Write-Host "Target Database: $sqlPoolName"
Write-Host "Server: $dedicatedServerName"
Write-Host ""
write-host "Script completed at $(Get-Date)"
