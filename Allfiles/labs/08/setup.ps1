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
        Write-Host "Selected subscription: $($subs[$selectedIndex].Name)"
} elseif ($subs) {
    Select-AzSubscription -SubscriptionId $subs.Id
    az account set --subscription $subs.Id
    Write-Host "Using subscription: $($subs.Name)"
} else {
    Write-Error "No Azure subscriptions found. Please log in to Azure."
    exit
}


# --- 사용자로부터 리소스 그룹 정보 입력 받기 ---
Write-Host ""
$resourceGroupName = Read-Host "Enter the name of your existing Resource Group"
if (-not (Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue)) {
    Write-Error "Resource Group '$resourceGroupName' not found. Please check the name and try again."
    exit
}

# --- Synapse Workspace 검색 및 선택 ---
Write-Host ""
Write-Host "Searching for Synapse Workspaces in Resource Group '$resourceGroupName'..."
$synapseWorkspaces = Get-AzSynapseWorkspace -ResourceGroupName $resourceGroupName
if (-not $synapseWorkspaces) {
    Write-Error "No Synapse Workspaces found in Resource Group '$resourceGroupName'."
    exit
}

$synapseWorkspaceName = ""
if ($synapseWorkspaces.Count -eq 1) {
    $synapseWorkspaceName = $synapseWorkspaces[0].Name
    Write-Host "Automatically selected Synapse Workspace: $synapseWorkspaceName"
} else {
    Write-Host "Multiple Synapse Workspaces found. Please select one:"
    for ($i = 0; $i -lt $synapseWorkspaces.Count; $i++) {
        Write-Host "[$i]: $($synapseWorkspaces[$i].Name)"
    }
    $selectedIndex = -1
    $selectedValidIndex = 0
    while ($selectedValidIndex -ne 1) {
        $enteredValue = Read-Host ("Enter 0 to $($synapseWorkspaces.Count - 1)")
        if (-not ([string]::IsNullOrEmpty($enteredValue))) {
            if ([int]$enteredValue -in (0..($synapseWorkspaces.Count - 1))) {
                $selectedIndex = [int]$enteredValue
                $selectedValidIndex = 1
            } else {
                Write-Output "Please enter a valid number."
            }
        } else {
            Write-Output "Please enter a valid number."
        }
    }
    $synapseWorkspaceName = $synapseWorkspaces[$selectedIndex].Name
    Write-Host "Selected Synapse Workspace: $synapseWorkspaceName"
}

# --- Dedicated SQL Pool 검색 및 선택 ---
Write-Host ""
Write-Host "Searching for Dedicated SQL Pools in Synapse Workspace '$synapseWorkspaceName'..."
$sqlPools = Get-AzSynapseSqlPool -ResourceGroupName $resourceGroupName -WorkspaceName $synapseWorkspaceName
if (-not $sqlPools) {
    Write-Error "No Dedicated SQL Pools found in Synapse Workspace '$synapseWorkspaceName'."
    exit
}

$sqlPoolName = ""
if ($sqlPools.Count -eq 1) {
    $sqlPoolName = $sqlPools[0].Name
    Write-Host "Automatically selected Dedicated SQL Pool: $sqlPoolName"
} else {
    Write-Host "Multiple Dedicated SQL Pools found. Please select one:"
    for ($i = 0; $i -lt $sqlPools.Count; $i++) {
        Write-Host "[$i]: $($sqlPools[$i].Name) (Status: $($sqlPools[$i].Status))"
    }
    $selectedIndex = -1
    $selectedValidIndex = 0
    while ($selectedValidIndex -ne 1) {
        $enteredValue = Read-Host ("Enter 0 to $($sqlPools.Count - 1)")
        if (-not ([string]::IsNullOrEmpty($enteredValue))) {
            if ([int]$enteredValue -in (0..($sqlPools.Count - 1))) {
                $selectedIndex = [int]$enteredValue
                $selectedValidIndex = 1
            } else {
                Write-Output "Please enter a valid number."
            }
        } else {
            Write-Output "Please enter a valid number."
        }
    }
    $sqlPoolName = $sqlPools[$selectedIndex].Name
    Write-Host "Selected Dedicated SQL Pool: $sqlPoolName"
}

