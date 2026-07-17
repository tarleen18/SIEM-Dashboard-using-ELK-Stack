# Advanced Logstash Pipeline Configuration Examples

## Use Cases & Advanced Parsing

This file contains advanced Logstash pipeline configurations for different scenarios.
You can use these as templates for your own pipelines.

---

## 🔒 Advanced Security Log Parsing Pipeline

Save as: `logstash/pipeline/security-advanced.conf`

```logstash
# ============================================
# ADVANCED SECURITY LOG PARSING
# ============================================

input {
  beats {
    port => 5044
    host => "0.0.0.0"
  }
}

filter {
  # ==================== SYSLOG PARSING ====================
  grok {
    match => { 
      "message" => "%{SYSLOGBASE} %{DATA:service}\[?%{INT:pid}?\]?:? %{GREEDYDATA:content}"
    }
    overwrite => [ "message" ]
  }

  # ==================== SSH/AUTH LOG ENRICHMENT ====================
  if [service] =~ /sshd|auth/ {
    
    # Parse SSH authentication attempts
    if [content] =~ /Failed password/ or [content] =~ /Invalid user/ {
      
      # Extract username
      grok {
        match => {
          "content" => "(?:Failed password for|Invalid user) (?P<username>\S+)"
        }
      }
      
      # Extract source IP
      grok {
        match => {
          "content" => " from (?P<source_ip>[\w\d\-\.]+)"
        }
      }
      
      # Extract port
      grok {
        match => {
          "content" => " port (?P<source_port>\d+)"
        }
      }
      
      # Mark as security event
      mutate {
        add_tag => [ "security_event", "failed_auth" ]
        add_field => { "event_type" => "failed_login" }
      }
      
      # GeoIP enrichment (if GeoIP database available)
      if [source_ip] {
        geoip {
          source => "source_ip"
          target => "geoip"
        }
        
        # Alert if from unexpected country
        if [geoip][country_code2] != "US" {
          mutate {
            add_tag => [ "suspicious_location" ]
          }
        }
      }
    }
    
    # Parse successful logins
    if [content] =~ /Accepted/ {
      grok {
        match => {
          "content" => "Accepted (?P<auth_method>\S+) for (?P<username>\S+) from (?P<source_ip>[\w\d\-\.]+) port (?P<source_port>\d+)"
        }
      }
      
      mutate {
        add_tag => [ "successful_auth" ]
        add_field => { "event_type" => "successful_login" }
      }
    }
    
    # Detect brute force attempts
    if "_grok_parse_failure" not in [tags] {
      mutate {
        add_field => { "session_key" => "%{hostname}_%{username}_%{source_ip}" }
      }
    }
  }

  # ==================== SUDO LOG PARSING ====================
  if [service] == "sudo" {
    grok {
      match => {
        "content" => "%{WORD:sudo_user} : TTY=%{WORD:tty} ; PWD=%{PATH:pwd} ; USER=%{WORD:target_user} ; COMMAND=%{GREEDYDATA:command}"
      }
    }
    
    mutate {
      add_tag => [ "privilege_escalation" ]
      add_field => { "event_type" => "sudo_usage" }
    }
    
    # Alert on sensitive commands
    if [command] =~ /passwd|shadow|sudoers|iptables/ {
      mutate {
        add_tag => [ "sensitive_command" ]
      }
    }
  }

  # ==================== KERNEL LOG PARSING ====================
  if [service] == "kernel" {
    if [content] =~ /SELinux|AppArmor|audit/ {
      mutate {
        add_tag => [ "security_audit" ]
      }
    }
  }

  # ==================== TIMESTAMP NORMALIZATION ====================
  date {
    match => [ "timestamp", "MMM  d HH:mm:ss", "MMM dd HH:mm:ss" ]
    target => "@timestamp"
  }

  # ==================== IP REPUTATION & THREAT INTEL ====================
  if [source_ip] {
    # Lookup IP against threat intel database
    # (requires external database or service)
    
    # Example: Mark known bad IPs
    if [source_ip] =~ /^192\.168\.100\./ {
      mutate {
        add_tag => [ "internal_network" ]
      }
    } else {
      mutate {
        add_tag => [ "external_network" ]
      }
    }
  }

  # ==================== RISK SCORING ====================
  if "failed_auth" in [tags] {
    mutate {
      add_field => { "risk_score" => 50 }
    }
  }
  
  if "sensitive_command" in [tags] {
    mutate {
      add_field => { "risk_score" => 75 }
    }
  }
  
  if "suspicious_location" in [tags] {
    mutate {
      add_field => { "risk_score" => 100 }
    }
  }

  # ==================== CLEANUP ====================
  mutate {
    remove_field => [ "agent", "input.type", "log.file.path" ]
  }
}

output {
  # Send to Elasticsearch with dynamic index
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "security-logs-%{+YYYY.MM.dd}"
    user => "elastic"
    password => "changeme"
    
    # Route high-risk events to special index
    if [risk_score] > 80 {
      index => "security-alerts-%{+YYYY.MM.dd}"
    }
  }
  
  # Debug output
  stdout {
    codec => json_lines
  }
}
```

