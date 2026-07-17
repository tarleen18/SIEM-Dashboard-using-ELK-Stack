# SIEM ELK Stack - Troubleshooting Checklist & Debugging Guide

## 🔍 Pre-Launch Checklist

Before starting the system, verify:

- [ ] Docker is installed and running (`docker --version`)
- [ ] Docker Compose is installed (`docker-compose --version`)
- [ ] You have at least 4GB RAM available
- [ ] You have at least 20GB disk space
- [ ] Required ports are available (5601, 9200, 5044, 5000)
- [ ] All configuration files are in place
- [ ] Directory structure is created

---

## 🚀 Startup Verification

### Step 1: Check Docker Services

```bash
# View container status
docker-compose ps

# Expected output - all HEALTHY or UP
NAME          STATUS
elasticsearch  Up (healthy)
kibana         Up (healthy)
logstash       Up
```

### Step 2: Verify Elasticsearch

```bash
# Test connectivity
curl -u elastic:changeme http://localhost:9200/

# Expected response (JSON):
{
  "name" : "node-1",
  "cluster_name" : "siem-cluster",
  "version" : {
    "number" : "8.11.0"
  }
}

# Alternative test
curl -v http://localhost:9200/
# Should show: HTTP/1.1 200 OK
```

### Step 3: Verify Kibana

```bash
# Test API
curl http://localhost:5601/api/status

# Expected response
{"state":"green","status":{"overall":{"state":"green"}}}

# Access in browser
http://localhost:5601
```

### Step 4: Verify Logstash

```bash
# Check health
curl http://localhost:9600/_node/stats/pipelines

# Expected: JSON with pipeline information

# View specific pipeline
docker-compose logs logstash | grep -i "pipeline"
```

---

## 🐛 Common Issues & Advanced Troubleshooting

### Issue 1: Elasticsearch Won't Start

**Symptoms:**
- `docker-compose ps` shows "exited"
- Logs show memory errors
- Logs show binding errors

**Debug Steps:**

```bash
# View detailed logs
docker-compose logs -f elasticsearch

# Check for specific errors
docker-compose logs elasticsearch | grep -i "error\|exception"

# Check system resources
free -h                    # Linux
docker stats               # Check container memory

# Check port availability
lsof -i :9200             # Linux/macOS
netstat -ano | findstr 9200  # Windows
```

**Solutions:**

1. **Memory Issue:**
```bash
# Edit docker-compose.yml
# Reduce: "ES_JAVA_OPTS=-Xms512m -Xmx512m"
# To: "ES_JAVA_OPTS=-Xms256m -Xmx256m"

docker-compose down
docker-compose up -d
```

2. **Port Already In Use:**
```bash
# Find and kill process using port 9200
# Linux/macOS
lsof -i :9200 | grep LISTEN | awk '{print $2}' | xargs kill -9

# Windows
netstat -ano | findstr :9200
taskkill /PID <PID> /F

# Then restart
docker-compose up -d
```

