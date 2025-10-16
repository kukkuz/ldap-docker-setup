#!/bin/bash

# LDAP Testing Suite
# Complete test suite for LDAPS-only configuration
# Includes container setup, configuration validation, and LDAP functionality tests

set -e

# Configuration
LDAP_HOST="localhost"
LDAPS_PORT="1636"
ADMIN_DN="cn=admin,dc=example,dc=org"
ADMIN_PASSWORD="admin"
BASE_DN="dc=example,dc=org"
TLS_CERT_FILE="./tls/ldap.crt"

# Container runtime configuration - auto-detect available runtime
CONTAINER_CMD=""

# Detect available container runtime
detect_container_runtime() {
    # Check for podman first (if available, often preferred for rootless containers)
    if command -v podman &>/dev/null && podman ps --format "{{.Names}}" 2>/dev/null | grep -q "openldap"; then
        CONTAINER_CMD="podman"
        return 0
    fi
    
    # Check for docker
    if command -v docker &>/dev/null && docker ps --format "{{.Names}}" 2>/dev/null | grep -q "openldap"; then
        CONTAINER_CMD="docker"
        return 0
    fi
    
    # Check for colima (Docker Desktop alternative for macOS/Linux)
    if command -v colima &>/dev/null && colima status &>/dev/null && docker ps --format "{{.Names}}" 2>/dev/null | grep -q "openldap"; then
        CONTAINER_CMD="docker"  # colima uses docker commands
        return 0
    fi
    
    return 1
}

