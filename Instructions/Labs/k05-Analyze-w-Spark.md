---
lab:
    title: 'Spark를 사용하여 데이터 레이크의 데이터 분석'
    ilt-use: '데모 제안'
---
# Spark를 사용하여 데이터 레이크의 데이터 분석

Apache Spark는 분산 데이터 처리를 위한 오픈 소스 엔진이며, 데이터 레이크 스토리지에 있는 방대한 양의 데이터를 탐색, 처리 및 분석하는 데 널리 사용됩니다. Spark는 Microsoft Azure 클라우드 플랫폼의 Azure HDInsight, Azure Databricks, Azure Synapse Analytics를 포함한 많은 데이터 플랫폼 제품에서 처리 옵션으로 사용할 수 있습니다. Spark의 장점 중 하나는 Java, Scala, Python, SQL 등 다양한 프로그래밍 언어를 지원한다는 점으로, 이는 Spark를 데이터 정제 및 조작, 통계 분석 및 머신 러닝, 데이터 분석 및 시각화를 포함한 데이터 처리 워크로드에 매우 유연한 솔루션으로 만듭니다.

이 실습을 완료하는 데 약 **45**분이 소요됩니다.

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
    rm -r dp203 -f
    git clone  https://github.com/MicrosoftLearning/Dp-203-azure-data-engineer dp203
    ```

5.  리포지토리가 복제된 후 다음 명령을 입력하여 이 실습용 폴더로 변경하고 포함된 **setup.ps1** 스크립트를 실행합니다:

    ```
    cd dp203/Allfiles/labs/05
    ./setup.ps1
    ```

6.  메시지가 표시되면 사용할 구독을 선택합니다 (여러 Azure 구독에 액세스할 수 있는 경우에만 발생합니다).
7.  메시지가 표시되면 Azure Synapse SQL pool에 설정할 적절한 암호를 입력합니다.

    > **참고**: 이 암호를 반드시 기억하십시오!

8.  스크립트가 완료될 때까지 기다리십시오. 일반적으로 약 10분 정도 걸리지만 경우에 따라 더 오래 걸릴 수 있습니다. 기다리는 동안 Azure Synapse Analytics 설명서의 [Azure Synapse Analytics의 Apache Spark](https://docs.microsoft.com/azure/synapse-analytics/spark/apache-spark-overview) 문서를 검토하십시오.

## 파일의 데이터 쿼리

스크립트는 Azure Synapse Analytics 작업 영역과 데이터 레이크를 호스팅할 Azure Storage 계정을 프로비저닝한 다음, 일부 데이터 파일을 데이터 레이크에 업로드합니다.

### 데이터 레이크의 파일 보기

1.  스크립트가 완료된 후 Azure portal에서 스크립트가 생성한 **dp203-*xxxxxxx*** 리소스 그룹으로 이동하여 Synapse 작업 영역을 선택합니다.
2.  Synapse 작업 영역의 **Overview** 페이지에 있는 **Open Synapse Studio** 카드에서 **Open**을 선택하여 새 브라우저 탭에서 Synapse Studio를 엽니다. 메시지가 표시되면 로그인합니다.
3.  Synapse Studio 왼쪽에서 **&rsaquo;&rsaquo;** 아이콘을 사용하여 메뉴를 확장합니다. 이렇게 하면 리소스를 관리하고 데이터 분석 작업을 수행하는 데 사용할 Synapse Studio 내의 여러 페이지가 표시됩니다.
4.  **Manage** 페이지에서 **Apache Spark pools** 탭을 선택하고 **spark*xxxxxxx***와 유사한 이름의 Spark pool이 작업 영역에 프로비저닝되었는지 확인합니다. 나중에 이 Spark pool을 사용하여 작업 영역의 데이터 레이크 스토리지에 있는 파일에서 데이터를 로드하고 분석합니다.
5.  **Data** 페이지에서 **Linked** 탭을 보고 작업 영역에 Azure Data Lake Storage Gen2 스토리지 계정에 대한 링크가 포함되어 있는지 확인합니다. 이 계정의 이름은 **synapse*xxxxxxx* (Primary - datalake*xxxxxxx*)**와 유사해야 합니다.
6.  스토리지 계정을 확장하고 **files**라는 파일 시스템 컨테이너가 포함되어 있는지 확인합니다.
7.  **files** 컨테이너를 선택하고 **sales** 및 **synapse**라는 폴더가 포함되어 있는지 확인합니다. **synapse** 폴더는 Azure Synapse에서 사용되며, **sales** 폴더에는 쿼리할 데이터 파일이 들어 있습니다.
8.  **sales** 폴더와 그 안에 있는 **orders** 폴더를 열고, **orders** 폴더에 3년 치 판매 데이터에 대한 .csv 파일이 포함되어 있는지 확인합니다.
9.  파일 중 하나를 마우스 오른쪽 버튼으로 클릭하고 **Preview**를 선택하여 포함된 데이터를 확인합니다. 파일에 헤더 행이 포함되어 있지 않으므로 열 헤더 표시 옵션을 선택 취소할 수 있습니다.

### Spark를 사용하여 데이터 탐색

1.  **orders** 폴더의 파일 중 하나를 선택한 다음 도구 모음의 **New notebook** 목록에서 **Load to DataFrame**을 선택합니다. DataFrame은 Spark에서 테이블 형식 데이터 세트를 나타내는 구조입니다.
2.  새로 열린 **Notebook 1** 탭의 **Attach to** 목록에서 Spark pool(**spark*xxxxxxx***)을 선택합니다. 그런 다음 **&#9655; Run all** 버튼을 사용하여 Notebook의 모든 셀을 실행합니다 (현재는 하나만 있습니다!).

    이 세션에서 Spark 코드를 처음 실행하는 것이므로 Spark pool을 시작해야 합니다. 즉, 세션의 첫 번째 실행은 몇 분 정도 걸릴 수 있습니다. 이후 실행은 더 빨라집니다.

3.  Spark 세션이 초기화되기를 기다리는 동안 생성된 코드를 검토합니다. 다음과 유사합니다:

    ```Python
    %%pyspark
    df = spark.read.load('abfss://files@datalakexxxxxxx.dfs.core.windows.net/sales/orders/2019.csv', format='csv'
    ## If header exists uncomment line below
    ##, header=True
    )
    display(df.limit(10))
    ```

4.  코드가 실행 완료되면 Notebook의 셀 아래 출력을 검토합니다. 선택한 파일의 처음 10개 행을 보여주며, 자동 열 이름은 **_c0**, **_c1**, **_c2** 등의 형식입니다.
5.  **spark.read.load** 함수가 폴더의 <u>모든</u> CSV 파일에서 데이터를 읽고 **display** 함수가 처음 100개 행을 표시하도록 코드를 수정합니다. 코드는 다음과 같아야 합니다 ( *datalakexxxxxxx*는 데이터 레이크 저장소 이름과 일치).

    ```Python
    %%pyspark
    df = spark.read.load('abfss://files@datalakexxxxxxx.dfs.core.windows.net/sales/orders/*.csv', format='csv'
    )
    display(df.limit(100))
    ```

6.  코드 셀 왼쪽의 **&#9655;** 버튼을 사용하여 해당 셀만 실행하고 결과를 검토합니다.

    DataFrame에는 이제 모든 파일의 데이터가 포함되지만 열 이름은 유용하지 않습니다. Spark는 "읽기 시 스키마(schema-on-read)" 접근 방식을 사용하여 포함된 데이터를 기반으로 열에 적합한 데이터 형식을 결정하려고 시도하며, 텍스트 파일에 헤더 행이 있는 경우 해당 행을 사용하여 열 이름을 식별할 수 있습니다 ( **load** 함수에서 **header=True** 매개변수 지정). 또는 DataFrame에 대한 명시적인 스키마를 정의할 수 있습니다.

7.  DataFrame에 열 이름과 데이터 형식을 포함하는 명시적인 스키마를 정의하도록 다음과 같이 코드를 수정하고(*datalakexxxxxxx* 교체) 셀의 코드를 다시 실행합니다.

    ```Python
    %%pyspark
    from pyspark.sql.types import *
    from pyspark.sql.functions import *

    orderSchema = StructType([
        StructField("SalesOrderNumber", StringType()),
        StructField("SalesOrderLineNumber", IntegerType()),
        StructField("OrderDate", DateType()),
        StructField("CustomerName", StringType()),
        StructField("Email", StringType()),
        StructField("Item", StringType()),
        StructField("Quantity", IntegerType()),
        StructField("UnitPrice", FloatType()),
        StructField("Tax", FloatType())
        ])

    df = spark.read.load('abfss://files@datalakexxxxxxx.dfs.core.windows.net/sales/orders/*.csv', format='csv', schema=orderSchema)
    display(df.limit(100))
    ```

8.  결과 아래에서 **+ Code** 버튼을 사용하여 Notebook에 새 코드 셀을 추가합니다. 그런 다음 새 셀에 다음 코드를 추가하여 DataFrame의 스키마를 표시합니다:

    ```Python
    df.printSchema()
    ```

9.  새 셀을 실행하고 DataFrame 스키마가 정의한 **orderSchema**와 일치하는지 확인합니다. **printSchema** 함수는 자동으로 유추된 스키마가 있는 DataFrame을 사용할 때 유용할 수 있습니다.

## DataFrame에서 데이터 분석

Spark의 **dataframe** 객체는 Python의 Pandas DataFrame과 유사하며, 포함된 데이터를 조작, 필터링, 그룹화 및 분석하는 데 사용할 수 있는 광범위한 함수를 포함합니다.

### DataFrame 필터링

1.  Notebook에 새 코드 셀을 추가하고 다음 코드를 입력합니다:

    ```Python
    customers = df['CustomerName', 'Email']
    print(customers.count())
    print(customers.distinct().count())
    display(customers.distinct())
    ```

2.  새 코드 셀을 실행하고 결과를 검토합니다. 다음 세부 정보를 확인하십시오:
    *   DataFrame에서 작업을 수행하면 결과는 새 DataFrame이 됩니다 (이 경우 **df** DataFrame에서 특정 열 하위 집합을 선택하여 새 **customers** DataFrame이 생성됨).
    *   DataFrame은 포함된 데이터를 요약하고 필터링하는 데 사용할 수 있는 **count** 및 **distinct**와 같은 함수를 제공합니다.
    *   `dataframe['Field1', 'Field2', ...]` 구문은 열 하위 집합을 정의하는 간단한 방법입니다. **select** 메서드를 사용할 수도 있으므로 위 코드의 첫 번째 줄은 `customers = df.select("CustomerName", "Email")`로 작성할 수 있습니다.

3.  코드를 다음과 같이 수정합니다:

    ```Python
    customers = df.select("CustomerName", "Email").where(df['Item']=='Road-250 Red, 52')
    print(customers.count())
    print(customers.distinct().count())
    display(customers.distinct())
    ```

4.  수정된 코드를 실행하여 *Road-250 Red, 52* 제품을 구매한 고객을 확인합니다. 여러 함수를 "연결(chain)"하여 한 함수의 출력이 다음 함수의 입력이 되도록 할 수 있습니다. 이 경우 **select** 메서드로 생성된 DataFrame은 필터링 기준을 적용하는 데 사용되는 **where** 메서드의 소스 DataFrame이 됩니다.

### DataFrame에서 데이터 집계 및 그룹화

1.  Notebook에 새 코드 셀을 추가하고 다음 코드를 입력합니다:

    ```Python
    productSales = df.select("Item", "Quantity").groupBy("Item").sum()
    display(productSales)
    ```

2.  추가한 코드 셀을 실행하고 결과가 제품별 주문 수량 합계를 보여주는지 확인합니다. **groupBy** 메서드는 *Item*별로 행을 그룹화하고, 후속 **sum** 집계 함수는 나머지 모든 숫자 열(이 경우 *Quantity*)에 적용됩니다.

3.  Notebook에 다른 새 코드 셀을 추가하고 다음 코드를 입력합니다:

    ```Python
    yearlySales = df.select(year("OrderDate").alias("Year")).groupBy("Year").count().orderBy("Year")
    display(yearlySales)
    ```

4.  추가한 코드 셀을 실행하고 결과가 연도별 판매 주문 수를 보여주는지 확인합니다. **select** 메서드에는 *OrderDate* 필드의 연도 구성 요소를 추출하는 SQL **year** 함수가 포함되어 있으며, 그런 다음 **alias** 메서드를 사용하여 추출된 연도 값에 열 이름을 할당합니다. 그런 다음 데이터를 파생된 *Year* 열로 그룹화하고 각 그룹의 행 수를 계산한 다음 마지막으로 **orderBy** 메서드를 사용하여 결과 DataFrame을 정렬합니다.

## Spark SQL을 사용하여 데이터 쿼리

보았듯이 DataFrame 객체의 기본 메서드를 사용하면 데이터를 매우 효과적으로 쿼리하고 분석할 수 있습니다. 그러나 많은 데이터 분석가들은 SQL 구문으로 작업하는 것을 더 편안하게 생각합니다. Spark SQL은 Spark의 SQL 언어 API로, SQL 문을 실행하거나 관계형 테이블에 데이터를 유지하는 데 사용할 수 있습니다.

### PySpark 코드에서 Spark SQL 사용

Azure Synapse Studio Notebook의 기본 언어는 Spark 기반 Python 런타임인 PySpark입니다. 이 런타임 내에서 **spark.sql** 라이브러리를 사용하여 Python 코드 내에 Spark SQL 구문을 포함하고 테이블 및 뷰와 같은 SQL 구문으로 작업할 수 있습니다.

1.  Notebook에 새 코드 셀을 추가하고 다음 코드를 입력합니다:

    ```Python
    df.createOrReplaceTempView("salesorders")

    spark_df = spark.sql("SELECT * FROM salesorders")
    display(spark_df)
    ```

2.  셀을 실행하고 결과를 검토합니다. 다음을 확인하십시오:
    *   코드는 **df** DataFrame의 데이터를 **salesorders**라는 임시 뷰로 유지합니다. Spark SQL은 SQL 쿼리의 소스로 임시 뷰 또는 유지된 테이블 사용을 지원합니다.
    *   그런 다음 **spark.sql** 메서드를 사용하여 **salesorders** 뷰에 대해 SQL 쿼리를 실행합니다.
    *   쿼리 결과는 DataFrame에 저장됩니다.

### 셀에서 SQL 코드 실행

PySpark 코드가 포함된 셀에 SQL 문을 포함할 수 있는 것은 유용하지만, 데이터 분석가들은 종종 SQL로 직접 작업하기를 원합니다.

1.  Notebook에 새 코드 셀을 추가하고 다음 코드를 입력합니다:

    ```sql
    %%sql
    SELECT YEAR(OrderDate) AS OrderYear,
           SUM((UnitPrice * Quantity) + Tax) AS GrossRevenue
    FROM salesorders
    GROUP BY YEAR(OrderDate)
    ORDER BY OrderYear;
    ```

2.  셀을 실행하고 결과를 검토합니다. 다음을 확인하십시오:
    *   셀 시작 부분의 `%%sql` 줄(*매직(magic)*이라고 함)은 이 셀의 코드를 실행하는 데 PySpark 대신 Spark SQL 언어 런타임을 사용해야 함을 나타냅니다.
    *   SQL 코드는 이전에 PySpark를 사용하여 만든 **salesorder** 뷰를 참조합니다.
    *   SQL 쿼리의 출력은 셀 아래 결과로 자동으로 표시됩니다.

> **참고**: Spark SQL 및 DataFrame에 대한 자세한 내용은 [Spark SQL 설명서](https://spark.apache.org/docs/2.2.0/sql-programming-guide.html)를 참조하십시오.

## Spark로 데이터 시각화

그림은 속담처럼 천 마디 말의 가치가 있으며, 차트는 종종 천 줄의 데이터보다 낫습니다. Azure Synapse Analytics의 Notebook에는 DataFrame 또는 Spark SQL 쿼리에서 표시되는 데이터에 대한 기본 제공 차트 뷰가 포함되어 있지만 포괄적인 차트 작성용으로 설계되지 않았습니다. 그러나 **matplotlib** 및 **seaborn**과 같은 Python 그래픽 라이브러리를 사용하여 DataFrame의 데이터로 차트를 만들 수 있습니다.

### 결과를 차트로 보기

1.  Notebook에 새 코드 셀을 추가하고 다음 코드를 입력합니다:

    ```sql
    %%sql
    SELECT * FROM salesorders
    ```

2.  코드를 실행하고 이전에 만든 **salesorders** 뷰의 데이터를 반환하는지 확인합니다.
3.  셀 아래 결과 섹션에서 **View** 옵션을 **Table**에서 **Chart**로 변경합니다.
4.  차트 오른쪽 상단의 **View options** 버튼을 사용하여 차트의 옵션 창을 표시합니다. 그런 다음 옵션을 다음과 같이 설정하고 **Apply**를 선택합니다:
    *   **Chart type**: Bar chart
    *   **Key**: Item
    *   **Values**: Quantity
    *   **Series Group**: *비워 둡니다*
    *   **Aggregation**: Sum
    *   **Stacked**: *선택 해제*

5.  차트가 다음과 유사한지 확인합니다:

    ![제품별 총 주문 수량 막대 차트](./images/notebook-chart.png)

### **matplotlib** 시작하기

1.  Notebook에 새 코드 셀을 추가하고 다음 코드를 입력합니다:

    ```Python
    sqlQuery = "SELECT CAST(YEAR(OrderDate) AS CHAR(4)) AS OrderYear, \
                    SUM((UnitPrice * Quantity) + Tax) AS GrossRevenue \
                FROM salesorders \
                GROUP BY CAST(YEAR(OrderDate) AS CHAR(4)) \
                ORDER BY OrderYear"
    df_spark = spark.sql(sqlQuery)
    df_spark.show()
    ```

2.  코드를 실행하고 연간 수익을 포함하는 Spark DataFrame을 반환하는지 확인합니다.

    데이터를 차트로 시각화하기 위해 **matplotlib** Python 라이브러리를 사용하여 시작하겠습니다. 이 라이브러리는 다른 많은 라이브러리의 기반이 되는 핵심 플로팅 라이브러리이며 차트 생성에 뛰어난 유연성을 제공합니다.

3.  Notebook에 새 코드 셀을 추가하고 다음 코드를 추가합니다:

    ```Python
    from matplotlib import pyplot as plt

    # matplotlib에는 Spark DataFrame이 아닌 Pandas DataFrame이 필요합니다.
    df_sales = df_spark.toPandas()

    # 연도별 수익 막대 그래프 만들기
    plt.bar(x=df_sales['OrderYear'], height=df_sales['GrossRevenue'])

    # 그래프 표시
    plt.show()
    ```

4.  셀을 실행하고 결과를 검토합니다. 결과는 각 연도의 총 매출액을 나타내는 세로 막대형 차트로 구성됩니다. 이 차트를 생성하는 데 사용된 코드의 다음 기능을 확인하십시오:
    *   **matplotlib** 라이브러리에는 *Pandas* DataFrame이 필요하므로 Spark SQL 쿼리에서 반환된 *Spark* DataFrame을 이 형식으로 변환해야 합니다.
    *   **matplotlib** 라이브러리의 핵심에는 **pyplot** 객체가 있습니다. 이것은 대부분의 플로팅 기능의 기초입니다.
    *   기본 설정으로 사용 가능한 차트가 생성되지만 사용자 정의할 수 있는 범위가 상당히 넓습니다.

5.  다음과 같이 차트를 플로팅하도록 코드를 수정합니다:

    ```Python
    # 플롯 영역 지우기
    plt.clf()

    # 연도별 수익 막대 그래프 만들기
    plt.bar(x=df_sales['OrderYear'], height=df_sales['GrossRevenue'], color='orange')

    # 차트 사용자 정의
    plt.title('Revenue by Year')
    plt.xlabel('Year')
    plt.ylabel('Revenue')
    plt.grid(color='#95a5a6', linestyle='--', linewidth=2, axis='y', alpha=0.7)
    plt.xticks(rotation=45)

    # 그림 표시
    plt.show()
    ```

6.  코드 셀을 다시 실행하고 결과를 확인합니다. 이제 차트에 약간의 정보가 더 포함됩니다.

    플롯은 기술적으로 **Figure** 내에 포함됩니다. 이전 예에서는 그림이 암시적으로 생성되었지만 명시적으로 만들 수 있습니다.

7.  다음과 같이 차트를 플로팅하도록 코드를 수정합니다:

    ```Python
    # 플롯 영역 지우기
    plt.clf()

    # Figure 만들기
    fig = plt.figure(figsize=(8,3))

    # 연도별 수익 막대 그래프 만들기
    plt.bar(x=df_sales['OrderYear'], height=df_sales['GrossRevenue'], color='orange')

    # 차트 사용자 정의
    plt.title('Revenue by Year')
    plt.xlabel('Year')
    plt.ylabel('Revenue')
    plt.grid(color='#95a5a6', linestyle='--', linewidth=2, axis='y', alpha=0.7)
    plt.xticks(rotation=45)

    # 그림 표시
    plt.show()
    ```

8.  코드 셀을 다시 실행하고 결과를 확인합니다. 그림은 플롯의 모양과 크기를 결정합니다.

    그림에는 각각 자체 *축(axis)*에 여러 하위 플롯이 포함될 수 있습니다.

9.  다음과 같이 차트를 플로팅하도록 코드를 수정합니다:

    ```Python
    # 플롯 영역 지우기
    plt.clf()

    # 2개의 하위 플롯(1행, 2열)용 그림 만들기
    fig, ax = plt.subplots(1, 2, figsize = (10,4))

    # 첫 번째 축에 연도별 수익 막대 그래프 만들기
    ax[0].bar(x=df_sales['OrderYear'], height=df_sales['GrossRevenue'], color='orange')
    ax[0].set_title('Revenue by Year')

    # 두 번째 축에 연간 주문 수 파이 차트 만들기
    yearly_counts = df_sales['OrderYear'].value_counts()
    ax[1].pie(yearly_counts)
    ax[1].set_title('Orders per Year')
    ax[1].legend(yearly_counts.keys().tolist())

    # Figure에 제목 추가
    fig.suptitle('Sales Data')

    # 그림 표시
    plt.show()
    ```

10. 코드 셀을 다시 실행하고 결과를 확인합니다. 그림에는 코드에 지정된 하위 플롯이 포함됩니다.

> **참고**: matplotlib로 플로팅하는 방법에 대한 자세한 내용은 [matplotlib 설명서](https://matplotlib.org/)를 참조하십시오.

### **seaborn** 라이브러리 사용

**matplotlib**을 사용하면 여러 유형의 복잡한 차트를 만들 수 있지만 최상의 결과를 얻으려면 복잡한 코드가 필요할 수 있습니다. 이러한 이유로 수년에 걸쳐 matplotlib의 복잡성을 추상화하고 기능을 향상시키기 위해 matplotlib를 기반으로 많은 새로운 라이브러리가 만들어졌습니다. 이러한 라이브러리 중 하나가 **seaborn**입니다.

1.  Notebook에 새 코드 셀을 추가하고 다음 코드를 입력합니다:

    ```Python
    import seaborn as sns

    # 플롯 영역 지우기
    plt.clf()

    # 막대 차트 만들기
    ax = sns.barplot(x="OrderYear", y="GrossRevenue", data=df_sales)
    plt.show()
    ```

2.  코드를 실행하고 seaborn 라이브러리를 사용하여 막대 차트를 표시하는지 확인합니다.
3.  Notebook에 새 코드 셀을 추가하고 다음 코드를 입력합니다:

    ```Python
    # 플롯 영역 지우기
    plt.clf()

    # seaborn용 시각적 테마 설정
    sns.set_theme(style="whitegrid")

    # 막대 차트 만들기
    ax = sns.barplot(x="OrderYear", y="GrossRevenue", data=df_sales)
    plt.show()
    ```

4.  코드를 실행하고 seaborn을 사용하면 플롯에 일관된 색상 테마를 설정할 수 있는지 확인합니다.

5.  Notebook에 새 코드 셀을 추가하고 다음 코드를 입력합니다:

    ```Python
    # 플롯 영역 지우기
    plt.clf()

    # 선 차트 만들기
    ax = sns.lineplot(x="OrderYear", y="GrossRevenue", data=df_sales)
    plt.show()
    ```

6.  코드를 실행하여 연간 수익을 선 차트로 확인합니다.

> **참고**: seaborn으로 플로팅하는 방법에 대한 자세한 내용은 [seaborn 설명서](https://seaborn.pydata.org/index.html)를 참조하십시오.

## Azure 리소스 삭제

Azure Synapse Analytics 탐색을 마쳤으면 불필요한 Azure 비용을 피하기 위해 생성한 리소스를 삭제해야 합니다.

1.  Synapse Studio 브라우저 탭을 닫고 Azure portal로 돌아갑니다.
2.  Azure portal의 **Home** 페이지에서 **Resource groups**를 선택합니다.
3.  Synapse Analytics 작업 영역에 대한 **dp203-*xxxxxxx*** 리소스 그룹(관리형 리소스 그룹이 아님)을 선택하고 여기에 Synapse 작업 영역, 스토리지 계정 및 작업 영역용 Spark pool이 포함되어 있는지 확인합니다.
4.  리소스 그룹의 **Overview** 페이지 상단에서 **Delete resource group**을 선택합니다.
5.  **dp203-*xxxxxxx*** 리소스 그룹 이름을 입력하여 삭제할 것인지 확인하고 **Delete**를 선택합니다.

    몇 분 후 Azure Synapse 작업 영역 리소스 그룹과 이와 연결된 관리형 작업 영역 리소스 그룹이 삭제됩니다.
