---
lab:
    title: '관계형 데이터 웨어하우스 탐색'
    ilt-use: '데모 제안'
---

# 관계형 데이터 웨어하우스 탐색

Azure Synapse Analytics는 데이터 레이크의 파일 기반 데이터 분석은 물론 대규모 관계형 데이터 웨어하우스 및 이를 로드하는 데 사용되는 데이터 전송 및 변환 파이프라인을 포함하여 엔터프라이즈 데이터 웨어하우징을 지원하는 확장 가능한 기능 세트를 기반으로 구축되었습니다. 이 실습에서는 Azure Synapse Analytics의 dedicated SQL pool을 사용하여 관계형 데이터 웨어하우스에 데이터를 저장하고 쿼리하는 방법을 탐색합니다.

이 실습을 완료하는 데 약 **45**분이 소요됩니다.

## 시작하기 전에

관리자 수준 액세스 권한이 있는 [Azure 구독](https://azure.microsoft.com/free)이 필요합니다.

## Azure Synapse Analytics 작업 영역 프로비저닝

Azure Synapse Analytics *작업 영역(workspace)* 은 데이터 및 데이터 처리 런타임을 관리하기 위한 중앙 지점을 제공합니다. Azure portal의 대화형 인터페이스를 사용하여 작업 영역을 프로비저닝하거나, 스크립트 또는 템플릿을 사용하여 작업 영역 및 그 안의 리소스를 배포할 수 있습니다. 대부분의 프로덕션 시나리오에서는 리소스 배포를 반복 가능한 개발 및 운영 (*DevOps*) 프로세스에 통합할 수 있도록 스크립트와 템플릿으로 프로비저닝을 자동화하는 것이 가장 좋습니다.

이 실습에서는 PowerShell 스크립트와 ARM 템플릿을 조합하여 Azure Synapse Analytics를 프로비저닝합니다.

1.  `https://portal.azure.com`에서 [Azure portal](https://portal.azure.com)에 로그인합니다.
2.  페이지 상단 검색창 오른쪽의 **[\>_]** 버튼을 사용하여 Azure portal에서 새 Cloud Shell을 만들고, ***PowerShell*** 환경을 선택하고 메시지가 표시되면 스토리지를 만듭니다. Cloud Shell은 다음 그림과 같이 Azure portal 하단 창에 명령줄 인터페이스를 제공합니다:

    ![Azure portal과 Cloud Shell 창](./images/cloud-shell.png)

    > **참고**: 이전에 *Bash* 환경을 사용하는 Cloud Shell을 만든 경우, Cloud Shell 창 왼쪽 상단의 드롭다운 메뉴를 사용하여 ***PowerShell***로 변경하십시오.

3.  창 상단의 구분선을 드래그하거나 창 오른쪽 상단의 **&#8212;**, **&#9723;**, **X** 아이콘을 사용하여 Cloud Shell 크기를 조정할 수 있습니다. Azure Cloud Shell 사용에 대한 자세한 내용은 [Azure Cloud Shell 설명서](https://docs.microsoft.com/azure/cloud-shell/overview)를 참조하십시오.

4.  PowerShell 창에 다음 명령을 입력하여 이 리포지토리를 복제합니다:

    ```
    rm -r dp203 -f
    git clone  https://github.com/MicrosoftLearning/Dp-203-azure-data-engineer dp203
    ```

5.  리포지토리가 복제된 후 다음 명령을 입력하여 이 실습용 폴더로 변경하고 포함된 **setup.ps1** 스크립트를 실행합니다:

    ```
    cd dp203/Allfiles/labs/08
    ./setup.ps1
    ```

6.  메시지가 표시되면 사용할 구독을 선택합니다 (여러 Azure 구독에 액세스할 수 있는 경우에만 발생합니다).
7.  메시지가 표시되면 Azure Synapse SQL pool에 설정할 적절한 암호를 입력합니다.

    > **참고**: 이 암호를 반드시 기억하십시오!

8.  스크립트가 완료될 때까지 기다리십시오. 일반적으로 약 15분 정도 걸리지만 경우에 따라 더 오래 걸릴 수 있습니다. 기다리는 동안 Azure Synapse Analytics 설명서의 [Azure Synapse Analytics의 전용 SQL 풀이란?](https://docs.microsoft.com/azure/synapse-analytics/sql-data-warehouse/sql-data-warehouse-overview-what-is) 문서를 검토하십시오.

## 데이터 웨어하우스 스키마 탐색

이 실습에서 데이터 웨어하우스는 Azure Synapse Analytics의 dedicated SQL pool에서 호스팅됩니다.

### Dedicated SQL pool 시작

1.  스크립트가 완료된 후 Azure portal에서 스크립트가 생성한 **dp203-*xxxxxxx*** 리소스 그룹으로 이동하여 Synapse 작업 영역을 선택합니다.
2.  Synapse 작업 영역의 **Overview** 페이지에 있는 **Open Synapse Studio** 카드에서 **Open**을 선택하여 새 브라우저 탭에서 Synapse Studio를 엽니다. 메시지가 표시되면 로그인합니다.
3.  Synapse Studio 왼쪽에서 **&rsaquo;&rsaquo;** 아이콘을 사용하여 메뉴를 확장합니다. 이렇게 하면 리소스를 관리하고 데이터 분석 작업을 수행하는 데 사용되는 Synapse Studio 내의 여러 페이지가 표시됩니다.
4.  **Manage** 페이지에서 **SQL pools** 탭이 선택되어 있는지 확인한 다음 **sql*xxxxxxx*** dedicated SQL pool을 선택하고 해당 **&#9655;** 아이콘을 사용하여 시작합니다. 메시지가 표시되면 재개할 것인지 확인합니다.
5.  SQL pool이 재개될 때까지 기다립니다. 몇 분 정도 걸릴 수 있습니다. **&#8635; Refresh** 버튼을 사용하여 주기적으로 상태를 확인하십시오. 준비가 되면 상태가 **Online**으로 표시됩니다.

### 데이터베이스의 테이블 보기

1.  Synapse Studio에서 **Data** 페이지를 선택하고 **Workspace** 탭이 선택되어 있고 **SQL database** 카테고리를 포함하는지 확인합니다.
2.  **SQL database**, **sql*xxxxxxx*** pool 및 해당 **Tables** 폴더를 확장하여 데이터베이스의 테이블을 확인합니다.

    관계형 데이터 웨어하우스는 일반적으로 *팩트(fact)* 테이블과 *차원(dimension)* 테이블로 구성된 스키마를 기반으로 합니다. 테이블은 팩트 테이블의 숫자 메트릭을 차원 테이블로 표현되는 엔터티의 속성별로 집계하는 분석 쿼리에 최적화되어 있습니다. 예를 들어, 인터넷 판매 수익을 제품, 고객, 날짜 등으로 집계할 수 있습니다.
    
3.  **dbo.FactInternetSales** 테이블과 해당 **Columns** 폴더를 확장하여 이 테이블의 열을 확인합니다. 많은 열이 차원 테이블의 행을 참조하는 *키(keys)*입니다. 다른 열은 분석을 위한 숫자 값(*측정값(measures)*)입니다.
    
    키는 팩트 테이블을 하나 이상의 차원 테이블과 관련시키는 데 사용되며, 종종 *스타(star)* 스키마에서 사용됩니다. 스타 스키마에서는 팩트 테이블이 각 차원 테이블과 직접 관련됩니다(팩트 테이블이 중앙에 있는 여러 개의 뾰족한 "별" 모양 형성).

4.  **dbo.DimPromotion** 테이블의 열을 보고, 테이블의 각 행을 고유하게 식별하는 고유한 **PromotionKey**가 있는지 확인합니다. 또한 **AlternateKey**도 있습니다.

    일반적으로 데이터 웨어하우스의 데이터는 하나 이상의 트랜잭션 원본에서 가져옵니다. *대체(alternate)* 키는 원본에서 이 엔터티 인스턴스의 비즈니스 식별자를 반영하지만, 데이터 웨어하우스 차원 테이블의 각 행을 고유하게 식별하기 위해 일반적으로 고유한 숫자 *대리(surrogate)* 키가 생성됩니다. 이 접근 방식의 장점 중 하나는 데이터 웨어하우스가 서로 다른 시점의 동일한 엔터티의 여러 인스턴스를 포함할 수 있다는 것입니다(예: 주문 시 고객 주소를 반영하는 동일한 고객에 대한 레코드).

5.  **dbo.DimProduct**의 열을 보고, **ProductSubcategoryKey** 열이 포함되어 있는지 확인합니다. 이 열은 **dbo.DimProductSubcategory** 테이블을 참조하며, 이 테이블은 다시 **ProductCategoryKey** 열을 포함하여 **dbo.DimProductCategory** 테이블을 참조합니다.

    경우에 따라 차원은 제품을 하위 범주 및 범주로 그룹화할 수 있는 것과 같이 서로 다른 수준의 세분화(granularity)를 허용하기 위해 여러 관련 테이블로 부분적으로 정규화됩니다. 이로 인해 단순한 스타 스키마가 *눈송이(snowflake)* 스키마로 확장되며, 중앙 팩트 테이블은 차원 테이블과 관련되고, 이는 다시 추가 차원 테이블과 관련됩니다.

6.  **dbo.DimDate** 테이블의 열을 보고, 요일, 월의 일, 월, 연도, 요일 이름, 월 이름 등과 같이 날짜의 다양한 시간적 속성을 반영하는 여러 열이 포함되어 있는지 확인합니다.

    데이터 웨어하우스의 시간 차원은 일반적으로 팩트 테이블의 측정값을 집계하려는 가장 작은 시간 단위(종종 차원의 *결(grain)*이라고 함) 각각에 대한 행을 포함하는 차원 테이블로 구현됩니다. 이 경우 측정값을 집계할 수 있는 가장 낮은 결은 개별 날짜이며, 테이블에는 데이터에서 참조되는 첫 번째 날짜부터 마지막 날짜까지 각 날짜에 대한 행이 포함됩니다. **DimDate** 테이블의 속성을 통해 분석가는 팩트 테이블의 모든 날짜 키를 기반으로 일관된 시간적 속성 세트를 사용하여 측정값을 집계할 수 있습니다(예: 주문 날짜를 기반으로 월별 주문 보기). **FactInternetSales** 테이블에는 **DimDate** 테이블과 관련된 세 가지 키인 **OrderDateKey**, **DueDateKey**, **ShipDateKey**가 포함되어 있습니다.

## 데이터 웨어하우스 테이블 쿼리

데이터 웨어하우스 스키마의 몇 가지 중요한 측면을 살펴보았으므로 이제 테이블을 쿼리하고 일부 데이터를 검색할 준비가 되었습니다.

### 팩트 및 차원 테이블 쿼리

관계형 데이터 웨어하우스의 숫자 값은 관련 차원 테이블이 있는 팩트 테이블에 저장되며, 이를 사용하여 여러 속성에 걸쳐 데이터를 집계할 수 있습니다. 이러한 설계는 관계형 데이터 웨어하우스의 대부분의 쿼리가 관련 테이블(JOIN 절 사용)에 걸쳐 데이터를 집계하고 그룹화(집계 함수 및 GROUP BY 절 사용)하는 것을 의미합니다.

1.  **Data** 페이지에서 **sql*xxxxxxx*** SQL pool을 선택하고 해당 **...** 메뉴에서 **New SQL script** > **Empty script**를 선택합니다.
2.  새 **SQL Script 1** 탭이 열리면 해당 **Properties** 창에서 스크립트 이름을 **Analyze Internet Sales**로 변경하고 **Result settings per query**를 모든 행을 반환하도록 변경합니다. 그런 다음 도구 모음의 **Publish** 버튼을 사용하여 스크립트를 저장하고 도구 모음 오른쪽 끝에 있는 **Properties** 버튼( **&#128463;.** 와 유사하게 보임)을 사용하여 **Properties** 창을 닫아 스크립트 창을 볼 수 있도록 합니다.
3.  빈 스크립트에 다음 코드를 추가합니다:

    ```sql
    SELECT  d.CalendarYear AS Year,
            SUM(i.SalesAmount) AS InternetSalesAmount
    FROM FactInternetSales AS i
    JOIN DimDate AS d ON i.OrderDateKey = d.DateKey
    GROUP BY d.CalendarYear
    ORDER BY Year;
    ```

4.  **&#9655; Run** 버튼을 사용하여 스크립트를 실행하고 결과를 검토합니다. 결과에는 각 연도의 인터넷 판매 총액이 표시되어야 합니다. 이 쿼리는 인터넷 판매에 대한 팩트 테이블을 주문 날짜를 기준으로 시간 차원 테이블에 조인하고, 팩트 테이블의 판매 금액 측정값을 시간 차원 테이블의 달력 월 속성별로 집계합니다.

5.  다음과 같이 쿼리를 수정하여 시간 차원에서 월 속성을 추가한 다음 수정된 쿼리를 실행합니다.

    ```sql
    SELECT  d.CalendarYear AS Year,
            d.MonthNumberOfYear AS Month,
            SUM(i.SalesAmount) AS InternetSalesAmount
    FROM FactInternetSales AS i
    JOIN DimDate AS d ON i.OrderDateKey = d.DateKey
    GROUP BY d.CalendarYear, d.MonthNumberOfYear
    ORDER BY Year, Month;
    ```

    시간 차원의 속성을 사용하면 팩트 테이블의 측정값을 여러 계층 수준(이 경우 연도 및 월)에서 집계할 수 있습니다. 이는 데이터 웨어하우스에서 일반적인 패턴입니다.

6.  다음과 같이 쿼리를 수정하여 월을 제거하고 집계에 두 번째 차원을 추가한 다음 실행하여 결과를 확인합니다(각 지역의 연간 인터넷 판매 총액 표시):

    ```sql
    SELECT  d.CalendarYear AS Year,
            g.EnglishCountryRegionName AS Region,
            SUM(i.SalesAmount) AS InternetSalesAmount
    FROM FactInternetSales AS i
    JOIN DimDate AS d ON i.OrderDateKey = d.DateKey
    JOIN DimCustomer AS c ON i.CustomerKey = c.CustomerKey
    JOIN DimGeography AS g ON c.GeographyKey = g.GeographyKey
    GROUP BY d.CalendarYear, g.EnglishCountryRegionName
    ORDER BY Year, Region;
    ```

    지리는 고객 차원을 통해 인터넷 판매 팩트 테이블과 관련된 *눈송이(snowflake)* 차원입니다. 따라서 지리별 인터넷 판매를 집계하려면 쿼리에 두 개의 조인이 필요합니다.

7.  쿼리를 수정하고 다시 실행하여 다른 눈송이 차원을 추가하고 제품 범주별 연간 지역 판매를 집계합니다:

    ```sql
    SELECT  d.CalendarYear AS Year,
            pc.EnglishProductCategoryName AS ProductCategory,
            g.EnglishCountryRegionName AS Region,
            SUM(i.SalesAmount) AS InternetSalesAmount
    FROM FactInternetSales AS i
    JOIN DimDate AS d ON i.OrderDateKey = d.DateKey
    JOIN DimCustomer AS c ON i.CustomerKey = c.CustomerKey
    JOIN DimGeography AS g ON c.GeographyKey = g.GeographyKey
    JOIN DimProduct AS p ON i.ProductKey = p.ProductKey
    JOIN DimProductSubcategory AS ps ON p.ProductSubcategoryKey = ps.ProductSubcategoryKey
    JOIN DimProductCategory AS pc ON ps.ProductCategoryKey = pc.ProductCategoryKey
    GROUP BY d.CalendarYear, pc.EnglishProductCategoryName, g.EnglishCountryRegionName
    ORDER BY Year, ProductCategory, Region;
    ```

    이번에는 제품 범주에 대한 눈송이 차원에 제품, 하위 범주 및 범주 간의 계층적 관계를 반영하기 위해 세 개의 조인이 필요합니다.

8.  스크립트를 게시하여 저장합니다.

### 순위 함수 사용

대량의 데이터를 분석할 때 또 다른 일반적인 요구 사항은 파티션별로 데이터를 그룹화하고 특정 메트릭을 기반으로 파티션의 각 엔터티의 *순위(rank)*를 결정하는 것입니다.

1.  기존 쿼리 아래에 다음 SQL을 추가하여 국가/지역 이름을 기반으로 하는 파티션에 대한 2022년 판매 값을 검색합니다:

    ```sql
    SELECT  g.EnglishCountryRegionName AS Region,
            ROW_NUMBER() OVER(PARTITION BY g.EnglishCountryRegionName
                              ORDER BY i.SalesAmount ASC) AS RowNumber,
            i.SalesOrderNumber AS OrderNo,
            i.SalesOrderLineNumber AS LineItem,
            i.SalesAmount AS SalesAmount,
            SUM(i.SalesAmount) OVER(PARTITION BY g.EnglishCountryRegionName) AS RegionTotal,
            AVG(i.SalesAmount) OVER(PARTITION BY g.EnglishCountryRegionName) AS RegionAverage
    FROM FactInternetSales AS i
    JOIN DimDate AS d ON i.OrderDateKey = d.DateKey
    JOIN DimCustomer AS c ON i.CustomerKey = c.CustomerKey
    JOIN DimGeography AS g ON c.GeographyKey = g.GeographyKey
    WHERE d.CalendarYear = 2022
    ORDER BY Region;
    ```

2.  새 쿼리 코드만 선택하고 **&#9655; Run** 버튼을 사용하여 실행합니다. 그런 다음 결과를 검토합니다. 결과는 다음 표와 유사해야 합니다:

    | Region | RowNumber | OrderNo | LineItem | SalesAmount | RegionTotal | RegionAverage |
    |--|--|--|--|--|--|--|
    |Australia|1|SO73943|2|2.2900|2172278.7900|375.8918|
    |Australia|2|SO74100|4|2.2900|2172278.7900|375.8918|
    |...|...|...|...|...|...|...|
    |Australia|5779|SO64284|1|2443.3500|2172278.7900|375.8918|
    |Canada|1|SO66332|2|2.2900|563177.1000|157.8411|
    |Canada|2|SO68234|2|2.2900|563177.1000|157.8411|
    |...|...|...|...|...|...|...|
    |Canada|3568|SO70911|1|2443.3500|563177.1000|157.8411|
    |France|1|SO68226|3|2.2900|816259.4300|315.4016|
    |France|2|SO63460|2|2.2900|816259.4300|315.4016|
    |...|...|...|...|...|...|...|
    |France|2588|SO69100|1|2443.3500|816259.4300|315.4016|
    |Germany|1|SO70829|3|2.2900|922368.2100|352.4525|
    |Germany|2|SO71651|2|2.2900|922368.2100|352.4525|
    |...|...|...|...|...|...|...|
    |Germany|2617|SO67908|1|2443.3500|922368.2100|352.4525|
    |United Kingdom|1|SO66124|3|2.2900|1051560.1000|341.7484|
    |United Kingdom|2|SO67823|3|2.2900|1051560.1000|341.7484|
    |...|...|...|...|...|...|...|
    |United Kingdom|3077|SO71568|1|2443.3500|1051560.1000|341.7484|
    |United States|1|SO74796|2|2.2900|2905011.1600|289.0270|
    |United States|2|SO65114|2|2.2900|2905011.1600|289.0270|
    |...|...|...|...|...|...|...|
    |United States|10051|SO66863|1|2443.3500|2905011.1600|289.0270|

    이러한 결과에 대한 다음 사실을 확인하십시오:

    *   각 판매 주문 라인 항목에 대한 행이 있습니다.
    *   행은 판매가 이루어진 지역을 기준으로 파티션으로 구성됩니다.
    *   각 지역 파티션 내의 행은 판매 금액 순서(가장 작은 것부터 가장 큰 것 순)로 번호가 매겨집니다.
    *   각 행에 대해 라인 항목 판매 금액과 지역 총 판매 금액 및 평균 판매 금액이 포함됩니다.

3.  기존 쿼리 아래에 다음 코드를 추가하여 GROUP BY 쿼리 내에서 창 함수를 적용하고 총 판매 금액을 기준으로 각 지역의 도시 순위를 매깁니다:

    ```sql
    SELECT  g.EnglishCountryRegionName AS Region,
            g.City,
            SUM(i.SalesAmount) AS CityTotal,
            SUM(SUM(i.SalesAmount)) OVER(PARTITION BY g.EnglishCountryRegionName) AS RegionTotal,
            RANK() OVER(PARTITION BY g.EnglishCountryRegionName
                        ORDER BY SUM(i.SalesAmount) DESC) AS RegionalRank
    FROM FactInternetSales AS i
    JOIN DimDate AS d ON i.OrderDateKey = d.DateKey
    JOIN DimCustomer AS c ON i.CustomerKey = c.CustomerKey
    JOIN DimGeography AS g ON c.GeographyKey = g.GeographyKey
    GROUP BY g.EnglishCountryRegionName, g.City
    ORDER BY Region;
    ```

4.  새 쿼리 코드만 선택하고 **&#9655; Run** 버튼을 사용하여 실행합니다. 그런 다음 결과를 검토하고 다음을 확인합니다:
    *   결과에는 지역별로 그룹화된 각 도시에 대한 행이 포함됩니다.
    *   각 도시에 대한 총 판매액(개별 판매액의 합계)이 계산됩니다.
    *   지역 판매 총액(지역 내 각 도시의 판매액 합계의 합계)은 지역 파티션을 기준으로 계산됩니다.
    *   지역 파티션 내 각 도시의 순위는 도시별 총 판매액을 내림차순으로 정렬하여 계산됩니다.

5.  업데이트된 스크립트를 게시하여 변경 사항을 저장합니다.

> **팁**: ROW_NUMBER 및 RANK는 Transact-SQL에서 사용할 수 있는 순위 함수의 예입니다. 자세한 내용은 Transact-SQL 언어 설명서의 [순위 함수](https://docs.microsoft.com/sql/t-sql/functions/ranking-functions-transact-sql) 참조를 확인하십시오.

### 대략적인 개수 검색

매우 많은 양의 데이터를 탐색할 때 쿼리를 실행하는 데 상당한 시간과 리소스가 소요될 수 있습니다. 종종 데이터 분석에는 절대적으로 정확한 값이 필요하지 않으며, 대략적인 값 비교로 충분할 수 있습니다.

1.  기존 쿼리 아래에 다음 코드를 추가하여 각 달력 연도의 판매 주문 수를 검색합니다:

    ```sql
    SELECT d.CalendarYear AS CalendarYear,
        COUNT(DISTINCT i.SalesOrderNumber) AS Orders
    FROM FactInternetSales AS i
    JOIN DimDate AS d ON i.OrderDateKey = d.DateKey
    GROUP BY d.CalendarYear
    ORDER BY CalendarYear;
    ```

2.  새 쿼리 코드만 선택하고 **&#9655; Run** 버튼을 사용하여 실행합니다. 그런 다음 반환된 출력을 검토합니다:
    *   쿼리 아래 **Results** 탭에서 각 연도의 주문 수를 확인합니다.
    *   **Messages** 탭에서 쿼리의 총 실행 시간을 확인합니다.
3.  다음과 같이 쿼리를 수정하여 각 연도의 대략적인 개수를 반환합니다. 그런 다음 쿼리를 다시 실행합니다.

    ```sql
    SELECT d.CalendarYear AS CalendarYear,
        APPROX_COUNT_DISTINCT(i.SalesOrderNumber) AS Orders
    FROM FactInternetSales AS i
    JOIN DimDate AS d ON i.OrderDateKey = d.DateKey
    GROUP BY d.CalendarYear
    ORDER BY CalendarYear;
    ```

4.  반환된 출력을 검토합니다:
    *   쿼리 아래 **Results** 탭에서 각 연도의 주문 수를 확인합니다. 이전 쿼리에서 검색한 실제 개수의 2% 이내여야 합니다.
    *   **Messages** 탭에서 쿼리의 총 실행 시간을 확인합니다. 이전 쿼리보다 짧아야 합니다.

5.  스크립트를 게시하여 변경 사항을 저장합니다.

> **팁**: 자세한 내용은 [APPROX_COUNT_DISTINCT](https://docs.microsoft.com/sql/t-sql/functions/approx-count-distinct-transact-sql) 함수 설명서를 참조하십시오.

## 도전 과제 - 리셀러 판매 분석

1.  **sql*xxxxxxx*** SQL pool에 대한 새 빈 스크립트를 만들고 **Analyze Reseller Sales**라는 이름으로 저장합니다.
2.  **FactResellerSales** 팩트 테이블 및 이와 관련된 차원 테이블을 기반으로 다음 정보를 찾기 위한 SQL 쿼리를 스크립트에 만듭니다:
    *   회계 연도 및 분기별 총 판매 품목 수량.
    *   회계 연도, 분기 및 판매를 수행한 직원과 관련된 판매 지역별 총 판매 품목 수량.
    *   제품 범주별 회계 연도, 분기 및 판매 지역별 총 판매 품목 수량.
    *   연간 총 판매 금액을 기준으로 한 회계 연도별 각 판매 지역의 순위.
    *   각 판매 지역의 연간 대략적인 판매 주문 수.

    > **팁**: Synapse Studio의 **Develop** 페이지에 있는 **Solution** 스크립트의 쿼리와 비교해 보십시오.

3.  여가 시간에 데이터 웨어하우스 스키마의 나머지 테이블을 탐색하기 위한 쿼리를 실험해 보십시오.
4.  완료되면 **Manage** 페이지에서 **sql*xxxxxxx*** dedicated SQL pool을 일시 중지합니다.

## Azure 리소스 삭제

Azure Synapse Analytics 탐색을 마쳤으면 불필요한 Azure 비용을 피하기 위해 생성한 리소스를 삭제해야 합니다.

1.  Synapse Studio 브라우저 탭을 닫고 Azure portal로 돌아갑니다.
2.  Azure portal의 **Home** 페이지에서 **Resource groups**를 선택합니다.
3.  Synapse Analytics 작업 영역에 대한 **dp203-*xxxxxxx*** 리소스 그룹(관리형 리소스 그룹이 아님)을 선택하고 여기에 Synapse 작업 영역, 스토리지 계정 및 작업 영역용 dedicated SQL pool이 포함되어 있는지 확인합니다.
4.  리소스 그룹의 **Overview** 페이지 상단에서 **Delete resource group**을 선택합니다.
5.  **dp203-*xxxxxxx*** 리소스 그룹 이름을 입력하여 삭제할 것인지 확인하고 **Delete**를 선택합니다.

    몇 분 후 Azure Synapse 작업 영역 리소스 그룹과 이와 연결된 관리형 작업 영역 리소스 그룹이 삭제됩니다.
