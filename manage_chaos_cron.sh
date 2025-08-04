#!/bin/bash

# Management script for periodic chaos generation cron job

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_help() {
    echo -e "${CYAN}Chaos Cron Management Script${NC}"
    echo
    echo "Usage: $0 [COMMAND]"
    echo
    echo "Commands:"
    echo "  status    - Show current cron job status"
    echo "  start     - Start periodic chaos generation (every 5 minutes)"
    echo "  stop      - Stop periodic chaos generation"
    echo "  logs      - Show recent chaos generation logs"
    echo "  test      - Test run chaos generation once"
    echo "  help      - Show this help message"
    echo
    echo "Examples:"
    echo "  $0 status    # Check if cron job is active"
    echo "  $0 start     # Enable periodic chaos generation"
    echo "  $0 stop      # Disable periodic chaos generation"
    echo "  $0 logs      # View recent logs"
    echo "  $0 test      # Run chaos generation once for testing"
}

# Function to check if cron job is active
check_cron_status() {
    if crontab -l 2>/dev/null | grep -q "run_chaos_periodic.sh"; then
        return 0  # Active
    else
        return 1  # Inactive
    fi
}

# Function to show status
show_status() {
    print_status "Checking chaos generation cron job status..."
    
    if check_cron_status; then
        print_success "✅ Periodic chaos generation is ACTIVE"
        echo
        print_status "Current cron job:"
        crontab -l | grep "run_chaos_periodic.sh"
        echo
        print_status "Next execution times:"
        echo "  - Every 5 minutes (at :00, :05, :10, :15, etc.)"
        echo
        print_status "Recent logs:"
        if [ -d "logs" ] && ls logs/chaos_*.log >/dev/null 2>&1; then
            ls -la logs/chaos_*.log | tail -5
        else
            print_warning "No log files found"
        fi
    else
        print_warning "❌ Periodic chaos generation is INACTIVE"
        echo
        print_status "To start periodic chaos generation, run:"
        echo "  $0 start"
    fi
}

# Function to start periodic chaos generation
start_chaos() {
    print_status "Starting periodic chaos generation..."
    
    if check_cron_status; then
        print_warning "Periodic chaos generation is already active"
        return 0
    fi
    
    echo "*/5 * * * * /root/projects/opentelemetry-java-autoconfigure/run_chaos_periodic.sh" | crontab -
    
    if check_cron_status; then
        print_success "✅ Periodic chaos generation STARTED"
        print_status "Chaos will run every 5 minutes"
        print_status "Logs will be saved to: logs/chaos_*.log"
    else
        print_error "Failed to start periodic chaos generation"
        return 1
    fi
}

# Function to stop periodic chaos generation
stop_chaos() {
    print_status "Stopping periodic chaos generation..."
    
    if ! check_cron_status; then
        print_warning "Periodic chaos generation is not active"
        return 0
    fi
    
    # Remove the chaos cron job while keeping any other cron jobs
    crontab -l | grep -v "run_chaos_periodic.sh" | crontab -
    
    if ! check_cron_status; then
        print_success "✅ Periodic chaos generation STOPPED"
    else
        print_error "Failed to stop periodic chaos generation"
        return 1
    fi
}

# Function to show logs
show_logs() {
    print_status "Showing recent chaos generation logs..."
    
    if [ ! -d "logs" ]; then
        print_warning "Logs directory does not exist"
        return 0
    fi
    
    if ! ls logs/chaos_*.log >/dev/null 2>&1; then
        print_warning "No log files found"
        return 0
    fi
    
    echo
    print_status "Recent chaos generation logs:"
    echo "============================================================"
    
    # Show last 3 log files
    for log_file in $(ls -t logs/chaos_*.log | head -3); do
        echo
        print_status "Log file: $log_file"
        echo "------------------------------------------------------------"
        tail -20 "$log_file" 2>/dev/null || echo "Unable to read log file"
        echo "------------------------------------------------------------"
    done
    
    echo
    print_status "To view all logs: ls -la logs/chaos_*.log"
    print_status "To view specific log: cat logs/chaos_YYYYMMDD_HHMMSS.log"
}

# Function to test run chaos generation
test_chaos() {
    print_status "Running chaos generation test..."
    
    if [ ! -f "run_chaos_periodic.sh" ]; then
        print_error "Chaos script not found: run_chaos_periodic.sh"
        return 1
    fi
    
    if [ ! -x "run_chaos_periodic.sh" ]; then
        print_error "Chaos script is not executable"
        return 1
    fi
    
    print_status "Starting test run of chaos generation..."
    ./run_chaos_periodic.sh
    
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        print_success "✅ Test run completed successfully"
    else
        print_error "❌ Test run failed with exit code: $exit_code"
    fi
    
    return $exit_code
}

# Main execution
main() {
    case "${1:-help}" in
        "status")
            show_status
            ;;
        "start")
            start_chaos
            ;;
        "stop")
            stop_chaos
            ;;
        "logs")
            show_logs
            ;;
        "test")
            test_chaos
            ;;
        "help"|"-h"|"--help")
            print_help
            ;;
        *)
            print_error "Unknown command: $1"
            echo
            print_help
            exit 1
            ;;
    esac
}

# Run the script
main "$@" 