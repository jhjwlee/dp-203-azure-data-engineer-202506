Clear-Host
write-host "Starting script at $(Get-Date)"
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name Az.Synapse -Force

# Handle cases where the user has multiple subscriptions
$subs = Get-AzSubscription | Select-Object
if($subs.GetType().IsArray -and $subs.length -gt 1){
    Write-Host "You have multiple Azure subscriptions - please select the one you want to use:"
    for($i = 0; $i -lt $subs.length; $i++) {
        Write-Host "[$($i)]: $($subs[$i].Name) (ID = $($subs[$i].Id))"
    }
    $selectedIndex = -1
    $selectedValidIndex = 0
    while ($selectedValidIndex -ne 1) {
        $enteredValue = Read-Host("Enter 0 to $($subs.Length - 1)")
        if (-not ([string]::IsNullOrEmpty($enteredValue))) {
            if ([int]$enteredValue -in (0..$($subs.Length - 1))) {
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
    az account set --subscription $selectedSub
}

# Prompt user for a password for the SQL Database
$sqlUser = "SQLUser"
write-host ""
$sqlPassword = ""
$complexPassword = 0

while ($complexPassword -ne 1) {
    $SqlPassword = Read-Host "Enter a password to use for the $sqlUser login.`nThe password must meet complexity requirements:`n - Minimum 8 characters.`n - At least one upper case English letter [A-Z]`n - At least one lower case English letter [a-z]`n - At least one digit [0-9]`n - At least one special character (!,@,#,%,^,&,$)"

    if(($SqlPassword -cmatch '[a-z]') -and ($SqlPassword -cmatch '[A-Z]') -and ($SqlPassword -match '\d') -and ($SqlPassword.length -ge 8) -and ($SqlPassword -match '!|@|#|%|\^|&|\$')) {
        $complexPassword = 1
        Write-Output "Password $SqlPassword accepted. Make sure you remember this!"
    } else {
        Write-Output "$SqlPassword does not meet the complexity requirements."
    }
}

# 사용자로부터 리소스 그룹 입력 받기
$resourceGroupName = Read-Host "Enter the name of the existing Resource Group (it must already exist)"

# 리소스 그룹 존재 확인
if (-not (Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Resource group '$resourceGroupName' does not exist. Please create it first or enter a valid name."
    exit
}

# Register resource providers
Write-Host "Registering resource providers...";
$provider_list = "Microsoft.Synapse", "Microsoft.Sql", "Microsoft.Storage", "Microsoft.Compute"
$maxRetries = 5
$waittime = 30

foreach ($provider in $provider_list) {
    $retryCount = 0
    while ($retryCount -lt $maxRetries) {
        $currentStatus = (Get-AzResourceProvider -ProviderNamespace $provider).RegistrationState
        if ($currentStatus -eq "Registered") {
            Write-Host "$provider is successfully registered."
            break
        } else {
            Write-Host "$provider is not yet registered. Waiting for $waitTime seconds before rechecking..."
            Start-Sleep -Seconds $waitTime
            $retryCount++
        }
    }
    if ($retryCount -eq $maxRetries) {
        Write-Host "Failed to register $provider after $maxRetries attempts."
    }
}

# Generate unique random suffix with lab01 prefix
[string]$suffix =  -join ((48..57) + (97..122) | Get-Random -Count 7 | % {[char]$_})
$suffix = "lab01$suffix"
Write-Host "Your randomly-generated suffix for Azure resources is $suffix"

# Choose a random region
Write-Host "Finding an available region. This may take several minutes...";
$delay = 0, 30, 60, 90, 120 | Get-Random
Start-Sleep -Seconds $delay
$preferred_list = "australiaeast","centralus","southcentralus","eastus2","northeurope","southeastasia","uksouth","westeurope","westus","westus2"
$locations = Get-AzLocation | Where-Object {
    $_.Providers -contains "Microsoft.Synapse" -and
    $_.Providers -contains "Microsoft.Sql" -and
    $_.Providers -contains "Microsoft.Storage" -and
    $_.Providers -contains "Microsoft.Compute" -and
    $_.Location -in $preferred_list
}
$max_index = $locations.Count - 1
$rand = (0..$max_index) | Get-Random
$Region = $locations.Get($rand).Location

$success = 0
$tried_list = New-Object Collections.Generic.List[string]

while ($success -ne 1) {
    write-host "Trying $Region"
    $capability = Get-AzSqlCapability -LocationName $Region
    if($capability.Status -eq "Available") {
        $success = 1
        write-host "Using $Region"
    } else {
        $success = 0
        $tried_list.Add($Region)
        $locations = $locations | Where-Object {$_.Location -notin $tried_list}
        if ($locations.Count -ne 1) {
            $rand = (0..$($locations.Count - 1)) | Get-Random
            $Region = $locations.Get($rand).Location
        } else {
            Write-Host "Couldn't find an available region for deployment."
            Write-Host "Sorry! Try again later."
            Exit
        }
    }
}

# Create Synapse workspace
$synapseWorkspace = "synapse$suffix"
$dataLakeAccountName = "datalake$suffix"
$sparkPool = "spark$suffix"
$sqlDatabaseName = "sql$suffix"

write-host "Creating $synapseWorkspace Synapse Analytics workspace in $resourceGroupName resource group..."
write-host "(This may take some time!)"
New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName `
  -TemplateFile "setup.json" `
  -Mode Complete `
  -workspaceName $synapseWorkspace `
  -dataLakeAccountName $dataLakeAccountName `
  -sparkPoolName $sparkPool `
  -sqlDatabaseName $sqlDatabaseName `
  -sqlUser $sqlUser `
  -sqlPassword $sqlPassword `
  -uniqueSuffix $suffix `
  -Force

# 권한 부여
write-host "Granting permissions on the $dataLakeAccountName storage account..."
$subscriptionId = (Get-AzContext).Subscription.Id
$userName = ((az ad signed-in-user show) | ConvertFrom-JSON).UserPrincipalName
$id = (Get-AzADServicePrincipal -DisplayName $synapseWorkspace).id
New-AzRoleAssignment -Objectid $id -RoleDefinitionName "Storage Blob Data Owner" -Scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$dataLakeAccountName" -ErrorAction SilentlyContinue;
New-AzRoleAssignment -SignInName $userName -RoleDefinitionName "Storage Blob Data Owner" -Scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$dataLakeAccountName" -ErrorAction SilentlyContinue;

# Create database
write-host "Creating the $sqlDatabaseName database..."
sqlcmd -S "$synapseWorkspace.sql.azuresynapse.net" -U $sqlUser -P $sqlPassword -d $sqlDatabaseName -I -i setup.sql

# Load data
write-host "Loading data..."
Get-ChildItem "./data/*.txt" -File | Foreach-Object {
    write-host ""
    $file = $_.FullName
    Write-Host "$file"
    $table = $_.Name.Replace(".txt","")
    bcp dbo.$table in $file -S "$synapseWorkspace.sql.azuresynapse.net" -U $sqlUser -P $sqlPassword -d $sqlDatabaseName -f $file.Replace("txt", "fmt") -q -k -E -b 5000
}

# Pause SQL Pool
write-host "Pausing the $sqlDatabaseName SQL Pool..."
Suspend-AzSynapseSqlPool -WorkspaceName $synapseWorkspace -Name $sqlDatabaseName -AsJob

# Upload files
write-host "Uploading files to storage..."
$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $dataLakeAccountName
$storageContext = $storageAccount.Context
Get-ChildItem "./files/*.csv" -File | Foreach-Object {
    write-host ""
    $file = $_.Name
    Write-Host $file
    $blobPath = "sales_data/$file"
    Set-AzStorageBlobContent -File $_.FullName -Container "files" -Blob $blobPath -Context $storageContext
}

write-host "Script completed at $(Get-Date)"
