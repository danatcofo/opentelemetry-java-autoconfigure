#!/bin/bash

# Wrapper script for periodic chaos generation
# This script is designed to be called by cron every 5 minutes

set -e

# Configuration
SCRIPT_DIR="/root/projects/opentelemetry-java-autoconfigure"
CHAOS_SCRIPT="$SCRIPT_DIR/chaos_traffic.sh"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/chaos_$(date +%Y%m%d_%H%M%S).log"
PID_FILE="$SCRIPT_DIR/chaos_running.pid"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[PERIODIC]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check if chaos is already running
is_chaos_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0  # Running
        else
            # PID file exists but process is dead, clean it up
            rm -f "$PID_FILE"
        fi
    fi
    return 1  # Not running
}

# Function to cleanup on exit
cleanup() {
    rm -f "$PID_FILE"
}

# Main execution
main() {
    # Change to script directory
    cd "$SCRIPT_DIR"
    
    # Create logs directory if it doesn't exist
    mkdir -p "$LOG_DIR"
    
    # Check if chaos is already running
    if is_chaos_running; then
        print_warning "Chaos generation already running, skipping this execution"
        exit 0
    fi
    
    # Check if chaos script exists and is executable
    if [ ! -f "$CHAOS_SCRIPT" ]; then
        print_error "Chaos script not found: $CHAOS_SCRIPT"
        exit 1
    fi
    
    if [ ! -x "$CHAOS_SCRIPT" ]; then
        print_error "Chaos script is not executable: $CHAOS_SCRIPT"
        exit 1
    fi
    
    # Check if Docker is available
    if ! command -v docker > /dev/null 2>&1; then
        print_error "Docker is not available"
        exit 1
    fi
    
    # Check if docker-compose is available
    if ! command -v docker-compose > /dev/null 2>&1; then
        print_error "docker-compose is not available"
        exit 1
    fi
    
    # Check if services are running
    if ! docker ps --format "table {{.Names}}" | grep -q "opentelemetry-java-autoconfigure"; then
        print_warning "Services not running, starting them..."
        docker-compose up -d
        sleep 30  # Wait for services to start
    fi
    
    # Set up cleanup trap
    trap cleanup EXIT INT TERM
    
    # Create PID file
    echo $$ > "$PID_FILE"
    
    # Start chaos generation with logging
    print_status "Starting periodic chaos generation at $(date)"
    print_status "Log file: $LOG_FILE"
    
    # Run chaos script with full logging
    "$CHAOS_SCRIPT" > "$LOG_FILE" 2>&1
    local exit_code=$?
    
    # Log completion
    if [ $exit_code -eq 0 ]; then
        print_success "Chaos generation completed successfully at $(date)"
        echo "$(date): SUCCESS - Chaos generation completed" >> "$LOG_FILE"
    else
        print_error "Chaos generation failed with exit code: $exit_code at $(date)"
        echo "$(date): ERROR - Chaos generation failed with exit code: $exit_code" >> "$LOG_FILE"
    fi
    
    # Clean up old log files (keep last 24 hours)
    find "$LOG_DIR" -name "chaos_*.log" -mtime +1 -delete 2>/dev/null || true
    
    exit $exit_code
}

# Run the script
main "$@" 