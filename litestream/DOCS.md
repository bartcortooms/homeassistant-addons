# Litestream SQLite Backup

This add-on continuously replicates your Home Assistant SQLite database to cloud storage using [Litestream](https://litestream.io).

## Features

- **Continuous replication**: Changes are synced every 5 minutes (configurable)
- **Point-in-time recovery**: Restore your database to any point in time
- **Low cost**: ~$0.04/month for GCS with default settings
- **Supports**: Google Cloud Storage (GCS) and S3-compatible storage

## Configuration

### Google Cloud Storage (GCS)

1. Create a GCS bucket
2. Create a service account with `Storage Object Admin` role on the bucket
3. Download the JSON key file
4. Paste the entire JSON content into the `gcs_credentials_json` field

```yaml
replica_type: gcs
bucket: my-ha-backups
path: home-assistant
gcs_credentials_json: |
  {
    "type": "service_account",
    "project_id": "...",
    ...
  }
```

### Amazon S3 / S3-Compatible

For AWS S3:
```yaml
replica_type: s3
bucket: my-ha-backups
path: home-assistant
s3_access_key_id: AKIAIOSFODNN7EXAMPLE
s3_secret_access_key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
s3_region: us-east-1
```

For S3-compatible storage (MinIO, Backblaze B2, Wasabi, etc.):
```yaml
replica_type: s3
bucket: my-ha-backups
path: home-assistant
s3_endpoint: https://s3.us-west-001.backblazeb2.com
s3_access_key_id: your-key-id
s3_secret_access_key: your-secret-key
s3_region: us-west-001
```

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `replica_type` | `gcs` | Storage type: `gcs` or `s3` |
| `bucket` | (required) | Bucket name |
| `path` | `home-assistant` | Path prefix within bucket |
| `sync_interval` | `5m` | How often to sync changes |
| `retention` | `168h` | How long to keep WAL files (7 days) |
| `retention_check_interval` | `1h` | How often to clean up old WAL files |

**Note on durations:** Uses Go duration format - only `h` (hours), `m` (minutes), `s` (seconds) are supported. Days are not supported, use `168h` for 7 days.

### Cost Estimates (GCS)

| Sync Interval | Operations/month | Est. Cost |
|---------------|-----------------|-----------|
| 1s | 2,592,000 | ~$13/month |
| 1m | 43,200 | ~$0.22/month |
| 5m (default) | 8,640 | ~$0.04/month |

## Restoring from Backup

To restore your database from a backup:

1. Stop Home Assistant
2. Download and install Litestream locally
3. Run restore command:

```bash
# For GCS
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/credentials.json
litestream restore -o /path/to/restored.db gcs://bucket-name/home-assistant

# For S3
export AWS_ACCESS_KEY_ID=your-key
export AWS_SECRET_ACCESS_KEY=your-secret
litestream restore -o /path/to/restored.db s3://bucket-name/home-assistant
```

4. Replace your `home-assistant_v2.db` with the restored file
5. Restart Home Assistant

## Support

- [Litestream Documentation](https://litestream.io)
- [Home Assistant Community](https://community.home-assistant.io)
