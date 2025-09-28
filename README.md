**Telegram @IBM2702**

# Развёртываем Trino & AWS S3 & Yandex Cloud Storage on Apache Hive Metastore w Postgres

## Запускаем контейнер Trino<br> и организуем доступ к S3-хранилищам AWS и Яндекс-облаке
Шаги:
- в AWS S3 создать папку `awstrino`
- создать ключ доступа IAM / Users / <пользователь> / Security Credentials / Create Access Key
- в файле `.env_template` заполнить 
```
AWS3_ACCESS_KEY=
AWS3_SECRET_KEY=
AWS3_REGION=
```
- Yandex Cloud console / Object Storage / Бакеты / **создать бакет** `ysrtino`
- Identity and Access Management / Сервисные аккаунты / <`ваш аккаунт с ролью минимум storage admin`> / Создать новый ключ / **Статический ключ доступа**
- в файле `.env_template` **заполнить ключами и регионом**
```
YS3_ACCESS_KEY=
YS3_SECRET_KEY=
YS3_REGION=
YS3_ENDPOINT=https://storage.yandexcloud.net
```
- Переименовать `.env_template` в `env`
- в файле metastore/hive-yc-site.xml_template **вписать ключи и регион**
```
 <property>
    <name>fs.s3a.region</name>
    <value>...............</value>
  </property> 

  <property>
    <name>fs.s3a.access.key</name>
    <value>...........................</value>
  </property>
  <property>
    <name>fs.s3a.secret.key</name>
    <value>.....................</value>
  </property>
```
- переименовать `hive-yc-site.xml_template` в `hive-yc-site.xml`

### Для этапа разработки включено подробное логирование. <br>Надо создать папки и назначить владельца

- `mkdir -p logs`
- `mkdir -p logs/pg_aws_logs && sudo chown -R 999:999 logs/pg_aws_logs`
- `mkdir -p logs/pg_yc_logs && sudo chown -R 999:999 logs/pg_yc_logs`

Необходимо отметить, что конфигурация проекта ***очень*** чувствительна к версиям образов контейнеров и JAR <br>
*Например, последняя на 28.09.2025 apache/hive версия 4.1.0 содержала критический баг*<br>
**JAR**ы должны соответствовать друг другу, поэтому всё это хозяйство лучше сразу не менять на более свежeе - **утомитесь** вылавливать ошибки<br>

### Создаем папку jars (если не существует)
- `mkdir -p ./jars`

### Скачиваем aws-java-sdk-bundle-1.12.765.jar
- `wget -P ./jars https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.765/aws-java-sdk-bundle-1.12.765.jar`

### Скачиваем hadoop-aws-3.3.6.jar
- `wget -P ./jars https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.6/hadoop-aws-3.3.6.jar`

### Скачиваем postgresql-42.7.8.jar
- `wget -P ./jars https://jdbc.postgresql.org/download/postgresql-42.7.8.jar`

<hr>

### Запустите контейнеры
- ***docker compose up -d***
### Войдите в CLI TRINO контейнера **trino-coordinator-container**
- ***docker exec -it trino-coordinator-container trino***
### Выведите список каталогов
- *trino>* `show catalogs;`

```
    Catalog    
--------------
 aws3_catalog 
 system       
 tpcds        
 tpch         
 ys3_catalog  
(5 rows)
```
Имена каталогов - это имена файлов .properties в ***etc/catalog*** <br>(*Прим. Символ '-' в имени каталога недопустим, пользуем '_'*)<br>
`ls -l etc/catalog`
```
-rw-r--r-- 1 naeel naeel 1638 Sep 28 10:45 aws3_catalog.properties
-rw-r--r-- 1 naeel naeel   44 Sep 25 17:11 tpcds.properties
-rw-r--r-- 1 naeel naeel   42 Sep 25 17:11 tpch.properties
-rw-r--r-- 1 naeel naeel 1653 Sep 28 11:06 ys3_catalog.properties
```
- Про **tpcds**  https://github.com/Repinoid/Trinoid/blob/main/TPCDS.md
- Про **tpch** https://github.com/Repinoid/Trinoid/blob/main/TPCH.md
<hr>

