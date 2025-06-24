#Requires -Modules Az.Accounts, Az.Resources, Az.Synapse, SqlServer

Clear-Host
write-host "Starting script at $(Get-Date)"

# --- 모듈 설치 및 Azure 로그인 ---
Function Install-Module-If-Missing {
    param(
        [string]$ModuleName
    )
    if (Get-Module -ListAvailable -Name $ModuleName) {
        Write-Host "$ModuleName module is already available."
    } else {
        Write-Host "Installing $ModuleName module..."
        Install-Module -Name $ModuleName -Force -AllowClobber -Scope CurrentUser
    }
}

Install-Module-If-Missing -ModuleName Az.Accounts
Install-Module-If-Missing -ModuleName Az.Resources
Install-Module-If-Missing -ModuleName Az.Synapse
Install-Module-If-Missing -ModuleName SqlServer
# BCP를 사용하기 위해 SqlServer 모듈이 필요할 수 있으나, bcp는 보통 PATH에 있거나 별도 설치됩니다.
# SqlServer 모듈은 Invoke-Sqlcmd 등을 위해 설치하는 것이 좋습니다. 여기서는 bcp 직접 호출.

# Azure 계정 연결 확인 및 로그인
if (-not (Get-AzContext)) {
    Write-Host "Connecting to Azure..."
    Connect-AzAccount
} else {
    Write-Host "Already connected to Azure account: $((Get-AzContext).Account.Id)"
}

# --- Azure 구독 선택 ---
$subs = Get-AzSubscription | Select-Object Name, Id
if ($subs.Count -eq 0) {
    Write-Error "No Azure subscriptions found. Please check your Azure login."
    exit
} elseif ($subs.Count -gt 1) {
    Write-Host "You have multiple Azure subscriptions - please select the one you want to use:"
    for ($i = 0; $i -lt $subs.length; $i++) {
        Write-Host "[$($i)]: $($subs[$i].Name) (ID = $($subs[$i].Id))"
    }
    $selectedIndex = -1
    while ($selectedIndex -lt 0 -or $selectedIndex -ge $subs.Length) {
        try {
            $enteredValue = Read-Host "Enter the number for the subscription (0 to $($subs.Length - 1))"
            $selectedIndex = [int]$enteredValue
            if ($selectedIndex -lt 0 -or $selectedIndex -ge $subs.Length) {
                Write-Warning "Invalid selection. Please enter a number from the list."
            }
        }
        catch {
            Write-Warning "Invalid input. Please enter a number."
            $selectedIndex = -1
        }
    }
    $selectedSubId = $subs[$selectedIndex].Id
    Set-AzContext -SubscriptionId $selectedSubId
    Write-Host "Using subscription: $($subs[$selectedIndex].Name)"
} else {
    $selectedSubId = $subs[0].Id
    Set-AzContext -SubscriptionId $selectedSubId
    Write-Host "Using single available subscription: $($subs[0].Name)"
}

# --- 리소스 그룹명 입력 및 확인 ---
$resourceGroupName = ""
while (-not $resourceGroupName) {
    $resourceGroupName = Read-Host "Enter the name of the Azure Resource Group"
    if (-not $resourceGroupName) {
        Write-Warning "Resource Group name cannot be empty."
    } elseif (-not (Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue)) {
        Write-Warning "Resource Group '$resourceGroupName' not found. Please enter a valid name."
        $resourceGroupName = ""
    } else {
        Write-Host "Using Resource Group: $resourceGroupName"
    }
}

# --- Synapse 작업 영역 탐색 및 선택 ---
Write-Host "Looking for Synapse Workspaces in '$resourceGroupName'..."
$synapseWorkspaces = Get-AzSynapseWorkspace -ResourceGroupName $resourceGroupName
if ($synapseWorkspaces.Count -eq 0) {
    Write-Error "No Synapse Workspaces found in Resource Group '$resourceGroupName'."
    exit
}

