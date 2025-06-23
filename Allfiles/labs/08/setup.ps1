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

# 데이터 로드
Write-Host "Loading data to $sqlDatabaseName ..."
Get-ChildItem "./data/*.txt" -File | ForEach-Object {
    $file = $_.FullName
    $table = $_.Name.Replace(".txt", "")
    Write-Host "Importing $file to table $table..."
    bcp dbo.$table in $file -S "$synapseWorkspace.sql.azuresynapse.net" -U $sqlUser -P $plainPassword -d $sqlDatabaseName -f $file.Replace("txt", "fmt") -q -k -E -b 5000
}

# SQL Pool 일시 중지
Write-Host "Pausing the $sqlDatabaseName SQL Pool..."
Suspend-AzSynapseSqlPool -WorkspaceName $synapseWorkspace -Name $sqlDatabaseName -AsJob

# 스크립트 업로드
$solutionScriptPath = "Solution.sql"
Write-Host "Uploading solution script to Synapse..."
Set-AzSynapseSqlScript -WorkspaceName $synapseWorkspace -DefinitionFile $solutionScriptPath -SqlPoolName $sqlDatabaseName -SqlDatabaseName $sqlDatabaseName

Write-Host "Script completed at $(Get-Date)"
