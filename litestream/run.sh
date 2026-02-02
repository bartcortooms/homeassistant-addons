#!/usr/bin/with-contenv bashio

# Read configuration
REPLICA_TYPE=$(bashio::config 'replica_type')
BUCKET=$(bashio::config 'bucket')
PATH_PREFIX=$(bashio::config 'path')
SYNC_INTERVAL=$(bashio::config 'sync_interval')
RETENTION=$(bashio::config 'retention')
RETENTION_CHECK_INTERVAL=$(bashio::config 'retention_check_interval')

# Database path
DB_PATH="/config/home-assistant_v2.db"

# Check if database exists
if [ ! -f "$DB_PATH" ]; then
    bashio::log.error "Home Assistant database not found at $DB_PATH"
    exit 1
fi

bashio::log.info "Starting Litestream backup for Home Assistant database"
bashio::log.info "Replica type: ${REPLICA_TYPE}"
bashio::log.info "Bucket: ${BUCKET}"
bashio::log.info "Path: ${PATH_PREFIX}"

# Build replica configuration based on type
if [ "$REPLICA_TYPE" = "gcs" ]; then
    GCS_CREDS=$(bashio::config 'gcs_credentials_json')

    if [ -z "$GCS_CREDS" ]; then
        bashio::log.error "GCS credentials JSON is required for GCS replica type"
        exit 1
    fi

    # Write credentials to file
    echo "$GCS_CREDS" > /tmp/gcs-credentials.json
    export GOOGLE_APPLICATION_CREDENTIALS="/tmp/gcs-credentials.json"

    REPLICA_URL="gcs://${BUCKET}/${PATH_PREFIX}"

elif [ "$REPLICA_TYPE" = "s3" ]; then
    S3_ENDPOINT=$(bashio::config 's3_endpoint')
    S3_ACCESS_KEY=$(bashio::config 's3_access_key_id')
    S3_SECRET_KEY=$(bashio::config 's3_secret_access_key')
    S3_REGION=$(bashio::config 's3_region')

    if [ -z "$S3_ACCESS_KEY" ] || [ -z "$S3_SECRET_KEY" ]; then
        bashio::log.error "S3 access key and secret key are required for S3 replica type"
        exit 1
    fi

    export AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY"
    export AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY"

    REPLICA_URL="s3://${BUCKET}/${PATH_PREFIX}"
fi

# Create litestream configuration
cat > /tmp/litestream.yml << EOF
dbs:
  - path: ${DB_PATH}
    replicas:
      - type: ${REPLICA_TYPE}
        bucket: ${BUCKET}
        path: ${PATH_PREFIX}
        sync-interval: ${SYNC_INTERVAL}
        retention: ${RETENTION}
        retention-check-interval: ${RETENTION_CHECK_INTERVAL}
EOF

# Add S3-specific config
if [ "$REPLICA_TYPE" = "s3" ]; then
    S3_ENDPOINT=$(bashio::config 's3_endpoint')
    S3_REGION=$(bashio::config 's3_region')

    if [ -n "$S3_ENDPOINT" ]; then
        cat >> /tmp/litestream.yml << EOF
        endpoint: ${S3_ENDPOINT}
EOF
    fi

    if [ -n "$S3_REGION" ]; then
        cat >> /tmp/litestream.yml << EOF
        region: ${S3_REGION}
EOF
    fi
fi

bashio::log.info "Litestream configuration:"
cat /tmp/litestream.yml

bashio::log.info "Starting Litestream replication..."
exec /usr/local/bin/litestream replicate -config /tmp/litestream.yml
