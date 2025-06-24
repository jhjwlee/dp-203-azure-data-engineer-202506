Clear-Host
write-host "Starting script at $(Get-Date)"

# Az.Synapse 모듈이 이미 설치되어 있다고 가정합니다. 필요시 주석 해제하거나 설치 확인 로직 추가.
# Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
# Install-Module -Name Az.Synapse -Force

# --- 기존 구독 선택 로직 유지 ---
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
$synapseWorkspaceName = Read-Host "Enter the name of your existing Synapse Workspace" # 이 변수 이름을 일관되게 사용합니다.
$dataLakeAccountName = Read-Host "Enter the name of your existing Data Lake Storage Gen2 account"
$sqlPoolName = Read-Host "Enter the name of your existing Dedicated SQL Pool (e.g., sqlpool01)" # 사용자가 SQL Pool 이름을 직접 입력하도록 변경

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

$newSqlDatabaseName = Read-Host "Enter the name for the NEW database to be created in the SQL Pool '$sqlPoolName' (e.g., SalesDW)"

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
# $resourceGroupName = "dp203-$suffix" # 이제 사용자 입력 $resourceGroupName 사용

# # Choose a random region (기존 리소스를 사용하므로 지역 선택 불필요)
# # ... (지역 선택 로직 제거) ...

# Write-Host "Creating $resourceGroupName resource group in $Region ..."
# New-AzResourceGroup -Name $resourceGroupName -Location $Region | Out-Null

# # Create Synapse workspace (기존 작업 영역 사용)
# $synapseWorkspace = "synapse$suffix" # 이제 사용자 입력 $synapseWorkspaceName 사용
# $dataLakeAccountName = "datalake$suffix" # 이제 사용자 입력 $dataLakeAccountName 사용
# $sqlDatabaseName = "sql$suffix" # 이 변수는 이제 $sqlPoolName (기존 풀)과 $newSqlDatabaseName (새 DB)으로 대체됨

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

# Synapse Workspace Managed Identity의 Object ID를 사용하는 것이 더 정확합니다.
$synapseWorkspaceObj = Get-AzSynapseWorkspace -ResourceGroupName $resourceGroupName -Name $synapseWorkspaceName
if (-not $synapseWorkspaceObj) {
    Write-Error "Synapse Workspace '$synapseWorkspaceName' not found in resource group '$resourceGroupName'."
    exit
}
$synapseMIPrincipalId = $synapseWorkspaceObj.Identity.PrincipalId

if (-not $synapseMIPrincipalId) {
    Write-Error "Failed to get Managed Identity Principal ID for Synapse Workspace '$synapseWorkspaceName'"
    exit
}

New-AzRoleAssignment -ObjectId $synapseMIPrincipalId -RoleDefinitionName "Storage Blob Data Owner" -Scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$dataLakeAccountName" -ErrorAction SilentlyContinue;
New-AzRoleAssignment -SignInName $userName -RoleDefinitionName "Storage Blob Data Owner" -Scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$dataLakeAccountName" -ErrorAction SilentlyContinue;


# --- 새로운 데이터베이스 생성 (사용자 입력된 정보 사용) ---
$sqlPoolServerName = "$synapseWorkspaceName.sql.azuresynapse.net" # SQL Pool 서버 이름

write-host "Creating the NEW database '$newSqlDatabaseName' in SQL Pool '$sqlPoolName'..."
# master 데이터베이스에 연결하여 새 데이터베이스 생성
Invoke-Sqlcmd -ServerInstance $sqlPoolServerName -Username $sqlUser -Password $sqlPassword -Database "master" -Query "CREATE DATABASE [$newSqlDatabaseName] (SERVICE_OBJECTIVE = '$sqlPoolName');" # SQL Pool 내에 생성 명시
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create database '$newSqlDatabaseName' within SQL Pool '$sqlPoolName'."
    exit
}
Write-Host "Database '$newSqlDatabaseName' created successfully in SQL Pool '$sqlPoolName'."

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
    Set-AzStorageBlobContent -File $_.FullName -Container "files" -Blob $blobPath -Context $storageContext -Force
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to upload file '$file'."
    } else {
        Write-Host "File '$file' uploaded successfully to 'files/data/'."
    }
}

# --- SQL Pool 일시 중지 (사용자 입력된 SQL Pool 이름 사용) ---
# $sqlDatabaseName 변수는 이제 $sqlPoolName (기존 풀)과 $newSqlDatabaseName (새 DB)으로 나뉘었으므로,
# 실제 일시 중지할 대상은 기존에 생성된 SQL Pool입니다.
write-host "Pausing the '$sqlPoolName' SQL Pool in Workspace '$synapseWorkspaceName'..."
Suspend-AzSynapseSqlPool -WorkspaceName $synapseWorkspaceName -Name $sqlPoolName -ErrorAction Stop # AsJob 제거하고 에러 시 중지
if ($LASTEXITCODE -eq 0) {
    Write-Host "SQL Pool '$sqlPoolName' is being paused."
} else {
    Write-Warning "Failed to initiate pausing of SQL Pool '$sqlPoolName'."
}


write-host "Script completed at $(Get-Date)"
