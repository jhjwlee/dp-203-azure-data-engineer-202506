#Requires -Modules Az.Accounts, Az.Resources, Az.Synapse, SqlServer

Clear-Host
write-host "Starting script at $(Get-Date)"

# --- 모듈 설치 함수 ---
Function Install-Module-If-Missing {
    param(
        [string]$ModuleName,
        [string]$MinimumVersion = $null
    )
    $moduleInstalled = Get-Module -ListAvailable -Name $ModuleName
    if ($moduleInstalled -and ($MinimumVersion -eq $null -or $moduleInstalled.Version -ge [version]$MinimumVersion) ) {
        Write-Host "$ModuleName module is already available (Version: $($moduleInstalled.Version))."
    } else {
        if ($moduleInstalled) {
            Write-Host "Found $ModuleName module version $($moduleInstalled.Version), but require at least $MinimumVersion. Updating..."
        } else {
            Write-Host "Installing $ModuleName module..."
        }
        try {
            Install-Module -Name $ModuleName -MinimumVersion $MinimumVersion -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
            Write-Host "$ModuleName module installed/updated successfully."
        }
        catch {
            Write-Error "Failed to install/update $ModuleName module: $($_.Exception.Message)"
            Write-Warning "Please ensure PowerShellGet is up-to-date (Install-Module PowerShellGet -Force) and try again, or install the module manually."
            exit
        }
    }
}

# --- 필수 모듈 설치 ---
Install-Module-If-Missing -ModuleName Az.Accounts
Install-Module-If-Missing -ModuleName Az.Resources
Install-Module-If-Missing -ModuleName Az.Synapse
Install-Module-If-Missing -ModuleName SqlServer

# --- Azure 계정 연결 확인 및 로그인 ---
if (-not (Get-AzContext)) {
    Write-Host "Connecting to Azure..."
    try {
        Connect-AzAccount -ErrorAction Stop
    } catch {
        Write-Error "Failed to connect to Azure: $($_.Exception.Message)"
        exit
    }
} else {
    Write-Host "Already connected to Azure account: $((Get-AzContext).Account.Id)"
}

# --- Azure 구독 선택 ---
$subs = Get-AzSubscription | Select-Object Name, Id
if ($subs.Count -eq 0) {
    Write-Error "No Azure subscriptions found. Please check your Azure login."
    exit
}

$selectedSubId = $null
if ($subs.Count -gt 1) {
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
            $selectedIndex = -1 # 루프를 계속하기 위해 초기화
        }
    }
    $selectedSubId = $subs[$selectedIndex].Id
    Write-Host "Selected subscription: $($subs[$selectedIndex].Name)"
} else {
    $selectedSubId = $subs[0].Id
    Write-Host "Using single available subscription: $($subs[0].Name)"
}
Set-AzContext -SubscriptionId $selectedSubId -ErrorAction Stop

# --- 리소스 그룹명 입력 및 확인 ---
$resourceGroupName = ""
while ([string]::IsNullOrWhiteSpace($resourceGroupName)) {
    $resourceGroupName = Read-Host "Enter the name of the Azure Resource Group"
    if ([string]::IsNullOrWhiteSpace($resourceGroupName)) {
        Write-Warning "Resource Group name cannot be empty."
    } elseif (-not (Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue)) {
        Write-Warning "Resource Group '$resourceGroupName' not found. Please enter a valid name."
        $resourceGroupName = "" # 다시 입력 받도록 초기화
    } else {
        Write-Host "Using Resource Group: $resourceGroupName"
    }
}

# --- Synapse 작업 영역 탐색 및 선택 ---
Write-Host "Looking for Synapse Workspaces in '$resourceGroupName'..."
$synapseWorkspaces = Get-AzSynapseWorkspace -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue
if (-not $synapseWorkspaces -or $synapseWorkspaces.Count -eq 0) {
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
    Write-Host "Selected Synapse Workspace: $($selectedWorkspace.Name)"
} else {
    $selectedWorkspace = $synapseWorkspaces[0]
    Write-Host "Automatically selected Synapse Workspace: $($selectedWorkspace.Name)"
}
$synapseWorkspaceName = $selectedWorkspace.Name
$synapseSqlEndpoint = $selectedWorkspace.ConnectivityEndpoints.Sql
Write-Host "Synapse SQL Endpoint set to: '$synapseSqlEndpoint'" # 엔드포인트 값 확인

