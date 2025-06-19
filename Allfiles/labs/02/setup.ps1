Clear-Host
Write-Host "Starting upload script at $(Get-Date)"

# 사용자 입력 받기
$resourceGroupName = Read-Host "Enter the name of the Resource Group"
$storageAccountName = Read-Host "Enter the name of the Storage Account"

# 스토리지 계정 컨텍스트 가져오기
$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName
if (-not $storageAccount) {
    Write-Host "❌ Storage account not found. Please check the name and try again."
    exit
}
$storageContext = $storageAccount.Context

# CSV 업로드
Get-ChildItem "./data/*.csv" -File | ForEach-Object {
    Write-Host ""
    $file = $_.Name
    Write-Host "Uploading CSV: $file"
    $blobPath = "sales/csv/$file"
    Set-AzStorageBlobContent -File $_.FullName -Container "files" -Blob $blobPath -Context $storageContext
}

# Parquet 업로드
Get-ChildItem "./data/*.parquet" -File | ForEach-Object {
    Write-Host ""
    $originalFile = $_.Name
    Write-Host "Uploading Parquet: $originalFile"

    $year = $originalFile -replace "\\.snappy\\.parquet$", ""
    $newFileName = "orders.snappy.parquet"
    $blobPath = "sales/parquet/year=$year/$newFileName"

    Set-AzStorageBlobContent -File $_.FullName -Container "files" -Blob $blobPath -Context $storageContext
}

# JSON 업로드
Get-ChildItem "./data/*.json" -File | ForEach-Object {
    Write-Host ""
    $file = $_.Name
    Write-Host "Uploading JSON: $file"
    $blobPath = "sales/json/$file"
    Set-AzStorageBlobContent -File $_.FullName -Container "files" -Blob $blobPath -Context $storageContext
}

Write-Host "✅ Upload script completed at $(Get-Date)"
