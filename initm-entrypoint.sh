#!/bin/sh
set -e

DB_USER=${HIVE_METASTORE_USER}
DB_PASSWD=${HIVE_METASTORE_PASSWORD}

ERROR_OCCURRED=false

# Функция для проверки и инициализации схемы
init_schema() {
  local db_name=$1
  local db_host=$2
  
  echo "Checking $db_name database schema..."
  local schema_status=$(/opt/hive/bin/beeline -u jdbc:postgresql://${db_host}:5432/metastore -n "$DB_USER" -p "$DB_PASSWD" --showHeader=false --outputFormat=tsv2 -e "SELECT schemaname FROM pg_tables WHERE tablename = 'VERSION'" 2>/dev/null || echo "")
  
  if [ -z "${schema_status}" ]; then
    echo "$db_name schema has not been initialized yet. Initializing..."
    if /opt/hive/bin/schematool -initSchema \
      -dbType postgres \
      -userName "$DB_USER" \
      -passWord "$DB_PASSWD" \
      -url jdbc:postgresql://${db_host}:5432/metastore \
      -verbose; then
      echo "$db_name schema initialized successfully."
      return 0
    else
      echo "ERROR: $db_name schema initialization failed!"
      return 1
    fi
  else
    echo "$db_name schema is already initialized."
    return 0
  fi
}

# Инициализируем обе базы данных
if ! init_schema "AWS" "metastore-db-aws-service"; then
  ERROR_OCCURRED=true
fi

if ! init_schema "Yandex Cloud" "metastore-db-yc-service"; then
  ERROR_OCCURRED=true
fi

# Проверяем результат
if [ "$ERROR_OCCURRED" = true ]; then
  echo "One or more schema initializations failed!"
  exit 1
else
  echo "All database schemas are properly initialized!"
  exit 0
fi