---

## 🌐 Web Server Log Parsing Pipeline

Save as: `logstash/pipeline/webserver.conf`

```logstash
# ============================================
# WEB SERVER LOG PARSING (NGINX/APACHE)
# ============================================

input {
  beats {
    port => 5044
    host => "0.0.0.0"
  }
}

filter {
  # Parse NGINX/Apache logs
  grok {
    match => {
      "message" => "%{IPORHOST:client_ip} - %{DATA:username} \[%{HTTPDATE:timestamp}\] \"%{WORD:method} %{DATA:request} %{DATA:httpversion}\" %{NUMBER:status_code} %{NUMBER:bytes_sent} \"%{DATA:referrer}\" \"%{DATA:user_agent}\""
    }
  }

  # Parse user agent
  useragent {
    source => "user_agent"
    target => "ua"
  }

  # Identify suspicious activities
  if [status_code] =~ /401|403|404|500/ {
    mutate {
      add_tag => [ "http_error" ]
    }
  }
  
  # Detect SQL injection attempts
  if [request] =~ /union|select|insert|delete|drop|update|where.*=|or.*=/ {
    mutate {
      add_tag => [ "potential_sql_injection" ]
    }
  }
  
  # Detect path traversal
  if [request] =~ /\.\.\/|\.\.\\/ {
    mutate {
      add_tag => [ "path_traversal_attempt" ]
    }
  }

  # Normalize timestamp
  date {
    match => [ "timestamp", "dd/MMM/YYYY:HH:mm:ss Z" ]
    target => "@timestamp"
  }

  # Cleanup
  mutate {
    remove_field => [ "timestamp" ]
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "web-logs-%{+YYYY.MM.dd}"
    user => "elastic"
    password => "changeme"
  }
}
```

---

## 📱 Application Log Parsing Pipeline

Save as: `logstash/pipeline/application.conf`

```logstash
# ============================================
# APPLICATION LOG PARSING (JSON FORMAT)
# ============================================

input {
  beats {
    port => 5044
    host => "0.0.0.0"
  }
}

filter {
  # Try to parse JSON logs
  json {
    source => "message"
    skip_on_invalid_json => true
  }

  # If not JSON, try grok
  if "_jsonparsefailure" in [tags] {
    grok {
      match => {
        "message" => "\[%{TIMESTAMP_ISO8601:timestamp}\] %{LOGLEVEL:log_level} \[%{DATA:logger}\] %{GREEDYDATA:log_message}"
      }
    }
    mutate {
      remove_tag => [ "_jsonparsefailure" ]
    }
  }

  # Extract stack traces
  multiline {
    pattern => "^\s"
    what => "previous"
  }

  # Identify errors
  if [log_level] =~ /ERROR|FATAL|CRITICAL/ {
    mutate {
      add_tag => [ "error" ]
    }
  }

  # Identify security events
  if [log_message] =~ /unauthorized|forbidden|invalid|credentials|permission denied/ {
    mutate {
      add_tag => [ "security_event" ]
    }
  }

  # Normalize timestamp
  if [timestamp] {
    date {
      match => [ "timestamp", "ISO8601", "YYYY-MM-dd HH:mm:ss,SSS" ]
      target => "@timestamp"
    }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "app-logs-%{[app_name]}-%{+YYYY.MM.dd}"
    user => "elastic"
    password => "changeme"
  }
}
```

---

## 🔐 Combined Multi-Source Pipeline

Save as: `logstash/pipeline/multi-source.conf`