# Check if any container runtime has openldap running
check_container_available() {
    # Try podman
    if command -v podman &>/dev/null && podman ps --format "{{.Names}}" 2>/dev/null | grep -q "openldap"; then
        return 0
    fi
    
    # Try docker (including colima)
    if command -v docker &>/dev/null && docker ps --format "{{.Names}}" 2>/dev/null | grep -q "openldap"; then
        return 0
    fi
    
    return 1
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Print header with styling
print_header() {
    echo ""
    echo -e "${BOLD}${CYAN}🔹 $1${NC}"
    echo -e "${CYAN}$(printf '━%.0s' {1..60})${NC}"
}

print_subheader() {
    echo ""
    echo -e "${BOLD}${BLUE}▶ $1${NC}"
    echo -e "${BLUE}$(printf '─%.0s' {1..40})${NC}"
}

print_success() {
    echo -e "  ${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "  ${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "  ${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "  ${BLUE}ℹ️  $1${NC}"
}

print_usage() {
    echo ""
    echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${CYAN}│           LDAP Testing Suite            │${NC}"
    echo -e "${BOLD}${CYAN}└─────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${BOLD}Usage:${NC} $0 {command}"
    echo ""
    
    echo -e "${BOLD}${YELLOW}📋 Available Commands:${NC}"
    echo -e "  ${GREEN}test${NC}        Run complete test suite (setup + all LDAP tests)"
    echo -e "  ${GREEN}search${NC}           Interactive LDAP search"
    echo ""
    
    echo -e "${BOLD}${CYAN}💡 Examples:${NC}"
    echo -e "  ${BLUE}./ldap-test.sh test${NC}"
    echo -e "  ${BLUE}./ldap-test.sh search${NC}"
    echo ""
    
    echo -e "${BOLD}${YELLOW}🔒 TLS Configuration:${NC}"
    echo -e "  • LDAPS ONLY - TLS required for all connections (port 1636)"
    echo -e "  • Plain LDAP disabled for security"
    echo -e "  • Certificates managed externally (Docker Compose init container)"
    echo ""
    
    echo -e "${BOLD}${YELLOW}🚀 Setup Instructions:${NC}"
    echo -e "  ${CYAN}1.${NC} Start containers: ${BLUE}docker-compose up -d${NC} (or ${BLUE}podman-compose up -d${NC})"
    echo -e "  ${CYAN}2.${NC} Run tests: ${BLUE}./ldap-test.sh test${NC}"
    echo -e "  ${CYAN}3.${NC} For custom queries: ${BLUE}./ldap-test.sh search${NC}"
    echo ""
}

# LDAP Configuration Setup Functions
ldap_config_setup() {
    print_header "LDAP Configuration Setup & Validation"
    
    # Detect and set container runtime
    if ! detect_container_runtime; then
        print_error "Could not detect container runtime"
        return 1
    fi
    
    print_subheader "System Configuration"
    print_info "Container Runtime: $CONTAINER_CMD"
    print_info "LDAPS Port: 1636 (secure, TLS required)"
    print_info "LDAP Port: DISABLED (TLS required)"
    print_info "External Access: ldaps://localhost:1636"
    
    print_subheader "Connection Tests"
    
    # Test LDAPS connection from inside the container
    echo -n "  🔒 LDAPS Connection Test: "
    if $CONTAINER_CMD exec openldap ldapsearch -x -H "ldaps://localhost:1636" \
        -o tls_reqcert=never \
        -D "cn=admin,dc=example,dc=org" \
        -w "admin" \
        -b "dc=example,dc=org" \
        -s base &>/dev/null; then
        echo -e "${GREEN}✅ SUCCESS${NC}"
    else
        echo -e "${RED}❌ FAILED${NC}"
    fi
    
    # Test plain LDAP connection (should fail)
    echo -n "  🚫 LDAP Connection Test (should fail): "
    if $CONTAINER_CMD exec openldap ldapsearch -x -H "ldap://localhost:1389" \
        -D "cn=admin,dc=example,dc=org" \
        -w "admin" \
        -b "dc=example,dc=org" \
        -s base &>/dev/null; then
        echo -e "${RED}❌ SECURITY ISSUE (plain LDAP succeeded)${NC}"
    else
        echo -e "${GREEN}✅ BLOCKED (TLS required)${NC}"
    fi
    
    print_subheader "Data Import Validation"
    
    # Test LDIF imported users
    echo -n "  👥 Users Import Test: "
    user_count=$($CONTAINER_CMD exec openldap ldapsearch -x -H "ldaps://localhost:1636" \
        -o tls_reqcert=never \
        -D "cn=admin,dc=example,dc=org" \
        -w "admin" \
        -b "ou=people,dc=example,dc=org" \
        "(objectClass=inetOrgPerson)" uid 2>/dev/null | grep -c "^uid:" || echo "0")
    
    if [ "$user_count" -gt 0 ]; then
        echo -e "${GREEN}✅ Found $user_count users${NC}"
    else
        echo -e "${YELLOW}⚠️  No users found${NC}"
    fi
    
    # Test LDIF imported groups
    echo -n "  🏷️  Groups Import Test: "
    group_count=$($CONTAINER_CMD exec openldap ldapsearch -x -H "ldaps://localhost:1636" \
        -o tls_reqcert=never \
        -D "cn=admin,dc=example,dc=org" \
        -w "admin" \
        -b "ou=groups,dc=example,dc=org" \
        "(objectClass=groupOfNames)" cn 2>/dev/null | grep -c "^cn:" || echo "0")
    
    if [ "$group_count" -gt 0 ]; then
        echo -e "${GREEN}✅ Found $group_count groups${NC}"
    else
        echo -e "${YELLOW}⚠️  No groups found${NC}"
    fi
    
    print_subheader "TLS Certificate Status"
    if $CONTAINER_CMD exec openldap test -f opt/bitnami/openldap/certs/ldap.crt; then
        print_success "Certificate found in container"
        echo -e "  ${BLUE}Certificate Details:${NC}"
        $CONTAINER_CMD exec openldap openssl x509 -in opt/bitnami/openldap/certs/ldap.crt -text -noout | grep -E "(Subject:|Not After|DNS:|IP:)" | sed 's/^/    /' || echo "    Certificate parsing failed"
    else
        print_error "Certificate not found in container"
        print_warning "Check if cert-init container completed successfully"
    fi
}

# LDAP Helper Functions
run_container_ldapsearch() {
    local base_dn="$1"
    local filter="$2" 
    local attributes="$3"
    local description="$4"
    
    # Ensure container runtime is detected
    if ! detect_container_runtime; then
        print_error "Could not detect container runtime"
        return 1
    fi

    $CONTAINER_CMD exec openldap ldapsearch -x -H "ldaps://localhost:1636" \
        -o tls_reqcert=never \
        -D "$ADMIN_DN" \
        -w "$ADMIN_PASSWORD" \
        -b "$base_dn" \
        "$filter" \
        $attributes &>/dev/null
    
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        print_success "$description"
    else
        print_error "$description (exit code: $exit_code)"
        return $exit_code
    fi
}

check_user_exists() {
    local username="$1"
    local expected_cn="$2"
    
    echo -n "  👤 Checking user $username: "
    
    # Ensure container runtime is detected
    if ! detect_container_runtime; then
        echo -e "${RED}❌ Runtime error${NC}"
        return 1
    fi
    
    local search_result
    search_result=$($CONTAINER_CMD exec openldap ldapsearch -x -H "ldaps://localhost:1636" \
        -o tls_reqcert=never \
        -D "$ADMIN_DN" \
        -w "$ADMIN_PASSWORD" \
        -b "ou=people,$BASE_DN" \
        "(uid=$username)" cn 2>/dev/null)
    
    if echo "$search_result" | grep -q "cn: $expected_cn"; then
        echo -e "${GREEN}✅ Found ($expected_cn)${NC}"
        return 0
    else
        echo -e "${RED}❌ Not found or incorrect${NC}"
        return 1
    fi
}

test_user_auth() {
    local username="$1"
    local password="$2"
    local user_dn="uid=$username,ou=people,$BASE_DN"
    
    echo -n "  🔐 Testing auth for $username: "
    
    # Ensure container runtime is detected
    if ! detect_container_runtime; then
        echo -e "${RED}❌ Runtime error${NC}"
        return 1
    fi
    
    $CONTAINER_CMD exec openldap ldapsearch -x -H "ldaps://localhost:1636" \
        -o tls_reqcert=never \
        -D "$user_dn" \
        -w "$password" \
        -b "$BASE_DN" \
        -s base &>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ SUCCESS${NC}"
        return 0
    else
        echo -e "${RED}❌ FAILED${NC}"
        return 1
    fi
}

test_users() {
    # Check if container is available
    if ! check_container_available; then
        print_warning "Skipping user tests (container not running)"
        return 1
    fi
    
    print_subheader "Individual User Validation"
    check_user_exists "john.doe" "John Doe"
    check_user_exists "jane.smith" "Jane Smith"
    check_user_exists "admin" "Admin User"
    
    print_subheader "User Directory Query"
    run_container_ldapsearch "ou=people,$BASE_DN" "(objectClass=inetOrgPerson)" "uid cn mail" "All users query"
    
    user_count=$($CONTAINER_CMD exec openldap ldapsearch -x -H "ldaps://localhost:1636" \
        -o tls_reqcert=never \
        -D "$ADMIN_DN" \
        -w "$ADMIN_PASSWORD" \
        -b "ou=people,$BASE_DN" \
        "(objectClass=inetOrgPerson)" uid 2>/dev/null | grep -c "^uid:" || echo "0")
    print_success "Total users found: $user_count"
}

test_groups() {
    # Check if container is available
    if ! check_container_available; then
        print_warning "Skipping group tests (container not running)"
        return 1
    fi
    
    run_container_ldapsearch "ou=groups,$BASE_DN" "(objectClass=groupOfNames)" "cn member" "All groups query"

    group_count=$($CONTAINER_CMD exec openldap ldapsearch -x -H "ldaps://localhost:1636" \
        -o tls_reqcert=never \
        -D "$ADMIN_DN" \
        -w "$ADMIN_PASSWORD" \
        -b "ou=groups,$BASE_DN" \
        "(objectClass=groupOfNames)" cn 2>/dev/null | grep -c "^cn:" || echo "0")
    print_success "Total groups found: $group_count"
}

test_authentication() {
    
    # Check if container is available
    if ! check_container_available; then
        print_warning "Skipping authentication tests (container not running)"
        return 1
    fi 

    print_subheader "User Authentication Tests" 
    test_user_auth "john.doe" "test" 
    test_user_auth "jane.smith" "test" 
    test_user_auth "admin" "admin" 

    print_subheader "Admin Authentication Test" 
    echo -n " 🔐 Testing auth for admin: " 
    $CONTAINER_CMD exec openldap ldapsearch -x -H "ldaps://localhost:1636" \
        -o tls_reqcert=never \
        -D "$ADMIN_DN" \
        -w "$ADMIN_PASSWORD" \
        -b "$BASE_DN" \
        -s base &>/dev/null

    if [ $? -eq 0 ]; then 
        echo -e "${GREEN} ✅ SUCCESS${NC}" 
    else 
        echo -e "${RED}❌ FAILED${NC}" 
    fi
}

test_organizational_units() {
    print_subheader " Testing Organizational Units"
    
    # Check if container is available
    if ! check_container_available; then
        echo -e "${YELLOW}⚠️  Skipping OU tests (container not running)${NC}"
        return 1
    fi
    
    # Test OU search
    run_container_ldapsearch "$BASE_DN" "(objectClass=organizationalUnit)" "ou description" "Organizational Units query"
    
    # Count OUs
    ou_count=$($CONTAINER_CMD exec openldap ldapsearch -x -H "ldaps://localhost:1636" \
        -o tls_reqcert=never \
        -D "$ADMIN_DN" \
        -w "$ADMIN_PASSWORD" \
        -b "$BASE_DN" \
        "(objectClass=organizationalUnit)" ou 2>/dev/null | grep -c "^ou:" || echo "0")
    echo -e "${GREEN}  ✅ Found $ou_count organizational units${NC}"
    echo ""
}

interactive_search() {
    print_header "🔍 Interactive LDAP Search"
    
    # Ensure container is available
    if ! check_container_available; then
        echo -e "${YELLOW}⚠️  Interactive search not available (container not running)${NC}"
        return 1
    fi
    
    print_subheader "Search Examples & Common Filters"
    echo -e "  ${CYAN}Basic Searches:${NC}"
    echo -e "    ${YELLOW}1.${NC} All entries: ${BLUE}(objectClass=*)${NC}"
    echo -e "    ${YELLOW}2.${NC} All users: ${BLUE}(objectClass=inetOrgPerson)${NC}"
    echo -e "    ${YELLOW}3.${NC} All groups: ${BLUE}(objectClass=groupOfNames)${NC}"
    echo -e "    ${YELLOW}4.${NC} Specific user: ${BLUE}(uid=john.doe)${NC}"
    echo -e "    ${YELLOW}5.${NC} Users by name: ${BLUE}(cn=John*)${NC}"
    echo ""
    
    echo -e "  ${CYAN}Advanced Searches:${NC}"
    echo -e "    ${YELLOW}6.${NC} Users with email: ${BLUE}(mail=*@example.org)${NC}"
    echo -e "    ${YELLOW}7.${NC} Group membership: ${BLUE}(member=uid=john.doe,ou=people,$BASE_DN)${NC}"
    echo -e "    ${YELLOW}8.${NC} Multiple conditions: ${BLUE}(&(objectClass=inetOrgPerson)(cn=*admin*))${NC}"
    echo -e "    ${YELLOW}9.${NC} OR conditions: ${BLUE}(|(uid=john.doe)(uid=jane.smith))${NC}"
    echo -e "    ${YELLOW}10.${NC} NOT conditions: ${BLUE}(&(objectClass=*)(!(objectClass=organizationalUnit)))${NC}"
    echo ""
    
    echo -e "  ${CYAN}Common Base DNs:${NC}"
    echo -e "    • ${BLUE}$BASE_DN${NC} - Search entire directory"
    echo -e "    • ${BLUE}ou=people,$BASE_DN${NC} - Search only users"
    echo -e "    • ${BLUE}ou=groups,$BASE_DN${NC} - Search only groups"
    echo ""
    
    echo -e "  ${CYAN}Useful Attributes:${NC}"
    echo -e "    • ${BLUE}dn cn uid mail${NC} - Basic user info"
    echo -e "    • ${BLUE}cn member description${NC} - Group info"
    echo -e "    • ${BLUE}objectClass${NC} - Entry types"
    echo -e "    • ${BLUE}*${NC} or leave blank - All attributes"
    echo ""
    
    print_subheader "Custom Search"
    
    read -p "Enter base DN [default: $BASE_DN]: " base_dn
    base_dn=${base_dn:-$BASE_DN}

    read -p "Enter search filter [default: (objectClass=*)]: " filter
    filter=${filter:-(objectClass=*)}
    
    read -p "Enter attributes (space-separated) [default: all]: " attributes
    
    # Ensure container runtime is detected
    if ! detect_container_runtime; then
        print_error "Could not detect container runtime"
        return 1
    fi
    
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    $CONTAINER_CMD exec openldap ldapsearch -x -H "ldaps://localhost:1636" \
        -o tls_reqcert=never \
        -D "$ADMIN_DN" \
        -w "$ADMIN_PASSWORD" \
        -b "$base_dn" \
        "$filter" $attributes
    
    local exit_code=$?
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if [ $exit_code -eq 0 ]; then
        print_success "Search completed successfully"
    else
        print_error "Search failed with exit code: $exit_code"
    fi
}

test_all_ldap_functionality() {
    print_header "LDAP Functionality Tests"
    
    test_organizational_units
    test_users  
    test_groups
    test_authentication
}

run_full_test_suite() {
    print_header "Comprehensive LDAP Test Suite"
    print_info "Running complete test suite including containers and LDAP functionality..."
    
    # LDAP configuration setup
    if check_container_available; then
        ldap_config_setup
    else
        print_warning "Skipping LDAP setup (container not running)"
    fi
    
    # LDAP functionality tests
    test_all_ldap_functionality
    
    echo ""
    echo ""
    echo -e "${GREEN}✅ All LDAP functionality tests completed successfully${NC}"
}

# Main script logic
case "$1" in
    test)
        run_full_test_suite
        ;;
    search)
        interactive_search
        ;;
    *)
        print_usage
        exit 1
        ;;
esac
