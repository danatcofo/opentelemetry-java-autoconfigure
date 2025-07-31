#!/bin/bash

# Manual Chaos Engineering Script
# Provides individual commands to control Redis during traffic generation

# Configuration
REDIS_CONTAINER_NAME="opentelemetry-java-autoconfigure-redis-1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_chaos() {
    echo -e "${PURPLE}[CHAOS]${NC} $1"
}

print_recovery() {
    echo -e "${CYAN}[RECOVERY]${NC} $1"
}

# Function to check Redis status
check_redis() {
    print_status "Checking Redis container status..."
    
    if docker ps --filter "name=${REDIS_CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}" | grep -q "$REDIS_CONTAINER_NAME"; then
        print_success "Redis is running"
        
        # Test connectivity
        if docker exec "$REDIS_CONTAINER_NAME" redis-cli ping > /dev/null 2>&1; then
            print_success "Redis is responding to ping"
        else
            print_error "Redis container is running but not responding"
        fi
    else
        print_error "Redis container is not running"
        
        # Check if it exists but stopped
        if docker ps -a --filter "name=${REDIS_CONTAINER_NAME}" --format "{{.Names}}" | grep -q "$REDIS_CONTAINER_NAME"; then
            local status=$(docker ps -a --filter "name=${REDIS_CONTAINER_NAME}" --format "{{.Status}}")
            print_status "Container status: $status"
        else
            print_error "Redis container does not exist"
        fi
    fi
}

# Function to stop Redis
stop_redis() {
    print_chaos "🔥 Stopping Redis service for chaos testing..."
    
    if docker ps --filter "name=${REDIS_CONTAINER_NAME}" --format "{{.Names}}" | grep -q "$REDIS_CONTAINER_NAME"; then
        docker stop "$REDIS_CONTAINER_NAME"
        print_chaos "💥 Redis STOPPED - Cache errors should now appear in traces!"
        echo
        print_status "🔍 Monitor these in OpenTelemetry:"
        echo "  ❌ JedisConnectionException in review service"
        echo "  ❌ Cache operation failures (GET/PUT/EVICT)"
        echo "  ❌ ERROR status spans in reviews-api"
        echo "  ❌ Exception details in span events"
        echo "  ❌ Service degradation patterns"
    else
        print_error "Redis container is not running"
        return 1
    fi
}

# Function to start Redis
start_redis() {
    print_recovery "🔧 Starting Redis service..."
    
    if ! docker ps --filter "name=${REDIS_CONTAINER_NAME}" --format "{{.Names}}" | grep -q "$REDIS_CONTAINER_NAME"; then
        docker start "$REDIS_CONTAINER_NAME"
        
        # Wait for Redis to be ready
        print_status "Waiting for Redis to be ready..."
        local attempts=0
        local max_attempts=30
        
        while [ $attempts -lt $max_attempts ]; do
            if docker exec "$REDIS_CONTAINER_NAME" redis-cli ping > /dev/null 2>&1; then
                print_recovery "✅ Redis RECOVERED - Cache operations resuming!"
                echo
                print_status "🔍 Monitor these in OpenTelemetry:"
                echo "  ✅ Cache operations succeeding again"
                echo "  ✅ Connection recovery traces"
                echo "  ✅ Performance improvement patterns"
                echo "  ✅ Error rate decrease"
                return 0
            fi
            
            echo -n "."
            sleep 1
            attempts=$((attempts + 1))
        done
        
        print_error "Redis started but not responding after $max_attempts seconds"
        return 1
    else
        print_status "Redis container is already running"
    fi
}

# Function to restart Redis
restart_redis() {
    print_status "🔄 Restarting Redis service..."
    docker restart "$REDIS_CONTAINER_NAME"
    
    # Wait for readiness
    print_status "Waiting for Redis to be ready..."
    local attempts=0
    local max_attempts=30
    
    while [ $attempts -lt $max_attempts ]; do
        if docker exec "$REDIS_CONTAINER_NAME" redis-cli ping > /dev/null 2>&1; then
            print_success "Redis restarted successfully!"
            return 0
        fi
        
        echo -n "."
        sleep 1
        attempts=$((attempts + 1))
    done
    
    print_error "Redis restart failed or not responding"
    return 1
}

# Function to show usage
show_usage() {
    echo "============================================================"
    echo "  🎭 Manual Chaos Engineering for OpenTelemetry"
    echo "============================================================"
    echo "Usage: $0 <command>"
    echo
    echo "Commands:"
    echo "  check     - Check Redis container status"
    echo "  stop      - Stop Redis to introduce cache failures"
    echo "  start     - Start Redis to recover from failures"  
    echo "  restart   - Restart Redis service"
    echo "  help      - Show this help message"
    echo
    echo "Typical workflow:"
    echo "  1. Start traffic generation: ./generate_traffic.sh &"
    echo "  2. Let it run for baseline: sleep 30"
    echo "  3. Introduce chaos: $0 stop"
    echo "  4. Observe error traces for 30s"
    echo "  5. Recover service: $0 start"
    echo "  6. Monitor recovery patterns"
    echo
    echo "Monitor traces at:"
    echo "  - Jaeger UI: http://localhost:16686"
    echo "  - BMC Platform: (your configured endpoint)"
    echo "============================================================"
}

# Main execution
main() {
    case "${1:-help}" in
        "check")
            check_redis
            ;;
        "stop")
            stop_redis
            ;;
        "start")
            start_redis
            ;;
        "restart")
            restart_redis
            ;;
        "help"|"--help"|"-h"|"")
            show_usage
            ;;
        *)
            print_error "Unknown command: $1"
            echo
            show_usage
            exit 1
            ;;
    esac
}

# Run the script
main "$@" 