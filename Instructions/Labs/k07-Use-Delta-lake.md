---
lab:
    title: 'Azure Synapse Analytics에서 Delta Lake 사용'
    ilt-use: '실습'
---

# Azure Synapse Analytics에서 Spark와 함께 Delta Lake 사용

Delta Lake는 데이터 레이크 위에 트랜잭션 데이터 스토리지 계층을 구축하기 위한 오픈 소스 프로젝트입니다. Delta Lake는 배치 및 스트리밍 데이터 작업 모두에 대한 관계형 시맨틱 지원을 추가하고, Apache Spark를 사용하여 데이터 레이크의 기본 파일을 기반으로 하는 테이블의 데이터를 처리하고 쿼리할 수 있는 *Lakehouse* 아키텍처 생성을 가능하게 합니다.

이 실습을 완료하는 데 약 **40**분이 소요됩니다.

## 시작하기 전에

관리자 수준 액세스 권한이 있는 [Azure 구독](https://azure.microsoft.com/free)이 필요합니다.

## Azure Synapse Analytics 작업 영역 프로비저닝

데이터 레이크 스토리지에 액세스할 수 있는 Azure Synapse Analytics 작업 영역과 데이터 레이크의 파일을 쿼리하고 처리하는 데 사용할 수 있는 Apache Spark pool이 필요합니다.

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
    cd dp-203/Allfiles/labs/07
    ./setup.ps1
    ```

6.  메시지가 표시되면 사용할 구독을 선택합니다 (여러 Azure 구독에 액세스할 수 있는 경우에만 발생합니다).
7.  메시지가 표시되면 Azure Synapse SQL pool에 설정할 적절한 암호를 입력합니다.

    > **참고**: 이 암호를 반드시 기억하십시오!

8.  스크립트가 완료될 때까지 기다리십시오. 일반적으로 약 10분 정도 걸리지만 경우에 따라 더 오래 걸릴 수 있습니다. 기다리는 동안 Azure Synapse Analytics 설명서의 [Delta Lake란 무엇인가](https://docs.microsoft.com/azure/synapse-analytics/spark/apache-spark-what-is-delta-lake) 문서를 검토하십시오.

## Delta 테이블 만들기

스크립트는 Azure Synapse Analytics 작업 영역과 데이터 레이크를 호스팅할 Azure Storage 계정을 프로비저닝한 다음, 데이터 파일을 데이터 레이크에 업로드합니다.

### 데이터 레이크의 데이터 탐색

1.  스크립트가 완료된 후 Azure portal에서 스크립트가 생성한 **dp203-*xxxxxxx*** 리소스 그룹으로 이동하여 Synapse 작업 영역을 선택합니다.
2.  Synapse 작업 영역의 **Overview** 페이지에 있는 **Open Synapse Studio** 카드에서 **Open**을 선택하여 새 브라우저 탭에서 Synapse Studio를 엽니다. 메시지가 표시되면 로그인합니다.
3.  Synapse Studio 왼쪽에서 **&rsaquo;&rsaquo;** 아이콘을 사용하여 메뉴를 확장합니다. 이렇게 하면 리소스를 관리하고 데이터 분석 작업을 수행하는 데 사용할 Synapse Studio 내의 여러 페이지가 표시됩니다.
4.  **Data** 페이지에서 **Linked** 탭을 보고 작업 영역에 Azure Data Lake Storage Gen2 스토리지 계정에 대한 링크가 포함되어 있는지 확인합니다. 이 계정의 이름은 **synapse*xxxxxxx* (Primary - datalake*xxxxxxx*)**와 유사해야 합니다.
5.  스토리지 계정을 확장하고 **files**라는 파일 시스템 컨테이너가 포함되어 있는지 확인합니다.
6.  **files** 컨테이너를 선택하고 **products**라는 폴더가 포함되어 있는지 확인합니다. 이 폴더에는 이 실습에서 작업할 데이터가 들어 있습니다.
7.  **products** 폴더를 열고 **products.csv**라는 파일이 포함되어 있는지 확인합니다.
8.  **products.csv**를 선택한 다음 도구 모음의 **New notebook** 목록에서 **Load to DataFrame**을 선택합니다.
9.  열리는 **Notebook 1** 창의 **Attach to** 목록에서 **sparkxxxxxxx** Spark pool을 선택하고 **Language**가 **PySpark (Python)**로 설정되어 있는지 확인합니다.
10. Notebook의 첫 번째 (유일한) 셀에 있는 코드를 검토합니다. 다음과 같아야 합니다:

    ```Python
    %%pyspark
    df = spark.read.load('abfss://files@datalakexxxxxxx.dfs.core.windows.net/products/products.csv', format='csv'
    ## If header exists uncomment line below
    ##, header=True
    )
    display(df.limit(10))
    ```

11. `,header=True` 줄의 주석 처리를 제거합니다 (products.csv 파일의 첫 번째 줄에 열 헤더가 있기 때문). 코드는 다음과 같아야 합니다:

    ```Python
    %%pyspark
    df = spark.read.load('abfss://files@datalakexxxxxxx.dfs.core.windows.net/products/products.csv', format='csv'
    ## If header exists uncomment line below
    , header=True
    )
    display(df.limit(10))
    ```

12. 코드 셀 왼쪽의 **&#9655;** 아이콘을 사용하여 실행하고 결과를 기다립니다. Notebook에서 셀을 처음 실행하면 Spark pool이 시작되므로 결과가 반환되기까지 1분 정도 걸릴 수 있습니다. 결국 결과가 셀 아래에 나타나며 다음과 유사해야 합니다:

    | ProductID | ProductName | Category | ListPrice |
    | -- | -- | -- | -- |
    | 771 | Mountain-100 Silver, 38 | Mountain Bikes | 3399.9900 |
    | 772 | Mountain-100 Silver, 42 | Mountain Bikes | 3399.9900 |
    | ... | ... | ... | ... |

### 파일 데이터를 Delta 테이블로 로드

1.  첫 번째 코드 셀에서 반환된 결과 아래에서 **+ Code** 버튼을 사용하여 새 코드 셀을 추가합니다. 그런 다음 새 셀에 다음 코드를 입력하고 실행합니다:

    ```Python
    delta_table_path = "/delta/products-delta"
    df.write.format("delta").save(delta_table_path)
    ```

2.  **files** 탭에서 도구 모음의 **&#8593;** 아이콘을 사용하여 **files** 컨테이너의 루트로 돌아가고 **delta**라는 새 폴더가 생성되었는지 확인합니다. 이 폴더와 여기에 포함된 **products-delta** 테이블을 열면 데이터가 포함된 parquet 형식 파일(들)을 볼 수 있습니다.

3.  **Notebook 1** 탭으로 돌아가서 다른 새 코드 셀을 추가합니다. 그런 다음 새 셀에 다음 코드를 추가하고 실행합니다:

    ```Python
    from delta.tables import *
    from pyspark.sql.functions import *

    # deltaTable 객체 생성
    deltaTable = DeltaTable.forPath(spark, delta_table_path)

    # 테이블 업데이트 (제품 771 가격 10% 인하)
    deltaTable.update(
        condition = "ProductID == 771",
        set = { "ListPrice": "ListPrice * 0.9" })

    # 업데이트된 데이터를 DataFrame으로 보기
    deltaTable.toDF().show(10)
    ```

    데이터는 **DeltaTable** 객체로 로드되고 업데이트됩니다. 쿼리 결과에서 업데이트가 반영된 것을 볼 수 있습니다.

4.  다음 코드로 다른 새 코드 셀을 추가하고 실행합니다:

    ```Python
    new_df = spark.read.format("delta").load(delta_table_path)
    new_df.show(10)
    ```

    이 코드는 데이터 레이크의 해당 위치에서 Delta 테이블 데이터를 DataFrame으로 로드하여 **DeltaTable** 객체를 통해 변경한 내용이 유지되었는지 확인합니다.

5.  방금 실행한 코드를 다음과 같이 수정하여 Delta Lake의 *시간 여행(time travel)* 기능을 사용하여 데이터의 이전 버전을 보도록 옵션을 지정합니다.

    ```Python
    new_df = spark.read.format("delta").option("versionAsOf", 0).load(delta_table_path)
    new_df.show(10)
    ```

    수정된 코드를 실행하면 결과에 원본 데이터 버전이 표시됩니다.

6.  다음 코드로 다른 새 코드 셀을 추가하고 실행합니다:

    ```Python
    deltaTable.history(10).show(20, False, True)
    ```

    테이블에 대한 마지막 20개 변경 내역이 표시됩니다. 두 개(원본 생성 및 수행한 업데이트)여야 합니다.

## 카탈로그 테이블 만들기

지금까지 테이블이 기반으로 하는 parquet 파일이 포함된 폴더에서 데이터를 로드하여 Delta 테이블 작업을 수행했습니다. 데이터에 대한 캡슐화를 제공하고 SQL 코드에서 참조할 수 있는 명명된 테이블 엔터티를 제공하는 *카탈로그 테이블(catalog tables)*을 정의할 수 있습니다. Spark는 Delta Lake에 대해 두 가지 종류의 카탈로그 테이블을 지원합니다:

-   테이블 데이터가 포함된 parquet 파일 경로로 정의되는 *외부(External)* 테이블.
-   Spark pool의 Hive 메타스토어에 정의되는 *관리형(Managed)* 테이블.

### 외부 테이블 만들기

1.  새 코드 셀에 다음 코드를 추가하고 실행합니다:

    ```Python
    spark.sql("CREATE DATABASE AdventureWorks")
    spark.sql("CREATE TABLE AdventureWorks.ProductsExternal USING DELTA LOCATION '{0}'".format(delta_table_path))
    spark.sql("DESCRIBE EXTENDED AdventureWorks.ProductsExternal").show(truncate=False)
    ```

    이 코드는 **AdventureWorks**라는 새 데이터베이스를 만들고 이전에 정의한 parquet 파일 경로를 기반으로 해당 데이터베이스에 **ProductsExternal**이라는 외부 테이블을 만듭니다. 그런 다음 테이블 속성에 대한 설명을 표시합니다. **Location** 속성이 지정한 경로인지 확인하십시오.

2.  새 코드 셀을 추가한 다음 다음 코드를 입력하고 실행합니다:

    ```sql
    %%sql

    USE AdventureWorks;

    SELECT * FROM ProductsExternal;
    ```

    이 코드는 SQL을 사용하여 컨텍스트를 **AdventureWorks** 데이터베이스로 전환하고(데이터를 반환하지 않음) **ProductsExternal** 테이블을 쿼리합니다(Delta Lake 테이블의 제품 데이터를 포함하는 결과 집합 반환).

### 관리형 테이블 만들기

1.  새 코드 셀에 다음 코드를 추가하고 실행합니다:

    ```Python
    df.write.format("delta").saveAsTable("AdventureWorks.ProductsManaged")
    spark.sql("DESCRIBE EXTENDED AdventureWorks.ProductsManaged").show(truncate=False)
    ```

    이 코드는 원래 **products.csv** 파일에서 로드한 DataFrame(제품 771의 가격을 업데이트하기 전)을 기반으로 **ProductsManaged**라는 관리형 테이블을 만듭니다. 테이블에서 사용하는 parquet 파일의 경로를 지정하지 않습니다. 이는 Hive 메타스토어에서 관리되며 테이블 설명의 **Location** 속성( **files/synapse/workspaces/synapsexxxxxxx/warehouse** 경로)에 표시됩니다.

2.  새 코드 셀을 추가한 다음 다음 코드를 입력하고 실행합니다:

    ```sql
    %%sql

    USE AdventureWorks;

    SELECT * FROM ProductsManaged;
    ```

    이 코드는 SQL을 사용하여 **ProductsManaged** 테이블을 쿼리합니다.

### 외부 테이블과 관리형 테이블 비교

1.  새 코드 셀에 다음 코드를 추가하고 실행합니다:

    ```sql
    %%sql

    USE AdventureWorks;

    SHOW TABLES;
    ```

    이 코드는 **AdventureWorks** 데이터베이스의 테이블을 나열합니다.

2.  다음과 같이 코드 셀을 수정하고 실행합니다:

    ```sql
    %%sql

    USE AdventureWorks;

    DROP TABLE IF EXISTS ProductsExternal;
    DROP TABLE IF EXISTS ProductsManaged;
    ```

    이 코드는 메타스토어에서 테이블을 삭제합니다.

3.  **files** 탭으로 돌아가서 **files/delta/products-delta** 폴더를 봅니다. 이 위치에 데이터 파일이 여전히 존재하는지 확인하십시오. 외부 테이블을 삭제하면 메타스토어에서 테이블이 제거되지만 데이터 파일은 그대로 유지됩니다.
4.  **files/synapse/workspaces/synapsexxxxxxx/warehouse** 폴더를 보고 **ProductsManaged** 테이블 데이터에 대한 폴더가 없는지 확인하십시오. 관리형 테이블을 삭제하면 메타스토어에서 테이블이 제거되고 테이블의 데이터 파일도 삭제됩니다.

### SQL을 사용하여 테이블 만들기

1.  새 코드 셀을 추가한 다음 다음 코드를 입력하고 실행합니다:

    ```sql
    %%sql

    USE AdventureWorks;

    CREATE TABLE Products
    USING DELTA
    LOCATION '/delta/products-delta';
    ```

2.  새 코드 셀을 추가한 다음 다음 코드를 입력하고 실행합니다:

    ```sql
    %%sql

    USE AdventureWorks;

    SELECT * FROM Products;
    ```

    새 카탈로그 테이블이 기존 Delta Lake 테이블 폴더에 대해 생성되었으며, 이는 이전에 수행된 변경 사항을 반영합니다.

## 스트리밍 데이터에 Delta 테이블 사용

Delta Lake는 스트리밍 데이터를 지원합니다. Delta 테이블은 Spark Structured Streaming API를 사용하여 만든 데이터 스트림의 *싱크(sink)* 또는 *소스(source)*가 될 수 있습니다. 이 예에서는 시뮬레이션된 사물 인터넷(IoT) 시나리오에서 스트리밍 데이터의 싱크로 Delta 테이블을 사용합니다.

1.  **Notebook 1** 탭으로 돌아가서 새 코드 셀을 추가합니다. 그런 다음 새 셀에 다음 코드를 추가하고 실행합니다:

    ```python
    from notebookutils import mssparkutils
    from pyspark.sql.types import *
    from pyspark.sql.functions import *

    # 폴더 만들기
    inputPath = '/data/'
    mssparkutils.fs.mkdirs(inputPath)

    # JSON 스키마를 사용하여 폴더에서 데이터를 읽는 스트림 만들기
    jsonSchema = StructType([
    StructField("device", StringType(), False),
    StructField("status", StringType(), False)
    ])
    iotstream = spark.readStream.schema(jsonSchema).option("maxFilesPerTrigger", 1).json(inputPath)

    # 폴더에 일부 이벤트 데이터 쓰기
    device_data = '''{"device":"Dev1","status":"ok"}
    {"device":"Dev1","status":"ok"}
    {"device":"Dev1","status":"ok"}
    {"device":"Dev2","status":"error"}
    {"device":"Dev1","status":"ok"}
    {"device":"Dev1","status":"error"}
    {"device":"Dev2","status":"ok"}
    {"device":"Dev2","status":"error"}
    {"device":"Dev1","status":"ok"}'''
    mssparkutils.fs.put(inputPath + "data.txt", device_data, True)
    print("Source stream created...")
    ```

    *Source stream created...* 메시지가 인쇄되었는지 확인하십시오. 방금 실행한 코드는 가상 IoT 장치의 판독값을 나타내는 일부 데이터가 저장된 폴더를 기반으로 스트리밍 데이터 원본을 만들었습니다.

2.  새 코드 셀에 다음 코드를 추가하고 실행합니다:

    ```python
    # 스트림을 Delta 테이블에 쓰기
    delta_stream_table_path = '/delta/iotdevicedata'
    checkpointpath = '/delta/checkpoint'
    deltastream = iotstream.writeStream.format("delta").option("checkpointLocation", checkpointpath).start(delta_stream_table_path)
    print("Streaming to delta sink...")
    ```

    이 코드는 스트리밍 장치 데이터를 Delta 형식으로 씁니다.

3.  새 코드 셀에 다음 코드를 추가하고 실행합니다:

    ```python
    # Delta 형식의 데이터를 DataFrame으로 읽기
    df = spark.read.format("delta").load(delta_stream_table_path)
    display(df)
    ```

    이 코드는 스트리밍된 데이터를 Delta 형식으로 DataFrame에 읽습니다. 스트리밍 데이터를 로드하는 코드는 Delta 폴더에서 정적 데이터를 로드하는 데 사용되는 코드와 다르지 않습니다.

4.  새 코드 셀에 다음 코드를 추가하고 실행합니다:

    ```python
    # 스트리밍 싱크를 기반으로 카탈로그 테이블 만들기
    spark.sql("CREATE TABLE IotDeviceData USING DELTA LOCATION '{0}'".format(delta_stream_table_path))
    ```

    이 코드는 Delta 폴더를 기반으로 **IotDeviceData**라는 카탈로그 테이블(**default** 데이터베이스)을 만듭니다. 다시 말하지만 이 코드는 스트리밍되지 않는 데이터에 사용되는 코드와 동일합니다.

5.  새 코드 셀에 다음 코드를 추가하고 실행합니다:

    ```sql
    %%sql

    SELECT * FROM IotDeviceData;
    ```

    이 코드는 스트리밍 원본의 장치 데이터를 포함하는 **IotDeviceData** 테이블을 쿼리합니다.

6.  새 코드 셀에 다음 코드를 추가하고 실행합니다:

    ```python
    # 소스 스트림에 데이터 추가
    more_data = '''{"device":"Dev1","status":"ok"}
    {"device":"Dev1","status":"ok"}
    {"device":"Dev1","status":"ok"}
    {"device":"Dev1","status":"ok"}
    {"device":"Dev1","status":"error"}
    {"device":"Dev2","status":"error"}
    {"device":"Dev1","status":"ok"}'''

    mssparkutils.fs.put(inputPath + "more-data.txt", more_data, True)
    ```

    이 코드는 스트리밍 원본에 더 많은 가상 장치 데이터를 씁니다.

7.  새 코드 셀에 다음 코드를 추가하고 실행합니다:

    ```sql
    %%sql

    SELECT * FROM IotDeviceData;
    ```

    이 코드는 **IotDeviceData** 테이블을 다시 쿼리하며, 이제 스트리밍 원본에 추가된 추가 데이터가 포함되어야 합니다.

8.  새 코드 셀에 다음 코드를 추가하고 실행합니다:

    ```python
    deltastream.stop()
    ```

    이 코드는 스트림을 중지합니다.

## Serverless SQL pool에서 Delta 테이블 쿼리

Spark pool 외에도 Azure Synapse Analytics에는 내장된 serverless SQL pool이 포함되어 있습니다. 이 풀의 관계형 데이터베이스 엔진을 사용하여 SQL로 Delta 테이블을 쿼리할 수 있습니다.

1.  **files** 탭에서 **files/delta** 폴더로 이동합니다.
2.  **products-delta** 폴더를 선택하고 도구 모음의 **New SQL script** 드롭다운 목록에서 **Select TOP 100 rows**를 선택합니다.
3.  **Select TOP 100 rows** 창의 **File type** 목록에서 **Delta format**을 선택한 다음 **Apply**를 선택합니다.
4.  생성된 SQL 코드를 검토합니다. 다음과 같아야 합니다:

    ```sql
    -- This is auto-generated code
    SELECT
        TOP 100 *
    FROM
        OPENROWSET(
            BULK 'https://datalakexxxxxxx.dfs.core.windows.net/files/delta/products-delta/',
            FORMAT = 'DELTA'
        ) AS [result]
    ```

5.  **&#9655; Run** 아이콘을 사용하여 스크립트를 실행하고 결과를 검토합니다. 결과는 다음과 유사해야 합니다:

    | ProductID | ProductName | Category | ListPrice |
    | -- | -- | -- | -- |
    | 771 | Mountain-100 Silver, 38 | Mountain Bikes | 3059.991 |
    | 772 | Mountain-100 Silver, 42 | Mountain Bikes | 3399.9900 |
    | ... | ... | ... | ... |

    이는 Spark를 사용하여 만든 Delta 형식 파일을 serverless SQL pool을 사용하여 쿼리하고 보고 또는 분석에 결과를 사용할 수 있는 방법을 보여줍니다.

6.  쿼리를 다음 SQL 코드로 바꿉니다:

    ```sql
    USE AdventureWorks;

    SELECT * FROM Products;
    ```

7.  코드를 실행하고 serverless SQL pool을 사용하여 Spark 메타스토어에 정의된 카탈로그 테이블의 Delta Lake 데이터를 쿼리할 수도 있음을 확인합니다.

## Azure 리소스 삭제

Azure Synapse Analytics 탐색을 마쳤으면 불필요한 Azure 비용을 피하기 위해 생성한 리소스를 삭제해야 합니다.

1.  Synapse Studio 브라우저 탭을 닫고 Azure portal로 돌아갑니다.
2.  Azure portal의 **Home** 페이지에서 **Resource groups**를 선택합니다.
3.  Synapse Analytics 작업 영역에 대한 **dp203-*xxxxxxx*** 리소스 그룹(관리형 리소스 그룹이 아님)을 선택하고 여기에 Synapse 작업 영역, 스토리지 계정 및 작업 영역용 Spark pool이 포함되어 있는지 확인합니다.
4.  리소스 그룹의 **Overview** 페이지 상단에서 **Delete resource group**을 선택합니다.
5.  **dp203-*xxxxxxx*** 리소스 그룹 이름을 입력하여 삭제할 것인지 확인하고 **Delete**를 선택합니다.

    몇 분 후 Azure Synapse 작업 영역 리소스 그룹과 이와 연결된 관리형 작업 영역 리소스 그룹이 삭제됩니다.
