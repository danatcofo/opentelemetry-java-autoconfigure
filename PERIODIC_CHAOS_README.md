# Periodic Chaos Generation Setup

This setup provides automated chaos engineering that runs every 5 minutes to continuously test your OpenTelemetry observability infrastructure.

## 🎯 Overview

The periodic chaos generation system consists of:

1. **`run_chaos_periodic.sh`** - Wrapper script called by cron
2. **`manage_chaos_cron.sh`** - Management script for controlling the cron job
3. **Cron job** - Runs every 5 minutes to execute chaos scenarios
4. **Logging** - All executions are logged with timestamps

## 🚀 Quick Start

### Check Status
```bash
./manage_chaos_cron.sh status
```

### Start Periodic Chaos Generation
```bash
./manage_chaos_cron.sh start
```

### Stop Periodic Chaos Generation
```bash
./manage_chaos_cron.sh stop
```

### View Recent Logs
```bash
./manage_chaos_cron.sh logs
```

### Test Run (Once)
```bash
./manage_chaos_cron.sh test
```

## 📋 Features

### ✅ **Automatic Service Management**
- Checks if Docker services are running
- Automatically starts services if needed
- Waits for services to be ready before chaos

### ✅ **Collision Prevention**
- Prevents multiple chaos runs from overlapping
- Uses PID file to track running instances
- Skips execution if chaos is already running

### ✅ **Comprehensive Logging**
- All executions logged with timestamps
- Log files: `logs/chaos_YYYYMMDD_HHMMSS.log`
- Automatic cleanup of old logs (24+ hours)

### ✅ **Robust Error Handling**
- Checks for required dependencies (Docker, docker-compose)
- Validates script permissions and existence
- Graceful cleanup on script termination

### ✅ **Multi-Service Chaos**
- Stops both Redis AND MySQL during chaos
- Tests cache and database failure scenarios
- Provides comprehensive observability data

## ⏰ Execution Schedule

The cron job runs every 5 minutes:
- **:00, :05, :10, :15, :20, :25, :30, :35, :40, :45, :50, :55**

Each execution includes:
1. **Baseline Period** (30-60 seconds) - Normal operations
2. **Chaos Period** (30 seconds) - Redis + MySQL failures
3. **Recovery Period** (20 seconds) - Service restoration
4. **Post-Recovery** - Complete trace analysis

## 📊 Expected OpenTelemetry Traces

### During Chaos Period:
- ❌ **Redis Failures**: `JedisConnectionException` spans
- ❌ **MySQL Failures**: `SQLException` spans  
- ❌ **Cache Errors**: Cache operation failures
- ❌ **Database Errors**: Connection pool exhaustion
- ❌ **Service Degradation**: Error propagation patterns

### During Recovery Period:
- ✅ **Redis Recovery**: Cache operation resumption
- ✅ **MySQL Recovery**: Database connection restoration
- ✅ **Service Health**: Performance improvement patterns
- ✅ **Connection Recovery**: Pool restoration traces

## 🔍 Monitoring & Analysis

### View Logs
```bash
# Recent logs
./manage_chaos_cron.sh logs

# All log files
ls -la logs/chaos_*.log

# Specific log file
cat logs/chaos_20240804_143000.log
```

### Jaeger Analysis
- **URL**: http://localhost:16686
- **Filter by Service**: `reviews-api`, `books-api`
- **Search Terms**: `cache.error OR JedisConnectionException OR SQLException`

### Key Metrics to Monitor
1. **Error Rate**: Before/during/after chaos periods
2. **Response Time**: Service degradation patterns
3. **Recovery Time**: How quickly services restore
4. **Error Propagation**: Cross-service impact
5. **Connection Pool**: Database/cache connection patterns

## 🛠️ Troubleshooting

### Check Cron Job Status
```bash
crontab -l
```

### Manual Test Run
```bash
./manage_chaos_cron.sh test
```

### View System Logs
```bash
# Cron job logs
tail -f /var/log/cron

# Docker service logs
docker-compose logs -f
```

### Common Issues

**Services not starting:**
```bash
docker-compose up -d
```

**Permission denied:**
```bash
chmod +x run_chaos_periodic.sh
chmod +x manage_chaos_cron.sh
```

**Cron job not running:**
```bash
# Check cron service
systemctl status crond

# Restart cron service
systemctl restart crond
```

## 📈 Benefits

### Continuous Testing
- **24/7 Chaos**: Continuous failure simulation
- **Realistic Scenarios**: Production-like failure patterns
- **Observability Validation**: Constant testing of monitoring

### Data Collection
- **Baseline Metrics**: Normal operation patterns
- **Failure Patterns**: Error propagation analysis
- **Recovery Patterns**: Service restoration metrics
- **Performance Impact**: Before/during/after comparisons

### Alert Testing
- **Alert Validation**: Ensures alerts fire correctly
- **Response Time**: Tests alert response procedures
- **Escalation**: Validates escalation workflows

## 🔧 Customization

### Change Execution Frequency
Edit the cron job:
```bash
# Every 10 minutes
echo "*/10 * * * * /root/projects/opentelemetry-java-autoconfigure/run_chaos_periodic.sh" | crontab -

# Every hour
echo "0 * * * * /root/projects/opentelemetry-java-autoconfigure/run_chaos_periodic.sh" | crontab -
```

### Modify Chaos Duration
Edit `chaos_traffic.sh`:
```bash
CHAOS_DURATION=60  # 60 seconds instead of 30
```

### Add More Services
Edit `chaos_traffic.sh` to add more service failures:
```bash
# Add PostgreSQL, MongoDB, etc.
POSTGRES_CONTAINER_NAME="opentelemetry-java-autoconfigure-postgres-1"
```

## 🎉 Summary

The periodic chaos generation system provides:

- ✅ **Automated chaos engineering** every 5 minutes
- ✅ **Multi-service failure testing** (Redis + MySQL)
- ✅ **Comprehensive logging** and monitoring
- ✅ **Easy management** with simple commands
- ✅ **Robust error handling** and collision prevention
- ✅ **Continuous observability validation**

This setup ensures your OpenTelemetry observability infrastructure is constantly tested and validated against realistic failure scenarios. 