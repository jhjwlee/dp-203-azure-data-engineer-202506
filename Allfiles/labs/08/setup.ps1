Clear-Host
Write-Host "Starting script at $(Get-Date)"

# 필요한 모듈 설치 (이미 설치되어 있다면 이 부분은 주석 처리하거나 조건부로 실행할 수 있습니다)
# Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
# Install-Module -Name Az.Synapse -Force

# 구독 선택
$subs = Get-AzSubscription | Select-Object
if($subs.GetType().IsArray -and $subs.Count -gt 1){ # 배열인지, 그리고 항목이 1개 초과인지 확인
    Write-Host "You have multiple Azure subscriptions - please select the one you want to use:"
    for($i = 0; $i -lt $subs.Count; $i++) {
        Write-Host "[$($i)]: $($subs[$i].Name) (ID = $($subs[$i].Id))"
    }
    $selectedIndex = -1
    $selectedValidIndex = 0
    while ($selectedValidIndex -ne 1)
    {
            $enteredValue = Read-Host("Enter 0 to $($subs.Count - 1)")
            if (-not ([string]::IsNullOrEmpty($enteredValue)))
            {
                if ([int]$enteredValue -in (0..($subs.Count - 1))) # 범위 확인 수정
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
} elseif ($subs.Count -eq 1) {
    Write-Host "Using subscription: $($subs.Name) (ID = $($subs.Id))"
    # 단일 구독인 경우 자동으로 선택된 것으로 간주할 수 있습니다.
    # Select-AzSubscription -SubscriptionId $subs.Id # 명시적으로 선택
    # az account set --subscription $subs.Id # 명시적으로 선택
} else {
    Write-Error "No Azure subscriptions found. Please log in to Azure."
    exit
}


# 사용자 입력
$resourceGroupName = Read-Host "Enter the existing Resource Group Name"
$synapseWorkspaceName = Read-Host "Enter the existing Synapse Workspace Name" # 변수명 일관성 유지
$dataLakeAccountName = Read-Host "Enter the existing Data Lake Storage Account Name"
$sqlPoolName = Read-Host "Enter the existing Dedicated SQL Pool Name (e.g., sqlpool01)" # 이전 스크립트의 $sqlDatabaseName 과 혼동 방지

# --- SQL 사용자 이름 입력 받기 ---
$sqlUser = Read-Host "Enter the SQL Admin username for the Synapse SQL Pool '$sqlPoolName'"

# 새 데이터베이스 이름 입력 (SQL Pool 내에 생성될 데이터베이스)
$newSqlDatabaseName = Read-Host "Enter the name for the NEW database to be created in SQL Pool '$sqlPoolName' (e.g., SalesDW)"


# 비밀번호 입력 (일반 문자열, 복잡성 검사 포함)
$complexPassword = 0
while ($complexPassword -ne 1) {
    $sqlPassword = Read-Host "Enter the password for SQL Admin user '$sqlUser' (min 8 chars, 1 upper, 1 lower, 1 digit, 1 special)"

    if(($sqlPassword -cmatch '[a-z]') -and ($sqlPassword -cmatch '[A-Z]') -and ($sqlPassword -match '\d') -and ($sqlPassword.Length -ge 8) -and ($sqlPassword -match '[!@#%^\&\$]')) { # 정규식 수정
        $complexPassword = 1
        Write-Output "Password accepted. Make sure you remember this!"
    } else {
        Write-Output "Password does not meet complexity requirements. Please try again."
    }
}

# 리소스 프로바이더 등록 (이전 스크립트에서 가져옴)
Write-Host "Registering resource providers (if not already registered)...";
$provider_list = "Microsoft.Synapse", "Microsoft.Sql", "Microsoft.Storage", "Microsoft.Compute"
foreach ($provider in $provider_list){
    $currentProvider = Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction SilentlyContinue
    if ($null -eq $currentProvider -or $currentProvider.RegistrationState -ne "Registered") {
        Register-AzResourceProvider -ProviderNamespace $provider
        Write-Host "$provider : Registered"
    } else {
        Write-Host "$provider : Already Registered"
    }
}

# 권한 부여
Write-Host "Granting permissions on the $dataLakeAccountName storage account..."
$subscriptionId = (Get-AzContext).Subscription.Id
$userName = ((az ad signed-in-user show --output json 2>$null) | ConvertFrom-Json).UserPrincipalName
if (-not $userName) {
    Write-Warning "Could not retrieve signed-in user's UPN. Manual permission grant might be needed for the current user."
}

# Synapse Workspace Managed Identity 사용
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

New-AzRoleAssignment -ObjectId $synapseMIPrincipalId -RoleDefinitionName "Storage Blob Data Owner" -Scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$dataLakeAccountName" -ErrorAction SilentlyContinue
if ($userName) {
    New-AzRoleAssignment -SignInName $userName -RoleDefinitionName "Storage Blob Data Owner" -Scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$dataLakeAccountName" -ErrorAction SilentlyContinue
}


# SQL Pool 서버 이름
$sqlPoolServerName = "$synapseWorkspaceName.sql.azuresynapse.net"

# Create new database within the specified SQL Pool
write-host "Creating the NEW database '$newSqlDatabaseName' in SQL Pool '$sqlPoolName'..."
Invoke-Sqlcmd -ServerInstance $sqlPoolServerName -Username $sqlUser -Password $sqlPassword -Database "master" -Query "CREATE DATABASE [$newSqlDatabaseName];" # SERVICE_OBJECTIVE는 SQL Pool 내에서는 불필요할 수 있음, 확인 필요
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create database '$newSqlDatabaseName' in SQL Pool '$sqlPoolName'."
    exit
}
Write-Host "Database '$newSqlDatabaseName' created successfully in SQL Pool '$sqlPoolName'."

# setup.sql 실행 (새 데이터베이스 컨텍스트)
write-host "Running setup.sql in the new database '$newSqlDatabaseName'..."
Invoke-Sqlcmd -ServerInstance $sqlPoolServerName -Username $sqlUser -Password $sqlPassword -Database $newSqlDatabaseName -InputFile ".\setup.sql" -QueryTimeout 0
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to run setup.sql in database '$newSqlDatabaseName'."
    exit
}
Write-Host "setup.sql executed successfully in '$newSqlDatabaseName'."