$selectedWorkspace = $null
if ($synapseWorkspaces.Count -gt 1) {
    Write-Host "Multiple Synapse Workspaces found. Please select one:"
    for ($i = 0; $i -lt $synapseWorkspaces.length; $i++) {
        Write-Host "[$($i)]: $($synapseWorkspaces[$i].Name) (Location: $($synapseWorkspaces[$i].Location))"
    }
    $selectedIndex = -1
    while ($selectedIndex -lt 0 -or $selectedIndex -ge $synapseWorkspaces.Length) {
        try {
            $enteredValue = Read-Host "Enter the number for the Synapse Workspace (0 to $($synapseWorkspaces.Length - 1))"
            $selectedIndex = [int]$enteredValue
            if ($selectedIndex -lt 0 -or $selectedIndex -ge $synapseWorkspaces.Length) {
                Write-Warning "Invalid selection. Please enter a number from the list."
            }
        }
        catch {
            Write-Warning "Invalid input. Please enter a number."
            $selectedIndex = -1
        }
    }
    $selectedWorkspace = $synapseWorkspaces[$selectedIndex]
} else {
    $selectedWorkspace = $synapseWorkspaces[0]
    Write-Host "Automatically selected Synapse Workspace: $($selectedWorkspace.Name)"
}
$synapseWorkspaceName = $selectedWorkspace.Name
$synapseSqlEndpoint = $selectedWorkspace.ConnectivityEndpoints.Sql

# --- 전용 SQL 풀 탐색 및 선택 ---
Write-Host "Looking for dedicated SQL Pools in Synapse Workspace '$synapseWorkspaceName'..."
$sqlPools = Get-AzSynapseSqlPool -ResourceGroupName $resourceGroupName -WorkspaceName $synapseWorkspaceName
if ($sqlPools.Count -eq 0) {
    Write-Error "No dedicated SQL Pools found in Synapse Workspace '$synapseWorkspaceName'."
    exit
}

$selectedSqlPool = $null
if ($sqlPools.Count -gt 1) {
    Write-Host "Multiple dedicated SQL Pools found. Please select one:"
    for ($i = 0; $i -lt $sqlPools.length; $i++) {
        Write-Host "[$($i)]: $($sqlPools[$i].Name) (Status: $($sqlPools[$i].Status))"
    }
    $selectedIndex = -1
    while ($selectedIndex -lt 0 -or $selectedIndex -ge $sqlPools.Length) {
        try {
            $enteredValue = Read-Host "Enter the number for the SQL Pool (0 to $($sqlPools.Length - 1))"
            $selectedIndex = [int]$enteredValue
            if ($selectedIndex -lt 0 -or $selectedIndex -ge $sqlPools.Length) {
                Write-Warning "Invalid selection. Please enter a number from the list."
            }
        }
        catch {
            Write-Warning "Invalid input. Please enter a number."
            $selectedIndex = -1
        }
    }
    $selectedSqlPool = $sqlPools[$selectedIndex]
} else {
    $selectedSqlPool = $sqlPools[0]
    Write-Host "Automatically selected SQL Pool: $($selectedSqlPool.Name)"
}
$sqlPoolName = $selectedSqlPool.Name # 이 이름이 bcp의 -d 옵션으로 사용될 데이터베이스 이름

# SQL 풀 상태 확인 및 재개 (필요시)
if ($selectedSqlPool.Status -ne "Online") {
    Write-Warning "SQL Pool '$sqlPoolName' is not Online (Current status: $($selectedSqlPool.Status))."
    $resumePool = Read-Host "Do you want to attempt to resume it? (y/n)"
    if ($resumePool -eq 'y') {
        Write-Host "Resuming SQL Pool '$sqlPoolName'..."
        Resume-AzSynapseSqlPool -WorkspaceName $synapseWorkspaceName -Name $sqlPoolName
        Write-Host "Waiting for SQL Pool to be online..."
        $poolStatus = (Get-AzSynapseSqlPool -WorkspaceName $synapseWorkspaceName -Name $sqlPoolName).Status
        while($poolStatus -ne "Online"){
            Start-Sleep -Seconds 30
            $poolStatus = (Get-AzSynapseSqlPool -WorkspaceName $synapseWorkspaceName -Name $sqlPoolName).Status
            Write-Host "Current pool status: $poolStatus"
        }
        Write-Host "SQL Pool '$sqlPoolName' is now Online."
    } else {
        Write-Error "SQL Pool must be Online to proceed. Exiting."
        exit
    }
}

