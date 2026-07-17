#!/bin/bash

# ===============================================
# SIEM ELK Stack - Quick Start Script
# ===============================================
# This script sets up and starts the ELK Stack
# ===============================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Step 1: Check Docker
print_header "Step 1: Checking Docker Installation"

if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed"
    echo "Please install Docker from: https://docs.docker.com/get-docker/"
    exit 1
fi

print_success "Docker is installed: $(docker --version)"

if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose is not installed"
    echo "Please install Docker Compose from: https://docs.docker.com/compose/install/"
    exit 1
fi

print_success "Docker Compose is installed: $(docker-compose --version)"

# Step 2: Check if Docker daemon is running
print_header "Step 2: Checking Docker Daemon"

if ! docker info &> /dev/null; then
    print_error "Docker daemon is not running"
    echo "Please start Docker Desktop or Docker daemon"
    exit 1
fi

print_success "Docker daemon is running"

# Step 3: Create directory structure
print_header "Step 3: Creating Directory Structure"

mkdir -p elasticsearch/config
mkdir -p elasticsearch/data
mkdir -p kibana/config
mkdir -p logstash/config
mkdir -p logstash/pipeline
mkdir -p filebeat
mkdir -p sample-logs

print_success "Directory structure created"

# Step 4: Set permissions on data directory
print_header "Step 4: Setting Permissions"

chmod 777 elasticsearch/data 2>/dev/null || print_warning "Could not set permissions (may require sudo)"
print_success "Permissions set"

# Step 5: Pull Docker images
print_header "Step 5: Pulling Docker Images (this may take a few minutes)"

docker-compose pull

if [ $? -eq 0 ]; then
    print_success "Docker images pulled successfully"
else
    print_error "Failed to pull Docker images"
    exit 1
fi

# Step 6: Start services
print_header "Step 6: Starting ELK Stack Services"

docker-compose up -d

if [ $? -eq 0 ]; then
    print_success "Docker containers started"
else
    print_error "Failed to start containers"
    docker-compose logs
    exit 1
fi

# Step 7: Wait for services to be healthy
print_header "Step 7: Waiting for Services to Be Healthy"

print_info "This may take 1-2 minutes..."

# Wait for Elasticsearch
echo -n "Waiting for Elasticsearch..."
for i in {1..30}; do
    if curl -s http://localhost:9200/ &> /dev/null; then
        echo -e " ${GREEN}Ready!${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

# Wait for Kibana
echo -n "Waiting for Kibana..."
for i in {1..30}; do
    if curl -s http://localhost:5601/api/status &> /dev/null; then
        echo -e " ${GREEN}Ready!${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

# Step 8: Verify services
print_header "Step 8: Verifying Services"

print_info "Checking container status..."
docker-compose ps

print_header "✓ SIEM ELK Stack Setup Complete!"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}         SETUP SUCCESSFUL!${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo "Available Services:"
echo -e "  ${BLUE}Elasticsearch:${NC} http://localhost:9200"
echo -e "  ${BLUE}Kibana:${NC}        http://localhost:5601"
echo -e "  ${BLUE}Logstash:${NC}      localhost:5044 (Beats)"
echo ""
echo "Next Steps:"
echo "  1. Open Kibana: http://localhost:5601"
echo "  2. Setup Filebeat on your systems to collect logs"
echo "  3. Create index patterns in Kibana (Stack Management → Index Patterns)"
echo "  4. Build visualizations and dashboards"
echo ""
echo "For testing purposes:"
echo "  • Send test logs via TCP:"
echo "    nc -w 0 localhost 5000 < sample-logs/auth.log"
echo ""
echo "Documentation:"
echo "  See SIEM-ELK-STACK-COMPLETE-GUIDE.md for detailed instructions"
echo ""

# Optional: Ask if user wants to test
read -p "Do you want to test the system now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_header "Running System Tests"
    
    # Test Elasticsearch
    echo "Testing Elasticsearch connection..."
    curl -u elastic:changeme http://localhost:9200/ | jq . && print_success "Elasticsearch is working" || print_error "Elasticsearch connection failed"
    
    # Test Kibana
    echo -e "\nTesting Kibana API..."
    curl -s http://localhost:5601/api/status | jq '.state' && print_success "Kibana is working" || print_error "Kibana connection failed"
    
    # Test Logstash
    echo -e "\nTesting Logstash..."
    curl -s http://localhost:9600/_node/stats | jq '.logstash.version' && print_success "Logstash is working" || print_error "Logstash connection failed"
fi

echo -e "\n${BLUE}For troubleshooting, check logs with:${NC}"
echo "  docker-compose logs elasticsearch"
echo "  docker-compose logs kibana"
echo "  docker-compose logs logstash"
echo ""