# 데이터 로드 (새로운 데이터베이스 이름 사용)
Write-Host "Loading data into '$newSqlDatabaseName' ..."
Get-ChildItem "./data/*.txt" -File | ForEach-Object {
    $file = $_.FullName
    $table = $_.Name.Replace(".txt", "")
    Write-Host "Importing $file to table $table..."
    # bcp 명령어에서 데이터베이스 이름을 $newSqlDatabaseName 으로 변경
    bcp dbo.$table in $file -S $sqlPoolServerName -U $sqlUser -P $sqlPassword -d $newSqlDatabaseName -f $file.Replace("txt", "fmt") -q -k -E -b 5000
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "BCP command failed for table '$table' and file '$file'."
    } else {
        Write-Host "Data loaded successfully into table '$table'."
    }
}

# 파일 업로드 (이전 스크립트에서 가져옴)
write-host "Uploading data files to Data Lake '$dataLakeAccountName'..."
$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $dataLakeAccountName
if (-not $storageAccount) {
    Write-Error "Storage Account '$dataLakeAccountName' not found in resource group '$resourceGroupName'."
    exit
}
$storageContext = $storageAccount.Context
Get-ChildItem "./data/*.csv" -File | Foreach-Object {
    write-host ""
    $currentFile = $_.Name # 변수명 충돌 방지
    Write-Host "Uploading $currentFile"
    $blobPath = "data/$currentFile"
    Set-AzStorageBlobContent -File $_.FullName -Container "files" -Blob $blobPath -Context $storageContext -Force
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to upload file '$currentFile'."
    } else {
        Write-Host "File '$currentFile' uploaded successfully to 'files/data/'."
    }
}


