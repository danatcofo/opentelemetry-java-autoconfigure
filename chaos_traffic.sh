#!/bin/bash

# OpenTelemetry Chaos Engineering Script
# Generates API traffic while introducing Redis failures for observability testing

set -e

# Configuration
TRAFFIC_SCRIPT="./generate_traffic.sh"
REDIS_CONTAINER_NAME="opentelemetry-java-autoconfigure-redis-1"
MYSQL_CONTAINER_NAME="opentelemetry-java-autoconfigure-mysql-1"
MIN_WAIT_BEFORE_CHAOS=30    # Minimum seconds before introducing chaos
MAX_WAIT_BEFORE_CHAOS=60    # Maximum seconds before introducing chaos
CHAOS_DURATION=30           # How long to keep services down (seconds)
RECOVERY_WAIT=20            # Time to wait after service recovery before ending

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

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_chaos() {
    echo -e "${PURPLE}[CHAOS]${NC} $1"
}

print_recovery() {
    echo -e "${CYAN}[RECOVERY]${NC} $1"
}

# Function to check if Docker container is running
is_container_running() {
    local container_name="$1"
    docker ps --format "table {{.Names}}" | grep -q "^${container_name}$"
}

# Function to get container status
get_container_status() {
    local container_name="$1"
    docker ps -a --filter "name=${container_name}" --format "{{.Status}}" | head -1
}

# Function to wait for Redis to be ready
wait_for_redis() {
    print_status "Waiting for Redis to be ready..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker exec "$REDIS_CONTAINER_NAME" redis-cli ping > /dev/null 2>&1; then
            print_success "Redis is ready!"
            return 0
        fi
        
        echo -n "."
        sleep 1
        attempt=$((attempt + 1))
    done
    
    print_error "Redis failed to become ready after $max_attempts seconds"
    return 1
}

# Function to wait for MySQL to be ready
wait_for_mysql() {
    print_status "Waiting for MySQL to be ready..."
    local max_attempts=60
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker exec "$MYSQL_CONTAINER_NAME" mysqladmin ping -h localhost --silent > /dev/null 2>&1; then
            print_success "MySQL is ready!"
            return 0
        fi
        
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    print_error "MySQL failed to become ready after $max_attempts seconds"
    return 1
}

# Function to stop Redis container
stop_redis() {
    print_chaos "🔥 INTRODUCING CHAOS: Stopping Redis service..."
    
    if is_container_running "$REDIS_CONTAINER_NAME"; then
        docker stop "$REDIS_CONTAINER_NAME" > /dev/null 2>&1
        print_chaos "💥 Redis service STOPPED - Cache failures expected!"
        
        # Show what to expect
        echo
        print_warning "Expected OpenTelemetry traces during Redis failure:"
        echo "  ❌ Cache GET/PUT/EVICT errors in review service"
        echo "  ❌ JedisConnectionException spans"
        echo "  ❌ ERROR status spans with exception details"
        echo "  ❌ Cache fallback behavior traces"
        echo "  ❌ Service degradation patterns"
        echo
    else
        print_error "Redis container is not running!"
        return 1
    fi
}

# Function to start Redis container
start_redis() {
    print_recovery "🔧 RECOVERY: Starting Redis service..."
    
    if ! is_container_running "$REDIS_CONTAINER_NAME"; then
        docker start "$REDIS_CONTAINER_NAME" > /dev/null 2>&1
        
        if wait_for_redis; then
            print_recovery "✅ Redis service RECOVERED - Cache operations resuming!"
            
            # Show what to expect
            echo
            print_success "Expected OpenTelemetry traces during Redis recovery:"
            echo "  ✅ Successful cache operations resuming"
            echo "  ✅ Connection recovery spans"
            echo "  ✅ Service health improvement patterns"
            echo "  ✅ Performance comparison before/during/after failure"
            echo
        else
            print_error "Failed to recover Redis service"
            return 1
        fi
    else
        print_warning "Redis container is already running"
    fi
}

# Function to stop MySQL container
stop_mysql() {
    print_chaos "🔥 INTRODUCING CHAOS: Stopping MySQL service..."
    
    if is_container_running "$MYSQL_CONTAINER_NAME"; then
        docker stop "$MYSQL_CONTAINER_NAME" > /dev/null 2>&1
        print_chaos "💥 MySQL service STOPPED - Database failures expected!"
        
        # Show what to expect
        echo
        print_warning "Expected OpenTelemetry traces during MySQL failure:"
        echo "  ❌ Database connection errors in books service"
        echo "  ❌ SQLException spans"
        echo "  ❌ ERROR status spans with database exception details"
        echo "  ❌ Connection pool exhaustion traces"
        echo "  ❌ Service degradation patterns"
        echo
    else
        print_error "MySQL container is not running!"
        return 1
    fi
}