# --- Synapse SQL 사용자명 및 암호 입력 ---
$sqlUser = Read-Host "Enter the SQL admin username for '$synapseWorkspaceName'"
$sqlPassword = ""
$complexPassword = 0

while ($complexPassword -ne 1) {
    $SqlPassword = Read-Host -AsSecureString "Enter the password for SQL user '$sqlUser'.
    `The password must meet complexity requirements:
    ` - Minimum 8 characters. 
    ` - At least one upper case English letter [A-Z]
    ` - At least one lower case English letter [a-z]
    ` - At least one digit [0-9]
    ` - At least one special character (!,@,#,%,^,&,$)
    ` " | ConvertFrom-SecureString -AsPlainText

    if (($SqlPassword -cmatch '[a-z]') -and `
        ($SqlPassword -cmatch '[A-Z]') -and `
        ($SqlPassword -match '\d') -and `
        ($SqlPassword.length -ge 8) -and `
        ($SqlPassword -match '[!@#%^&$]')) { # 주의: $는 정규식에서 문자열 끝을 의미할 수 있어 이스케이프 필요시 \$. 여기서는 OR 조건이라 괜찮을 수 있음.
                                            # 좀 더 안전하게 하려면 $SqlPassword -match '[\!\@\#\%\^\&\$]'
        $complexPassword = 1
	    Write-Output "Password accepted. Make sure you remember this!"
    } else {
        Write-Warning "$SqlPassword does not meet the complexity requirements. Please try again."
    }
}

# --- 리소스 공급자 등록 (안전을 위해 유지) ---
Write-Host "Registering resource providers (if not already registered)...";
$provider_list = "Microsoft.Synapse", "Microsoft.Sql", "Microsoft.Storage" # Microsoft.Compute는 여기서는 직접 사용 안함
foreach ($provider in $provider_list){
    $registrationState = (Get-AzResourceProvider -ProviderNamespace $provider).RegistrationState
    if($registrationState -ne "Registered"){
        Write-Host "Registering $provider..."
        Register-AzResourceProvider -ProviderNamespace $provider
        # 등록 완료까지 시간이 걸릴 수 있으므로, 실제 운영 스크립트에서는 완료 대기 로직이 필요할 수 있습니다.
        Write-Host "$provider registration initiated. Status: $((Get-AzResourceProvider -ProviderNamespace $provider).RegistrationState)"
    } else {
        Write-Host "$provider is already registered."
    }
}

# --- 데이터베이스 스키마 생성 (setup.sql 실행) ---
# setup.sql 파일이 스크립트와 동일한 디렉토리에 있다고 가정
$setupSqlPath = Join-Path $PSScriptRoot "setup.sql" # 스크립트가 있는 디렉토리 기준
if (-not (Test-Path $setupSqlPath)) {
    Write-Error "Setup script 'setup.sql' not found at '$setupSqlPath'. Please create it. This script typically contains CREATE TABLE statements."
    # 예시: Write-Host "Example content for setup.sql: CREATE TABLE dbo.MyTable (ID INT, Name VARCHAR(100));"
    exit
}

# bcp와 sqlcmd 경로 확인 (필요시)
$bcpPath = Get-Command bcp -ErrorAction SilentlyContinue
$sqlcmdPath = Get-Command sqlcmd -ErrorAction SilentlyContinue

if (-not $bcpPath) {
    Write-Error "bcp.exe not found in PATH. Please install SQL Server Command Line Utilities."
    exit
}
if (-not $sqlcmdPath) {
    Write-Error "sqlcmd.exe not found in PATH. Please install SQL Server Command Line Utilities."
    exit
}

write-host "Creating/configuring database objects in '$sqlPoolName' using '$setupSqlPath'..."
try {
    # -d 옵션에는 전용 SQL 풀의 이름을 사용합니다. 이것이 작업 대상 데이터베이스입니다.
    # -I 옵션은 SET QUOTED_IDENTIFIER ON을 설정합니다.
    sqlcmd -S "$($synapseSqlEndpoint)" -U $sqlUser -P $sqlPassword -d $sqlPoolName -I -i "$setupSqlPath" -b # -b: 오류 시 종료
    Write-Host "Database schema setup complete."
} catch {
    Write-Error "Error executing setup.sql: $($_.Exception.Message)"
    exit
}


# --- 데이터 로딩 ---
# 데이터 파일들이 ./data/ 디렉토리에 있고, 각 .txt 파일에 해당하는 .fmt 파일이 있다고 가정
$dataFolderPath = Join-Path $PSScriptRoot "data" # 스크립트가 있는 디렉토리 기준 ./data/
if (-not (Test-Path $dataFolderPath -PathType Container)) {
    Write-Warning "Data folder '$dataFolderPath' not found. Skipping data loading."
} else {
    write-host "Loading data into '$sqlPoolName'..."
    Get-ChildItem -Path $dataFolderPath -Filter "*.txt" -File | ForEach-Object {
        $textFile = $_.FullName
        $tableName = $_.BaseName # 확장자 제외한 파일 이름 (예: "customers")
        $formatFile = Join-Path $_.DirectoryName ($tableName + ".fmt")

        Write-Host ""
        Write-Host "Processing data file: $textFile for table: dbo.$tableName"

        if (-not (Test-Path $formatFile)) {
            Write-Warning "Format file '$formatFile' not found for '$textFile'. Skipping this file."
            return # Foreach-Object의 현재 반복을 건너뜀 (continue와 유사)
        }

        Write-Host "Loading data using bcp into dbo.$tableName..."
        try {
            # bcp dbo.$table in $file -S "server.sql.azuresynapse.net" -U user -P pass -d database_name -f format_file.fmt -q -k -E -b 5000
            $bcpArgs = "dbo.$tableName", "in", "`"$textFile`"", "-S", "`"$($synapseSqlEndpoint)`"", "-U", $sqlUser, "-P", $sqlPassword, "-d", $sqlPoolName, "-f", "`"$formatFile`"", "-q", "-k", "-E", "-b", "5000", "-e", "`"$($textFile).err`""
            # & bcp $bcpArgs # 이 방식은 공백이 있는 경로/파일명에 문제 발생 가능
            Start-Process -FilePath "bcp" -ArgumentList $bcpArgs -Wait -NoNewWindow
            # & $bcpPath.Source $bcpArgs # 이렇게 하면 공백 문제 해결될 수도 있음
            # Invoke-Expression "bcp $($bcpArgs -join ' ')" # 또 다른 방법
            
            Write-Host "Data loading for $tableName completed."
            if (Test-Path "$($textFile).err") {
                $errorContent = Get-Content "$($textFile).err"
                if ($errorContent) {
                    Write-Warning "BCP encountered errors for $tableName. Check $($textFile).err for details:"
                    Get-Content "$($textFile).err" | Write-Warning
                } else {
                    Remove-Item "$($textFile).err" # 오류 없으면 에러 파일 삭제
                }
            }
        } catch {
            Write-Error "Error during bcp for table '$tableName' with file '$textFile': $($_.Exception.Message)"
            Write-Warning "Check $($textFile).err for bcp error details if it was created."
        }
    }
}

write-host "Script completed at $(Get-Date)"
