# OpenTelemetry Chaos Engineering Scripts

This directory contains scripts for generating traffic and introducing controlled failures to test OpenTelemetry observability.

## Scripts Overview

### 1. `generate_traffic.sh` - Traffic Generation
**Purpose:** Generates comprehensive API traffic across all services for baseline telemetry collection.

**What it does:**
- Creates 5 authors with realistic data
- Creates 3 books per author (15 total books)
- Creates 4 reviews per book (60 total reviews) 
- Performs read operations to generate cache hits
- Tests error scenarios with invalid data
- Generates mixed traffic patterns

**Usage:**
```bash
./generate_traffic.sh
```

### 2. `chaos_traffic.sh` - Automated Chaos Engineering
**Purpose:** Runs traffic generation while automatically introducing Redis failures at random times.

**What it does:**
- Ensures Redis is healthy
- Starts traffic generation in background
- Waits 30-60 seconds (random) for baseline
- Stops Redis service for 30 seconds
- Restarts Redis service
- Waits for recovery and completion

**Usage:**
```bash
./chaos_traffic.sh
```

### 3. `manual_chaos.sh` - Manual Chaos Control
**Purpose:** Provides manual control over Redis service for precise chaos timing.

**Commands:**
```bash
./manual_chaos.sh check    # Check Redis status
./manual_chaos.sh stop     # Stop Redis (introduce chaos)
./manual_chaos.sh start    # Start Redis (recover)
./manual_chaos.sh restart  # Restart Redis
./manual_chaos.sh help     # Show usage
```

## Recommended Workflows

### Workflow 1: Automated Chaos Testing
```bash
# Start all services
docker-compose up -d

# Run automated chaos experiment
./chaos_traffic.sh

# View results in Jaeger UI: http://localhost:16686
```

### Workflow 2: Manual Chaos Testing
```bash
# Terminal 1: Start traffic generation
./generate_traffic.sh &

# Terminal 2: Monitor and control chaos
sleep 30                           # Baseline period
./manual_chaos.sh stop            # Introduce failure
sleep 30                           # Observe failures  
./manual_chaos.sh start           # Recover service
```

### Workflow 3: Repeated Testing
```bash
# Multiple chaos experiments
for i in {1..3}; do
    echo "=== Chaos Experiment $i ==="
    ./chaos_traffic.sh
    sleep 60  # Cool down between experiments
done
```

## OpenTelemetry Traces to Monitor

### During Normal Operations
- ✅ Successful HTTP requests across gateway
- ✅ Database operations (MySQL reads/writes)
- ✅ Cache hits/misses (Redis operations)
- ✅ Inter-service communication (Feign calls)
- ✅ Custom span annotations (@WithSpan)

### During Redis Failures
- ❌ **JedisConnectionException** spans
- ❌ **Cache operation failures** (GET/PUT/EVICT)
- ❌ **ERROR status spans** in reviews-api
- ❌ **Exception details** in span events
- ❌ **Service degradation** patterns
- ❌ **Error propagation** across services

### During Recovery
- ✅ **Connection recovery** traces
- ✅ **Cache operations resuming**
- ✅ **Performance improvement** patterns
- ✅ **Error rate decrease**

## Analysis Guide

### 1. Jaeger UI Analysis
**URL:** http://localhost:16686

**Filters to use:**
- Service: `reviews-api`
- Tags: `error=true`
- Operation: `ReviewService.getReviews`
- Search: `JedisConnectionException`

### 2. BMC Platform Analysis
**Endpoint:** Your configured OTLP endpoint

**Key metrics to track:**
- Error rate changes during chaos
- Latency spikes during failures
- Recovery time measurements
- Service dependency mapping

### 3. Trace Patterns to Look For

#### Error Propagation
```
Gateway → Books API → Reviews API → Redis (FAIL)
   ↓
ERROR spans with proper exception correlation
```

#### Cache Fallback Behavior
```
Reviews API → Redis (FAIL) → Database (FALLBACK)
   ↓
Different performance characteristics in traces
```

#### Service Recovery
```
Redis RESTART → Connection Pool Recovery → Normal Operations
   ↓
Gradual performance improvement in traces
```

## Configuration

### Traffic Generation Settings
Edit `generate_traffic.sh`:
```bash
TOTAL_AUTHORS=5           # Number of authors to create
BOOKS_PER_AUTHOR=3       # Books per author
REVIEWS_PER_BOOK=4       # Reviews per book
SLEEP_BETWEEN_CALLS=1    # Delay between API calls
```

### Chaos Timing Settings
Edit `chaos_traffic.sh`:
```bash
MIN_WAIT_BEFORE_CHAOS=30    # Min seconds before chaos
MAX_WAIT_BEFORE_CHAOS=60    # Max seconds before chaos  
CHAOS_DURATION=30           # Chaos duration in seconds
RECOVERY_WAIT=20            # Recovery observation time
```

## Expected Results

### Traffic Volume
- **Authors:** 5 created
- **Books:** 15 created (3 per author)
- **Reviews:** 60 created (4 per book)
- **Read Operations:** ~25 cache lookups
- **Error Tests:** 3 deliberate failures

### Trace Volume
- **Successful spans:** ~150 spans
- **Error spans:** ~10 spans (during chaos)
- **Cross-service calls:** ~90 spans
- **Database operations:** ~80 spans
- **Cache operations:** ~70 spans

### Observability Insights
1. **Baseline Performance:** Normal operation metrics
2. **Failure Impact:** Service degradation patterns
3. **Error Handling:** Exception trace correlation
4. **Recovery Patterns:** Service restoration behavior
5. **Dependency Mapping:** Service interaction visualization

## Troubleshooting

### Common Issues
1. **Redis container not found:** Run `docker-compose up -d`
2. **Traffic script not executable:** Run `chmod +x *.sh`
3. **Services not responding:** Check `docker-compose logs`
4. **No traces in Jaeger:** Verify OTLP collector is running

### Debug Commands
```bash
# Check all services
docker-compose ps

# View logs
docker-compose logs reviews-api
docker-compose logs otel-collector

# Test connectivity
curl http://localhost:9000/author
curl http://localhost:16686
``` 