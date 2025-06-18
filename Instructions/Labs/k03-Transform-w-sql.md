---
lab:
    title: 'Serverless SQL pool을 사용하여 데이터 변환'
    ilt-use: '실습'
---

# Serverless SQL pool을 사용하여 파일 변환

데이터 *분석가*는 종종 분석 및 보고를 위해 데이터를 쿼리하는 데 SQL을 사용합니다. 데이터 *엔지니어* 또한 SQL을 사용하여 데이터를 조작하고 변환할 수 있으며, 이는 종종 데이터 수집 파이프라인 또는 추출, 변환, 로드(ETL) 프로세스의 일부로 수행됩니다.

이 실습에서는 Azure Synapse Analytics의 serverless SQL pool을 사용하여 파일의 데이터를 변환합니다.

이 실습을 완료하는 데 약 **30**분이 소요됩니다.

## 시작하기 전에

관리자 수준 액세스 권한이 있는 [Azure 구독](https://azure.microsoft.com/free)이 필요합니다.

## Azure Synapse Analytics 작업 영역 프로비저닝

데이터 레이크 스토리지에 액세스할 수 있는 Azure Synapse Analytics 작업 영역이 필요합니다. 내장된 serverless SQL pool을 사용하여 데이터 레이크의 파일을 쿼리할 수 있습니다.

이 실습에서는 PowerShell 스크립트와 ARM 템플릿을 조합하여 Azure Synapse Analytics 작업 영역을 프로비저닝합니다.

1.  `https://portal.azure.com`에서 [Azure portal](https://portal.azure.com)에 로그인합니다.
2.  페이지 상단 검색창 오른쪽의 **[\>_]** 버튼을 사용하여 Azure portal에서 새 Cloud Shell을 만들고, ***PowerShell*** 환경을 선택하고 메시지가 표시되면 스토리지를 만듭니다. Cloud Shell은 다음 그림과 같이 Azure portal 하단 창에 명령줄 인터페이스를 제공합니다:

    ![Azure portal과 Cloud Shell 창](./images/cloud-shell.png)

    > **참고**: 이전에 *Bash* 환경을 사용하는 Cloud Shell을 만든 경우, Cloud Shell 창 왼쪽 상단의 드롭다운 메뉴를 사용하여 ***PowerShell***로 변경하십시오.

3.  창 상단의 구분선을 드래그하거나 창 오른쪽 상단의 **&#8212;**, **&#9723;**, **X** 아이콘을 사용하여 Cloud Shell 크기를 조정할 수 있습니다. Azure Cloud Shell 사용에 대한 자세한 내용은 [Azure Cloud Shell 설명서](https://docs.microsoft.com/azure/cloud-shell/overview)를 참조하십시오.

4.  PowerShell 창에 다음 명령을 입력하여 이 리포지토리를 복제합니다:

    ```
    rm -r dp-203 -f
    git clone https://github.com/MicrosoftLearning/dp-203-azure-data-engineer dp-203
    ```

5.  리포지토리가 복제된 후 다음 명령을 입력하여 이 실습용 폴더로 변경하고 포함된 **setup.ps1** 스크립트를 실행합니다:

    ```
    cd dp-203/Allfiles/labs/03
    ./setup.ps1
    ```

6.  메시지가 표시되면 사용할 구독을 선택합니다 (여러 Azure 구독에 액세스할 수 있는 경우에만 발생합니다).
7.  메시지가 표시되면 Azure Synapse SQL pool에 설정할 적절한 암호를 입력합니다.

    > **참고**: 이 암호를 반드시 기억하십시오!

8.  스크립트가 완료될 때까지 기다리십시오. 일반적으로 약 10분 정도 걸리지만 경우에 따라 더 오래 걸릴 수 있습니다. 기다리는 동안 Azure Synapse Analytics 설명서의 [Synapse SQL을 사용한 CETAS](https://docs.microsoft.com/azure/synapse-analytics/sql/develop-tables-cetas) 문서를 검토하십시오.

## 파일의 데이터 쿼리

스크립트는 Azure Synapse Analytics 작업 영역과 데이터 레이크를 호스팅할 Azure Storage 계정을 프로비저닝한 다음, 일부 데이터 파일을 데이터 레이크에 업로드합니다.

### 데이터 레이크의 파일 보기

1.  스크립트가 완료된 후 Azure portal에서 스크립트가 생성한 **dp203-*xxxxxxx*** 리소스 그룹으로 이동하여 Synapse 작업 영역을 선택합니다.
2.  Synapse 작업 영역의 **Overview** 페이지에 있는 **Open Synapse Studio** 카드에서 **Open**을 선택하여 새 브라우저 탭에서 Synapse Studio를 엽니다. 메시지가 표시되면 로그인합니다.
3.  Synapse Studio 왼쪽에서 **&rsaquo;&rsaquo;** 아이콘을 사용하여 메뉴를 확장합니다. 이렇게 하면 리소스를 관리하고 데이터 분석 작업을 수행하는 데 사용할 Synapse Studio 내의 여러 페이지가 표시됩니다.
4.  **Data** 페이지에서 **Linked** 탭을 보고 작업 영역에 Azure Data Lake Storage Gen2 스토리지 계정에 대한 링크가 포함되어 있는지 확인합니다. 이 계정의 이름은 **synapse*xxxxxxx* (Primary - datalake*xxxxxxx*)**와 유사해야 합니다.
5.  스토리지 계정을 확장하고 **files**라는 파일 시스템 컨테이너가 포함되어 있는지 확인합니다.
6.  **files** 컨테이너를 선택하고 **sales**라는 폴더가 포함되어 있는지 확인합니다. 이 폴더에는 쿼리할 데이터 파일이 들어 있습니다.
7.  **sales** 폴더와 그 안에 있는 **csv** 폴더를 열고 이 폴더에 3년 치 판매 데이터에 대한 .csv 파일이 포함되어 있는지 확인합니다.
8.  파일 중 하나를 마우스 오른쪽 버튼으로 클릭하고 **Preview**를 선택하여 포함된 데이터를 확인합니다. 파일에 헤더 행이 포함되어 있습니다.
9.  미리보기를 닫은 다음 **&#8593;** 버튼을 사용하여 **sales** 폴더로 다시 이동합니다.

### SQL을 사용하여 CSV 파일 쿼리

1.  **csv** 폴더를 선택한 다음 도구 모음의 **New SQL script** 목록에서 **Select TOP 100 rows**를 선택합니다.
2.  **File type** 목록에서 **Text format**을 선택한 다음 설정을 적용하여 폴더의 데이터를 쿼리하는 새 SQL 스크립트를 엽니다.
3.  생성된 **SQL Script 1**의 **Properties** 창에서 이름을 **Query Sales CSV files**로 변경하고 결과 설정을 **All rows**를 표시하도록 변경합니다. 그런 다음 도구 모음에서 **Publish**를 선택하여 스크립트를 저장하고 도구 모음 오른쪽 끝에 있는 **Properties** 버튼( **&#128463;<sub>*</sub>** 와 유사하게 보임)을 사용하여 **Properties** 창을 숨깁니다.
4.  생성된 SQL 코드를 검토합니다. 다음과 유사해야 합니다:

    ```SQL
    -- This is auto-generated code
    SELECT
        TOP 100 *
    FROM
        OPENROWSET(
            BULK 'https://datalakexxxxxxx.dfs.core.windows.net/files/sales/csv/**',
            FORMAT = 'CSV',
            PARSER_VERSION='2.0'
        ) AS [result]
    ```

    이 코드는 OPENROWSET을 사용하여 sales 폴더의 CSV 파일에서 데이터를 읽고 처음 100개 행의 데이터를 검색합니다.

5.  이 경우 데이터 파일의 첫 번째 행에 열 이름이 포함되어 있으므로, 다음과 같이 `OPENROWSET` 절에 `HEADER_ROW = TRUE` 매개변수를 추가하도록 쿼리를 수정합니다 (이전 매개변수 뒤에 쉼표를 추가하는 것을 잊지 마십시오):

    ```SQL
    SELECT
        TOP 100 *
    FROM
        OPENROWSET(
            BULK 'https://datalakexxxxxxx.dfs.core.windows.net/files/sales/csv/**',
            FORMAT = 'CSV',
            PARSER_VERSION='2.0',
            HEADER_ROW = TRUE
        ) AS [result]
    ```

6.  **Connect to** 목록에서 **Built-in**이 선택되어 있는지 확인합니다. 이는 작업 영역과 함께 생성된 내장 SQL Pool을 나타냅니다. 그런 다음 도구 모음에서 **&#9655; Run** 버튼을 사용하여 SQL 코드를 실행하고 결과를 검토합니다. 결과는 다음과 유사해야 합니다:

    | SalesOrderNumber | SalesOrderLineNumber | OrderDate | CustomerName | EmailAddress | Item | Quantity | UnitPrice | TaxAmount |
    | -- | -- | -- | -- | -- | -- | -- | -- | -- |
    | SO43701 | 1 | 2019-07-01 | Christy Zhu | christy12@adventure-works.com |Mountain-100 Silver, 44 | 1 | 3399.99 | 271.9992 |
    | ... | ... | ... | ... | ... | ... | ... | ... | ... |

7.  스크립트 변경 사항을 게시한 다음 스크립트 창을 닫습니다.

## CREATE EXTERNAL TABLE AS SELECT (CETAS) 문을 사용하여 데이터 변환

SQL을 사용하여 파일의 데이터를 변환하고 그 결과를 다른 파일에 유지하는 간단한 방법은 CREATE EXTERNAL TABLE AS SELECT (CETAS) 문을 사용하는 것입니다. 이 문은 쿼리 요청을 기반으로 테이블을 만들지만, 테이블의 데이터는 데이터 레이크의 파일로 저장됩니다. 변환된 데이터는 외부 테이블을 통해 쿼리하거나 파일 시스템에서 직접 액세스할 수 있습니다 (예: 변환된 데이터를 데이터 웨어하우스로 로드하는 다운스트림 프로세스에 포함).

### 외부 데이터 원본(external data source) 및 파일 형식(file format) 만들기

데이터베이스에 외부 데이터 원본을 정의하면 이를 사용하여 외부 테이블용 파일을 저장할 데이터 레이크 위치를 참조할 수 있습니다. 외부 파일 형식을 사용하면 해당 파일의 형식(예: Parquet 또는 CSV)을 정의할 수 있습니다. 이러한 개체를 사용하여 외부 테이블과 작업하려면 기본 **master** 데이터베이스가 아닌 다른 데이터베이스에서 만들어야 합니다.

1.  Synapse Studio의 **Develop** 페이지에 있는 **+** 메뉴에서 **SQL script**를 선택합니다.
2.  새 스크립트 창에서 다음 코드를 추가하여(*datalakexxxxxxx*를 데이터 레이크 스토리지 계정 이름으로 바꿈) 새 데이터베이스를 만들고 여기에 외부 데이터 원본을 추가합니다.

    ```sql
    -- Sales 데이터용 데이터베이스
    CREATE DATABASE Sales
      COLLATE Latin1_General_100_BIN2_UTF8;
    GO;
    
    Use Sales;
    GO;
    
    -- 외부 데이터는 데이터 레이크의 Files 컨테이너에 있습니다.
    CREATE EXTERNAL DATA SOURCE sales_data WITH (
        LOCATION = 'https://datalakexxxxxxx.dfs.core.windows.net/files/'
    );
    GO;
    
    -- 테이블 파일용 형식
    CREATE EXTERNAL FILE FORMAT ParquetFormat
        WITH (
                FORMAT_TYPE = PARQUET,
                DATA_COMPRESSION = 'org.apache.hadoop.io.compress.SnappyCodec'
            );
    GO;
    ```

3.  스크립트 속성을 수정하여 이름을 **Create Sales DB**로 변경하고 게시합니다.
4.  스크립트가 **Built-in** SQL pool과 **master** 데이터베이스에 연결되어 있는지 확인한 다음 실행합니다.
5.  **Data** 페이지로 다시 전환하고 Synapse Studio 오른쪽 상단의 **&#8635;** 버튼을 사용하여 페이지를 새로 고칩니다. 그런 다음 **Data** 창의 **Workspace** 탭을 보면 **SQL database** 목록이 표시됩니다. 이 목록을 확장하여 **Sales** 데이터베이스가 생성되었는지 확인합니다.
6.  **Sales** 데이터베이스, 해당 **External Resources** 폴더 및 그 아래의 **External data sources** 폴더를 확장하여 생성한 **sales_data** 외부 데이터 원본을 확인합니다.

### 외부 테이블(External table) 만들기

1.  Synapse Studio의 **Develop** 페이지에 있는 **+** 메뉴에서 **SQL script**를 선택합니다.
2.  새 스크립트 창에서 다음 코드를 추가하여 외부 데이터 원본을 사용하여 CSV 판매 파일에서 데이터를 검색하고 집계합니다. **BULK** 경로는 데이터 원본이 정의된 폴더 위치에 상대적이라는 점에 유의하십시오:

    ```sql
    USE Sales;
    GO;
    
    SELECT Item AS Product,
           SUM(Quantity) AS ItemsSold,
           ROUND(SUM(UnitPrice) - SUM(TaxAmount), 2) AS NetRevenue
    FROM
        OPENROWSET(
            BULK 'sales/csv/*.csv',
            DATA_SOURCE = 'sales_data',
            FORMAT = 'CSV',
            PARSER_VERSION = '2.0',
            HEADER_ROW = TRUE
        ) AS orders
    GROUP BY Item;
    ```

3.  스크립트를 실행합니다. 결과는 다음과 유사해야 합니다:

    | Product | ItemsSold | NetRevenue |
    | -- | -- | -- |
    | AWC Logo Cap | 1063 | 8791.86 |
    | ... | ... | ... |

4.  SQL 코드를 수정하여 쿼리 결과를 외부 테이블에 다음과 같이 저장합니다:

    ```sql
    CREATE EXTERNAL TABLE ProductSalesTotals
        WITH (
            LOCATION = 'sales/productsales/',
            DATA_SOURCE = sales_data,
            FILE_FORMAT = ParquetFormat
        )
    AS
    SELECT Item AS Product,
        SUM(Quantity) AS ItemsSold,
        ROUND(SUM(UnitPrice) - SUM(TaxAmount), 2) AS NetRevenue
    FROM
        OPENROWSET(
            BULK 'sales/csv/*.csv',
            DATA_SOURCE = 'sales_data',
            FORMAT = 'CSV',
            PARSER_VERSION = '2.0',
            HEADER_ROW = TRUE
        ) AS orders
    GROUP BY Item;
    ```

5.  스크립트를 실행합니다. 이번에는 출력이 없지만 코드는 쿼리 결과를 기반으로 외부 테이블을 만들었어야 합니다.
6.  스크립트 이름을 **Create ProductSalesTotals table**로 지정하고 게시합니다.
7.  **Data** 페이지의 **Workspace** 탭에서 **Sales** SQL 데이터베이스의 **External tables** 폴더 내용을 보고 **ProductSalesTotals**라는 새 테이블이 생성되었는지 확인합니다.
8.  **ProductSalesTotals** 테이블의 **...** 메뉴에서 **New SQL script** > **Select TOP 100 rows**를 선택합니다. 그런 다음 결과 스크립트를 실행하고 집계된 제품 판매 데이터를 반환하는지 확인합니다.
9.  데이터 레이크의 파일 시스템을 포함하는 **files** 탭에서 **sales** 폴더의 내용을 보고 (필요한 경우 뷰를 새로 고침) 새 **productsales** 폴더가 생성되었는지 확인합니다.
10. **productsales** 폴더에서 ABC123DE----.parquet와 유사한 이름을 가진 하나 이상의 파일이 생성되었는지 확인합니다. 이 파일에는 집계된 제품 판매 데이터가 포함되어 있습니다. 이를 증명하기 위해 파일 중 하나를 선택하고 **New SQL script** > **Select TOP 100 rows** 메뉴를 사용하여 직접 쿼리할 수 있습니다.

## 저장 프로시저(stored procedure)에 데이터 변환 캡슐화

데이터를 자주 변환해야 하는 경우 저장 프로시저를 사용하여 CETAS 문을 캡슐화할 수 있습니다.

1.  Synapse Studio의 **Develop** 페이지에 있는 **+** 메뉴에서 **SQL script**를 선택합니다.
2.  새 스크립트 창에서 다음 코드를 추가하여 **Sales** 데이터베이스에 연도별 판매를 집계하고 그 결과를 외부 테이블에 저장하는 저장 프로시저를 만듭니다:

    ```sql
    USE Sales;
    GO;
    CREATE PROCEDURE sp_GetYearlySales
    AS
    BEGIN
        -- 기존 테이블 삭제
        IF EXISTS (
                SELECT * FROM sys.external_tables
                WHERE name = 'YearlySalesTotals'
            )
            DROP EXTERNAL TABLE YearlySalesTotals
        -- 외부 테이블 생성
        CREATE EXTERNAL TABLE YearlySalesTotals
        WITH (
                LOCATION = 'sales/yearlysales/',
                DATA_SOURCE = sales_data,
                FILE_FORMAT = ParquetFormat
            )
        AS
        SELECT YEAR(OrderDate) AS CalendarYear,
                SUM(Quantity) AS ItemsSold,
                ROUND(SUM(UnitPrice) - SUM(TaxAmount), 2) AS NetRevenue
        FROM
            OPENROWSET(
                BULK 'sales/csv/*.csv',
                DATA_SOURCE = 'sales_data',
                FORMAT = 'CSV',
                PARSER_VERSION = '2.0',
                HEADER_ROW = TRUE
            ) AS orders
        GROUP BY YEAR(OrderDate)
    END
    ```

3.  스크립트를 실행하여 저장 프로시저를 만듭니다.
4.  방금 실행한 코드 아래에 다음 코드를 추가하여 저장 프로시저를 호출합니다:

    ```sql
    EXEC sp_GetYearlySales;
    ```

5.  방금 추가한 `EXEC sp_GetYearlySales;` 문만 선택하고 **&#9655; Run** 버튼을 사용하여 실행합니다.
6.  데이터 레이크의 파일 시스템을 포함하는 **files** 탭에서 **sales** 폴더의 내용을 보고 (필요한 경우 뷰를 새로 고침) 새 **yearlysales** 폴더가 생성되었는지 확인합니다.
7.  **yearlysales** 폴더에서 집계된 연간 판매 데이터가 포함된 parquet 파일이 생성되었는지 확인합니다.
8.  SQL 스크립트로 다시 전환하고 `EXEC sp_GetYearlySales;` 문을 다시 실행하면 오류가 발생하는 것을 확인합니다.

    스크립트가 외부 테이블을 삭제하더라도 데이터가 포함된 폴더는 삭제되지 않습니다. 예를 들어 예약된 데이터 변환 파이프라인의 일부로 저장 프로시저를 다시 실행하려면 이전 데이터를 삭제해야 합니다.

9.  **files** 탭으로 다시 전환하여 **sales** 폴더를 봅니다. 그런 다음 **yearlysales** 폴더를 선택하고 삭제합니다.
10. SQL 스크립트로 다시 전환하고 `EXEC sp_GetYearlySales;` 문을 다시 실행합니다. 이번에는 작업이 성공하고 새 데이터 파일이 생성됩니다.

## Azure 리소스 삭제

Azure Synapse Analytics 탐색을 마쳤으면 불필요한 Azure 비용을 피하기 위해 생성한 리소스를 삭제해야 합니다.

1.  Synapse Studio 브라우저 탭을 닫고 Azure portal로 돌아갑니다.
2.  Azure portal의 **Home** 페이지에서 **Resource groups**를 선택합니다.
3.  Synapse Analytics 작업 영역에 대한 **dp203-*xxxxxxx*** 리소스 그룹(관리형 리소스 그룹이 아님)을 선택하고 여기에 Synapse 작업 영역과 작업 영역용 스토리지 계정이 포함되어 있는지 확인합니다.
4.  리소스 그룹의 **Overview** 페이지 상단에서 **Delete resource group**을 선택합니다.
5.  **dp203-*xxxxxxx*** 리소스 그룹 이름을 입력하여 삭제할 것인지 확인하고 **Delete**를 선택합니다.

    몇 분 후 Azure Synapse 작업 영역 리소스 그룹과 이와 연결된 관리형 작업 영역 리소스 그룹이 삭제됩니다.
