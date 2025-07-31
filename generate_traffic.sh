#!/bin/bash

# OpenTelemetry Traffic Generation Script
# Generates API traffic across all services for observability testing

set -e

# Configuration
BASE_URL="http://localhost:9000"
SLEEP_BETWEEN_CALLS=1
TOTAL_AUTHORS=5
BOOKS_PER_AUTHOR=3
REVIEWS_PER_BOOK=4

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Array to store created IDs
declare -a AUTHOR_IDS
declare -a BOOK_IDS

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

# Function to make API calls with error handling
make_api_call() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    local description="$4"
    
    print_status "Making $method request to $endpoint - $description"
    
    if [ "$method" = "POST" ]; then
        response=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
            -X POST \
            -H "Content-Type: application/json" \
            -H "User-Agent: OTel-Traffic-Generator/1.0" \
            -d "$data" \
            "$BASE_URL$endpoint")
    else
        response=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
            -H "User-Agent: OTel-Traffic-Generator/1.0" \
            "$BASE_URL$endpoint")
    fi
    
    # Extract HTTP code and body
    http_code=$(echo "$response" | tail -n1 | sed 's/.*HTTP_CODE://')
    response_body=$(echo "$response" | sed '$d')
    
    if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
        print_success "$description completed (HTTP $http_code)"
        echo "$response_body"
        sleep $SLEEP_BETWEEN_CALLS
        return 0
    else
        print_error "$description failed (HTTP $http_code)"
        echo "Response: $response_body"
        return 1
    fi
}

# Function to extract ID from JSON response
extract_id() {
    echo "$1" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2
}

# Function to create authors
create_authors() {
    print_status "Creating $TOTAL_AUTHORS authors..."
    
    local authors=(
        '{"name": "J.K. Rowling", "birth": 1965, "location": "United Kingdom"}'
        '{"name": "Stephen King", "birth": 1947, "location": "United States"}'
        '{"name": "Agatha Christie", "birth": 1890, "location": "United Kingdom"}'
        '{"name": "George Orwell", "birth": 1903, "location": "United Kingdom"}'
        '{"name": "Mark Twain", "birth": 1835, "location": "United States"}'
        '{"name": "Charles Dickens", "birth": 1812, "location": "United Kingdom"}'
        '{"name": "Jane Austen", "birth": 1775, "location": "United Kingdom"}'
        '{"name": "Ernest Hemingway", "birth": 1899, "location": "United States"}'
    )
    
    for i in $(seq 1 $TOTAL_AUTHORS); do
        local author_data="${authors[$((i-1))]}"
        local response=$(make_api_call "POST" "/author" "$author_data" "Creating author $i")
        
        if [ $? -eq 0 ]; then
            local author_id=$(extract_id "$response")
            AUTHOR_IDS+=("$author_id")
            print_success "Created author with ID: $author_id"
        fi
    done
    
    print_success "Created ${#AUTHOR_IDS[@]} authors"
}