# Function to start MySQL container
start_mysql() {
    print_recovery "🔧 RECOVERY: Starting MySQL service..."
    
    if ! is_container_running "$MYSQL_CONTAINER_NAME"; then
        docker start "$MYSQL_CONTAINER_NAME" > /dev/null 2>&1
        
        if wait_for_mysql; then
            print_recovery "✅ MySQL service RECOVERED - Database operations resuming!"
            
            # Show what to expect
            echo
            print_success "Expected OpenTelemetry traces during MySQL recovery:"
            echo "  ✅ Successful database operations resuming"
            echo "  ✅ Connection pool recovery spans"
            echo "  ✅ Service health improvement patterns"
            echo "  ✅ Performance comparison before/during/after failure"
            echo
        else
            print_error "Failed to recover MySQL service"
            return 1
        fi
    else
        print_warning "MySQL container is already running"
    fi
}

# Function to monitor traffic script
monitor_traffic() {
    local traffic_pid="$1"
    
    while kill -0 "$traffic_pid" 2>/dev/null; do
        sleep 2
    done
    
    wait "$traffic_pid"
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        print_success "Traffic generation completed successfully"
    else
        print_warning "Traffic generation completed with exit code: $exit_code"
    fi
    
    return $exit_code
}

# Function to cleanup on script exit
cleanup() {
    print_status "Cleaning up..."
    
    # Kill traffic generation if still running
    if [ ! -z "$TRAFFIC_PID" ] && kill -0 "$TRAFFIC_PID" 2>/dev/null; then
        print_status "Stopping traffic generation..."
        kill "$TRAFFIC_PID" 2>/dev/null || true
        wait "$TRAFFIC_PID" 2>/dev/null || true
    fi
    
    # Ensure Redis is running for next time
    if ! is_container_running "$REDIS_CONTAINER_NAME"; then
        print_status "Ensuring Redis is running for next execution..."
        start_redis || true
    fi
    
    # Ensure MySQL is running for next time
    if ! is_container_running "$MYSQL_CONTAINER_NAME"; then
        print_status "Ensuring MySQL is running for next execution..."
        start_mysql || true
    fi
    
    print_status "Cleanup complete"
}

# Function to show chaos timeline
show_chaos_timeline() {
    local chaos_wait="$1"
    
    echo
    print_status "🎭 CHAOS ENGINEERING TIMELINE:"
    echo "  📊 Phase 1: Normal Operations (0-${chaos_wait}s)"
    echo "      - Baseline telemetry collection"
    echo "      - All services healthy"
    echo "      - Cache and database operations working"
    echo
    echo "  💥 Phase 2: Chaos Introduction (${chaos_wait}s)"
    echo "      - Redis service failure"
    echo "      - MySQL service failure"
    echo "      - Cache and database errors and exceptions"
    echo "      - Error trace generation"
    echo
    echo "  ⚡ Phase 3: Chaos Duration (${chaos_wait}-$((chaos_wait + CHAOS_DURATION))s)"
    echo "      - Service degradation patterns"
    echo "      - Fallback behavior traces"
    echo "      - Error propagation observation"
    echo "      - Multi-service failure impact"
    echo
    echo "  🔧 Phase 4: Recovery ($((chaos_wait + CHAOS_DURATION))s)"
    echo "      - Redis service restoration"
    echo "      - MySQL service restoration"
    echo "      - Connection recovery traces"
    echo "      - Service health improvement"
    echo
    echo "  📈 Phase 5: Post-Recovery"
    echo "      - Performance comparison"
    echo "      - Complete trace analysis"
    echo "      - SLI/SLO impact assessment"
    echo "      - Multi-service recovery patterns"
    echo
}

