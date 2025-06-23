---
lab:
    title: '관계형 데이터 웨어하우스에 데이터 로드'
    ilt-use: '실습'
---

# 관계형 데이터 웨어하우스에 데이터 로드

이 실습에서는 dedicated SQL Pool에 데이터를 로드합니다.

이 실습을 완료하는 데 약 **30**분이 소요됩니다.

## 시작하기 전에

관리자 수준 액세스 권한이 있는 [Azure 구독](https://azure.microsoft.com/free)이 필요합니다.

## Azure Synapse Analytics 작업 영역 프로비저닝

데이터 레이크 스토리지 및 데이터 웨어하우스를 호스팅하는 dedicated SQL pool에 액세스할 수 있는 Azure Synapse Analytics 작업 영역이 필요합니다.

이 실습에서는 PowerShell 스크립트와 ARM 템플릿을 조합하여 Azure Synapse Analytics 작업 영역을 프로비저닝합니다.

1.  `https://portal.azure.com`에서 [Azure portal](https://portal.azure.com)에 로그인합니다.
2.  페이지 상단 검색창 오른쪽의 **[\>_]** 버튼을 사용하여 Azure portal에서 새 Cloud Shell을 만들고, ***PowerShell*** 환경을 선택하고 메시지가 표시되면 스토리지를 만듭니다. Cloud Shell은 다음 그림과 같이 Azure portal 하단 창에 명령줄 인터페이스를 제공합니다:

    ![Azure portal과 Cloud Shell 창](./images/cloud-shell.png)

    > **참고**: 이전에 *Bash* 환경을 사용하는 Cloud Shell을 만든 경우, Cloud Shell 창 왼쪽 상단의 드롭다운 메뉴를 사용하여 ***PowerShell***로 변경하십시오.

3.  Cloud Shell은 창 상단의 구분선을 드래그하거나 창 오른쪽 상단의 —, **&#9723;** 및 **X** 아이콘을 사용하여 최소화, 최대화 및 닫을 수 있습니다. Azure Cloud Shell 사용에 대한 자세한 내용은 [Azure Cloud Shell 설명서](https://docs.microsoft.com/azure/cloud-shell/overview)를 참조하십시오.

4.  PowerShell 창에 다음 명령을 입력하여 이 리포지토리를 복제합니다:

    ```powershell
    rm -r dp-203 -f
    git clone https://github.com/MicrosoftLearning/dp-203-azure-data-engineer dp-203
    ```

5.  리포지토리가 복제된 후 다음 명령을 입력하여 이 실습용 폴더로 변경하고 포함된 **setup.ps1** 스크립트를 실행합니다:

    ```powershell
    cd dp-203/Allfiles/labs/09
    ./setup.ps1
    ```

6.  메시지가 표시되면 사용할 구독을 선택합니다 (이 옵션은 여러 Azure 구독에 액세스할 수 있는 경우에만 발생합니다).
7.  메시지가 표시되면 Azure Synapse SQL pool에 설정할 적절한 암호를 입력합니다.

    > **참고**: 이 암호를 반드시 기억하십시오!

8.  스크립트가 완료될 때까지 기다리십시오. 일반적으로 약 10분 정도 걸리지만 경우에 따라 더 오래 걸릴 수 있습니다. 기다리는 동안 Azure Synapse Analytics 설명서의 [Azure Synapse Analytics의 전용 SQL 풀에 대한 데이터 로드 전략](https://learn.microsoft.com/azure/synapse-analytics/sql-data-warehouse/design-elt-data-loading) 문서를 검토하십시오.

## 데이터 로드 준비

1.  스크립트가 완료된 후 Azure portal에서 스크립트가 생성한 **dp203-*xxxxxxx*** 리소스 그룹으로 이동하여 Synapse 작업 영역을 선택합니다.
2.  Synapse 작업 영역의 **Overview page**에 있는 **Open Synapse Studio** 카드에서 **Open**을 선택하여 새 브라우저 탭에서 Synapse Studio를 엽니다. 메시지가 표시되면 로그인합니다.
3.  Synapse Studio 왼쪽에서 ›› 아이콘을 사용하여 메뉴를 확장합니다. 이렇게 하면 리소스를 관리하고 데이터 분석 작업을 수행하는 데 사용할 Synapse Studio 내의 여러 페이지가 표시됩니다.
4.  **Manage** 페이지의 **SQL pools** 탭에서 이 실습의 데이터 웨어하우스를 호스팅하는 **sql*xxxxxxx*** dedicated SQL pool 행을 선택하고 해당 **&#9655;** 아이콘을 사용하여 시작합니다. 메시지가 표시되면 재개할 것인지 확인합니다.

    풀을 재개하는 데 몇 분 정도 걸릴 수 있습니다. **&#8635; Refresh** 버튼을 사용하여 주기적으로 상태를 확인할 수 있습니다. 준비가 되면 상태가 **Online**으로 표시됩니다. 기다리는 동안 아래 단계에 따라 로드할 데이터 파일을 확인하십시오.

5.  **Data** 페이지에서 **Linked** 탭을 보고 작업 영역에 Azure Data Lake Storage Gen2 스토리지 계정에 대한 링크가 포함되어 있는지 확인합니다. 이 계정의 이름은 **synapsexxxxxxx (Primary - datalakexxxxxxx)**와 유사해야 합니다.
6.  스토리지 계정을 확장하고 **files (primary)**라는 파일 시스템 컨테이너가 포함되어 있는지 확인합니다.
7.  files 컨테이너를 선택하고 **data**라는 폴더가 포함되어 있는지 확인합니다. 이 폴더에는 데이터 웨어하우스에 로드할 데이터 파일이 들어 있습니다.
8.  **data** 폴더를 열고 고객 및 제품 데이터의 .csv 파일이 포함되어 있는지 확인합니다.
9.  파일 중 하나를 마우스 오른쪽 버튼으로 클릭하고 **Preview**를 선택하여 포함된 데이터를 확인합니다. 파일에 헤더 행이 포함되어 있으므로 열 헤더 표시 옵션을 선택할 수 있습니다.
10. **Manage** 페이지로 돌아가서 dedicated SQL pool이 온라인 상태인지 확인합니다.

## 데이터 웨어하우스 테이블 로드

데이터 웨어하우스에 데이터를 로드하는 몇 가지 SQL 기반 접근 방식을 살펴보겠습니다.

1.  **Data** 페이지에서 **workspace** 탭을 선택합니다.
2.  **SQL Database**를 확장하고 **sql*xxxxxxx*** 데이터베이스를 선택합니다. 그런 다음 해당 **...** 메뉴에서 **New SQL Script** > 
**Empty Script**를 선택합니다.

이제 다음 실습을 위해 인스턴스에 연결된 빈 SQL 페이지가 생겼습니다. 이 스크립트를 사용하여 데이터를 로드하는 데 사용할 수 있는 몇 가지 SQL 기술을 살펴볼 것입니다.

### COPY 문을 사용하여 데이터 레이크에서 데이터 로드

1.  SQL 스크립트 창에 다음 코드를 입력합니다.

    ```sql
    SELECT COUNT(1) 
    FROM dbo.StageProduct
    ```

2.  도구 모음에서 **&#9655; Run** 버튼을 사용하여 SQL 코드를 실행하고 현재 **StageProduct** 테이블에 **0**개의 행이 있는지 확인합니다.
3.  코드를 다음 COPY 문으로 바꿉니다( **datalake*xxxxxx***를 데이터 레이크 이름으로 변경).

    ```sql
    COPY INTO dbo.StageProduct
        (ProductID, ProductName, ProductCategory, Color, Size, ListPrice, Discontinued)
    FROM 'https://datalakexxxxxx.blob.core.windows.net/files/data/Product.csv'
    WITH
    (
        FILE_TYPE = 'CSV',
        MAXERRORS = 0,
        IDENTITY_INSERT = 'OFF',
        FIRSTROW = 2 --헤더 행 건너뛰기
    );


    SELECT COUNT(1) 
    FROM dbo.StageProduct
    ```

4.  스크립트를 실행하고 결과를 검토합니다. **StageProduct** 테이블에 11개의 행이 로드되어야 합니다.

    이제 동일한 기술을 사용하여 다른 테이블을 로드해 보겠습니다. 이번에는 발생할 수 있는 모든 오류를 기록합니다.

5.  스크립트 창의 SQL 코드를 다음 코드로 바꾸고, ```FROM``` 절과 ```ERRORFILE``` 절 모두에서 **datalake*xxxxxx***를 데이터 레이크 이름으로 변경합니다.

    ```sql
    COPY INTO dbo.StageCustomer
    (GeographyKey, CustomerAlternateKey, Title, FirstName, MiddleName, LastName, NameStyle, BirthDate, 
    MaritalStatus, Suffix, Gender, EmailAddress, YearlyIncome, TotalChildren, NumberChildrenAtHome, EnglishEducation, 
    SpanishEducation, FrenchEducation, EnglishOccupation, SpanishOccupation, FrenchOccupation, HouseOwnerFlag, 
    NumberCarsOwned, AddressLine1, AddressLine2, Phone, DateFirstPurchase, CommuteDistance)
    FROM 'https://datalakexxxxxx.dfs.core.windows.net/files/data/Customer.csv'
    WITH
    (
    FILE_TYPE = 'CSV'
    ,MAXERRORS = 5
    ,FIRSTROW = 2 -- 헤더 행 건너뛰기
    ,ERRORFILE = 'https://datalakexxxxxx.dfs.core.windows.net/files/'
    );
    ```

6.  스크립트를 실행하고 결과 메시지를 검토합니다. 원본 파일에 잘못된 데이터가 포함된 행이 있으므로 한 행이 거부됩니다. 위 코드는 최대 **5**개의 오류를 지정하므로 단일 오류로 인해 유효한 행이 로드되는 것을 막지는 못했을 것입니다. 다음 쿼리를 실행하여 로드된 행을 볼 수 있습니다.

    ```sql
    SELECT *
    FROM dbo.StageCustomer
    ```

7.  **files** 탭에서 데이터 레이크의 루트 폴더를 보고 **_rejectedrows**라는 새 폴더가 생성되었는지 확인합니다(이 폴더가 보이지 않으면 **More** 메뉴에서 **Refresh**를 선택하여 뷰를 새로 고침).
8.  **_rejectedrows** 폴더와 여기에 포함된 날짜 및 시간별 하위 폴더를 열고 ***QID123_1_2*.Error.Txt** 및 ***QID123_1_2*.Row.Txt**와 유사한 이름을 가진 파일이 생성되었는지 확인합니다. 각 파일을 마우스 오른쪽 버튼으로 클릭하고 **Preview**를 선택하여 오류 및 거부된 행에 대한 세부 정보를 볼 수 있습니다.

    스테이징 테이블을 사용하면 기존 차원 테이블에 추가하거나 업데이트하기 전에 데이터를 유효성 검사하거나 변환할 수 있습니다. COPY 문은 데이터 레이크의 파일에서 스테이징 테이블로 데이터를 쉽게 로드하는 데 사용할 수 있는 간단하지만 고성능 기술을 제공하며, 보았듯이 잘못된 행을 식별하고 리디렉션할 수 있습니다.

### CREATE TABLE AS (CTAS) 문 사용

1.  스크립트 창으로 돌아가서 포함된 코드를 다음 코드로 바꿉니다.

    ```sql
    CREATE TABLE dbo.DimProduct
    WITH
    (
        DISTRIBUTION = HASH(ProductAltKey),
        CLUSTERED COLUMNSTORE INDEX
    )
    AS
    SELECT ROW_NUMBER() OVER(ORDER BY ProductID) AS ProductKey,
        ProductID AS ProductAltKey,
        ProductName,
        ProductCategory,
        Color,
        Size,
        ListPrice,
        Discontinued
    FROM dbo.StageProduct;
    ```

2.  스크립트를 실행합니다. 이 스크립트는 **ProductAltKey**를 해시 배포 키로 사용하고 클러스터형 columnstore 인덱스가 있는 스테이징된 제품 데이터에서 **DimProduct**라는 새 테이블을 만듭니다.
3.  다음 쿼리를 사용하여 새 **DimProduct** 테이블의 내용을 확인합니다.

    ```sql
    SELECT ProductKey,
        ProductAltKey,
        ProductName,
        ProductCategory,
        Color,
        Size,
        ListPrice,
        Discontinued
    FROM dbo.DimProduct;
    ```

    CREATE TABLE AS SELECT (CTAS) 표현식에는 다음과 같은 다양한 용도가 있습니다.

    *   더 나은 쿼리 성능을 위해 다른 테이블과 정렬되도록 테이블의 해시 키를 재배포합니다.
    *   델타 분석을 수행한 후 기존 값을 기반으로 스테이징 테이블에 대리 키를 할당합니다.
    *   보고서용 집계 테이블을 빠르게 만듭니다.

### INSERT 및 UPDATE 문을 결합하여 Slowly Changing Dimension 테이블 로드

**DimCustomer** 테이블은 유형 1 및 유형 2 Slowly Changing Dimensions(SCD)를 지원합니다. 유형 1 변경은 기존 행에 대한 현재 위치 업데이트를 발생시키고, 유형 2 변경은 특정 차원 엔터티 인스턴스의 최신 버전을 나타내는 새 행을 발생시킵니다. 이 테이블을 로드하려면 INSERT 문(새 고객 로드)과 UPDATE 문(유형 1 또는 유형 2 변경 적용)의 조합이 필요합니다.

1.  쿼리 창에서 기존 SQL 코드를 다음 코드로 바꿉니다.

    ```sql
    INSERT INTO dbo.DimCustomer ([GeographyKey],[CustomerAlternateKey],[Title],[FirstName],[MiddleName],[LastName],[NameStyle],[BirthDate],[MaritalStatus],
    [Suffix],[Gender],[EmailAddress],[YearlyIncome],[TotalChildren],[NumberChildrenAtHome],[EnglishEducation],[SpanishEducation],[FrenchEducation],
    [EnglishOccupation],[SpanishOccupation],[FrenchOccupation],[HouseOwnerFlag],[NumberCarsOwned],[AddressLine1],[AddressLine2],[Phone],
    [DateFirstPurchase],[CommuteDistance])
    SELECT *
    FROM dbo.StageCustomer AS stg
    WHERE NOT EXISTS
        (SELECT * FROM dbo.DimCustomer AS dim
        WHERE dim.CustomerAlternateKey = stg.CustomerAlternateKey);

    -- Type 1 updates (이름, 이메일 또는 전화번호 현재 위치 변경)
    UPDATE dbo.DimCustomer
    SET LastName = stg.LastName,
        EmailAddress = stg.EmailAddress,
        Phone = stg.Phone
    FROM DimCustomer dim inner join StageCustomer stg
    ON dim.CustomerAlternateKey = stg.CustomerAlternateKey
    WHERE dim.LastName <> stg.LastName OR dim.EmailAddress <> stg.EmailAddress OR dim.Phone <> stg.Phone

    -- Type 2 updates (주소 변경 시 새 항목 트리거)
    INSERT INTO dbo.DimCustomer
    SELECT stg.GeographyKey,stg.CustomerAlternateKey,stg.Title,stg.FirstName,stg.MiddleName,stg.LastName,stg.NameStyle,stg.BirthDate,stg.MaritalStatus,
    stg.Suffix,stg.Gender,stg.EmailAddress,stg.YearlyIncome,stg.TotalChildren,stg.NumberChildrenAtHome,stg.EnglishEducation,stg.SpanishEducation,stg.FrenchEducation,
    stg.EnglishOccupation,stg.SpanishOccupation,stg.FrenchOccupation,stg.HouseOwnerFlag,stg.NumberCarsOwned,stg.AddressLine1,stg.AddressLine2,stg.Phone,
    stg.DateFirstPurchase,stg.CommuteDistance
    FROM dbo.StageCustomer AS stg
    JOIN dbo.DimCustomer AS dim
    ON stg.CustomerAlternateKey = dim.CustomerAlternateKey
    AND stg.AddressLine1 <> dim.AddressLine1;
    ```

2.  스크립트를 실행하고 출력을 검토합니다.

## 로드 후 최적화 수행

데이터 웨어하우스에 새 데이터를 로드한 후에는 테이블 인덱스를 다시 빌드하고 자주 쿼리되는 열에 대한 통계를 업데이트하는 것이 좋습니다.

1.  스크립트 창의 코드를 다음 코드로 바꿉니다.

    ```sql
    ALTER INDEX ALL ON dbo.DimProduct REBUILD;
    ```

2.  스크립트를 실행하여 **DimProduct** 테이블의 인덱스를 다시 빌드합니다.
3.  스크립트 창의 코드를 다음 코드로 바꿉니다.

    ```sql
    CREATE STATISTICS customergeo_stats
    ON dbo.DimCustomer (GeographyKey);
    ```

4.  스크립트를 실행하여 **DimCustomer** 테이블의 **GeographyKey** 열에 대한 통계를 만들거나 업데이트합니다.

## Azure 리소스 삭제

Azure Synapse Analytics 탐색을 마쳤으면 불필요한 Azure 비용을 피하기 위해 생성한 리소스를 삭제해야 합니다.

1.  Synapse Studio 브라우저 탭을 닫고 Azure portal로 돌아갑니다.
2.  Azure portal의 **Home** 페이지에서 **Resource groups**를 선택합니다.
3.  Synapse Analytics 작업 영역에 대한 **dp203-*xxxxxxx*** 리소스 그룹(관리형 리소스 그룹이 아님)을 선택하고 여기에 Synapse 작업 영역, 스토리지 계정 및 작업 영역용 Spark pool이 포함되어 있는지 확인합니다.
4.  리소스 그룹의 **Overview** 페이지 상단에서 **Delete resource group**을 선택합니다.
5.  **dp203-*xxxxxxx*** 리소스 그룹 이름을 입력하여 삭제할 것인지 확인하고 **Delete**를 선택합니다.

    몇 분 후 Azure Synapse 작업 영역 리소스 그룹과 이와 연결된 관리형 작업 영역 리소스 그룹이 삭제됩니다.