# SQL Pool 일시 중지 (기존 SQL Pool 이름 사용)
Write-Host "Pausing the '$sqlPoolName' SQL Pool in Workspace '$synapseWorkspaceName'..."
Suspend-AzSynapseSqlPool -WorkspaceName $synapseWorkspaceName -Name $sqlPoolName -ErrorAction Stop
if ($LASTEXITCODE -eq 0) {
    Write-Host "SQL Pool '$sqlPoolName' is being paused."
} else {
    Write-Warning "Failed to initiate pausing of SQL Pool '$sqlPoolName'."
}

# 스크립트 업로드 (Solution.sql)
# 이 부분은 Synapse Studio의 SQL 스크립트로 업로드하는 것을 의미하는 것으로 보입니다.
# 파일 내용을 읽어서 Set-AzSynapseSqlScript cmdlet으로 업로드합니다.
$solutionScriptFilePath = ".\Solution.sql" # 로컬 파일 경로
if (Test-Path $solutionScriptFilePath) {
    Write-Host "Uploading solution script '$solutionScriptFilePath' to Synapse Workspace '$synapseWorkspaceName' for SQL Pool '$sqlPoolName' and Database '$newSqlDatabaseName'..."
    $scriptContent = Get-Content -Path $solutionScriptFilePath -Raw
    $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($solutionScriptFilePath) + "_" + (Get-Date -Format "yyyyMMddHHmmss") # 고유한 스크립트 이름 생성

    # Set-AzSynapseSqlScript 의 파라미터 확인 및 조정 필요
    # -SqlPoolName 은 Dedicated SQL Pool의 이름입니다.
    # -SqlDatabaseName 은 해당 SQL Pool 내의 데이터베이스 이름입니다.
    # 이 예제에서는 새로 생성한 데이터베이스에 연결되는 스크립트로 업로드합니다.
    try {
        Set-AzSynapseSqlScript -WorkspaceName $synapseWorkspaceName -Name $scriptName -Definition $scriptContent -FolderPath "LabSolutions" -ErrorAction Stop
        # Set-AzSynapseSqlScript 는 SQL Pool 이나 Database 에 직접 연결하는 옵션이 없을 수 있습니다.
        # 스크립트 자체는 작업 영역 레벨에서 관리되고, 실행 시 연결 컨텍스트를 지정합니다.
        # 따라서, SqlPoolName, SqlDatabaseName 파라미터는 실행 컨텍스트를 의미하는 것이 아니라,
        # 해당 스크립트가 주로 사용될 풀이나 데이터베이스를 메타데이터로 지정하는 것일 수 있습니다.
        # 정확한 사용법은 cmdlet 문서를 참고해야 합니다.
        # 만약 연결 정보 저장이 필요하다면 스크립트 내용에 USE [$newSqlDatabaseName]; 등을 포함해야 할 수 있습니다.

        # 더 일반적인 접근: 스크립트를 작업 영역에 저장하고, 실행 시 풀과 데이터베이스를 지정.
        # 아래는 스크립트를 생성하는 예시입니다. 'FolderPath' 등을 사용하여 정리할 수 있습니다.
        # Set-AzSynapseSqlScript -WorkspaceName $synapseWorkspaceName -Name "UploadedSolutionScript" -Definition $scriptContent -FolderPath "UploadedScripts"
        Write-Host "Solution script '$scriptName' uploaded successfully."
    } catch {
        Write-Warning "Failed to upload solution script '$solutionScriptFilePath'. Error: $($_.Exception.Message)"
    }
} else {
    Write-Warning "Solution script file not found at '$solutionScriptFilePath'."
}


Write-Host "Script completed at $(Get-Date)"