### Создание схемы mini в каталоге aws3_catalog 
```
CREATE SCHEMA aws3_catalog.mini WITH (location = 's3a://awstrino/');
```
`s3a://awstrino/` - это привязка к созданному вами бакету в AWS `awstrino` <br>
Удостоверяемся:<br>
*trino>* `show schemas from aws3_catalog;`
```
       Schema       
--------------------
 default            
 information_schema 
 mini
(3 rows)
```
### Создадим таблицу client в схеме mini каталога aws3_catalog,<br>это копия 10 строк таблицы tpch.tiny.customer
```
CREATE TABLE aws3_catalog.mini.client
WITH (
    format = 'ORC',
    external_location = 's3a://awstrino/customer/'
) 
AS SELECT * FROM tpch.tiny.customer limit 10;
```
Проверим:
- trino> `select * from aws3_catalog.mini.client;`
<br>Получим подобное
```
 custkey |        name        |               address                | nationkey |      phone      | acctbal | mktsegment |                                                   comment                                        >
---------+--------------------+--------------------------------------+-----------+-----------------+---------+------------+-------------------------------------------------------------------------------------------------->
     751 | Customer#000000751 | e OSrreG6sx7l1t3wAg8u11DWk D 9       |         0 | 10-658-550-2257 | 2130.98 | FURNITURE  | ges sleep furiously bold deposits. furiously regular requests cajole slyly. unusual accounts nag >
     752 | Customer#000000752 | KtdEacPUecPdPLt99kwZrnH9oIxUxpw      |         8 | 18-924-993-6038 | 8363.66 | MACHINERY  | mong the ironic, final waters. regular deposits above the fluffily ironic instructions           >
     753 | Customer#000000753 | 9k2PLlDRbMq4oSvW5Hh7Ak5iRDH          |        17 | 27-817-126-3646 | 8114.44 | HOUSEHOLD  | cies. deposits snooze. final, regular excuses wake furiously about the furiously final foxes. dep>
     754 | Customer#000000754 | 8r5wwhhlL9MkAxOhRK                   |         0 | 10-646-595-5871 | -566.86 | BUILDING   | er regular accounts against the furiously unusual somas sleep carefull                           >
     755 | Customer#000000755 | F2YYbRT2EV                           |        16 | 26-395-247-2207 | 7631.94 | HOUSEHOLD  | xpress instructions breach; pending request                                                      >
     756 | Customer#000000756 | Lv7cG by4Wyd8Hzmumwp8hSIZg9          |        14 | 24-267-298-7503 | 8116.99 | AUTOMOBILE | ly unusual deposits. fluffily express deposits nag blithely above the silent, even instructions. >
     757 | Customer#000000757 | VFnouow3LhLvEDy                      |         3 | 13-704-408-2991 | 9334.82 | AUTOMOBILE | riously furiously unusual asymptotes. slyly                                                      >
     758 | Customer#000000758 | 8fJLXfS5Zup0GQ3xBKL3eAC Q            |        17 | 27-175-799-9168 | 6352.14 | HOUSEHOLD  | eposits. blithely unusual deposits affix care                                                    >
     759 | Customer#000000759 | IX1uj4NFhOmu0V xDtiYzHVzWfi8bl,5EHtJ |         1 | 11-731-806-1019 | 3477.59 | FURNITURE  | above the quickly pending requests nag final, ex                                                 >
     760 | Customer#000000760 | jp8DYJ7GPQSDQC                       |         2 | 12-176-116-3113 | 2883.24 | BUILDING   | uriously alongside of the ironic deposits. slyly thin pinto beans a                              >
(10 rows)
```
### Создание схемы schematoz в каталоге ys3_catalog 
```
CREATE SCHEMA ys3_catalog.schematoz WITH (location = 's3a://ystrino/');
```
`s3a://ystrino/` - это привязка к созданному вами бакету в Yandex Cloud `ystrino` <br>
Удостоверяемся:<br>
*trino>* `show schemas from ys3_catalog;`
```
       Schema       
--------------------
 default            
 information_schema 
 schematoz
(3 rows)
```
### Создадим таблицу tablo в схеме schematoz каталога ys3_catalog, это копия трёх строк <br>созданной на предыдущем шаге таблицы aws3_catalog.mini.client
```
CREATE TABLE ys3_catalog.schematoz.tablo
WITH (
    format = 'ORC',
    external_location = 's3a://ystrino/customer/'
) 
AS SELECT * FROM aws3_catalog.mini.client limit 3;
```
Делаем запрос:
trino> `select * from ys3_catalog.schematoz.tablo;`
```
 custkey |        name        |             address             | nationkey |      phone      | acctbal | mktsegment |                                                   comment                                             >
---------+--------------------+---------------------------------+-----------+-----------------+---------+------------+------------------------------------------------------------------------------------------------------->
     751 | Customer#000000751 | e OSrreG6sx7l1t3wAg8u11DWk D 9  |         0 | 10-658-550-2257 | 2130.98 | FURNITURE  | ges sleep furiously bold deposits. furiously regular requests cajole slyly. unusual accounts nag unusu>
     752 | Customer#000000752 | KtdEacPUecPdPLt99kwZrnH9oIxUxpw |         8 | 18-924-993-6038 | 8363.66 | MACHINERY  | mong the ironic, final waters. regular deposits above the fluffily ironic instructions                >
     753 | Customer#000000753 | 9k2PLlDRbMq4oSvW5Hh7Ak5iRDH     |        17 | 27-817-126-3646 | 8114.44 | HOUSEHOLD  | cies. deposits snooze. final, regular excuses wake furiously about the furiously final foxes. dependen>
(3 rows)
```
Через консоль AWS (или, например, S3 Browser) посмотрите бакет `awstrino` <br><br>
В нём появилась папка `customer`, в ней файл с именем типа `20250928_135333_00004_3bwb7_13a87dce-4f11-4cb0-87e4-2032947f948b`<br><br>
В Yandex Cloud Storage также изменения, появился файл `customer/20250928_140259_00008_3bwb7_c3e591a2-609d-4b15-b717-143098f8c2c5`<br><br>
Это - образы созданных таблиц. <br>
Структура же таблиц и прочая информация хранится в постгрес-базах Metastore<br>

Через SQL запросы в Trino можно работать с S3-хранилищами как с обычными БД<br><br>
Можно ещё и Minio подключить,<br>но ***цель проекта - сделать рабочую конфигурацию с TRINO для AWS S3 & Yandex Cloud Storage***<hr>

`docker compose down` удалит все контейнеры, таблицы же сохранятся на хосте<br>
`docker compose up` всё восстановит<br>
`docker compose down -v ` удалит и тома<br>
Но - бакеты с файлами в S3 останутся<br>
Восстановить из них БД и таблицы можно, но фактически вручную создавая структуру<br><br>

Засим,<br>
пишите в Телегу **@IBM2702**