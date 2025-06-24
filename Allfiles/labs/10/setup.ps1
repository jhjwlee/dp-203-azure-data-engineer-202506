Clear-Host
write-host "Starting script at $(Get-Date)"

# Az.Synapse 모듈이 이미 설치되어 있다고 가정합니다. 필요시 주석 해제하거나 설치 확인 로직 추가.
# Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
# Install-Module -Name Az.Synapse -Force

# --- 기존 구독 선택 로직 유지 ---
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

# --- 사용자로부터 기존 리소스 정보 및 새 데이터베이스 이름 입력 받기 ---
Write-Host ""
$resourceGroupName = Read-Host "Enter the name of your existing Resource Group"
$synapseWorkspaceName = Read-Host "Enter the name of your existing Synapse Workspace"
$dataLakeAccountName = Read-Host "Enter the name of your existing Data Lake Storage Gen2 account"
# SQL Pool 이름은 일반적으로 Synapse Workspace 이름과 동일하거나 특정 패턴을 따를 수 있습니다.
# 여기서는 Synapse Workspace 이름과 동일하다고 가정하고, 필요시 별도 입력 받도록 수정 가능합니다.
# $sqlPoolName = Read-Host "Enter the name of your existing Dedicated SQL Pool (if different from workspace name)"
$sqlPoolName = $synapseWorkspaceName # 또는 sql$synapseWorkspaceName 와 같이 패턴이 있다면 해당 패턴 사용

$sqlUser = "SQLUser" # 또는 기존 SQL 관리자 사용자 이름을 입력받도록 수정
$sqlPassword = ""
$complexPassword = 0

while ($complexPassword -ne 1)
{
    $SqlPassword = Read-Host "Enter the password for the SQL Admin user '$sqlUser' of your Synapse SQL Pool.
    `The password must meet complexity requirements:
    ` - Minimum 8 characters.
    ` - At least one upper case English letter [A-Z]
    ` - At least one lower case English letter [a-z]
    ` - At least one digit [0-9]
    ` - At least one special character (!,@,#,%,^,&,$)
    ` "

    if(($SqlPassword -cmatch '[a-z]') -and ($SqlPassword -cmatch '[A-Z]') -and ($SqlPassword -match '\d') -and ($SqlPassword.length -ge 8) -and ($SqlPassword -match '!|@|#|%|\^|&|\$'))
    {
        $complexPassword = 1
	    Write-Output "Password accepted."
    }
    else
    {
        Write-Output "$SqlPassword does not meet the complexity requirements."
    }
}

$newSqlDatabaseName = Read-Host "Enter the name for the NEW database to be created in the SQL Pool (e.g., SalesDB)"

# --- 리소스 프로바이더 등록 (필요시 유지) ---
Write-Host "Registering resource providers (if not already registered)...";
$provider_list = "Microsoft.Synapse", "Microsoft.Sql", "Microsoft.Storage", "Microsoft.Compute"
foreach ($provider in $provider_list){
    $result = Get-AzResourceProvider -ProviderNamespace $provider
    if ($result.RegistrationState -ne "Registered") {
        Register-AzResourceProvider -ProviderNamespace $provider
        Write-Host "$provider : Registered"
    } else {
        Write-Host "$provider : Already Registered"
    }
}

# --- 리소스 생성 로직 제거 또는 주석 처리 ---
# # Generate unique random suffix
# [string]$suffix =  -join ((48..57) + (97..122) | Get-Random -Count 7 | % {[char]$_})
# Write-Host "Your randomly-generated suffix for Azure resources is $suffix"
# $resourceGroupName = "dp203-$suffix"

# # Choose a random region (기존 리소스를 사용하므로 지역 선택 불필요)
# # ... (지역 선택 로직 제거) ...

# Write-Host "Creating $resourceGroupName resource group in $Region ..."
# New-AzResourceGroup -Name $resourceGroupName -Location $Region | Out-Null

# # Create Synapse workspace (기존 작업 영역 사용)
# $synapseWorkspace = "synapse$suffix"
# $dataLakeAccountName = "datalake$suffix"
# $sqlDatabaseName = "sql$suffix" # 이 변수는 이제 $newSqlDatabaseName 으로 대체됨

# write-host "Creating $synapseWorkspace Synapse Analytics workspace in $resourceGroupName resource group..."
# write-host "(This may take some time!)"
# New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName `
#   -TemplateFile "setup.json" `
#   -Mode Complete `
#   -uniqueSuffix $suffix `
#   -workspaceName $synapseWorkspace `
#   -dataLakeAccountName $dataLakeAccountName `
#   -sqlDatabaseName $sqlDatabaseName ` # 기존 템플릿의 SQL DB 생성 부분은 무시되거나, 새 DB 생성 로직으로 대체
#   -sqlUser $sqlUser `
#   -sqlPassword $sqlPassword `
#   -Force

# --- 데이터 레이크 저장소에 대한 권한 부여 (사용자 입력된 정보 사용) ---
write-host "Granting permissions on the $dataLakeAccountName storage account..."
write-host "(you can ignore any warnings!)"
$subscriptionId = (Get-AzContext).Subscription.Id
$userName = ((az ad signed-in-user show) | ConvertFrom-JSON).UserPrincipalName
$synapseServicePrincipal = Get-AzSynapseWorkspace -ResourceGroupName $resourceGroupName -Name $synapseWorkspaceName
$id = $synapseServicePrincipal.ManagedVirtualNetworkSettings.AllowedAadTenantIdsForLinking[0] # 실제 SP ID 가져오는 방식 확인 필요, 또는 Get-AzADServicePrincipal 사용

# Synapse Workspace의 Managed Identity를 사용하거나, 사용자가 직접 SP를 지정하는 것이 더 일반적입니다.
# 아래는 예시이며, 실제 환경에 맞게 SP ID를 정확히 가져와야 합니다.
# 일반적으로 Get-AzADServicePrincipal -DisplayName $synapseWorkspaceName 를 사용하지만,
# Synapse Workspace의 Managed Identity를 사용하는 것이 권장됩니다.
# $synapseManagedIdentity = (Get-AzSynapseWorkspace -ResourceGroupName $resourceGroupName -Name $synapseWorkspaceName).Identity.PrincipalId
# if ($synapseManagedIdentity) {
#   $id = $synapseManagedIdentity
# } else {
#   Write-Warning "Could not retrieve Managed Identity for Synapse Workspace. Trying to find Service Principal by display name. This might not be accurate."
#   $id = (Get-AzADServicePrincipal -DisplayName $synapseWorkspaceName).id
# }

# Synapse Workspace Managed Identity의 Object ID를 사용하는 것이 더 정확합니다.
$synapseWorkspaceObj = Get-AzSynapseWorkspace -ResourceGroupName $resourceGroupName -Name $synapseWorkspaceName
$synapseMIPrincipalId = $synapseWorkspaceObj.Identity.PrincipalId

if (-not $synapseMIPrincipalId) {
    Write-Error "Failed to get Managed Identity Principal ID for Synapse Workspace '$synapseWorkspaceName'"
    exit
}

New-AzRoleAssignment -ObjectId $synapseMIPrincipalId -RoleDefinitionName "Storage Blob Data Owner" -Scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$dataLakeAccountName" -ErrorAction SilentlyContinue;
New-AzRoleAssignment -SignInName $userName -RoleDefinitionName "Storage Blob Data Owner" -Scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$dataLakeAccountName" -ErrorAction SilentlyContinue;


# --- 새로운 데이터베이스 생성 (사용자 입력된 정보 사용) ---
# 기존 setup.sql 파일은 특정 데이터베이스 (sql$suffix)를 대상으로 했을 수 있습니다.
# 새로운 데이터베이스를 생성하고 해당 데이터베이스 컨텍스트에서 setup.sql을 실행해야 합니다.
# SQL Pool의 서버 이름은 Synapse Workspace 이름과 동일한 패턴을 따릅니다.
$sqlPoolServerName = "$synapseWorkspaceName.sql.azuresynapse.net"

write-host "Creating the NEW database '$newSqlDatabaseName' in SQL Pool '$sqlPoolName'..."
# master 데이터베이스에 연결하여 새 데이터베이스 생성
Invoke-Sqlcmd -ServerInstance $sqlPoolServerName -Username $sqlUser -Password $sqlPassword -Database "master" -Query "CREATE DATABASE [$newSqlDatabaseName];"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create database '$newSqlDatabaseName'."
    exit
}
Write-Host "Database '$newSqlDatabaseName' created successfully."

# 생성된 새 데이터베이스 컨텍스트에서 setup.sql 실행 (테이블 생성 등)
write-host "Running setup.sql in the new database '$newSqlDatabaseName'..."
Invoke-Sqlcmd -ServerInstance $sqlPoolServerName -Username $sqlUser -Password $sqlPassword -Database $newSqlDatabaseName -InputFile ".\setup.sql" -QueryTimeout 0
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to run setup.sql in database '$newSqlDatabaseName'."
    # 데이터베이스 생성 실패 시 롤백 고려 (예: DROP DATABASE)
    exit
}
Write-Host "setup.sql executed successfully in '$newSqlDatabaseName'."