3. **Max Virtual Memory:**
```bash
# Linux only
sudo sysctl -w vm.max_map_count=262144

# Make permanent
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

4. **Data Corruption:**
```bash
# WARNING: This deletes all data!
rm -rf elasticsearch/data/*
docker-compose restart elasticsearch
```

---

### Issue 2: Kibana Can't Connect to Elasticsearch

**Symptoms:**
- Kibana shows "Unable to connect to Elasticsearch"
- Red/orange status page
- Logs show connection refused

**Debug Steps:**

```bash
# From Kibana container, test Elasticsearch
docker-compose exec kibana curl -v http://elasticsearch:9200/

# Check Kibana logs for specific errors
docker-compose logs kibana | grep -i "error\|elasticsearch"

# Verify network connectivity
docker-compose exec kibana ping elasticsearch

# Check Kibana environment variables
docker-compose exec kibana env | grep ELASTIC
```

**Solutions:**

1. **Wrong Elasticsearch URL:**
```bash
# Edit docker-compose.yml
# Verify: ELASTICSEARCH_HOSTS=http://elasticsearch:9200
# (NOT localhost, use service name)

docker-compose restart kibana
```

2. **Wrong Credentials:**
```bash
# Verify username and password match
# In docker-compose.yml and elasticsearch config
# Default: elastic / changeme

docker-compose restart kibana
```

3. **Elasticsearch Not Ready:**
```bash
# Wait longer for Elasticsearch to start
docker-compose logs elasticsearch | tail -20

# Check if cluster is healthy
curl -u elastic:changeme http://localhost:9200/_cluster/health

# Wait and retry
sleep 30
docker-compose restart kibana
```

4. **Network Issue:**
```bash
# Recreate network
docker-compose down
docker network prune
docker-compose up -d
```

---

### Issue 3: Logstash Not Processing Logs

**Symptoms:**
- Logs not appearing in Elasticsearch
- Logstash container running but idle
- No errors in logs

**Debug Steps:**

```bash
# Check if Filebeat is connected
docker-compose logs logstash | grep -i "beats\|connection"

# Check pipeline status
curl http://localhost:9600/_node/stats/pipelines | jq '.pipelines'

# Test Logstash input directly
echo "TEST LOG" | nc localhost 5000

# Verify Elasticsearch connection from Logstash
docker-compose exec logstash curl -s http://elasticsearch:9200/ | jq .

# Check pipeline syntax
docker-compose exec logstash /usr/share/logstash/bin/logstash -t \
  -f /usr/share/logstash/pipeline/syslog.conf
```

**Solutions:**

1. **Pipeline Syntax Error:**
```bash
# View full error message
docker-compose logs logstash

# Fix errors in logstash/pipeline/syslog.conf

# Validate syntax
docker-compose exec logstash /usr/share/logstash/bin/logstash -t \
  -f /usr/share/logstash/pipeline/

# Restart
docker-compose restart logstash
```

2. **No Data Reaching Logstash:**
```bash
# Check if Filebeat is sending data
# On Filebeat system:
sudo systemctl status filebeat
sudo tail -f /var/log/filebeat/filebeat

# Test connectivity to Logstash
telnet <logstash-ip> 5044

# Check Filebeat config
sudo filebeat test config

# Test with sample log
cat sample-logs/auth.log | nc localhost 5000
```

3. **Elasticsearch Connection Issue:**
```bash
# From Logstash container
docker-compose exec logstash curl -v http://elasticsearch:9200/

# Check credentials
# In syslog.conf, verify: user and password

# Restart Logstash
docker-compose restart logstash
```

---

### Issue 4: Filebeat Not Sending Logs

**Symptoms:**
- No logs in Elasticsearch
- Filebeat shows connected but no data
- Dashboard shows no recent events

**Debug Steps:**

```bash
# Check Filebeat service
sudo systemctl status filebeat

# View Filebeat logs
sudo tail -f /var/log/filebeat/filebeat

# Test configuration
sudo filebeat test config -c /etc/filebeat/filebeat.yml

# Test connection to Logstash
sudo filebeat test output -c /etc/filebeat/filebeat.yml

# List enabled modules
sudo filebeat modules list | grep enabled

# Check if files are being read
sudo filebeat test input -c /etc/filebeat/filebeat.yml
```

**Solutions:**

1. **Module Not Enabled:**
```bash
sudo filebeat modules enable system
sudo filebeat modules enable auth
sudo systemctl restart filebeat
```

2. **Wrong Logstash Address:**
```bash
# Edit /etc/filebeat/filebeat.yml
# Verify output.logstash.hosts
# Example: output.logstash.hosts: ["192.168.1.100:5044"]

sudo filebeat test output
sudo systemctl restart filebeat
```

3. **Log Files Not Accessible:**
```bash
# Filebeat requires read access to log files
# Usually needs to run as root
sudo systemctl status filebeat

# If not running as root, fix permissions
sudo chmod 644 /var/log/auth.log
sudo chmod 644 /var/log/syslog
sudo systemctl restart filebeat
```

4. **Network Connectivity:**
```bash
# Test connectivity to Logstash
nc -zv <logstash-ip> 5044

# If fails, check firewall
sudo ufw allow 5044
sudo systemctl restart filebeat
```

---

### Issue 5: High Memory/Disk Usage

**Symptoms:**
- System becomes very slow
- Docker containers use 100%+ of allocated memory
- Disk space running out

**Debug Steps:**

```bash
# Check memory usage
docker stats

# Check disk usage
df -h

# Check Elasticsearch indices
curl -u elastic:changeme http://localhost:9200/_cat/indices?v

# Check old indices
curl -u elastic:changeme 'http://localhost:9200/_cat/indices?s=creation.date:desc&v'
```

**Solutions:**

1. **Reduce Memory Allocation:**
```bash
# Edit docker-compose.yml
# Change heap sizes:
# Elasticsearch: "ES_JAVA_OPTS=-Xms256m -Xmx256m"
# Logstash: "LS_JAVA_OPTS=-Xmx128m -Xms128m"

docker-compose down
docker-compose up -d
```

2. **Delete Old Indices:**
```bash
# List indices
curl -u elastic:changeme http://localhost:9200/_cat/indices?v

# Delete specific index
curl -u elastic:changeme -X DELETE 'http://localhost:9200/logs-2024.07.01'

# Delete all indices older than 30 days
# (Using bash script)
for index in $(curl -s -u elastic:changeme 'http://localhost:9200/_cat/indices' | \
  grep 'logs-' | awk '{print $3}' | sort -r | tail -n +30); do
  curl -u elastic:changeme -X DELETE "http://localhost:9200/$index"
done
```

3. **Enable Index Lifecycle Management (ILM):**
```bash
# Create ILM policy to auto-delete old indices
curl -u elastic:changeme -X PUT 'http://localhost:9200/_ilm/policy/logs-policy' \
  -H 'Content-Type: application/json' \
  -d '{
    "policy": "logs-policy",
    "phases": {
      "hot": {"min_age": "0d", "actions": {}},
      "delete": {"min_age": "30d", "actions": {"delete": {}}}
    }
  }'
```

---

### Issue 6: Dashboard Slow to Load

**Symptoms:**
- Dashboard takes 10+ seconds to load
- Kibana becomes unresponsive
- Visualizations don't update

**Debug Steps:**

```bash
# Check Kibana logs
docker-compose logs kibana

# Monitor resource usage during load
docker stats kibana

# Check number of documents
curl -u elastic:changeme 'http://localhost:9200/logs-*/_search?size=0' | \
  jq '.hits.total.value'
