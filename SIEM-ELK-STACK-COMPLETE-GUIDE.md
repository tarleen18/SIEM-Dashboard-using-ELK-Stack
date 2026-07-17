# 🔐 Complete SIEM Dashboard Guide Using ELK Stack with Docker

**A Beginner-to-Advanced Hands-On Guide**

---

## 📋 Table of Contents

1. [Project Overview](#project-overview)
2. [System Requirements](#system-requirements)
3. [Tools & Components](#tools--components)
4. [Phase 1: Foundation Setup](#phase-1-foundation-setup)
5. [Phase 2: Data Collection](#phase-2-data-collection)
6. [Phase 3: Dashboard Creation](#phase-3-dashboard-creation)
7. [Alerting Setup](#alerting-setup)
8. [Testing & Validation](#testing--validation)
9. [Troubleshooting](#troubleshooting)
10. [Learning Resources](#learning-resources)

---

## 🎯 Project Overview

### What is a SIEM Dashboard?
A **Security Information and Event Management (SIEM)** dashboard is a centralized platform that:
- Collects logs from multiple sources
- Processes and analyzes security data in real-time
- Visualizes security events and threats
- Triggers alerts for suspicious activities
- Provides forensic analysis capabilities

### What You'll Build
By following this guide, you'll create a fully functional SIEM system that:
✅ Collects logs from Linux systems using Filebeat
✅ Processes logs with Logstash pipelines
✅ Stores data in Elasticsearch
✅ Visualizes security metrics in Kibana
✅ Detects failed login attempts, SSH anomalies, and suspicious activities
✅ Generates automatic alerts for security events

---

## 📦 System Requirements

### Minimum Requirements
| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 2 cores | 4+ cores |
| RAM | 4 GB | 8+ GB |
| Storage | 20 GB | 50+ GB |
| OS | Linux/Windows/macOS | Ubuntu 20.04 LTS |
| Docker | 19.03+ | Latest stable |
| Docker Compose | 1.25+ | Latest stable |

### Network Requirements
- Port 9200: Elasticsearch (REST API)
- Port 9300: Elasticsearch (node communication)
- Port 5601: Kibana (web interface)
- Port 5044: Logstash (Beats input)
- Port 5000: Logstash (alternative input)

### Storage Considerations
- **Small setup (testing):** 20-30 GB
- **Medium setup (production):** 50-100 GB
- **Large setup (enterprise):** 100+ GB

**Tip:** Each GB of logs requires approximately 1.5x storage due to indexing overhead.

---

## 🛠 Tools & Components

### 1. **Elasticsearch**
- **Purpose:** Search and analytics engine that stores all logs
- **Role:** Central data repository
- **Version:** 8.x (latest stable)
- **Memory requirement:** 1-2 GB minimum

### 2. **Logstash**
- **Purpose:** Log processing and transformation pipeline
- **Role:** Parse, filter, and enrich logs before storage
- **Version:** 8.x (same as Elasticsearch)
- **Memory requirement:** 512 MB - 1 GB

### 3. **Kibana**
- **Purpose:** Data visualization and dashboard platform
- **Role:** Create dashboards and visualizations
- **Version:** 8.x (same as Elasticsearch)
- **Memory requirement:** 512 MB - 1 GB

### 4. **Filebeat**
- **Purpose:** Lightweight log shipper
- **Role:** Collect logs from systems and send to Logstash
- **Version:** 8.x
- **Memory requirement:** 50-100 MB

### 5. **Docker & Docker Compose**
- **Purpose:** Containerization platform
- **Benefit:** Easy deployment, isolation, consistency

### 6. **Additional Tools**
- **curl:** Command-line tool for testing APIs
- **jq:** JSON query processor (optional, for pretty output)

---

# Phase 1: Foundation Setup

## Step 1: Install Docker and Docker Compose

### On Ubuntu/Debian:

```bash
# Update system packages
sudo apt-get update && sudo apt-get upgrade -y

# Install Docker
sudo apt-get install -y docker.io

# Add current user to docker group (run Docker without sudo)
sudo usermod -aG docker $USER

# Apply new group membership
newgrp docker

# Install Docker Compose
sudo apt-get install -y docker-compose

# Verify installation
docker --version
docker-compose --version
```

### On Windows (using WSL2):

```powershell
# Install Docker Desktop for Windows
# Download from: https://docs.docker.com/desktop/install/windows-install/

# After installation, verify:
docker --version
docker-compose --version
```

### On macOS:

```bash
# Install using Homebrew
brew install docker docker-compose

# Start Docker Desktop application
# Then verify:
docker --version
docker-compose --version
```

---

## Step 2: Create Project Directory Structure

```bash
# Create main project directory
mkdir -p ~/siem-elk-stack
cd ~/siem-elk-stack

# Create subdirectories
mkdir -p elasticsearch/config
mkdir -p elasticsearch/data
mkdir -p kibana/config
mkdir -p logstash/config
mkdir -p logstash/pipeline
mkdir -p filebeat
mkdir -p sample-logs

# Set proper permissions
chmod 777 elasticsearch/data
```

---

## Step 3: Create Docker Compose Configuration

Create a file: `docker-compose.yml`

```yaml
version: '3.8'

services:
  # ==================== ELASTICSEARCH ====================
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
      - ELASTIC_PASSWORD=changeme
    ports:
      - "9200:9200"
      - "9300:9300"
    volumes:
      - ./elasticsearch/data:/usr/share/elasticsearch/data
      - ./elasticsearch/config/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml:ro
    networks:
      - siem-network
    healthcheck:
      test: curl -s http://localhost:9200 >/dev/null || exit 1
      interval: 10s
      timeout: 10s
      retries: 5
    restart: unless-stopped

  # ==================== KIBANA ====================
  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.0
    container_name: kibana
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      - ELASTICSEARCH_USERNAME=elastic
      - ELASTICSEARCH_PASSWORD=changeme
      - XPACK_SECURITY_ENABLED=false
    ports:
      - "5601:5601"
    depends_on:
      elasticsearch:
        condition: service_healthy
    networks:
      - siem-network
    healthcheck:
      test: curl -s http://localhost:5601/api/status >/dev/null || exit 1
      interval: 10s
      timeout: 10s
      retries: 5
    restart: unless-stopped

  # ==================== LOGSTASH ====================
  logstash:
    image: docker.elastic.co/logstash/logstash:8.11.0
    container_name: logstash
    environment:
      - "LS_JAVA_OPTS=-Xmx256m -Xms256m"
    ports:
      - "5044:5044"
      - "5000:5000"
      - "9600:9600"
    volumes:
      - ./logstash/pipeline:/usr/share/logstash/pipeline:ro
      - ./logstash/config/logstash.yml:/usr/share/logstash/config/logstash.yml:ro
    depends_on:
      elasticsearch:
        condition: service_healthy
    networks:
      - siem-network
    restart: unless-stopped

networks:
  siem-network:
    driver: bridge

volumes:
  elasticsearch_data:
```

---

## Step 4: Configure Elasticsearch

Create file: `elasticsearch/config/elasticsearch.yml`

```yaml
# Cluster settings
cluster.name: "siem-cluster"
node.name: "node-1"

# Network settings
network.host: 0.0.0.0
http.port: 9200

# Disable security for simplicity (enable in production)
xpack.security.enabled: false

# Memory settings
bootstrap.memory_lock: false

# Index settings
indices.memory.index_buffer_size: 30%

# Logging
logger.level: info
```

---

## Step 5: Configure Logstash

Create file: `logstash/config/logstash.yml`

```yaml
# Node settings
node.name: "logstash-node"
pipeline.id: "main"

# HTTP API
http.host: "0.0.0.0"
http.port: 9600

# Pipeline settings
pipeline.workers: 2
pipeline.batch.size: 125

# Logging
log.level: info
```

---

## Step 6: Create Logstash Pipeline Configuration

Create file: `logstash/pipeline/syslog.conf`

```logstash
# ============================================
# LOGSTASH SYSLOG PIPELINE CONFIGURATION
# ============================================

input {
  # Receive logs from Filebeat
  beats {
    port => 5044
    host => "0.0.0.0"
  }
}

filter {
  # Parse syslog messages
  if [fileset][module] == "system" {
    if [fileset][name] == "auth" {
      # Parse authentication logs
      grok {
        match => { 
          "message" => "%{SYSLOGBASE} %{DATA:auth_mechanism}(?:\[%{INT:pid}\])?: %{GREEDYDATA:auth_message}"
        }
      }

      # Identify failed logins
      if "Failed password" in [message] or "failure" in [message] {
        mutate {
          add_field => { "[@metadata][type]" => "failed_login" }
          add_tag => [ "failed_login", "security_event" ]
        }
      }

      # Identify successful logins
      if "Accepted" in [message] {
        mutate {
          add_field => { "[@metadata][type]" => "successful_login" }
          add_tag => [ "successful_login" ]
        }
      }

      # Extract username and IP address
      grok {
        match => { 
          "message" => "(?:Invalid user|Received disconnect from|Connection closed by|Invalid password for|Accepted %{WORD} for) %{DATA:username}"
        }
        optional => true
      }

      grok {
        match => { 
          "message" => "(?:from|for) %{IP:source_ip}"
        }
        optional => true
      }
    }
  }

  # Add timestamp
  mutate {
    add_field => { "[@metadata][index_name]" => "logs-%{+YYYY.MM.dd}" }
  }

  # Remove unwanted fields
  mutate {
    remove_field => [ "agent", "host", "input" ]
  }
}

output {
  # Send to Elasticsearch
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "logs-%{+YYYY.MM.dd}"
    user => "elastic"
    password => "changeme"
  }

  # Also print to console for debugging
  stdout { 
    codec => json_lines
  }
}
```

---

## Step 7: Configure Kibana

Create file: `kibana/config/kibana.yml`

```yaml
# Server settings
server.name: "kibana-server"
server.host: "0.0.0.0"
server.port: 5601

# Elasticsearch connection
elasticsearch.hosts: ["http://elasticsearch:9200"]
elasticsearch.username: "elastic"
elasticsearch.password: "changeme"

# Logging
logging.level: info

# Index pattern
kibana.defaultAppId: "discover"
```

---

## Step 8: Start the ELK Stack

```bash
# Navigate to project directory
cd ~/siem-elk-stack

# Pull Docker images
docker-compose pull

# Start all services in background
docker-compose up -d

# Check status of services
docker-compose ps

# View logs
docker-compose logs -f

# Wait for services to be healthy (2-3 minutes)
```

### Expected Output:
```
NAME                 COMMAND                  SERVICE         STATUS      PORTS
elasticsearch        "/bin/bash /usr/local…"   elasticsearch   Up (healthy)   0.0.0.0:9200->9200/tcp
kibana               "/bin/tini -- /usr/l…"   kibana          Up (healthy)   0.0.0.0:5601->5601/tcp
logstash             "/usr/local/bin/logst…"  logstash        Up              0.0.0.0:5044->5044/tcp
```

---

## Step 9: Verify Elasticsearch is Working

```bash
# Test Elasticsearch connectivity
curl -u elastic:changeme http://localhost:9200/

# Expected response (JSON):
{
  "name" : "node-1",
  "cluster_name" : "siem-cluster",
  "version" : {
    "number" : "8.11.0"
  },
  "tagline" : "You Know, for Search"
}

# Check cluster health
curl -u elastic:changeme http://localhost:9200/_cluster/health | jq .

# Expected status: "green" (all shards are allocated)
```

---

## Step 10: Verify Kibana is Running

```bash
# Access Kibana
# Open browser and visit: http://localhost:5601

# You should see the Kibana home page
# Default username: elastic
# Default password: changeme
```

---

# Phase 2: Data Collection

## Step 1: Install and Configure Filebeat

### On the source Linux machine (that you want to collect logs from):

```bash
# Download Filebeat
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.11.0-linux-x86_64.tar.gz

# Extract
tar xzvf filebeat-8.11.0-linux-x86_64.tar.gz
cd filebeat-8.11.0-linux-x86_64

# Or install via apt on Debian/Ubuntu
sudo apt-get install -y filebeat

# Verify installation
./filebeat version
```

---

## Step 2: Configure Filebeat

Edit: `/etc/filebeat/filebeat.yml` (or `filebeat.yml` in extracted folder)

```yaml
# ==================== Filebeat inputs ====================
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /var/log/auth.log          # Authentication logs
    - /var/log/syslog            # System logs
    - /var/log/kern.log          # Kernel logs
  multiline.pattern: '^\['
  multiline.negate: true
  multiline.match: after

# ==================== Filebeat Modules ====================
filebeat.config.modules:
  path: ${path.config}/modules.d/*.yml
  reload.enabled: true
  reload.period: 10s

# ==================== Elasticsearch Output ====================
output.logstash:
  hosts: ["localhost:5044"]      # or IP address of Logstash server
  loadbalance: true
  worker: 2

# ==================== Logging ====================
logging.level: info
logging.to_files: true
logging.files:
  path: /var/log/filebeat
  name: filebeat
  keepfiles: 7
  permissions: 0644
```

---

## Step 3: Enable Filebeat System Module

```bash
# Enable system module (logs authentication, syslog, etc.)
./filebeat modules enable system

# OR if installed via apt:
sudo filebeat modules enable system

# List enabled modules
./filebeat modules list
```

---

## Step 4: Setup Filebeat for Elasticsearch (if needed)

```bash
# This creates index templates in Elasticsearch
./filebeat setup --index-management -E output.logstash.enabled=false -E 'output.elasticsearch.hosts=["localhost:9200"]'

# OR
sudo filebeat setup --index-management
```

---

## Step 5: Start Filebeat

```bash
# If you extracted it manually:
./filebeat -e -c filebeat.yml

# If installed via apt:
sudo systemctl start filebeat
sudo systemctl enable filebeat     # Enable on boot

# Check status
sudo systemctl status filebeat

# View logs
sudo tail -f /var/log/filebeat/filebeat
```

---

## Step 6: Verify Logs are Being Collected

```bash
# Check if Logstash is receiving data
docker-compose logs logstash | tail -20

# Expected output: You should see logs being processed

# Check Elasticsearch indices
curl -u elastic:changeme http://localhost:9200/_cat/indices?v

# You should see indices like: logs-2024.07.17
```

---

## Step 7: Create Test Logs (for demonstration)

If you don't have real logs, create sample logs:

```bash
# Create sample log file
cat > sample-logs/auth.log << 'EOF'
Jul 17 10:15:32 siem-server sshd[12345]: Failed password for invalid user admin from 192.168.1.100 port 54321 ssh2
Jul 17 10:15:35 siem-server sshd[12346]: Failed password for root from 192.168.1.101 port 54322 ssh2
Jul 17 10:16:00 siem-server sshd[12347]: Accepted publickey for testuser from 192.168.1.50 port 54323 ssh2
Jul 17 10:17:15 siem-server sudo: testuser : TTY=pts/0 ; PWD=/home/testuser ; USER=root ; COMMAND=/bin/systemctl status sshd
Jul 17 10:18:45 siem-server sshd[12348]: Failed password for testuser from 192.168.1.102 port 54324 ssh2
Jul 17 10:19:00 siem-server sshd[12349]: Failed password for testuser from 192.168.1.102 port 54325 ssh2
Jul 17 10:19:05 siem-server sshd[12350]: Failed password for testuser from 192.168.1.102 port 54326 ssh2
Jul 17 10:20:30 siem-server sshd[12351]: Connection closed by 192.168.1.102 port 54327 [preauth]
EOF

# If Filebeat is configured to watch this file, it will send logs to Logstash
```

---

## Step 8: Troubleshooting Data Collection

### Check if Logstash is receiving data from Filebeat:

```bash
# View Logstash logs
docker-compose logs logstash

# Check Logstash pipeline stats
curl http://localhost:9600/_node/stats/pipelines | jq .
```

### Check if data is in Elasticsearch:

```bash
# Count documents in all indices
curl -u elastic:changeme http://localhost:9200/_search?pretty | jq '.hits.total.value'

# Search for specific logs
curl -u elastic:changeme http://localhost:9200/logs-*/_search?q=failed_login&pretty

# Get sample documents
curl -u elastic:changeme 'http://localhost:9200/logs-*/_search?size=5&pretty'
```

### Common issues and fixes:

| Issue | Cause | Solution |
|-------|-------|----------|
| No logs appearing | Filebeat not connected | Verify Logstash port (5044) is accessible |
| Logstash crashing | Pipeline syntax error | Check `docker-compose logs logstash` |
| Elasticsearch full | Storage limit reached | Delete old indices or increase storage |

---

# Phase 3: Dashboard Creation

## Step 1: Access Kibana and Create Index Pattern

1. **Open Kibana:**
   - Navigate to: `http://localhost:5601`
   - Login: `elastic` / `changeme`

2. **Create Index Pattern:**
   - Go to: **Stack Management** → **Index Patterns**
   - Click: **Create Index Pattern**
   - Index pattern name: `logs-*`
   - Time field: `@timestamp`
   - Click: **Create Index Pattern**

---

## Step 2: Verify Data in Discover Tab

1. **Open Discover:**
   - Click: **Discover** in the left sidebar
   - Select index pattern: `logs-*`
   - You should see logs appearing

2. **Explore fields:**
   - Look for: `message`, `source_ip`, `username`, `hostname`

---

## Step 3: Create Visualizations

### Visualization 1: Failed Login Attempts (Pie Chart)

```bash
# Using Kibana UI:
1. Go to: Visualizations → Create Visualization
2. Select: Pie Chart
3. Data:
   - Metrics: Count
   - Buckets: Terms on "message.keyword"
   - Filter: "Failed password" in message
4. Save as: "Failed Login Attempts"
```

### Visualization 2: Login Attempts Over Time (Line Chart)

```bash
1. Go to: Visualizations → Create Visualization
2. Select: Line Chart
3. Data:
   - Metrics: Count
   - Buckets: Date Histogram on @timestamp (1 hour interval)
   - Filter: ("Accepted" OR "Failed password") in message
4. Save as: "Login Activity Timeline"
```

### Visualization 3: Top Source IPs (Bar Chart)

```bash
1. Go to: Visualizations → Create Visualization
2. Select: Bar Chart (Horizontal)
3. Data:
   - Metrics: Count
   - Buckets: Terms on "source_ip.keyword"
4. Save as: "Top Source IPs"
```

### Visualization 4: Failed Login Attempts by User (Table)

```bash
1. Go to: Visualizations → Create Visualization
2. Select: Data Table
3. Data:
   - Metrics: Count
   - Buckets: Terms on "username.keyword"
   - Filter: "Failed password" in message
4. Save as: "Failed Logins by User"
```

### Visualization 5: SSH Activity Heat Map

```bash
1. Go to: Visualizations → Create Visualization
2. Select: Area Chart
3. Data:
   - Metrics: Count
   - Buckets: Date Histogram on @timestamp (30 minutes)
   - Sub-buckets: Terms on "username.keyword"
4. Save as: "SSH Activity Heatmap"
```

---

## Step 4: Create the Main SIEM Dashboard

1. **Create Dashboard:**
   - Go to: **Dashboards** → **Create Dashboard**
   - Title: **"SIEM Dashboard - Security Overview"**

2. **Add Visualizations:**
   - Click: **Edit**
   - Click: **Add Panel**
   - Select all visualizations created above
   - Arrange them in a logical layout:

```
┌─────────────────────────────────────┐
│   Failed Login Attempts (Pie)        │
│   Login Activity Timeline (Line)     │
├─────────────────────────────────────┤
│   Top Source IPs (Bar)               │
│   Failed Logins by User (Table)      │
├─────────────────────────────────────┤
│   SSH Activity Heatmap (Area)        │
└─────────────────────────────────────┘
```

3. **Save Dashboard:**
   - Click: **Save**
   - Name: **"SIEM Security Dashboard"**

---

## Step 5: Advanced Dashboard Features

### Add Alert Badge to Dashboard

```bash
# Add a count visualization for critical events
1. Create new visualization: Metric
2. Data: Count of failed logins in last 24 hours
3. Field: "Failed password" in message
4. Conditions: timestamp > now-24h
5. Save as: "Failed Logins (24h)"
6. Add to dashboard
```

### Create Date Filter

```bash
1. On dashboard, click: "Edit"
2. Add time picker at top
3. Set default to: "Last 24 hours"
4. Allow users to customize time range
```

### Create Drill-Down

```bash
# Allow clicking on an IP to see all activity from that IP
1. Edit Top Source IPs visualization
2. Click: on any bar in the chart
3. It should show filtered logs from that IP
```

---

## Step 6: Dashboard Best Practices

### Layout Guidelines:
- **High-risk information:** Top-left (most visible)
- **Timeline charts:** Use for trends
- **Tables:** For detailed data
- **Gauges/Metrics:** For quick KPIs

### Color Coding:
- **Red:** Critical/Alerts
- **Orange:** Warnings
- **Yellow:** Info
- **Green:** Normal

### Real-Time Updates:
1. On dashboard, click **Refresh** → **Auto**
2. Set refresh interval to 10 seconds for real-time monitoring

---

# Alerting Setup

## Step 1: Configure Alerting in Kibana (Kibana Stack Rules)

### Create Alert Rule for Multiple Failed Logins:

1. **Go to:**
   - **Stack Management** → **Rules and Connectors** → **Rules**
   - Click: **Create Rule**

2. **Configure Trigger:**
   - Rule type: **Elasticsearch Query**
   - Data view: `logs-*`
   - Query: `message:"Failed password"`
   - Threshold: Count >= 5 in last 15 minutes

3. **Set Condition:**
   - When query results count is >= 5

4. **Choose Action:**
   - Action: **Send Email**
   - Email address: `admin@example.com`
   - Subject: `ALERT: Multiple Failed Login Attempts Detected`
   - Message:
   ```
   Alert: {{rule.name}}
   
   Multiple failed SSH login attempts detected!
   
   Details:
   - Number of attempts: {{context.results}}
   - Time window: Last 15 minutes
   - Source IPs: Check dashboard
   
   Action: Review SIEM dashboard for details
   ```

5. **Save Rule:**
   - Name: **"Alert: Multiple Failed Logins"**
   - Enable: Yes

---

### Create Alert Rule for Unusual Activity:

```bash
1. Create Rule → Elasticsearch Query
2. Data view: logs-*
3. Query: message:("Connection closed" OR "Accepted")
4. Threshold: Count >= 20 in last 5 minutes
5. Action: Send Email
6. Save as: "Alert: High SSH Activity"
```

---

## Step 2: Setup Email Notifications

### Configure SMTP Server:

1. **Go to:**
   - **Stack Management** → **Rules and Connectors** → **Connectors**

2. **Create Connector:**
   - Type: **Email**
   - Connector name: **SMTP Server**
   - Host: `smtp.gmail.com` (or your SMTP server)
   - Port: `587`
   - Secure connection: TLS
   - Username: `your-email@gmail.com`
   - Password: `your-app-password`

3. **Test Connection:**
   - Click: **Save and Test**

---

## Step 3: Create Advanced Alert - Suspicious Login Pattern

```bash
Rule Name: "Alert: Suspicious User Behavior"

Conditions:
- Failed logins >= 3 for same user in 10 minutes
- From different IPs
- During unusual hours (outside 9-5)

Actions:
- Send email to security team
- Create event in system log
- Trigger Slack notification (if integrated)
```

---

# Testing & Validation

## Step 1: Test Failed Login Detection

### Generate failed logins:

```bash
# SSH into a system and intentionally fail login attempts
ssh testuser@your-system
# Enter wrong password 5 times

# Check Kibana for alerts
# Go to Dashboard → Check if "Failed Login Attempts" increased
```

### Verify logs in Elasticsearch:

```bash
# Query failed login attempts
curl -u elastic:changeme 'http://localhost:9200/logs-*/_search?q=failed_login&pretty' | head -30
```

---

## Step 2: Test Successful Logins

```bash
# Successfully login to a system
ssh testuser@your-system
# Enter correct password

# Verify in Kibana
# Should show "Accepted" message in logs
```

---

## Step 3: Simulate Attack Scenarios

### Scenario 1: Brute Force Attack

```bash
# Simulate multiple failed login attempts from single IP
for i in {1..10}; do
  echo "Attempt $i"
  timeout 2 ssh -v attackip@target 2>&1 | grep -i password
  sleep 1
done

# Check alerts in Kibana
# Should trigger: "Alert: Multiple Failed Logins"
```

### Scenario 2: Suspicious Source IP

```bash
# Simulate SSH from unusual IP
ssh -o ConnectTimeout=2 testuser@target < /dev/null

# Check Kibana
# Look for source IPs in "Top Source IPs" visualization
# See if any are flagged as suspicious
```

### Scenario 3: Port Scanning Activity

```bash
# Simulate scanning (if you have test environment)
nmap -sV target-ip

# Kibana should show increased connection attempts
```

---

## Step 4: Validate Alert Functionality

1. **Check if alerts triggered:**
   - Go to: **Stack Management** → **Rules and Connectors** → **Rules**
   - View rule execution history
   - Verify emails were sent

2. **Test notification:**
   - Trigger a known alert scenario
   - Verify email arrives in inbox within 5 minutes

---

## Step 5: Dashboard Accuracy Checks

```bash
# Verify dashboard metrics match raw logs
curl -u elastic:changeme 'http://localhost:9200/logs-*/_search' \
  -H 'Content-Type: application/json' \
  -d '{
    "size": 0,
    "aggs": {
      "failed_logins": {
        "filter": {
          "match": {"message": "Failed password"}
        }
      }
    }
  }' | jq '.aggregations.failed_logins.doc_count'

# Compare with dashboard "Failed Login Attempts" count
# Should match within 30 seconds
```

---

# Troubleshooting

## Common Issues and Solutions

### Issue 1: Elasticsearch Not Starting

**Symptoms:**
```
docker-compose ps shows "exited"
```

**Solutions:**

```bash
# Check logs
docker-compose logs elasticsearch

# Common fixes:
# 1. Insufficient memory
docker-compose down
sudo sysctl -w vm.max_map_count=262144  # Linux only
docker-compose up -d

# 2. Port already in use
lsof -i :9200
kill -9 <PID>

# 3. Data corruption
rm -rf elasticsearch/data/*
docker-compose up -d
```

---

### Issue 2: Logstash Not Processing Logs

**Symptoms:**
```
Logs not appearing in Elasticsearch
Logstash container running but idle
```

**Solutions:**

```bash
# Check Logstash pipeline configuration
docker-compose logs logstash

# Verify connection to Elasticsearch
docker-compose exec logstash curl -s http://elasticsearch:9200/ | jq .

# Test with manual input
echo "TEST LOG MESSAGE" | nc localhost 5000

# Check pipeline errors
docker-compose exec logstash cat /usr/share/logstash/config/logstash.yml

# Validate pipeline syntax
docker-compose exec logstash /usr/share/logstash/bin/logstash -t -f /usr/share/logstash/pipeline/
```

---

### Issue 3: Kibana Not Connecting to Elasticsearch

**Symptoms:**
```
Kibana shows "Unable to connect to Elasticsearch"
Status page shows red
```

**Solutions:**

```bash
# Check if Elasticsearch is healthy
curl -u elastic:changeme http://localhost:9200/_cluster/health

# Verify connectivity from Kibana container
docker-compose exec kibana curl -u elastic:changeme http://elasticsearch:9200/

# Check Kibana logs
docker-compose logs kibana

# Restart Kibana
docker-compose restart kibana

# If still failing, check environment variables in docker-compose.yml
# Ensure: ELASTICSEARCH_HOSTS=http://elasticsearch:9200
```

---

### Issue 4: Filebeat Not Sending Logs

**Symptoms:**
```
No logs appearing in Elasticsearch
Filebeat running but no output
```

**Solutions:**

```bash
# Check Filebeat status
sudo systemctl status filebeat

# View Filebeat logs
sudo tail -f /var/log/filebeat/filebeat

# Test connectivity to Logstash
telnet localhost 5044

# Verify Filebeat configuration
sudo filebeat test config -c /etc/filebeat/filebeat.yml

# Check if module is enabled
sudo filebeat modules list

# Re-enable module if needed
sudo filebeat modules enable system
sudo filebeat modules enable auth
```

---

### Issue 5: High Memory Usage

**Symptoms:**
```
Docker containers using excessive RAM
System becoming slow
```

**Solutions:**

```bash
# Check memory usage
docker stats

# Reduce Elasticsearch heap size in docker-compose.yml
# Change: "ES_JAVA_OPTS=-Xms512m -Xmx512m"
# To: "ES_JAVA_OPTS=-Xms256m -Xmx256m"

# Reduce Logstash heap
# Change: "LS_JAVA_OPTS=-Xmx256m -Xms256m"
# To: "LS_JAVA_OPTS=-Xmx128m -Xms128m"

# Delete old indices to free space
curl -u elastic:changeme -X DELETE 'http://localhost:9200/logs-2024.07.01'

# Restart services
docker-compose down
docker-compose up -d
```

---

### Issue 6: Dashboard Slow to Load

**Symptoms:**
```
Dashboard takes 10+ seconds to load
Visualizations not updating
```

**Solutions:**

```bash
# Reduce number of visualizations on dashboard (max 6-8)
# Use more specific time ranges (e.g., 24 hours instead of all time)
# Add indices pattern filter to reduce data scanned

# Optimize index settings
curl -u elastic:changeme -X PUT 'http://localhost:9200/logs-*/_settings' \
  -H 'Content-Type: application/json' \
  -d '{
    "index": {
      "refresh_interval": "30s",
      "number_of_replicas": 0
    }
  }'

# Delete unnecessary fields
curl -u elastic:changeme -X PUT 'http://localhost:9200/logs-*/_mapping' \
  -H 'Content-Type: application/json' \
  -d '{
    "properties": {
      "old_field": {
        "enabled": false
      }
    }
  }'
```

---

### Issue 7: Out of Disk Space

**Symptoms:**
```
Elasticsearch stops accepting data
Error: "disk full" or "water mark exceeded"
```

**Solutions:**

```bash
# Check disk usage
df -h

# View Elasticsearch disk status
curl -u elastic:changeme http://localhost:9200/_cat/allocation?v

# Delete old indices
curl -u elastic:changeme -X GET 'http://localhost:9200/_cat/indices?v' | head -20

# Delete specific old index
curl -u elastic:changeme -X DELETE 'http://localhost:9200/logs-2024.07.01'

# Setup index lifecycle management (ILM) to auto-delete old indices
curl -u elastic:changeme -X PUT 'http://localhost:9200/_ilm/policy/logs-policy' \
  -H 'Content-Type: application/json' \
  -d '{
    "policy": "logs-policy",
    "phases": {
      "hot": {"min_age": "0d", "actions": {}},
      "warm": {"min_age": "7d", "actions": {}},
      "delete": {"min_age": "30d", "actions": {"delete": {}}}
    }
  }'
```

---

### Issue 8: Grok Filter Not Parsing Logs

**Symptoms:**
```
Logs received but not parsed correctly
Fields not extracted (username, source_ip empty)
```

**Solutions:**

```bash
# Test grok pattern before using
# Use Kibana's Grok Debugger:
# Stack Management → Dev Tools → Grok Debugger

# Example test log:
# Jul 17 10:15:32 server sshd[12345]: Failed password for testuser from 192.168.1.100 port 54321

# Try pattern:
# %{SYSLOGBASE} %{DATA:service}\[%{INT:pid}\]: %{GREEDYDATA:message}

# If pattern fails, check Logstash logs
docker-compose logs logstash | grep -i error

# Update pipeline with correct pattern
nano logstash/pipeline/syslog.conf

# Test pipeline without restarting
docker-compose exec logstash /usr/share/logstash/bin/logstash -t -f /usr/share/logstash/pipeline/

# Reload pipeline
docker-compose restart logstash
```

---

## Monitoring and Maintenance

### Daily Checklist

```bash
# Check system health
1. Verify all containers running:
   docker-compose ps

2. Monitor disk space:
   df -h

3. Check Elasticsearch status:
   curl -u elastic:changeme http://localhost:9200/_cluster/health | jq .

4. Verify incoming logs:
   curl -u elastic:changeme http://localhost:9200/logs-*/_search?size=0 | jq '.hits.total.value'

5. Check active alerts:
   curl http://localhost:9200/.kibana/_search?q=alert | jq '.hits.hits[0]'
```

### Weekly Tasks

```bash
# 1. Review disk usage and delete old indices (>30 days old)
curl -u elastic:changeme http://localhost:9200/_cat/indices?v | grep logs-

# 2. Update filters and alert rules based on findings
# Go to Kibana → Rules and Connectors

# 3. Test backup and recovery procedure
docker-compose down
docker-compose up -d

# 4. Review audit logs in Kibana
# Look for "unusual" source IPs or users
```

### Monthly Tasks

```bash
# 1. Upgrade to latest stable version
docker-compose pull
docker-compose down
docker-compose up -d

# 2. Review and optimize Logstash pipeline
nano logstash/pipeline/syslog.conf

# 3. Update Filebeat to latest version
sudo apt-get install --only-upgrade filebeat

# 4. Generate monthly security report
# Export dashboard as PDF from Kibana
```

---

# Learning Resources

## Official Documentation

### Elasticsearch
- **Getting Started:** https://www.elastic.co/guide/en/elasticsearch/reference/current/getting-started.html
- **API Documentation:** https://www.elastic.co/guide/en/elasticsearch/reference/current/api-conventions.html
- **Query DSL:** https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl.html

### Logstash
- **Documentation:** https://www.elastic.co/guide/en/logstash/current/introduction.html
- **Pipeline Configuration:** https://www.elastic.co/guide/en/logstash/current/configuration.html
- **Grok Patterns:** https://www.elastic.co/guide/en/logstash/current/plugins-filters-grok.html

### Kibana
- **User Guide:** https://www.elastic.co/guide/en/kibana/current/index.html
- **Dashboard Guide:** https://www.elastic.co/guide/en/kibana/current/dashboard.html
- **Alerting Guide:** https://www.elastic.co/guide/en/kibana/current/alerting-getting-started.html

### Filebeat
- **Documentation:** https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-overview.html
- **Module Configuration:** https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-modules.html

---

## Beginner-Friendly Tutorials

1. **Elastic Official Tutorial:**
   - https://www.elastic.co/training/free
   - Free online courses on ELK Stack fundamentals

2. **YouTube Channels:**
   - Elastic Official Channel: https://www.youtube.com/user/elasticsearch
   - Search for "ELK Stack Tutorial"

3. **Interactive Learning:**
   - Elastic Labs: https://www.elastic.co/guide/en/starting-with-the-elasticsearch-platform-and-solutions/current/overview.html

---

## Quick Reference Commands

### Docker Commands

```bash
# View service status
docker-compose ps

# View logs
docker-compose logs -f <service_name>

# Access container shell
docker-compose exec <service_name> /bin/bash

# Stop all services
docker-compose down

# Start all services
docker-compose up -d

# Rebuild images
docker-compose build --no-cache
```

### Elasticsearch Commands

```bash
# Cluster health
curl -u elastic:changeme http://localhost:9200/_cluster/health?pretty

# List indices
curl -u elastic:changeme http://localhost:9200/_cat/indices?v

# Delete index
curl -u elastic:changeme -X DELETE http://localhost:9200/index-name

# Search documents
curl -u elastic:changeme 'http://localhost:9200/index-name/_search?q=keyword&pretty'

# Index statistics
curl -u elastic:changeme http://localhost:9200/_cat/indices/logs-*?v
```

### Kibana API Commands

```bash
# List index patterns
curl -u elastic:changeme http://localhost:5601/api/saved_objects/index-pattern

# List dashboards
curl -u elastic:changeme http://localhost:5601/api/saved_objects/dashboard

# Export dashboard
curl -u elastic:changeme http://localhost:5601/api/saved_objects/dashboard/dashboard-id > dashboard.json
```

---

## Books and Further Reading

1. **"Elasticsearch in Action"** by Radu Gheorghe
2. **"ELK Stack Cookbook"** by Yuri Bogomolov
3. **"Securing Elasticsearch"** by Elastic
4. **"Log Analysis and Management" (free eBook)** - Elastic

---

# Project Summary and Next Steps

## What You've Built

✅ **Complete SIEM Infrastructure:**
- Elasticsearch cluster for centralized log storage
- Logstash pipelines for log processing and enrichment
- Kibana dashboards for security visualization
- Filebeat agents for log collection
- Automated alerts for security events

✅ **Security Monitoring Capabilities:**
- Failed login detection and alerting
- SSH activity tracking
- Suspicious IP identification
- Real-time threat detection
- Historical log analysis

✅ **Production-Ready Setup:**
- Docker containerization for easy deployment
- Health checks and auto-restart capabilities
- Proper security configuration
- Scalable architecture

---

## Next Steps for Enhancement

### 1. **Add More Data Sources**
```bash
# Windows event logs (via Winlogbeat)
# Firewall logs
# Web server logs (Apache, Nginx)
# Application logs (custom)
# Network flow data (Zeek, Suricata)
```

### 2. **Implement Advanced Security**
```bash
# Enable X-Pack security
# Setup role-based access control (RBAC)
# Configure TLS/SSL encryption
# Enable authentication for all components
```

### 3. **Create Advanced Visualizations**
```bash
# Geolocation heat maps
# User behavior analytics
# Anomaly detection
# Predictive alerting
# Custom dashboards for different teams
```

### 4. **Setup High Availability**
```bash
# Multi-node Elasticsearch cluster
# Logstash load balancer
# Kibana failover
# Automated backups
```

### 5. **Integrate with Other Tools**
```bash
# Slack notifications
# PagerDuty integration
# Splunk integration
# SOAR platform integration
# Threat intelligence feeds
```

---

## Estimated Time to Complete This Guide

| Phase | Estimated Time |
|-------|----------------|
| Phase 1: Foundation Setup | 30-45 minutes |
| Phase 2: Data Collection | 30-60 minutes |
| Phase 3: Dashboard Creation | 45-60 minutes |
| Testing & Validation | 30-45 minutes |
| **Total** | **2-4 hours** |

---

## Success Criteria Checklist

Before considering the project complete, verify:

- [ ] All Docker containers are running and healthy
- [ ] Elasticsearch is accepting and storing data
- [ ] Kibana dashboard is accessible at localhost:5601
- [ ] Filebeat is collecting logs successfully
- [ ] Logstash is parsing logs correctly
- [ ] At least one visualization is showing real data
- [ ] Main SIEM dashboard displays security metrics
- [ ] Alerts are configured and tested
- [ ] Tested failed login detection works
- [ ] Documentation and screenshots are saved

---

## Security Best Practices

### For Production Deployment

1. **Enable Security:**
```bash
# Set xpack.security.enabled=true in elasticsearch.yml
# Configure strong passwords
# Setup SSL/TLS certificates
```

2. **Network Security:**
```bash
# Use firewall rules to restrict access
# Only expose Kibana (port 5601) to internal network
# VPN or bastion host for remote access
```

3. **Data Protection:**
```bash
# Implement encryption at rest
# Enable audit logging
# Regular backups to secure storage
# Data retention policies
```

4. **Access Control:**
```bash
# Setup role-based access (RBAC)
# Multi-factor authentication (MFA)
# API key management
# Regular access reviews
```

---

## Conclusion

You now have a fully functional SIEM system capable of:
- Collecting logs from multiple sources
- Processing and analyzing security data in real-time
- Visualizing threats and security events
- Alerting on suspicious activities
- Supporting forensic investigations

This setup provides a solid foundation for enterprise security monitoring. As you grow, you can add more data sources, implement advanced analytics, and integrate with other security tools.

**Remember:** A SIEM is only as good as the data it collects and the rules it enforces. Regularly review and update your detection rules, validate alerts, and keep all components updated.

---

## Support and Questions

- **Official Elastic Community:** https://discuss.elastic.co/
- **Elastic Support:** https://www.elastic.co/support/
- **Stack Overflow:** Tag `elasticsearch`, `logstash`, `kibana`
- **GitHub Issues:** https://github.com/elastic/

---

**Last Updated:** July 2024
**Guide Version:** 1.0
**ELK Stack Version:** 8.11.0

---