# --- 데이터 로드 (새로운 데이터베이스 이름 사용) ---
write-host "Loading data into '$newSqlDatabaseName'..."
Get-ChildItem "./data/*.txt" -File | Foreach-Object {
    write-host ""
    $file = $_.FullName
    Write-Host "$file"
    $table = $_.Name.Replace(".txt","")
    # bcp 명령어에서 데이터베이스 이름을 $newSqlDatabaseName 으로 변경
    bcp dbo.$table in $file -S $sqlPoolServerName -U $sqlUser -P $sqlPassword -d $newSqlDatabaseName -f $file.Replace("txt", "fmt") -q -k -E -b 5000
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "BCP command failed for table '$table' and file '$file'."
    } else {
        Write-Host "Data loaded successfully into table '$table'."
    }
}

# --- 파일 업로드 (기존 로직 유지, Data Lake 계정 이름 변수 사용) ---
write-host "Uploading files to Data Lake '$dataLakeAccountName'..."
$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $dataLakeAccountName
if (-not $storageAccount) {
    Write-Error "Storage Account '$dataLakeAccountName' not found in resource group '$resourceGroupName'."
    exit
}
$storageContext = $storageAccount.Context
Get-ChildItem "./data/*.csv" -File | Foreach-Object {
    write-host ""
    $file = $_.Name
    Write-Host "Uploading $file"
    $blobPath = "data/$file" # 업로드 경로 확인 및 필요시 수정
    Set-AzStorageBlobContent -File $_.FullName -Container "files" -Blob $blobPath -Context $storageContext -Force # -Force 옵션 추가 (덮어쓰기)
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to upload file '$file'."
    } else {
        Write-Host "File '$file' uploaded successfully to 'files/data/'."
    }
}

Write-Host "Script finished at $(Get-Date)"