# Main execution
main() {
    echo "============================================================"
    echo "  🎭 OpenTelemetry Chaos Engineering Script"
    echo "============================================================"
    echo "Purpose: Generate realistic failure scenarios for observability"
    echo "Target: Redis cache and MySQL database failures during traffic generation"
    echo "Traffic Script: $TRAFFIC_SCRIPT"
    echo "Chaos Window: ${MIN_WAIT_BEFORE_CHAOS}-${MAX_WAIT_BEFORE_CHAOS}s"
    echo "Chaos Duration: ${CHAOS_DURATION}s"
    echo "============================================================"
    echo
    
    # Setup cleanup trap
    trap cleanup EXIT INT TERM
    
    # Pre-flight checks
    print_status "🔍 Running pre-flight checks..."
    
    # Check if traffic script exists
    if [ ! -f "$TRAFFIC_SCRIPT" ]; then
        print_error "Traffic script not found: $TRAFFIC_SCRIPT"
        exit 1
    fi
    
    if [ ! -x "$TRAFFIC_SCRIPT" ]; then
        print_error "Traffic script is not executable: $TRAFFIC_SCRIPT"
        print_status "Run: chmod +x $TRAFFIC_SCRIPT"
        exit 1
    fi
    
    # Check if Docker is available
    if ! command -v docker > /dev/null 2>&1; then
        print_error "Docker is not available"
        exit 1
    fi
    
    # Check if Redis container exists
    if ! docker ps -a --filter "name=${REDIS_CONTAINER_NAME}" --format "{{.Names}}" | grep -q "^${REDIS_CONTAINER_NAME}$"; then
        print_error "Redis container not found: $REDIS_CONTAINER_NAME"
        print_status "Make sure to run: docker-compose up -d"
        exit 1
    fi
    
    # Check if MySQL container exists
    if ! docker ps -a --filter "name=${MYSQL_CONTAINER_NAME}" --format "{{.Names}}" | grep -q "^${MYSQL_CONTAINER_NAME}$"; then
        print_error "MySQL container not found: $MYSQL_CONTAINER_NAME"
        print_status "Make sure to run: docker-compose up -d"
        exit 1
    fi
    
    # Ensure Redis is running
    if ! is_container_running "$REDIS_CONTAINER_NAME"; then
        print_status "Starting Redis container..."
        start_redis
    else
        print_success "Redis container is already running"
        # Verify Redis is actually responsive
        if ! wait_for_redis; then
            print_error "Redis is not responding, attempting restart..."
            docker restart "$REDIS_CONTAINER_NAME" > /dev/null 2>&1
            wait_for_redis
        fi
    fi
    
    # Ensure MySQL is running
    if ! is_container_running "$MYSQL_CONTAINER_NAME"; then
        print_status "Starting MySQL container..."
        start_mysql
    else
        print_success "MySQL container is already running"
        # Verify MySQL is actually responsive
        if ! wait_for_mysql; then
            print_error "MySQL is not responding, attempting restart..."
            docker restart "$MYSQL_CONTAINER_NAME" > /dev/null 2>&1
            wait_for_mysql
        fi
    fi
    
    # Calculate random chaos timing
    local chaos_wait=$((RANDOM % (MAX_WAIT_BEFORE_CHAOS - MIN_WAIT_BEFORE_CHAOS + 1) + MIN_WAIT_BEFORE_CHAOS))
    
    show_chaos_timeline "$chaos_wait"
    
    # Start traffic generation in background
    print_status "🚀 Starting traffic generation..."
    "$TRAFFIC_SCRIPT" &
    TRAFFIC_PID=$!
    
    print_success "Traffic generation started (PID: $TRAFFIC_PID)"
    print_status "📊 Collecting baseline telemetry for ${chaos_wait} seconds..."
    
    # Wait for the chaos moment
    sleep "$chaos_wait"
    
    # Introduce chaos (stop Redis and MySQL)
    stop_redis
    stop_mysql
    
    # Let chaos run for specified duration
    print_status "⏱️  Chaos running for ${CHAOS_DURATION} seconds..."
    sleep "$CHAOS_DURATION"
    
    # Recover services
    start_redis
    start_mysql
    
    # Wait a bit more for recovery traces
    print_status "⏱️  Collecting recovery telemetry for ${RECOVERY_WAIT} seconds..."
    sleep "$RECOVERY_WAIT"
    
    # Wait for traffic generation to complete
    print_status "⏳ Waiting for traffic generation to complete..."
    monitor_traffic "$TRAFFIC_PID"
    
    # Final summary
    echo
    echo "============================================================"
    echo "  🎉 Chaos Engineering Experiment Complete!"
    echo "============================================================"
    echo "Chaos Timeline:"
    echo "  ✅ Baseline Period: ${chaos_wait}s"
    echo "  💥 Chaos Period: ${CHAOS_DURATION}s" 
    echo "  🔧 Recovery Period: ${RECOVERY_WAIT}s"
    echo
    echo "🔍 Recommended Analysis:"
    echo "  1. Compare trace performance before/during/after failure"
    echo "  2. Analyze error propagation patterns across services"
    echo "  3. Verify cache fallback behavior in traces"
    echo "  4. Check database connection error patterns"
    echo "  5. Check exception correlation in spans"
    echo "  6. Measure service recovery time"
    echo "  7. Analyze multi-service failure impact"
    echo
    echo "📊 View Results:"
    echo "  - Jaeger UI: http://localhost:16686"
    echo "  - BMC Platform: (your configured endpoint)"
    echo "  - Filter by service: reviews-api, books-api"
    echo "  - Search for: cache.error OR JedisConnectionException OR SQLException"
    echo "============================================================"
}

# Run the script
main "$@" 