```logstash
# ============================================
# MULTI-SOURCE LOG AGGREGATION PIPELINE
# ============================================

input {
  # Filebeat input
  beats {
    port => 5044
    host => "0.0.0.0"
    tags => [ "beats" ]
  }

  # TCP input for direct log submission
  tcp {
    port => 5000
    codec => "plain"
    tags => [ "tcp" ]
  }

  # UDP input for syslog
  udp {
    port => 5514
    codec => "plain"
    tags => [ "udp" ]
  }
}

filter {
  # Add source information
  mutate {
    add_field => { "log_source" => "%{[@metadata][beat]}" }
  }

  # Route based on source
  if [fileset][name] == "auth" or "ssh" in [message] {
    mutate {
      add_field => { "log_category" => "authentication" }
    }
    # Apply auth log parsing
    # ... (include auth parsing filters) ...
  } else if [fileset][name] == "syslog" {
    mutate {
      add_field => { "log_category" => "system" }
    }
    # Apply system log parsing
  }

  # Common enrichment
  geoip {
    source => "source_ip"
    target => "geoip"
  }

  # Add metadata
  mutate {
    add_field => { "[@metadata][index_name]" => "logs-%{log_category}-%{+YYYY.MM.dd}" }
  }

  # Cleanup
  mutate {
    remove_field => [ "agent.ephemeral_id" ]
  }
}

output {
  # Route high-priority events to separate index
  if "security_event" in [tags] or "error" in [tags] {
    elasticsearch {
      hosts => ["elasticsearch:9200"]
      index => "alerts-%{log_category}-%{+YYYY.MM.dd}"
      user => "elastic"
      password => "changeme"
    }
  } else {
    elasticsearch {
      hosts => ["elasticsearch:9200"]
      index => "logs-%{log_category}-%{+YYYY.MM.dd}"
      user => "elastic"
      password => "changeme"
    }
  }

  stdout {
    codec => json_lines
  }
}
```

---

## 🔍 How to Use These Pipelines

### Step 1: Choose Your Pipeline

Depending on your use case:
- **Security monitoring:** Use `security-advanced.conf`
- **Web server monitoring:** Use `webserver.conf`
- **Application monitoring:** Use `application.conf`
- **Multiple sources:** Use `multi-source.conf`

### Step 2: Add to Logstash

```bash
# Copy pipeline file to pipeline directory
cp security-advanced.conf logstash/pipeline/

# Edit docker-compose.yml to use specific pipeline
# In logstash service, set:
# - LOGSTASH_PIPELINE=security-advanced

# Or create a pipelines.yml file in logstash/config/
```

### Step 3: Create pipelines.yml

Create: `logstash/config/pipelines.yml`

```yaml
- pipeline.id: main
  path.config: "/usr/share/logstash/pipeline/*.conf"

# Or run specific pipeline:
- pipeline.id: security
  path.config: "/usr/share/logstash/pipeline/security-advanced.conf"
```

### Step 4: Restart Logstash

```bash
docker-compose restart logstash
```

### Step 5: Verify

```bash
# Check logs
docker-compose logs -f logstash

# Verify pipeline is running
curl http://localhost:9600/_node/stats/pipelines | jq '.pipelines'

# Send test data
echo "Test log message" | nc localhost 5000

# Check Elasticsearch
curl -u elastic:changeme 'http://localhost:9200/logs-*/_search?size=5'
```

---

## 📚 Common Grok Patterns

```logstash
# Basic patterns
%{WORD}           # Single word
%{NOTSPACE}       # Non-whitespace
%{INT}            # Integer
%{NUMBER}         # Decimal number
%{IP}             # IP address
%{IPORHOST}       # IP or hostname

# Security patterns
%{USERNAME}       # Username
%{PASSWORD}       # Password
%{EMAILADDRESS}   # Email address

# Date/Time patterns
%{TIMESTAMP_ISO8601}  # ISO8601 timestamp
%{HTTPDATE}           # HTTP date
%{SYSLOGDATE}         # Syslog date

# Complex patterns
%{SYSLOGBASE}     # Full syslog header
%{QS}             # Quoted string
%{PATH}           # File path
%{URI}            # URI/URL
%{GREEDYDATA}     # Everything remaining
```

---

## 🧪 Testing Grok Patterns

### Online Grok Debugger:
https://grokdebug.herokuapp.com/

### In Kibana:
1. Go to: **Stack Management** → **Dev Tools** → **Grok Debugger**
2. Paste your grok pattern
3. Paste sample log
4. Click "Simulate" to test

### Command Line:
```bash
# Test pattern with Logstash
echo "Jul 17 10:15:32 server sshd[12345]: Failed password" | \
  /usr/share/logstash/bin/logstash -f - -e 'filter {
    grok {
      match => { "message" => "%{SYSLOGBASE} %{GREEDYDATA}" }
    }
  }' -o /dev/null
```

---

## ⚡ Performance Tips

1. **Use Efficient Patterns:**
   - `%{GREEDYDATA}` should be last (greedy = slow)
   - Use specific patterns instead of generic ones

2. **Limit Processing:**
   - Use `if` statements to only parse relevant logs
   - Avoid unnecessary filters

3. **Batch Processing:**
   - Adjust `pipeline.batch.size` in logstash.yml
   - Default: 125 events

4. **Memory Management:**
   - Set appropriate Java heap size
   - Default: `-Xmx256m -Xms256m`

5. **Asynchronous Output:**
   - Elasticsearch output is async by default
   - Monitor output queue size

---

**Last Updated:** July 2024
**Version:** 1.0
