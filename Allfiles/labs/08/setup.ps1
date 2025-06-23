Clear-Host
Write-Host "Starting script at $(Get-Date)"

# 필요한 모듈 설치
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name Az.Synapse -Force

# 구독 선택
$subs = Get-AzSubscription | Select-Object
if($subs.Count -gt 1){
    Write-Host "You have multiple Azure subscriptions - please select the one you want to use:"
    for($i = 0; $i -lt $subs.Count; $i++) {
        Write-Host "[$($i)]: $($subs[$i].Name) (ID = $($subs[$i].Id))"
    }
    $selectedIndex = Read-Host "Enter 0 to $($subs.Count - 1)"
    $selectedSub = $subs[$selectedIndex].Id
    Select-AzSubscription -SubscriptionId $selectedSub
    az account set --subscription $selectedSub
}

# 사용자 입력
$resourceGroupName = Read-Host "Enter the existing Resource Group Name"
$synapseWorkspace = Read-Host "Enter the existing Synapse Workspace Name"
$dataLakeAccountName = Read-Host "Enter the existing Data Lake Storage Account Name"
$sqlDatabaseName = Read-Host "Enter the existing Dedicated SQL Pool Name"
$sqlUser = "SQLUser"

# 비밀번호 입력 (일반 문자열, 복잡성 검사 포함)
$complexPassword = 0
while ($complexPassword -ne 1) {
    $sqlPassword = Read-Host "Enter a password for '$sqlUser' (min 8 chars, 1 upper, 1 lower, 1 digit, 1 special)"

    if(($sqlPassword -cmatch '[a-z]') -and ($sqlPassword -cmatch '[A-Z]') -and ($sqlPassword -match '\d') -and ($sqlPassword.Length -ge 8) -and ($sqlPassword -match '[!@#%^\&\$]')) {
        $complexPassword = 1
        Write-Output "Password accepted. Make sure you remember this!"
    } else {
        Write-Output "Password does not meet complexity requirements. Please try again."
    }
}

# 권한 부여
Write-Host "Granting permissions on the $dataLakeAccountName storage account..."
$subscriptionId = (Get-AzContext).Subscription.Id
$userName = ((az ad signed-in-user show) | ConvertFrom-Json).UserPrincipalName
$spId = (Get-AzADServicePrincipal -DisplayName $synapseWorkspace).Id

New-AzRoleAssignment -ObjectId $spId -RoleDefinitionName "Storage Blob Data Owner" -Scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$dataLakeAccountName" -ErrorAction SilentlyContinue
New-AzRoleAssignment -SignInName $userName -RoleDefinitionName "Storage Blob Data Owner" -Scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$dataLakeAccountName" -ErrorAction SilentlyContinue

# Create database
write-host "Creating the $sqlDatabaseName database..."
sqlcmd -S "$synapseWorkspace.sql.azuresynapse.net" -U $sqlUser -P $sqlPassword -d $sqlDatabaseName -I -i setup.sql

# 데이터 로드
Write-Host "Loading data to $sqlDatabaseName ..."
Get-ChildItem "./data/*.txt" -File | ForEach-Object {
    $file = $_.FullName
    $table = $_.Name.Replace(".txt", "")
    Write-Host "Importing $file to table $table..."
    bcp dbo.$table in $file -S "$synapseWorkspace.sql.azuresynapse.net" -U $sqlUser -P $sqlPassword -d $sqlDatabaseName -f $file.Replace("txt", "fmt") -q -k -E -b 5000
}

# SQL Pool 일시 중지 (요청에 따라 주석 처리)
# Write-Host "Pausing the $sqlDatabaseName SQL Pool..."
# Suspend-AzSynapseSqlPool -WorkspaceName $synapseWorkspace -Name $sqlDatabaseName -AsJob

# 스크립트 업로드
$solutionScriptPath = "Solution.sql"
Write-Host "Uploading solution script to Synapse..."
Set-AzSynapseSqlScript -WorkspaceName $synapseWorkspace -DefinitionFile $solutionScriptPath -SqlPoolName $sqlDatabaseName -SqlDatabaseName $sqlDatabaseName

Write-Host "Script completed at $(Get-Date)"