```

**Solutions:**

1. **Reduce Dashboard Content:**
```bash
# Remove visualizations not being used
# Keep max 6-8 visualizations per dashboard
# Use smaller time ranges (e.g., 24 hours instead of all time)
```

2. **Optimize Index Settings:**
```bash
# Increase refresh interval
curl -u elastic:changeme -X PUT 'http://localhost:9200/logs-*/_settings' \
  -H 'Content-Type: application/json' \
  -d '{
    "index": {
      "refresh_interval": "30s",
      "number_of_replicas": 0
    }
  }'
```

3. **Delete Unnecessary Fields:**
```bash
# Remove fields you don't need
curl -u elastic:changeme -X PUT 'http://localhost:9200/logs-*/_mapping' \
  -H 'Content-Type: application/json' \
  -d '{
    "properties": {
      "agent": {"enabled": false},
      "input": {"enabled": false}
    }
  }'
```

---

### Issue 7: Grok Filter Not Parsing Logs

**Symptoms:**
- Logs received but fields not extracted
- username, source_ip, etc. are empty
- Raw message contains unparsed data

**Debug Steps:**

```bash
# Test grok pattern with debugger
# In Kibana: Stack Management → Dev Tools → Grok Debugger

# Sample test log:
# Jul 17 10:15:32 server sshd[12345]: Failed password for testuser from 192.168.1.100

