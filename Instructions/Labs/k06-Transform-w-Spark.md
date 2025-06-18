---
lab:
    title: 'Synapse Analytics에서 Spark를 사용하여 데이터 변환'
    ilt-use: '실습'
---

# Synapse Analytics에서 Spark를 사용하여 데이터 변환

데이터 *엔지니어*는 종종 Spark Notebook을 선호하는 도구 중 하나로 사용하여 데이터를 한 형식이나 구조에서 다른 형식이나 구조로 변환하는 *추출, 변환, 로드(ETL)* 또는 *추출, 로드, 변환(ELT)* 활동을 수행합니다.

이 실습에서는 Azure Synapse Analytics의 Spark Notebook을 사용하여 파일의 데이터를 변환합니다.

이 실습을 완료하는 데 약 **30**분이 소요됩니다.

## 시작하기 전에

관리자 수준 액세스 권한이 있는 [Azure 구독](https://azure.microsoft.com/free)이 필요합니다.

## Azure Synapse Analytics 작업 영역 프로비저닝

데이터 레이크 스토리지 및 Spark pool에 액세스할 수 있는 Azure Synapse Analytics 작업 영역이 필요합니다.

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
    cd dp-203/Allfiles/labs/06
    ./setup.ps1
    ```

6.  메시지가 표시되면 사용할 구독을 선택합니다 (여러 Azure 구독에 액세스할 수 있는 경우에만 발생합니다).
7.  메시지가 표시되면 Azure Synapse SQL pool에 설정할 적절한 암호를 입력합니다.

    > **참고**: 이 암호를 반드시 기억하십시오!

8.  스크립트가 완료될 때까지 기다리십시오. 일반적으로 약 10분 정도 걸리지만 경우에 따라 더 오래 걸릴 수 있습니다. 기다리는 동안 Azure Synapse Analytics 설명서의 [Azure Synapse Analytics의 Apache Spark 핵심 개념](https://learn.microsoft.com/azure/synapse-analytics/spark/apache-spark-concepts) 문서를 검토하십시오.

## Spark Notebook을 사용하여 데이터 변환

1.  배포 스크립트가 완료된 후 Azure portal에서 스크립트가 생성한 **dp203-*xxxxxxx*** 리소스 그룹으로 이동하여 이 리소스 그룹에 Synapse 작업 영역, 데이터 레이크용 Storage account 및 Apache Spark pool이 포함되어 있는지 확인합니다.
2.  Synapse 작업 영역을 선택하고 **Overview** 페이지의 **Open Synapse Studio** 카드에서 **Open**을 선택하여 새 브라우저 탭에서 Synapse Studio를 엽니다. 메시지가 표시되면 로그인합니다.
3.  Synapse Studio 왼쪽에서 **&rsaquo;&rsaquo;** 아이콘을 사용하여 메뉴를 확장합니다. 이렇게 하면 리소스를 관리하고 데이터 분석 작업을 수행하는 데 사용할 Synapse Studio 내의 여러 페이지가 표시됩니다.
4.  **Manage** 페이지에서 **Apache Spark pools** 탭을 선택하고 **spark*xxxxxxx***와 유사한 이름의 Spark pool이 작업 영역에 프로비저닝되었는지 확인합니다.
5.  **Data** 페이지에서 **Linked** 탭을 보고 작업 영역에 Azure Data Lake Storage Gen2 스토리지 계정에 대한 링크가 포함되어 있는지 확인합니다. 이 계정의 이름은 **synapse*xxxxxxx* (Primary - datalake*xxxxxxx*)**와 유사해야 합니다.
6.  스토리지 계정을 확장하고 **files (Primary)**라는 파일 시스템 컨테이너가 포함되어 있는지 확인합니다.
7.  **files** 컨테이너를 선택하고 **data** 및 **synapse**라는 폴더가 포함되어 있는지 확인합니다. synapse 폴더는 Azure Synapse에서 사용되며, **data** 폴더에는 쿼리할 데이터 파일이 들어 있습니다.
8.  **data** 폴더를 열고 3년 치 판매 데이터에 대한 .csv 파일이 포함되어 있는지 확인합니다.
9.  파일 중 하나를 마우스 오른쪽 버튼으로 클릭하고 **Preview**를 선택하여 포함된 데이터를 확인합니다. 파일에 헤더 행이 포함되어 있으므로 열 헤더 표시 옵션을 선택할 수 있습니다.
10. 미리보기를 닫습니다. 그런 다음 [Allfiles/labs/06/notebooks](https://github.com/MicrosoftLearning/dp-203-azure-data-engineer/tree/master/Allfiles/labs/06/notebooks)에서 **Spark Transform.ipynb**를 다운로드합니다.

    > **참고**: 이 텍스트를 ***ctrl+a***로 전체 선택한 후 ***ctrl+c***로 복사하여 메모장과 같은 도구에 ***ctrl+v***로 붙여넣은 다음, 파일 형식을 ***all files***로 지정하여 **Spark Transform.ipynb**로 저장하는 것이 가장 좋습니다. 파일을 클릭한 다음 줄임표(...)를 선택하고 다운로드를 선택하여 파일을 다운로드할 수도 있으며, 저장 위치를 기억하십시오.
    ![GitHub에서 Spark Notebook 다운로드](./images/select-download-notebook.png)

11. 그런 다음 **Develop** 페이지에서 **Notebooks**를 확장하고 **+ Import** 옵션을 클릭합니다.

    ![Spark Notebook 가져오기](./images/spark-notebook-import.png)
        
12. 방금 다운로드하여 **Spark Transform.ipynb**로 저장한 파일을 선택합니다.
13. Notebook을 **spark*xxxxxxx*** Spark pool에 연결합니다.
14. Notebook의 메모를 검토하고 코드 셀을 실행합니다.

    > **참고**: 첫 번째 코드 셀은 Spark pool을 시작해야 하므로 실행하는 데 몇 분 정도 걸립니다. 이후 셀은 더 빨리 실행됩니다.

## Azure 리소스 삭제

Azure Synapse Analytics 탐색을 마쳤으면 불필요한 Azure 비용을 피하기 위해 생성한 리소스를 삭제해야 합니다.

1.  Synapse Studio 브라우저 탭을 닫고 Azure portal로 돌아갑니다.
2.  Azure portal의 **Home** 페이지에서 **Resource groups**를 선택합니다.
3.  Synapse Analytics 작업 영역에 대한 **dp203-*xxxxxxx*** 리소스 그룹(관리형 리소스 그룹이 아님)을 선택하고 여기에 Synapse 작업 영역, 스토리지 계정 및 작업 영역용 Spark pool이 포함되어 있는지 확인합니다.
4.  리소스 그룹의 **Overview** 페이지 상단에서 **Delete resource group**을 선택합니다.
5.  **dp203-*xxxxxxx*** 리소스 그룹 이름을 입력하여 삭제할 것인지 확인하고 **Delete**를 선택합니다.

    몇 분 후 Azure Synapse 작업 영역 리소스 그룹과 이와 연결된 관리형 작업 영역 리소스 그룹이 삭제됩니다.
