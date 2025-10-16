# LDAPS Development Setup
This setup provides a local OpenLDAP server using [Bitnami OpenLDAP](https://techdocs.broadcom.com/us/en/vmware-tanzu/bitnami-secure-images/bitnami-secure-images/services/bsi-app-doc/apps-containers-openldap-index.html) (modern, secure, and well-maintained) with [phpLDAPadmin](https://phpldapadmin.org/) web interface for development and testing purposes.

## Prerequisites

### Container Runtime (one of the following):
- **Docker**: Standard container runtime
- **Podman**: Rootless container alternative
- **Colima**: Docker Desktop alternative for macOS/Linux

### System Requirements:
- Available ports: 1636 (LDAPS), 8081 (phpLDAPadmin)
- Bash shell for running test scripts

## Get Started

### 1. Start the Services
```bash
# With Docker
docker-compose up -d        # Start all services
docker-compose down         # Stop all services
docker-compose down -v      # Stop and remove volumes (reset data)
# With Podman
podman-compose up -d        # Start all services
podman-compose down         # Stop all services
podman-compose down -v      # Stop and remove volumes
# With Colima (uses docker commands)
colima start                # Start Colima if not running
docker-compose up -d        # Start all services
```
### 2. Access the Services
- **phpLDAPadmin**: http://localhost:8081
- **LDAP Server**: ldaps://localhost:1636
### 3. Testing & Validation
```bash
./ldap-test.sh test         # Run all tests
./ldap-test.sh search       # Interactive LDAP search
```
**Note**: The test script run within the openldap container. It automatically detects your container runtime (Docker, Podman, or Colima) and uses the appropriate commands.

## LDAP Configuration
Sample data is automatically populated when the container starts for the first time from ldif files in `./ldap-init` folder.

### Directory Structure
```
dc=example,dc=org
├── ou=people (users)
└── ou=groups (groups)
```
### Default Settings
- **Domain**: example.org
- **Base DN**: dc=example,dc=org
- **Admin DN**: cn=admin,dc=example,dc=org
- **Admin Password**: admin
- **Default Group**: cn=users
- **Custom Groups**: developers, admins

### Sample Users

| Username | Password | DN |
|----------|----------|-----|
| john.doe | test | uid=john.doe,ou=people,dc=example,dc=org |
| jane.smith | test | uid=jane.smith,ou=people,dc=example,dc=org |
| admin | admin | uid=admin,ou=people,dc=example,dc=org |

## Security Notes

 **This setup is for development only!**
- Uses default passwords
- SSL/TLS is configured but not enforced
- No access controls beyond basic authentication

For production use:
- Change all default passwords
- Enable TLS enforcement
- Configure proper access controls
- Use secure certificate management