if ([string]::IsNullOrWhiteSpace($synapseSqlEndpoint)) {
    Write-Error "Failed to retrieve Synapse SQL Endpoint for workspace '$synapseWorkspaceName'. Cannot proceed."
    exit
}

# --- 전용 SQL 풀 탐색 및 선택 ---
Write-Host "Looking for dedicated SQL Pools in Synapse Workspace '$synapseWorkspaceName'..."
$sqlPools = Get-AzSynapseSqlPool -ResourceGroupName $resourceGroupName -WorkspaceName $synapseWorkspaceName -ErrorAction SilentlyContinue
if (-not $sqlPools -or $sqlPools.Count -eq 0) {
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
    Write-Host "Selected SQL Pool: $($selectedSqlPool.Name)"
} else {
    $selectedSqlPool = $sqlPools[0]
    Write-Host "Automatically selected SQL Pool: $($selectedSqlPool.Name)"
}
$sqlPoolName = $selectedSqlPool.Name

# --- SQL 풀 상태 확인 및 재개 (필요시) ---
if ($selectedSqlPool.Status -ne "Online") {
    Write-Warning "SQL Pool '$sqlPoolName' is not Online (Current status: $($selectedSqlPool.Status))."
    $resumePoolConfirmation = Read-Host "Do you want to attempt to resume it? (y/n)"
    if ($resumePoolConfirmation -eq 'y') {
        Write-Host "Resuming SQL Pool '$sqlPoolName'..."
        try {
            Resume-AzSynapseSqlPool -WorkspaceName $synapseWorkspaceName -Name $sqlPoolName -ErrorAction Stop
            Write-Host "Waiting for SQL Pool '$sqlPoolName' to be online..."
            $timeoutSeconds = 600 # 10분 대기
            $startTime = Get-Date
            $poolStatus = (Get-AzSynapseSqlPool -WorkspaceName $synapseWorkspaceName -Name $sqlPoolName).Status
            while ($poolStatus -ne "Online" -and (Get-Date -UFormat %s) -lt ($startTime.AddSeconds($timeoutSeconds) | Get-Date -UFormat %s) ) {
                Write-Host "Current pool status: $poolStatus. Waiting..."
                Start-Sleep -Seconds 30
                $poolStatus = (Get-AzSynapseSqlPool -WorkspaceName $synapseWorkspaceName -Name $sqlPoolName).Status
            }
            if ($poolStatus -eq "Online") {
                Write-Host "SQL Pool '$sqlPoolName' is now Online."
            } else {
                Write-Error "SQL Pool '$sqlPoolName' did not come Online within the timeout period. Current status: $poolStatus. Exiting."
                exit
            }
        } catch {
            Write-Error "Failed to resume SQL Pool '$sqlPoolName': $($_.Exception.Message)"
            exit
        }
    } else {
        Write-Error "SQL Pool must be Online to proceed. Exiting."
        exit
    }
}

# --- Synapse SQL 사용자명 및 암호 입력 ---
$sqlUser = ""
while ([string]::IsNullOrWhiteSpace($sqlUser)) {
    $sqlUser = Read-Host "Enter the SQL admin username for '$synapseWorkspaceName'"
    if ([string]::IsNullOrWhiteSpace($sqlUser)) {
        Write-Warning "SQL username cannot be empty."
    }
}

