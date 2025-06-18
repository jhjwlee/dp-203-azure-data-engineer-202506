---

lab:
    title: 'Azure Synapse Analytics 탐색'
    ilt-use: '실습'
---

# Azure Synapse Analytics 탐색

Azure Synapse Analytics는 엔드-투-엔드 데이터 분석을 위한 단일 통합 데이터 분석 플랫폼을 제공합니다. 이 실습에서는 데이터를 수집하고 탐색하는 다양한 방법을 살펴봅니다. 이 실습은 Azure Synapse Analytics의 다양한 핵심 기능에 대한 개략적인 개요로 설계되었습니다. 특정 기능을 더 자세히 탐색하기 위한 다른 실습들이 준비되어 있습니다.

이 실습을 완료하는 데 약 **60**분이 소요됩니다.

## 시작하기 전에

관리자 수준 액세스 권한이 있는 [Azure 구독](https://azure.microsoft.com/free)이 필요합니다.

## Azure Synapse Analytics 작업 영역 프로비저닝

Azure Synapse Analytics *작업 영역(workspace)* 은 데이터 및 데이터 처리 런타임을 관리하기 위한 중앙 지점을 제공합니다. Azure portal의 대화형 인터페이스를 사용하여 작업 영역을 프로비저닝하거나, 스크립트 또는 템플릿을 사용하여 작업 영역 및 그 안의 리소스를 배포할 수 있습니다. 대부분의 프로덕션 시나리오에서는 리소스 배포를 반복 가능한 개발 및 운영 (*DevOps*) 프로세스에 통합할 수 있도록 스크립트와 템플릿으로 프로비저닝을 자동화하는 것이 가장 좋습니다.

이 실습에서는 PowerShell 스크립트와 ARM 템플릿을 조합하여 Azure Synapse Analytics를 프로비저닝합니다.

1.  웹 브라우저에서 `https://portal.azure.com`의 [Azure portal](https://portal.azure.com)에 로그인합니다.
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
    cd dp-203/Allfiles/labs/01
    ./setup.ps1
    ```

6.  메시지가 표시되면 사용할 구독을 선택합니다 (여러 Azure 구독에 액세스할 수 있는 경우에만 발생합니다).
7.  메시지가 표시되면 Azure Synapse SQL pool에 설정할 적절한 암호를 입력합니다.

    > **참고**: 이 암호를 반드시 기억하십시오! 또한 암호는 로그인 이름의 전체 또는 일부를 포함할 수 없습니다.

8.  스크립트가 완료될 때까지 기다리십시오. 일반적으로 약 20분 정도 걸리지만 경우에 따라 더 오래 걸릴 수 있습니다. 기다리는 동안 Azure Synapse Analytics 설명서의 [Azure Synapse Analytics란?](https://docs.microsoft.com/azure/synapse-analytics/overview-what-is) 문서를 검토하십시오.

## Synapse Studio 탐색

*Synapse Studio*는 Azure Synapse Analytics 작업 영역의 리소스를 관리하고 작업할 수 있는 웹 기반 포털입니다.

1.  설정 스크립트 실행이 완료되면 Azure portal에서 스크립트가 생성한 **dp203-*xxxxxxx*** 리소스 그룹으로 이동하여 이 리소스 그룹에 Synapse 작업 영역, 데이터 레이크용 Storage account, Apache Spark pool 및 Dedicated SQL pool이 포함되어 있는지 확인합니다.
2.  Synapse 작업 영역을 선택하고 **Overview** 페이지의 **Open Synapse Studio** 카드에서 **Open**을 선택하여 새 브라우저 탭에서 Synapse Studio를 엽니다. Synapse Studio는 Synapse Analytics 작업 영역에서 작업하는 데 사용할 수 있는 웹 기반 인터페이스입니다.
3.  Synapse Studio 왼쪽에서 **&rsaquo;&rsaquo;** 아이콘을 사용하여 메뉴를 확장합니다. 이렇게 하면 리소스를 관리하고 데이터 분석 작업을 수행하는 데 사용할 Synapse Studio 내의 여러 페이지가 다음과 같이 표시됩니다:

    ![Synapse Studio 확장 메뉴를 보여주는 이미지로, 리소스를 관리하고 데이터 분석 작업을 수행합니다](./images/synapse-studio.png)

4.  **Data** 페이지를 보고 데이터 원본을 포함하는 두 개의 탭이 있는지 확인합니다:
    *   작업 영역에 정의된 데이터베이스(dedicated SQL database 및 Data Explorer database 포함)를 포함하는 **Workspace** 탭.
    *   Azure Data Lake storage를 포함하여 작업 영역에 연결된 데이터 원본을 포함하는 **Linked** 탭.

5.  현재 비어 있는 **Develop** 페이지를 봅니다. 여기에서 데이터 처리 솔루션을 개발하는 데 사용되는 스크립트 및 기타 자산을 정의할 수 있습니다.
6.  마찬가지로 비어 있는 **Integrate** 페이지를 봅니다. 이 페이지를 사용하여 데이터 원본 간에 데이터를 전송하고 변환하는 파이프라인과 같은 데이터 수집 및 통합 자산을 관리합니다.
7.  **Monitor** 페이지를 봅니다. 여기에서 실행 중인 데이터 처리 작업을 관찰하고 기록을 볼 수 있습니다.
8.  **Manage** 페이지를 봅니다. 여기에서 Azure Synapse 작업 영역에서 사용되는 pool, 런타임 및 기타 자산을 관리합니다. **Analytics pools** 섹션의 각 탭을 보고 작업 영역에 다음 pool이 포함되어 있는지 확인합니다:
    *   **SQL pools**:
        *   **Built-in**: SQL 명령을 사용하여 데이터 레이크의 데이터를 탐색하거나 처리하기 위해 주문형으로 사용할 수 있는 *serverless* SQL pool입니다.
        *   **sql*xxxxxxx***: 관계형 데이터 웨어하우스 데이터베이스를 호스팅하는 *dedicated* SQL pool입니다.
    *   **Apache Spark pools**:
        *   **spark*xxxxxxx***: Scala 또는 Python과 같은 프로그래밍 언어를 사용하여 데이터 레이크의 데이터를 탐색하거나 처리하기 위해 주문형으로 사용할 수 있습니다.

## 파이프라인으로 데이터 수집

Azure Synapse Analytics로 수행할 수 있는 주요 작업 중 하나는 광범위한 원본에서 작업 영역으로 데이터를 전송(필요한 경우 변환)하여 분석하는 *파이프라인*을 정의하는 것입니다.

### Copy Data 작업을 사용하여 파이프라인 만들기

1.  Synapse Studio의 **Home** 페이지에서 **Ingest**를 선택하여 **Copy Data** 도구를 엽니다.
2.  Copy Data 도구의 **Properties** 단계에서 **Built-in copy task**와 **Run once now**가 선택되어 있는지 확인하고 **Next >**를 클릭합니다.
3.  **Source** 단계의 **Dataset** 하위 단계에서 다음 설정을 선택합니다:
    *   **Source type**: All
    *   **Connection**: *새 연결을 만들고, 나타나는 **Linked service** 창의 **Generic protocol** 탭에서 **HTTP**를 선택합니다. 그런 다음 계속해서 다음 설정을 사용하여 데이터 파일에 대한 연결을 만듭니다:*
        *   **Name**: Products
        *   **Description**: Product list via HTTP
        *   **Connect via integration runtime**: AutoResolveIntegrationRuntime
        *   **Base URL**: `https://raw.githubusercontent.com/MicrosoftLearning/dp-203-azure-data-engineer/master/Allfiles/labs/01/adventureworks/products.csv`
        *   **Server Certificate Validation**: Enable
        *   **Authentication type**: Anonymous
4.  연결을 만든 후, **Source data store** 페이지에서 다음 설정이 선택되었는지 확인하고 **Next >**를 선택합니다:
    *   **Relative URL**: *비워 둡니다*
    *   **Request method**: GET
    *   **Additional headers**: *비워 둡니다*
    *   **Binary copy**: <u>선택 해제</u>
    *   **Request timeout**: *비워 둡니다*
    *   **Max concurrent connections**: *비워 둡니다*
5.  **Source** 단계의 **Configuration** 하위 단계에서 **Preview data**를 선택하여 파이프라인이 수집할 제품 데이터 미리보기를 확인한 다음 미리보기를 닫습니다.
6.  데이터를 미리 본 후, **File format settings** 페이지에서 다음 설정이 선택되었는지 확인하고 **Next >**를 선택합니다:
    *   **File format**: DelimitedText
    *   **Column delimiter**: Comma (,)
    *   **Row delimiter**: Line feed (\n)
    *   **First row as header**: Selected
    *   **Compression type**: None
7.  **Destination** 단계의 **Dataset** 하위 단계에서 다음 설정을 선택합니다:
    *   **Destination type**: Azure Data Lake Storage Gen2
    *   **Connection**: *데이터 레이크 저장소에 대한 기존 연결을 선택합니다 (작업 영역을 만들 때 자동으로 생성되었습니다).*
8.  연결을 선택한 후, **Destination/Dataset** 단계에서 다음 설정이 선택되었는지 확인하고 **Next >**를 선택합니다:
    *   **Folder path**: files/product_data
    *   **File name**: products.csv
    *   **Copy behavior**: None
    *   **Max concurrent connections**: *비워 둡니다*
    *   **Block size (MB)**: *비워 둡니다*
9.  **Destination** 단계의 **Configuration** 하위 단계에 있는 **File format settings** 페이지에서 다음 속성이 선택되었는지 확인합니다. 그런 다음 **Next >**를 선택합니다:
    *   **File format**: DelimitedText
    *   **Column delimiter**: Comma (,)
    *   **Row delimiter**: Line feed (\n)
    *   **Add header to file**: Selected
    *   **Compression type**: None
    *   **Max rows per file**: *비워 둡니다*
    *   **File name prefix**: *비워 둡니다*
10. **Settings** 단계에서 다음 설정을 입력한 후 **Next >**를 클릭합니다:
    *   **Task name**: Copy products
    *   **Task description**: Copy products data
    *   **Fault tolerance**: *비워 둡니다*
    *   **Enable logging**: <u>선택 해제</u>
    *   **Enable staging**: <u>선택 해제</u>
11. **Review and finish** 단계의 **Review** 하위 단계에서 요약을 읽고 **Next >**를 클릭합니다.
12. **Deployment** 단계에서 파이프라인이 배포될 때까지 기다린 다음 **Finish**를 클릭합니다.
13. Synapse Studio에서 **Monitor** 페이지를 선택하고 **Pipeline runs** 탭에서 **Copy products** 파이프라인이 **Succeeded** 상태로 완료될 때까지 기다립니다 (Pipeline runs 페이지의 **&#8635; Refresh** 버튼을 사용하여 상태를 새로 고칠 수 있습니다).
14. **Integrate** 페이지를 보고 이제 **Copy products**라는 이름의 파이프라인이 포함되어 있는지 확인합니다.

### 수집된 데이터 보기

1.  **Data** 페이지에서 **Linked** 탭을 선택하고 **synapse*xxxxxxx* (Primary) datalake** 컨테이너 계층 구조를 확장하여 Synapse 작업 영역의 **files** 파일 스토리지를 확인합니다. 그런 다음 파일 스토리지를 선택하여 다음 그림과 같이 **products.csv**라는 파일을 포함하는 **product_data**라는 폴더가 이 위치에 복사되었는지 확인합니다:

    ![Synapse Studio에서 Synapse 작업 영역의 파일 스토리지를 보여주는 확장된 Azure Data Lake Storage 계층 구조 이미지](./images/product_files.png)

2.  **products.csv** 데이터 파일을 마우스 오른쪽 버튼으로 클릭하고 **Preview**를 선택하여 수집된 데이터를 봅니다. 그런 다음 미리보기를 닫습니다.

## Serverless SQL pool을 사용하여 데이터 분석

작업 영역에 일부 데이터를 수집했으므로 이제 Synapse Analytics를 사용하여 데이터를 쿼리하고 분석할 수 있습니다. 데이터를 쿼리하는 가장 일반적인 방법 중 하나는 SQL을 사용하는 것이며, Synapse Analytics에서는 serverless SQL pool을 사용하여 데이터 레이크의 데이터에 대해 SQL 코드를 실행할 수 있습니다.

1.  Synapse Studio에서 Synapse 작업 영역의 파일 스토리지에 있는 **products.csv** 파일을 마우스 오른쪽 버튼으로 클릭하고 **New SQL script**를 가리킨 다음 **Select TOP 100 rows**를 선택합니다.
2.  열리는 **SQL Script 1** 창에서 생성된 SQL 코드를 검토합니다. 다음과 유사해야 합니다:

    ```SQL
    -- This is auto-generated code
    SELECT
        TOP 100 *
    FROM
        OPENROWSET(
            BULK 'https://datalakexxxxxxx.dfs.core.windows.net/files/product_data/products.csv',
            FORMAT = 'CSV',
            PARSER_VERSION='2.0'
        ) AS [result]
    ```

    이 코드는 가져온 텍스트 파일에서 행 집합(rowset)을 열고 처음 100개 행의 데이터를 검색합니다.

3.  **Connect to** 목록에서 **Built-in**이 선택되어 있는지 확인합니다. 이는 작업 영역과 함께 생성된 내장 SQL Pool을 나타냅니다.
4.  도구 모음에서 **&#9655; Run** 버튼을 사용하여 SQL 코드를 실행하고 결과를 검토합니다. 결과는 다음과 유사해야 합니다:

    | C1 | C2 | C3 | C4 |
    | -- | -- | -- | -- |
    | ProductID | ProductName | Category | ListPrice |
    | 771 | Mountain-100 Silver, 38 | Mountain Bikes | 3399.9900 |
    | 772 | Mountain-100 Silver, 42 | Mountain Bikes | 3399.9900 |
    | ... | ... | ... | ... |

5.  결과는 C1, C2, C3, C4라는 네 개의 열로 구성되며 결과의 첫 번째 행에는 데이터 필드의 이름이 포함되어 있습니다. 이 문제를 해결하려면 OPENROWSET 함수에 `HEADER_ROW = TRUE` 매개변수를 다음과 같이 추가하고(*datalakexxxxxxx*를 데이터 레이크 스토리지 계정 이름으로 바꿈) 쿼리를 다시 실행하십시오:

    ```SQL
    SELECT
        TOP 100 *
    FROM
        OPENROWSET(
            BULK 'https://datalakexxxxxxx.dfs.core.windows.net/files/product_data/products.csv',
            FORMAT = 'CSV',
            PARSER_VERSION='2.0',
            HEADER_ROW = TRUE
        ) AS [result]
    ```

    이제 결과는 다음과 같습니다:

    | ProductID | ProductName | Category | ListPrice |
    | -- | -- | -- | -- |
    | 771 | Mountain-100 Silver, 38 | Mountain Bikes | 3399.9900 |
    | 772 | Mountain-100 Silver, 42 | Mountain Bikes | 3399.9900 |
    | ... | ... | ... | ... |

6.  다음과 같이 쿼리를 수정합니다(*datalakexxxxxxx*를 데이터 레이크 스토리지 계정 이름으로 바꿈):

    ```SQL
    SELECT
        Category, COUNT(*) AS ProductCount
    FROM
        OPENROWSET(
            BULK 'https://datalakexxxxxxx.dfs.core.windows.net/files/product_data/products.csv',
            FORMAT = 'CSV',
            PARSER_VERSION='2.0',
            HEADER_ROW = TRUE
        ) AS [result]
    GROUP BY Category;
    ```

7.  수정된 쿼리를 실행합니다. 각 카테고리별 제품 수를 포함하는 결과 집합이 반환되어야 하며, 다음과 같습니다:

    | Category | ProductCount |
    | -- | -- |
    | Bib Shorts | 3 |
    | Bike Racks | 1 |
    | ... | ... |

8.  **SQL Script 1**의 **Properties** 창에서 **Name**을 **Count Products by Category**로 변경합니다. 그런 다음 도구 모음에서 **Publish**를 선택하여 스크립트를 저장합니다.

9.  **Count Products by Category** 스크립트 창을 닫습니다.

10. Synapse Studio에서 **Develop** 페이지를 선택하고 게시된 **Count Products by Category** SQL 스크립트가 거기에 저장되었는지 확인합니다.

11. **Count Products by Category** SQL 스크립트를 선택하여 다시 엽니다. 그런 다음 스크립트가 **Built-in** SQL pool에 연결되어 있는지 확인하고 실행하여 제품 수를 검색합니다.

12. **Results** 창에서 **Chart** 뷰를 선택한 다음 차트에 대해 다음 설정을 선택합니다:
    *   **Chart type**: Column
    *   **Category column**: Category
    *   **Legend (series) columns**: ProductCount
    *   **Legend position**: bottom - center
    *   **Legend (series) label**: *비워 둡니다*
    *   **Legend (series) minimum value**: *비워 둡니다*
    *   **Legend (series) maximum**: *비워 둡니다*
    *   **Category label**: *비워 둡니다*

    결과 차트는 다음과 유사해야 합니다:

    ![제품 수 차트 뷰를 보여주는 이미지](./images/column-chart.png)

## Spark pool을 사용하여 데이터 분석

SQL은 구조화된 데이터 세트를 쿼리하는 일반적인 언어이지만, 많은 데이터 분석가들은 Python과 같은 언어가 데이터를 탐색하고 분석을 위해 준비하는 데 유용하다는 것을 알게 됩니다. Azure Synapse Analytics에서는 Apache Spark 기반의 분산 데이터 처리 엔진을 사용하는 *Spark pool*에서 Python (및 기타) 코드를 실행할 수 있습니다.

1.  Synapse Studio에서 이전에 열었던 **products.csv** 파일이 포함된 **files** 탭이 더 이상 열려 있지 않으면 **Data** 페이지에서 **product_data** 폴더를 찾습니다. 그런 다음 **products.csv**를 마우스 오른쪽 버튼으로 클릭하고 **New notebook**을 가리킨 다음 **Load to DataFrame**을 선택합니다.
2.  열리는 **Notebook 1** 창의 **Attach to** 목록에서 **sparkxxxxxxx** Spark pool을 선택하고 **Language**가 **PySpark (Python)**로 설정되어 있는지 확인합니다.
3.  Notebook의 첫 번째 (유일한) 셀에 있는 코드를 검토합니다. 다음과 같아야 합니다:

    ```Python
    %%pyspark
    df = spark.read.load('abfss://files@datalakexxxxxxx.dfs.core.windows.net/product_data/products.csv', format='csv'
    ## If header exists uncomment line below
    ##, header=True
    )
    display(df.limit(10))
    ```

4.  코드 셀 왼쪽의 **&#9655;** 아이콘을 사용하여 실행하고 결과를 기다립니다. Notebook에서 셀을 처음 실행하면 Spark pool이 시작되므로 결과가 반환되기까지 1분 정도 걸릴 수 있습니다.
5.  결국 결과가 셀 아래에 나타나며 다음과 유사해야 합니다:

    | _c0_ | _c1_ | _c2_ | _c3_ |
    | -- | -- | -- | -- |
    | ProductID | ProductName | Category | ListPrice |
    | 771 | Mountain-100 Silver, 38 | Mountain Bikes | 3399.9900 |
    | 772 | Mountain-100 Silver, 42 | Mountain Bikes | 3399.9900 |
    | ... | ... | ... | ... |

6.  `,header=True` 줄의 주석 처리를 제거합니다 (products.csv 파일의 첫 번째 줄에 열 헤더가 있기 때문). 코드는 다음과 같아야 합니다:

    ```Python
    %%pyspark
    df = spark.read.load('abfss://files@datalakexxxxxxx.dfs.core.windows.net/product_data/products.csv', format='csv'
    ## If header exists uncomment line below
    , header=True
    )
    display(df.limit(10))
    ```

7.  셀을 다시 실행하고 결과가 다음과 같은지 확인합니다:

    | ProductID | ProductName | Category | ListPrice |
    | -- | -- | -- | -- |
    | 771 | Mountain-100 Silver, 38 | Mountain Bikes | 3399.9900 |
    | 772 | Mountain-100 Silver, 42 | Mountain Bikes | 3399.9900 |
    | ... | ... | ... | ... |

    Spark pool이 이미 시작되었으므로 셀을 다시 실행하는 데 시간이 덜 걸립니다.

8.  결과 아래에서 **&#65291; Code** 아이콘을 사용하여 Notebook에 새 코드 셀을 추가합니다.
9.  새 빈 코드 셀에 다음 코드를 추가합니다:

    ```Python
    df_counts = df.groupby(df.Category).count()
    display(df_counts)
    ```

10. 해당 **&#9655;** 아이콘을 클릭하여 새 코드 셀을 실행하고 결과를 검토합니다. 결과는 다음과 유사해야 합니다:

    | Category | count |
    | -- | -- |
    | Headsets | 3 |
    | Wheels | 14 |
    | ... | ... |

11. 셀의 결과 출력에서 **Chart** 뷰를 선택합니다. 결과 차트는 다음과 유사해야 합니다:

    ![카테고리 수 차트 뷰를 보여주는 이미지](./images/bar-chart.png)

12. 아직 보이지 않으면 도구 모음 오른쪽 끝에 있는 **Properties** 버튼( **&#128463;<sub>*</sub>** 와 유사하게 보임)을 선택하여 **Properties** 페이지를 표시합니다. 그런 다음 **Properties** 창에서 Notebook 이름을 **Explore products**로 변경하고 도구 모음의 **Publish** 버튼을 사용하여 저장합니다.

13. Notebook 창을 닫고 메시지가 표시되면 Spark 세션을 중지합니다. 그런 다음 **Develop** 페이지를 보고 Notebook이 저장되었는지 확인합니다.

## Dedicated SQL pool을 사용하여 데이터 웨어하우스 쿼리

지금까지 데이터 레이크에서 파일 기반 데이터를 탐색하고 처리하는 몇 가지 기술을 살펴보았습니다. 많은 경우 엔터프라이즈 분석 솔루션은 데이터 레이크를 사용하여 비정형 데이터를 저장하고 준비한 다음, 이를 관계형 데이터 웨어하우스에 로드하여 비즈니스 인텔리전스(BI) 워크로드를 지원합니다. Azure Synapse Analytics에서 이러한 데이터 웨어하우스는 dedicated SQL pool에서 구현할 수 있습니다.

1.  Synapse Studio의 **Manage** 페이지, **SQL pools** 섹션에서 **sql*xxxxxxx*** dedicated SQL pool 행을 선택한 다음 해당 **&#9655;** 아이콘을 사용하여 다시 시작합니다.
2.  SQL pool이 시작될 때까지 기다립니다. 몇 분 정도 걸릴 수 있습니다. **&#8635; Refresh** 버튼을 사용하여 주기적으로 상태를 확인하십시오. 준비가 되면 상태가 **Online**으로 표시됩니다.
3.  SQL pool이 시작되면 **Data** 페이지를 선택합니다. **Workspace** 탭에서 **SQL databases**를 확장하고 **sql*xxxxxxx***가 나열되는지 확인합니다 (필요한 경우 페이지 왼쪽 상단의 **&#8635;** 아이콘을 사용하여 뷰를 새로 고침).
4.  **sql*xxxxxxx*** 데이터베이스와 해당 **Tables** 폴더를 확장한 다음, **FactInternetSales** 테이블의 **...** 메뉴에서 **New SQL script**를 가리키고 **Select TOP 100 rows**를 선택합니다.
5.  쿼리 결과를 검토합니다. 테이블의 처음 100개 판매 트랜잭션을 보여줍니다. 이 데이터는 설정 스크립트에 의해 데이터베이스에 로드되었으며 dedicated SQL pool과 연결된 데이터베이스에 영구적으로 저장됩니다.
6.  SQL 쿼리를 다음 코드로 바꿉니다:

    ```sql
    SELECT d.CalendarYear, d.MonthNumberOfYear, d.EnglishMonthName,
           p.EnglishProductName AS Product, SUM(o.OrderQuantity) AS UnitsSold
    FROM dbo.FactInternetSales AS o
    JOIN dbo.DimDate AS d ON o.OrderDateKey = d.DateKey
    JOIN dbo.DimProduct AS p ON o.ProductKey = p.ProductKey
    GROUP BY d.CalendarYear, d.MonthNumberOfYear, d.EnglishMonthName, p.EnglishProductName
    ORDER BY d.MonthNumberOfYear
    ```

7.  **&#9655; Run** 버튼을 사용하여 수정된 쿼리를 실행합니다. 이 쿼리는 연도 및 월별로 판매된 각 제품의 수량을 반환합니다.
8.  아직 보이지 않으면 도구 모음 오른쪽 끝에 있는 **Properties** 버튼( **&#128463;<sub>*</sub>** 와 유사하게 보임)을 선택하여 **Properties** 페이지를 표시합니다. 그런 다음 **Properties** 창에서 쿼리 이름을 **Aggregate product sales**로 변경하고 도구 모음의 **Publish** 버튼을 사용하여 저장합니다.

9.  쿼리 창을 닫은 다음 **Develop** 페이지를 보고 SQL 스크립트가 저장되었는지 확인합니다.

10. **Manage** 페이지에서 **sql*xxxxxxx*** dedicated SQL pool 행을 선택하고 해당 &#10074;&#10074; 아이콘을 사용하여 일시 중지합니다.

<!--- Data Explorer Pool 섹션은 주석 처리되어 있어 번역에서 제외합니다.
## Explore data with a Data Explorer pool
...
--->

## Azure 리소스 삭제

Azure Synapse Analytics 탐색을 마쳤으므로 불필요한 Azure 비용을 피하기 위해 생성한 리소스를 삭제해야 합니다.

1.  Synapse Studio 브라우저 탭을 닫고 Azure portal로 돌아갑니다.
2.  Azure portal의 **Home** 페이지에서 **Resource groups**를 선택합니다.
3.  Synapse Analytics 작업 영역에 대한 **dp203-*xxxxxxx*** 리소스 그룹(관리형 리소스 그룹이 아님)을 선택하고 여기에 Synapse 작업 영역, 스토리지 계정, SQL pool 및 작업 영역용 Spark pool이 포함되어 있는지 확인합니다.
4.  리소스 그룹의 **Overview** 페이지 상단에서 **Delete resource group**을 선택합니다.
5.  **dp203-*xxxxxxx*** 리소스 그룹 이름을 입력하여 삭제할 것인지 확인하고 **Delete**를 선택합니다.

    몇 분 후 Azure Synapse 작업 영역 리소스 그룹과 이와 연결된 관리형 작업 영역 리소스 그룹이 삭제됩니다.

---