# Test in Logstash
docker-compose exec logstash /usr/share/logstash/bin/logstash -e '
filter {
  grok {
    match => { "message" => "%{SYSLOGBASE} %{GREEDYDATA:message}" }
  }
}
'
```

**Solutions:**

1. **Update Logstash Pipeline:**
```bash
# Edit logstash/pipeline/syslog.conf
# Add/modify grok patterns

# Test syntax
docker-compose exec logstash /usr/share/logstash/bin/logstash -t \
  -f /usr/share/logstash/pipeline/syslog.conf

# Restart Logstash
docker-compose restart logstash
```

2. **Use Correct Pattern:**
```bash
# Common patterns:
# %{SYSLOGBASE}        - Standard syslog header
# %{WORD}              - Single word
# %{IP}                - IP address
# %{INT}               - Integer
# %{GREEDYDATA}        - Everything
# %{USERNAME}          - Username
# %{EMAILADDRESS}      - Email

# Test patterns in Kibana Grok Debugger
```

---

## 🔧 Advanced Debugging

### Enable Debug Logging

**Elasticsearch:**
```yaml
# Edit elasticsearch/config/elasticsearch.yml
logger.org.elasticsearch: debug
logger.org.elasticsearch.action: debug
logger.org.elasticsearch.indices: debug
```

**Logstash:**
```bash
# Run Logstash with debug output
docker-compose exec logstash /usr/share/logstash/bin/logstash \
  --log.level=debug \
  -f /usr/share/logstash/pipeline/syslog.conf
```

**Kibana:**
```yaml
# Edit kibana/config/kibana.yml
logging.level: debug
```

### Check Network Connectivity

```bash
# Between containers
docker-compose exec kibana ping elasticsearch
docker-compose exec logstash ping elasticsearch

# From host
docker exec -it elasticsearch bash -c "curl -s http://logstash:9600/ | head"
```

### Inspect Container Environment

```bash
# View all environment variables
docker-compose exec <service> env

# Check running processes
docker-compose exec <service> ps aux

# Check network connections
docker-compose exec <service> netstat -tlnp
```

---

## 📊 Performance Monitoring

### Check System Health

```bash
# Cluster health
curl -u elastic:changeme http://localhost:9200/_cluster/health | jq .

# Node stats
curl -u elastic:changeme http://localhost:9200/_nodes/stats | jq '.nodes'

# Index stats
curl -u elastic:changeme http://localhost:9200/_stats?human | jq '.indices'

# Shard allocation
curl -u elastic:changeme http://localhost:9200/_cat/shards?v
```

### Monitor Performance

```bash
# Real-time stats
watch -n 1 'docker stats'

# Elasticsearch metrics
curl -u elastic:changeme 'http://localhost:9200/_cat/nodes?h=name,heap.percent,disk.percent&v'

# Logstash metrics
curl http://localhost:9600/_node/stats/events
```

---

## ✅ Daily Maintenance Checklist

- [ ] Check disk space (`df -h`)
- [ ] Monitor memory usage (`docker stats`)
- [ ] Verify all services running (`docker-compose ps`)
- [ ] Check for errors in logs (`docker-compose logs`)
- [ ] Count incoming logs (`curl ... /logs-*/_search?size=0`)
- [ ] Review failed alerts (Kibana → Rules)
- [ ] Delete indices older than 30 days

---

## 📞 When All Else Fails

1. **Full Reset:**
```bash
docker-compose down
rm -rf elasticsearch/data/*
docker-compose up -d
```

2. **Clean Everything:**
```bash
docker-compose down -v
docker system prune -a
docker-compose up -d
```

3. **Check Official Logs:**
```bash
docker-compose logs --all --follow
```

4. **Get Professional Help:**
- Elastic Community: https://discuss.elastic.co/
- GitHub Issues: https://github.com/elastic/
- Stack Overflow: Tag `elasticsearch`, `logstash`, `kibana`

---

**Last Updated:** July 2024
**Version:** 1.0