$sqlPassword = ""
$complexPassword = 0
while ($complexPassword -ne 1) {
    $securePassword = Read-Host -AsSecureString "Enter the password for SQL user '$sqlUser'.
    `The password must meet complexity requirements:
    ` - Minimum 8 characters. 
    ` - At least one upper case English letter [A-Z]
    ` - At least one lower case English letter [a-z]
    ` - At least one digit [0-9]
    ` - At least one special character (!,@,#,%,^,&,$)"
    
    $sqlPassword = ConvertFrom-SecureString -SecureString $securePassword -AsPlainText

    if (($sqlPassword -cmatch '[a-z]') -and `
        ($sqlPassword -cmatch '[A-Z]') -and `
        ($sqlPassword -match '\d') -and `
        ($sqlPassword.length -ge 8) -and `
        ($sqlPassword -match '[\!\@\#\%\^\&\$]')) { # 정규식 특수문자 이스케이프 개선
        $complexPassword = 1
	    Write-Output "Password accepted. Make sure you remember this!"
    } else {
        Write-Warning "Password does not meet the complexity requirements. Please try again."
    }
}

# --- 리소스 공급자 등록 (안전을 위해 유지) ---
Write-Host "Checking/Registering resource providers..."
$provider_list = "Microsoft.Synapse", "Microsoft.Sql", "Microsoft.Storage"
foreach ($provider in $provider_list){
    $registrationState = (Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction SilentlyContinue).RegistrationState
    if($registrationState -ne "Registered"){
        Write-Host "Registering $provider..."
        try {
            Register-AzResourceProvider -ProviderNamespace $provider -ErrorAction Stop
            Write-Host "$provider registration initiated. Current status: $((Get-AzResourceProvider -ProviderNamespace $provider).RegistrationState)"
        } catch {
            # 수정된 부분: $_.Exception.Message를 더 안전하게 참조하고 $provider를 따옴표로 감쌈
            $errorMessage = $_.Exception.Message
            Write-Warning "Failed to register provider '$provider': $errorMessage"
        }
    } else {
        Write-Host "$provider is already registered."
    }
}

# --- 데이터베이스 스키마 생성 (setup.sql 실행) ---
$setupSqlPath = Join-Path $PSScriptRoot "setup.sql"
if (-not (Test-Path $setupSqlPath -PathType Leaf)) { # -PathType Leaf 로 파일인지 명확히 확인
    Write-Error "Setup script 'setup.sql' not found or is not a file at '$setupSqlPath'. Please create it. This script typically contains CREATE TABLE statements."
    exit
}

# bcp 경로 확인
$bcpPathInfo = Get-Command bcp -ErrorAction SilentlyContinue
if (-not $bcpPathInfo) {
    Write-Error "bcp.exe not found in PATH. Please install SQL Server Command Line Utilities."
    exit
}
$bcpExecutablePath = $bcpPathInfo.Source # bcp 실행 파일 경로

write-host "Creating/configuring database objects in '$sqlPoolName' using '$setupSqlPath'..."
try {
    Write-Host "Attempting to execute setup.sql via Invoke-Sqlcmd..."
    Write-Host "Server: $synapseSqlEndpoint, Database: $sqlPoolName, User: $sqlUser"
    Invoke-Sqlcmd -ServerInstance $synapseSqlEndpoint -Username $sqlUser -Password $sqlPassword -Database $sqlPoolName -InputFile $setupSqlPath -QueryTimeout 0 -ConnectionTimeout 60 -ErrorAction Stop
    Write-Host "Database schema setup complete using Invoke-Sqlcmd."
} catch {
    Write-Error "Error executing setup.sql with Invoke-Sqlcmd: $($_.Exception.ToString())"
    if ($_.Exception.InnerException) {
        Write-Warning "Inner Exception: $($_.Exception.InnerException.ToString())"
    }
    Write-Warning "Check Synapse SQL endpoint '$($synapseSqlEndpoint)', credentials, firewall rules on Synapse Workspace, and SQL Pool status ('$($selectedSqlPool.Status)')."
    exit
}

# --- 데이터 로딩 (bcp 사용) ---
$dataFolderPath = Join-Path $PSScriptRoot "data"
if (-not (Test-Path $dataFolderPath -PathType Container)) {
    Write-Warning "Data folder '$dataFolderPath' not found. Skipping data loading."
} else {
    write-host "Loading data into '$sqlPoolName' from '$dataFolderPath'..."
    Get-ChildItem -Path $dataFolderPath -Filter "*.txt" -File | ForEach-Object {
        $textFile = $_.FullName
        $tableName = $_.BaseName # 확장자 제외한 파일 이름
        $formatFile = Join-Path $_.DirectoryName ($tableName + ".fmt")

        Write-Host ""
        Write-Host "Processing data file: '$textFile' for table: 'dbo.$tableName'"

        if (-not (Test-Path $formatFile -PathType Leaf)) {
            Write-Warning "Format file '$formatFile' not found or is not a file for '$textFile'. Skipping this file."
            return # Foreach-Object의 현재 반복을 건너뜀 (continue와 유사)
        }

        Write-Host "Loading data using bcp into 'dbo.$tableName'..."
        
        # --- BCP 실행을 위한 디버깅 정보 출력 ---
        Write-Host "BCP Debug Info:"
        Write-Host "  BCP Executable: $bcpExecutablePath"
        Write-Host "  Table Name: dbo.$tableName"
        Write-Host "  Input File: $textFile"
        Write-Host "  Synapse SQL Endpoint: $synapseSqlEndpoint"
        Write-Host "  SQL User: $sqlUser"
        # 암호는 보안상 직접 출력하지 않습니다.
        Write-Host "  SQL Pool (Database): $sqlPoolName"
        Write-Host "  Format File: $formatFile"
        # --- 디버깅 정보 출력 끝 ---

        # bcp 실행 인자 구성 (각 인자를 별도의 문자열로 배열에 추가)
        $bcpArgumentList = @(
            "dbo.$tableName", 
            "in", 
            $textFile,
            "-S", $synapseSqlEndpoint,
            "-U", $sqlUser,
            "-P", $sqlPassword,
            "-d", $sqlPoolName,
            "-f", $formatFile,
            "-q",
            "-k",
            "-E",
            "-b", "5000",
            "-e", "$($textFile).err"
        )
        
        # 표시용 명령어 생성 (암호 마스킹)
        $bcpArgumentListForDisplay = $bcpArgumentList.Clone() # 배열 복제
        $passwordIndex = $bcpArgumentListForDisplay.IndexOf("-P") + 1
        if ($passwordIndex -gt 0 -and $passwordIndex -lt $bcpArgumentListForDisplay.Length) {
            $bcpArgumentListForDisplay[$passwordIndex] = "********" # 암호 마스킹
        }
        $fullBcpCommandForDisplay = "$bcpExecutablePath " + ($bcpArgumentListForDisplay -join ' ')
        Write-Host "Constructed BCP command (for display): $fullBcpCommandForDisplay"


        try {
            $process = Start-Process -FilePath $bcpExecutablePath -ArgumentList $bcpArgumentList -Wait -PassThru -NoNewWindow -ErrorAction Stop
            
            if ($process.ExitCode -ne 0) {
                $errorMessage = "BCP failed for table '$tableName' with file '$textFile'. Exit code: $($process.ExitCode)."
                if (Test-Path "$($textFile).err") {
                    $errorFileContent = Get-Content "$($textFile).err" -Raw -ErrorAction SilentlyContinue
                    if ($errorFileContent) {
                        $errorMessage += "`nBCP error file ('$($textFile).err') content:`n$errorFileContent"
                    }
                }
                throw $errorMessage
            }
            
            Write-Host "Data loading for '$tableName' completed successfully."
            if (Test-Path "$($textFile).err") {
                $errFileInfo = Get-Item "$($textFile).err"
                if ($errFileInfo.Length -eq 0) {
                    Remove-Item "$($textFile).err" -Force
                    Write-Host "Empty BCP error file '$($textFile).err' removed."
                } else {
                     Write-Warning "BCP reported issues for '$tableName'. Check error file '$($textFile).err' for details."
                }
            }
        } catch {
            Write-Error "Error during bcp for table '$tableName' with file '$textFile': $($_.Exception.Message)"
            if (Test-Path "$($textFile).err" -and ($_.Exception.Message -notmatch "BCP error file" -or $_.Exception.Message -notmatch "$($textFile).err") ) {
                Write-Warning "Content of BCP error file '$($textFile).err':"
                Get-Content "$($textFile).err" -Raw -ErrorAction SilentlyContinue | Write-Warning
            }
        }
    }
}

write-host "Script completed at $(Get-Date)"