# Function to create books
create_books() {
    print_status "Creating books for each author..."
    
    local book_templates=(
        '{"name": "The Mysterious Case", "year": 2023}'
        '{"name": "Adventures in Code", "year": 2022}'
        '{"name": "Digital Horizons", "year": 2024}'
        '{"name": "The Last Algorithm", "year": 2021}'
        '{"name": "Quantum Dreams", "year": 2023}'
        '{"name": "Binary Sunset", "year": 2022}'
        '{"name": "The Network Effect", "year": 2024}'
        '{"name": "Silicon Valley Tales", "year": 2023}'
        '{"name": "The Cloud Chronicles", "year": 2022}'
        '{"name": "Microservice Mysteries", "year": 2024}'
    )
    
    local book_index=0
    for author_id in "${AUTHOR_IDS[@]}"; do
        for j in $(seq 1 $BOOKS_PER_AUTHOR); do
            local base_book="${book_templates[$book_index]}"
            # Add author_id to the JSON
            local book_data=$(echo "$base_book" | sed "s/}$/, \"author_id\": $author_id}/")
            
            local response=$(make_api_call "POST" "/books" "$book_data" "Creating book $j for author $author_id")
            
            if [ $? -eq 0 ]; then
                local book_id=$(extract_id "$response")
                BOOK_IDS+=("$book_id")
                print_success "Created book with ID: $book_id for author: $author_id"
            fi
            
            book_index=$(((book_index + 1) % ${#book_templates[@]}))
        done
    done
    
    print_success "Created ${#BOOK_IDS[@]} books"
}

# Function to create reviews
create_reviews() {
    print_status "Creating reviews for each book..."
    
    local review_templates=(
        '{"review": "Absolutely fantastic! Could not put it down.", "rate": 5.0}'
        '{"review": "Great read, highly recommended.", "rate": 4.5}'
        '{"review": "Pretty good, but could be better.", "rate": 3.5}'
        '{"review": "Excellent storytelling and character development.", "rate": 5.0}'
        '{"review": "Good book, worth reading.", "rate": 4.0}'
        '{"review": "Not bad, but not great either.", "rate": 3.0}'
        '{"review": "Outstanding work! A masterpiece.", "rate": 5.0}'
        '{"review": "Decent read for a quiet evening.", "rate": 3.5}'
        '{"review": "Amazing plot twists and engaging narrative.", "rate": 4.5}'
        '{"review": "One of the best books I have read this year.", "rate": 5.0}'
        '{"review": "Could use some improvement but overall solid.", "rate": 3.0}'
        '{"review": "Captivating from start to finish.", "rate": 4.0}'
    )
    
    local review_index=0
    for book_id in "${BOOK_IDS[@]}"; do
        print_status "Creating $REVIEWS_PER_BOOK reviews for book ID: $book_id"
        
        for k in $(seq 1 $REVIEWS_PER_BOOK); do
            local base_review="${review_templates[$review_index]}"
            # Add book_id to the JSON
            local review_data=$(echo "$base_review" | sed "s/}$/, \"book_id\": $book_id}/")
            
            local response=$(make_api_call "POST" "/reviews" "$review_data" "Creating review $k for book $book_id")
            
            if [ $? -eq 0 ]; then
                local review_id=$(extract_id "$response")
                print_success "Created review with ID: $review_id for book: $book_id"
            fi
            
            review_index=$(((review_index + 1) % ${#review_templates[@]}))
        done
    done
}

# Function to fetch reviews (read operations)
fetch_reviews() {
    print_status "Fetching reviews for all books to generate read traffic..."
    
    for book_id in "${BOOK_IDS[@]}"; do
        local response=$(make_api_call "GET" "/reviews?book=$book_id" "" "Fetching reviews for book $book_id")
        
        if [ $? -eq 0 ]; then
            local review_count=$(echo "$response" | grep -o '"id":' | wc -l)
            print_success "Retrieved $review_count reviews for book ID: $book_id"
        fi
    done
}

# Function to generate mixed traffic patterns
generate_mixed_traffic() {
    print_status "Generating mixed traffic patterns for comprehensive traces..."
    
    # Random operations to create realistic traffic
    for i in $(seq 1 10); do
        # Randomly fetch reviews for different books
        if [ ${#BOOK_IDS[@]} -gt 0 ]; then
            local random_book_index=$((RANDOM % ${#BOOK_IDS[@]}))
            local random_book_id="${BOOK_IDS[$random_book_index]}"
            make_api_call "GET" "/reviews?book=$random_book_id" "" "Random review fetch #$i"
        fi
        
        sleep $((RANDOM % 3 + 1))  # Random sleep between 1-3 seconds
    done
}

# Function to test error scenarios
test_error_scenarios() {
    print_status "Testing error scenarios for exception traces..."
    
    # Test invalid book ID in review creation
    print_warning "Testing invalid book ID (should generate error trace)..."
    make_api_call "POST" "/reviews" '{"review": "Test review", "rate": 4.0, "book_id": 99999}' "Creating review with invalid book ID" || true
    
    # Test fetching reviews for non-existent book
    print_warning "Testing non-existent book review fetch (should generate error trace)..."
    make_api_call "GET" "/reviews?book=99999" "" "Fetching reviews for non-existent book" || true
    
    # Test invalid author data
    print_warning "Testing invalid author data (should generate validation error)..."
    make_api_call "POST" "/author" '{"name": "", "birth": 1800, "location": ""}' "Creating author with invalid data" || true
}

# Main execution
main() {
    echo "=================================================="
    echo "  OpenTelemetry Traffic Generation Script"
    echo "=================================================="
    echo "Target: $BASE_URL"
    echo "Authors: $TOTAL_AUTHORS"
    echo "Books per author: $BOOKS_PER_AUTHOR"  
    echo "Reviews per book: $REVIEWS_PER_BOOK"
    echo "Sleep between calls: ${SLEEP_BETWEEN_CALLS}s"
    echo "=================================================="
    echo
    
    # Check if services are running
    print_status "Checking if services are available..."
    if ! curl -s "$BASE_URL/author" > /dev/null 2>&1; then
        print_error "Services not available at $BASE_URL"
        print_error "Make sure to run: docker-compose up -d"
        exit 1
    fi
    print_success "Services are available!"
    echo
    
    # Execute traffic generation steps
    create_authors
    echo
    
    create_books  
    echo
    
    create_reviews
    echo
    
    fetch_reviews
    echo
    
    generate_mixed_traffic
    echo
    
    test_error_scenarios
    echo
    
    # Summary
    echo "=================================================="
    echo "  Traffic Generation Complete!"
    echo "=================================================="
    echo "Created:"
    echo "  - ${#AUTHOR_IDS[@]} authors"
    echo "  - ${#BOOK_IDS[@]} books"
    echo "  - $((${#BOOK_IDS[@]} * REVIEWS_PER_BOOK)) reviews"
    echo
    echo "OpenTelemetry Traces Generated:"
    echo "  - Cross-service calls (Gateway → Books → Reviews)"
    echo "  - Database operations (MySQL reads/writes)"
    echo "  - Cache operations (Redis for reviews)"
    echo "  - HTTP client calls (Feign between services)"
    echo "  - Error scenarios and exception handling"
    echo
    echo "View traces at:"
    echo "  - Jaeger UI: http://localhost:16686"
    echo "  - BMC Platform: (your configured endpoint)"
    echo "=================================================="
}

# Run the script
main "$@" 