# --- 기존 Data Lake Storage Gen2 계정 이름 입력 받기 ---
$dataLakeAccountName = Read-Host "Enter the name of your existing Data Lake Storage Gen2 account"
if (-not (Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $dataLakeAccountName -ErrorAction SilentlyContinue)) {
    Write-Error "Data Lake Storage Gen2 account '$dataLakeAccountName' not found in Resource Group '$resourceGroupName'. Please check the name and try again."
    exit
}

# --- SQL 관리자 자격 증명 입력 받기 ---
Write-Host ""
$sqlUser = Read-Host "Enter the SQL admin username for the Synapse SQL Pool '$sqlPoolName'"

Write-Host ""
Write-Host "Now, enter the password for the SQL Admin user '$sqlUser'."
$sqlPassword = Read-Host "Now, enter the password for the SQL Admin user '$sqlUser'."
$complexPassword = 1
while ($complexPassword -ne 1)
{
    # -AsSecureString 옵션을 사용하면 화면에 입력이 표시되지 않아 더 안전하지만,
    # 이후 bcp 명령어 등에 전달하려면 일반 텍스트로 변환해야 하는 번거로움이 있습니다.
    # 여기서는 원본 스크립트와 같이 일반 텍스트로 입력받되, 복잡성 검사를 수행합니다.
    $enteredPassword = Read-Host -Prompt "Enter the password for '$sqlUser'.
    `nThe password must meet complexity requirements:
    `n - Minimum 8 characters.
    `n - At least one upper case English letter [A-Z]
    `n - At least one lower case English letter [a-z]
    `n - At least one digit [0-9]
    `n - At least one special character (!,@,#,%,^,&,$)
    `n "

    if (($enteredPassword -cmatch '[a-z]') -and `
        ($enteredPassword -cmatch '[A-Z]') -and `
        ($enteredPassword -match '\d') -and `
        ($enteredPassword.length -ge 8) -and `
        ($enteredPassword -match '[!@#%^&$]')) # PowerShell 특수문자 ^, & 는 백틱(`)으로 이스케이프하거나 작은 따옴표 안에 넣어야 합니다.
    {
        $sqlPassword = $enteredPassword # 검증된 암호를 $sqlPassword 변수에 할당
        $complexPassword = 1
	    Write-Output "Password accepted."
    }
    else
    {
        # 사용자가 입력한 값을 직접 노출하지 않도록 메시지 수정
        Write-Output "The entered password does not meet the complexity requirements. Please try again."
    }
}

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

# --- 데이터 레이크 저장소에 대한 권한 부여 (사용자 입력된 정보 사용) ---
write-host "Granting permissions on the $dataLakeAccountName storage account..."
write-host "(you can ignore any warnings if permissions already exist!)"
$subscriptionId = (Get-AzContext).Subscription.Id
$userName = ""
try {
    $currentUser = az ad signed-in-user show --query userPrincipalName -o tsv
    if ($currentUser) {
        $userName = $currentUser
    } else {
        Write-Warning "Could not retrieve current user UPN via 'az ad signed-in-user show'. You may need to grant permissions manually or ensure Azure CLI is logged in."
    }
} catch {
    Write-Warning "Error retrieving current user UPN via 'az ad signed-in-user show': $($_.Exception.Message). You may need to grant permissions manually."
}

$synapseWorkspaceObj = Get-AzSynapseWorkspace -ResourceGroupName $resourceGroupName -Name $synapseWorkspaceName
$synapseMIPrincipalId = $synapseWorkspaceObj.Identity.PrincipalId

if (-not $synapseMIPrincipalId) {
    Write-Error "Failed to get Managed Identity Principal ID for Synapse Workspace '$synapseWorkspaceName'"
    exit
}

