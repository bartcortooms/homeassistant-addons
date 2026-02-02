# Home Assistant Add-ons

Custom add-ons for Home Assistant.

## Add-ons

### Litestream SQLite Backup

Continuously replicate your Home Assistant SQLite database to cloud storage (GCS, S3).

## Installation

1. In Home Assistant, go to **Settings → Add-ons → Add-on Store**
2. Click the three dots (top right) → **Repositories**
3. Add this repository URL: `https://github.com/bartcortooms/homeassistant-addons`
4. Find "Litestream SQLite Backup" and install it
5. Configure your cloud storage credentials
6. Start the add-on

## Restoring & Analyzing Your Data

### Install Litestream

```bash
# Linux (amd64)
wget https://github.com/benbjohnson/litestream/releases/download/v0.3.13/litestream-v0.3.13-linux-amd64.tar.gz
tar -xzf litestream-v0.3.13-linux-amd64.tar.gz
sudo mv litestream /usr/local/bin/
```

### Restore Database from Backup

```bash
# For GCS
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/credentials.json
litestream restore -o ha-restored.db gcs://your-bucket/home-assistant

# For S3
export AWS_ACCESS_KEY_ID=your-key
export AWS_SECRET_ACCESS_KEY=your-secret
litestream restore -o ha-restored.db s3://your-bucket/home-assistant
```

### Analyze with DuckDB

DuckDB can query SQLite databases directly without importing:

```bash
pip install duckdb
duckdb
```

```sql
-- Attach the restored database
INSTALL sqlite;
LOAD sqlite;
ATTACH 'ha-restored.db' AS ha (TYPE sqlite);

-- List all entities
SELECT entity_id FROM ha.main.states_meta ORDER BY entity_id;

-- Recent sensor readings
SELECT
    m.entity_id,
    s.state,
    to_timestamp(s.last_updated_ts) as timestamp
FROM ha.main.states s
JOIN ha.main.states_meta m ON s.metadata_id = m.metadata_id
WHERE m.entity_id LIKE 'sensor.%'
  AND s.state NOT IN ('unavailable', 'unknown')
ORDER BY s.last_updated_ts DESC
LIMIT 20;

-- Hourly averages for a sensor
SELECT
    date_trunc('hour', to_timestamp(s.last_updated_ts)) as hour,
    ROUND(AVG(TRY_CAST(s.state AS DOUBLE)), 1) as avg_value
FROM ha.main.states s
JOIN ha.main.states_meta m ON s.metadata_id = m.metadata_id
WHERE m.entity_id = 'sensor.your_sensor_name'
  AND TRY_CAST(s.state AS DOUBLE) IS NOT NULL
GROUP BY hour
ORDER BY hour DESC
LIMIT 24;

-- Export to CSV
COPY (
    SELECT
        m.entity_id,
        to_timestamp(s.last_updated_ts) as timestamp,
        TRY_CAST(s.state AS DOUBLE) as value
    FROM ha.main.states s
    JOIN ha.main.states_meta m ON s.metadata_id = m.metadata_id
    WHERE m.entity_id LIKE 'sensor.%temperature%'
      AND TRY_CAST(s.state AS DOUBLE) IS NOT NULL
) TO 'temperatures.csv' (HEADER, DELIMITER ',');
```

### Explore with Datasette

Datasette provides a web UI for exploring SQLite databases.

#### Basic Setup

```bash
pip install datasette
datasette ha-restored.db
```

Then open http://localhost:8001 in your browser.

#### With Visualizations

Install plugins for charts and dashboards:

```bash
pip install datasette datasette-vega datasette-dashboards
```

Create a `metadata.yaml` file with pre-built queries and dashboards:

```yaml
title: Home Assistant Data Explorer

settings:
  sql_time_limit_ms: 30000

plugins:
  datasette-dashboards:
    temperature-dashboard:
      title: Temperature Dashboard
      layout:
        - [temp-chart]
      charts:
        temp-chart:
          title: Temperature (24h)
          db: ha-restored
          query: |
            SELECT
              datetime(s.last_updated_ts, 'unixepoch', 'localtime') as timestamp,
              CAST(s.state AS REAL) as temperature
            FROM states s
            JOIN states_meta m ON s.metadata_id = m.metadata_id
            WHERE m.entity_id = 'sensor.your_temperature_sensor'
              AND s.state NOT IN ('unavailable', 'unknown', '')
              AND s.last_updated_ts > (strftime('%s', 'now') - 24*3600)
            ORDER BY s.last_updated_ts
          library: vega-lite
          display:
            mark: line
            encoding:
              x: {field: timestamp, type: temporal, title: Time}
              y: {field: temperature, type: quantitative, title: "°C", scale: {zero: false}}

databases:
  ha-restored:
    queries:
      sensor_history:
        title: Sensor History
        description: View history for any sensor
        sql: |
          SELECT
            datetime(s.last_updated_ts, 'unixepoch', 'localtime') as timestamp,
            CAST(s.state AS REAL) as value
          FROM states s
          JOIN states_meta m ON s.metadata_id = m.metadata_id
          WHERE m.entity_id = :entity_id
            AND s.state NOT IN ('unavailable', 'unknown', '')
            AND s.last_updated_ts > (strftime('%s', 'now') - :days*24*3600)
          ORDER BY s.last_updated_ts
        params:
          - entity_id
          - days
```

Run with metadata:

```bash
datasette ha-restored.db --metadata metadata.yaml --setting sql_time_limit_ms 30000
```

Access dashboards at: `http://localhost:8001/-/dashboards/`

## Database Schema

Key tables in the Home Assistant database:

| Table | Description |
|-------|-------------|
| `states` | All state changes (main sensor data) |
| `states_meta` | Entity ID to metadata_id mapping |
| `state_attributes` | Entity attributes (JSON) |
| `statistics` | Long-term statistics (hourly aggregates) |
| `statistics_short_term` | Short-term statistics (5-minute aggregates) |
| `statistics_meta` | Statistics metadata |

### Common Queries

**Find all your sensors:**
```sql
SELECT entity_id FROM states_meta WHERE entity_id LIKE 'sensor.%' ORDER BY entity_id;
```

**Get data range:**
```sql
SELECT
  datetime(MIN(last_updated_ts), 'unixepoch', 'localtime') as earliest,
  datetime(MAX(last_updated_ts), 'unixepoch', 'localtime') as latest,
  COUNT(*) as total_rows
FROM states;
```

**Daily aggregates:**
```sql
SELECT
  date(datetime(s.last_updated_ts, 'unixepoch', 'localtime')) as date,
  ROUND(AVG(CAST(s.state AS REAL)), 1) as avg,
  ROUND(MIN(CAST(s.state AS REAL)), 1) as min,
  ROUND(MAX(CAST(s.state AS REAL)), 1) as max
FROM states s
JOIN states_meta m ON s.metadata_id = m.metadata_id
WHERE m.entity_id = 'sensor.your_sensor'
  AND CAST(s.state AS REAL) IS NOT NULL
GROUP BY date
ORDER BY date DESC;
```