New-AzRoleAssignment -ObjectId $synapseMIPrincipalId -RoleDefinitionName "Storage Blob Data Contributor" -Scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$dataLakeAccountName" -ErrorAction SilentlyContinue;
if ($userName) {
    New-AzRoleAssignment -SignInName $userName -RoleDefinitionName "Storage Blob Data Contributor" -Scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$dataLakeAccountName" -ErrorAction SilentlyContinue;
}

# --- Dedicated SQL Pool 작업 준비 ---
$sqlPoolServerName = "$synapseWorkspaceName.sql.azuresynapse.net" # Dedicated SQL Pool Endpoint

Write-Host "The selected Dedicated SQL Pool '$sqlPoolName' on server '$sqlPoolServerName' will be used as the target database."
Write-Host "All tables and data will be created/loaded directly within this pool."

# setup.sql 실행 (테이블 생성 등)
$setupSqlPath = Join-Path $PSScriptRoot "setup.sql" # 스크립트 파일과 동일한 디렉터리에 있는 setup.sql 경로

if (-not (Test-Path $setupSqlPath)) {
    Write-Warning "$setupSqlPath file not found. Skipping table creation."
} else {
    write-host "Running setup.sql (from $setupSqlPath) in the Dedicated SQL Pool '$sqlPoolName'..."
    try {
        # -ErrorAction Stop을 추가하여 오류 발생 시 catch 블록으로 넘어가도록 함
        Invoke-Sqlcmd -ServerInstance $sqlPoolServerName -Username $sqlUser -Password $sqlPassword -Database $sqlPoolName -InputFile $setupSqlPath -QueryTimeout 0 -ErrorAction Stop
        Write-Host "setup.sql executed successfully in '$sqlPoolName'."
    }
    catch {
        Write-Error "Failed to run setup.sql in Dedicated SQL Pool '$sqlPoolName'."
        Write-Error "Error details: $($_.Exception.Message)"
        # 전체 오류 객체를 보고 싶다면:
        # Write-Error ($Error[0] | Format-List -Force | Out-String)
        # 스크립트 중단
        exit 1 # 0이 아닌 종료 코드로 실패를 알림
    }
}


# --- 데이터 로드 (선택된 SQL Pool 이름 사용) ---
write-host "Loading data into '$sqlPoolName'..."
Get-ChildItem "./data/*.txt" -File | Foreach-Object {
    write-host ""
    $file = $_.FullName
    Write-Host "Processing file: $file"
    $table = $_.Name.Replace(".txt","")
    Write-Host "Loading data into table 'dbo.$table' from '$file'..."
    # bcp 명령어 실행 시 $sqlPassword 변수 사용
    bcp dbo.$table in $file -S $sqlPoolServerName -U $sqlUser -P $sqlPassword -d $sqlPoolName -f $file.Replace("txt", "fmt") -q -k -E -b 5000
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "BCP command failed for table '$table' and file '$file'. Exit code: $LASTEXITCODE"
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
$fileContainer = "files"

if (-not (Get-AzStorageContainer -Name $fileContainer -Context $storageContext -ErrorAction SilentlyContinue)) {
    New-AzStorageContainer -Name $fileContainer -Context $storageContext
    Write-Host "Created container '$fileContainer' in storage account '$dataLakeAccountName'."
}

Get-ChildItem "./data/*.csv" -File | Foreach-Object {
    write-host ""
    $fileName = $_.Name
    Write-Host "Uploading $fileName"
    $blobPath = "data/$fileName"
    Set-AzStorageBlobContent -File $_.FullName -Container $fileContainer -Blob $blobPath -Context $storageContext -Force
    if ($LASTEXITCODE -ne 0 -and $Error.Count -gt 0) {
        Write-Warning "Failed to upload file '$fileName'."
    } else {
        Write-Host "File '$fileName' uploaded successfully to '$fileContainer/data/'."
    }
}

Write-Host "Script finished at $(Get-Date)"
