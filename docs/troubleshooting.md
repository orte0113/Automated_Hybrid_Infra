# Troubleshooting Guide

## Quick Diagnostic Commands

```bash
# Check all service status
docker-compose ps

# View all logs
docker-compose logs

# Check specific service
docker-compose logs -f [service-name]

# Check resource usage
docker stats

# Test connectivity
curl http://localhost:5000/health
```

## Common Issues

### Docker & Container Issues

#### Issue: Container exits immediately

**Symptoms:**
```bash
$ docker-compose ps
flask-app    Exit 1
```

**Diagnosis:**
```bash
docker-compose logs flask-app
docker-compose up flask-app  # Run in foreground
```

**Common Causes:**
1. Missing environment variables
2. Port already in use
3. Dependency not ready
4. Application error

**Solutions:**
```bash
# Check environment
docker-compose config

# Check ports
sudo lsof -i :5000
sudo netstat -tlnp | grep 5000

# Kill process using port
kill -9 $(lsof -t -i:5000)

# Wait for dependencies
docker-compose up -d postgres redis
sleep 10
docker-compose up -d flask-app
```

#### Issue: "Cannot connect to Docker daemon"

**Solution:**
```bash
# Start Docker
sudo systemctl start docker

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Verify
docker ps
```

#### Issue: "No space left on device"

**Diagnosis:**
```bash
df -h
docker system df
```

**Solution:**
```bash
# Remove unused containers
docker container prune

# Remove unused images
docker image prune -a

# Remove unused volumes
docker volume prune

# Nuclear option - clean everything
docker system prune -a --volumes
```

### Database Issues

#### Issue: PostgreSQL connection refused

**Symptoms:**
```
psycopg2.OperationalError: could not connect to server
```

**Diagnosis:**
```bash
# Check if PostgreSQL is running
docker-compose ps postgres

# Check PostgreSQL logs
docker-compose logs postgres

# Test connection
docker-compose exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB
```

**Solutions:**
```bash
# Verify connection string in .env
cat .env | grep POSTGRES

# Restart PostgreSQL
docker-compose restart postgres

# Check if database exists
docker-compose exec postgres psql -U $POSTGRES_USER -l

# Create database if missing
docker-compose exec postgres psql -U $POSTGRES_USER -c "CREATE DATABASE $POSTGRES_DB;"
```

#### Issue: PostgreSQL data corruption

**Symptoms:**
- Database fails to start
- "invalid page header" errors

**Solution:**
```bash
# Backup current data
docker-compose exec postgres pg_dump -U $POSTGRES_USER $POSTGRES_DB > backup.sql

# Stop and remove container
docker-compose down postgres

# Remove volume (WARNING: data loss)
docker volume rm hybrid-infrastructure-platform_postgres-data

# Recreate and restore
docker-compose up -d postgres
sleep 10
docker-compose exec -T postgres psql -U $POSTGRES_USER $POSTGRES_DB < backup.sql
```

### Redis Issues

#### Issue: Redis connection errors

**Symptoms:**
```
redis.exceptions.ConnectionError: Error connecting to Redis
```

**Diagnosis:**
```bash
# Check Redis status
docker-compose ps redis
docker-compose logs redis

# Test connection
docker-compose exec redis redis-cli ping
```

**Solutions:**
```bash
# With password
docker-compose exec redis redis-cli -a $REDIS_PASSWORD ping

# Check Redis info
docker-compose exec redis redis-cli -a $REDIS_PASSWORD INFO

# Restart Redis
docker-compose restart redis
```

### Flask Application Issues

#### Issue: 500 Internal Server Error

**Diagnosis:**
```bash
# Check application logs
docker-compose logs flask-app

# Check inside container
docker-compose exec flask-app python app.py
```

**Common Causes:**
1. Missing dependencies
2. Database connection issues
3. Configuration errors
4. Code bugs

**Solutions:**
```bash
# Rebuild image
docker-compose build flask-app
docker-compose up -d flask-app

# Install missing dependencies
docker-compose exec flask-app pip install -r requirements.txt

# Check Python environment
docker-compose exec flask-app python --version
docker-compose exec flask-app pip list
```

#### Issue: Flask not reflecting code changes

**Solution:**
```bash
# Restart Flask (development mode)
docker-compose restart flask-app

# Or rebuild if Dockerfile changed
docker-compose build --no-cache flask-app
docker-compose up -d flask-app
```

### Network Issues

#### Issue: Services can't communicate

**Symptoms:**
- Service A can't reach Service B
- Connection timeouts

**Diagnosis:**
```bash
# List networks
docker network ls

# Inspect network
docker network inspect hybrid-infrastructure-platform_app-network

# Test connectivity
docker-compose exec flask-app ping postgres
docker-compose exec flask-app curl http://redis:6379
```

**Solutions:**
```bash
# Recreate network
docker-compose down
docker-compose up -d

# Check service names in docker-compose.yml
# Ensure services are on same network
```

### Nginx Issues

#### Issue: 502 Bad Gateway

**Symptoms:**
- Nginx running but returns 502

**Diagnosis:**
```bash
# Check Nginx logs
docker-compose logs nginx

# Check upstream (Flask)
curl http://localhost:5000
docker-compose ps flask-app
```

**Solutions:**
```bash
# Verify upstream configuration
docker-compose exec nginx cat /etc/nginx/nginx.conf

# Test config
docker-compose exec nginx nginx -t

# Restart in order
docker-compose restart flask-app
sleep 5
docker-compose restart nginx
```

#### Issue: SSL/TLS errors

**Symptoms:**
```
SSL_ERROR_RX_RECORD_TOO_LONG
```

**Diagnosis:**
```bash
# Check certificates
openssl s_client -connect localhost:443

# Verify certificate files
docker-compose exec nginx ls -la /etc/nginx/certs/
```

**Solutions:**
```bash
# Regenerate certificates
cd pki/scripts
./generate-cert.sh nginx

# Copy to nginx container
docker-compose restart nginx

# Check certificate validity
openssl x509 -in pki/certs/nginx/nginx.crt -noout -dates
```

### PKI & Certificate Issues

#### Issue: Certificate verification failed

**Symptoms:**
```
SSL: CERTIFICATE_VERIFY_FAILED
```

**Diagnosis:**
```bash
# Check certificate
openssl x509 -in certificate.crt -text -noout

# Verify chain
openssl verify -CAfile ca-chain.crt service.crt

# Check expiration
openssl x509 -in certificate.crt -noout -dates
```

**Solutions:**
```bash
# Regenerate certificate
cd pki/scripts
./generate-cert.sh [service-name]

# Verify file permissions
chmod 600 pki/certs/*//*.key
chmod 644 pki/certs/*//*.crt

# Check certificate dates
date  # Current system time
openssl x509 -in cert.crt -noout -dates
```

#### Issue: "certificate has expired"

**Solution:**
```bash
# Check all certificates
find pki/certs -name "*.crt" -exec openssl x509 -noout -subject -dates -in {} \;

# Renew expired certificate
cd pki/scripts
./generate-cert.sh [service-name]

# Restart service
docker-compose restart [service-name]
```

### Monitoring Issues

#### Issue: Prometheus not collecting metrics

**Diagnosis:**
```bash
# Check Prometheus targets
curl http://localhost:9090/targets

# Check if service exposes metrics
curl http://localhost:5000/metrics

# Check Prometheus logs
docker-compose logs prometheus
```

**Solutions:**
```bash
# Verify prometheus.yml
cat monitoring/prometheus/prometheus.yml

# Restart Prometheus
docker-compose restart prometheus

# Check service endpoint
docker-compose exec prometheus wget -O- http://flask-app:5000/metrics
```

#### Issue: Grafana not showing data

**Diagnosis:**
```bash
# Check Grafana logs
docker-compose logs grafana

# Check datasource connection
# In Grafana UI: Configuration > Data Sources > Prometheus > Test
```

**Solutions:**
```bash
# Restart Grafana
docker-compose restart grafana

# Check Prometheus is reachable
docker-compose exec grafana wget -O- http://prometheus:9090/-/healthy

# Recreate datasource
# Delete and re-add in Grafana UI
```

### Ansible Issues

#### Issue: "Ansible playbook failed"

**Diagnosis:**
```bash
# Run with verbose output
ansible-playbook -i inventory/hosts.ini playbooks/deploy.yml -vvv

# Test connectivity
ansible all -i inventory/hosts.ini -m ping
```

**Solutions:**
```bash
# Check SSH access
ssh user@target-host

# Verify inventory
cat ansible/inventory/hosts.ini

# Check Python on remote
ansible all -i inventory/hosts.ini -m setup | grep ansible_python
```

## Performance Issues

### High CPU Usage

**Diagnosis:**
```bash
docker stats
top
```

**Solutions:**
- Check for infinite loops in application
- Review resource limits in docker-compose.yml
- Scale horizontally with multiple containers
- Optimize database queries

### High Memory Usage

**Diagnosis:**
```bash
docker stats
free -h
```

**Solutions:**
```bash
# Set memory limits
# In docker-compose.yml:
services:
  flask-app:
    mem_limit: 512m
    mem_reservation: 256m

# Clear cache
docker-compose exec redis redis-cli -a $REDIS_PASSWORD FLUSHALL
```

### Slow Database Queries

**Diagnosis:**
```bash
# Enable slow query log in PostgreSQL
docker-compose exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB
# SHOW log_min_duration_statement;

# Check running queries
SELECT * FROM pg_stat_activity;
```

**Solutions:**
- Add database indexes
- Optimize queries
- Increase connection pool
- Consider read replicas

## Data Issues

### Data Not Persisting

**Check volumes:**
```bash
docker volume ls
docker volume inspect hybrid-infrastructure-platform_postgres-data
```

**Solution:**
```bash
# Ensure volumes are defined in docker-compose.yml
volumes:
  postgres-data:
```

### Corrupted Data

**PostgreSQL:**
```bash
# Check integrity
docker-compose exec postgres pg_dump -U $POSTGRES_USER $POSTGRES_DB > /dev/null

# Rebuild from backup
docker-compose exec -T postgres psql -U $POSTGRES_USER $POSTGRES_DB < backup.sql
```

## Environment Issues

### Environment Variables Not Loading

**Check:**
```bash
# Verify .env file exists
cat .env

# Check if docker-compose sees them
docker-compose config
```

**Solution:**
```bash
# Recreate from example
cp .env.example .env

# Restart services
docker-compose down
docker-compose up -d
```

## Debugging Tools

### Docker Commands

```bash
# Interactive shell in container
docker-compose exec [service] /bin/bash
docker-compose exec [service] /bin/sh  # If bash not available

# Run command in container
docker-compose exec [service] [command]

# View container details
docker inspect [container-id]

# View container processes
docker top [container-id]
```

### Network Debugging

```bash
# Inside container
docker-compose exec flask-app /bin/bash

# Test DNS
nslookup postgres
dig postgres

# Test connectivity
ping postgres
telnet postgres 5432
nc -zv postgres 5432

# Check routes
ip route
netstat -rn
```

### Log Analysis

```bash
# Follow logs
docker-compose logs -f

# Last 100 lines
docker-compose logs --tail=100

# Since specific time
docker-compose logs --since 2024-01-01T00:00:00

# Multiple services
docker-compose logs flask-app postgres
```

## Getting Help

### Information to Gather

When asking for help, provide:

1. **System info:**
   ```bash
   uname -a
   docker --version
   docker-compose --version
   ```

2. **Service status:**
   ```bash
   docker-compose ps
   ```

3. **Relevant logs:**
   ```bash
   docker-compose logs [service] --tail=50
   ```

4. **Configuration:**
   ```bash
   docker-compose config
   ```

5. **Error messages:**
   - Full error output
   - Steps to reproduce

### Support Channels

- GitHub Issues: [repo-url]/issues
- Documentation: [wiki-url]
- Slack/Discord: [community-link]

## Prevention

### Health Checks

Implement in docker-compose.yml:
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

### Monitoring & Alerts

- Set up Grafana alerts
- Monitor certificate expiration
- Track resource usage
- Log aggregation

### Regular Maintenance

```bash
# Weekly
docker-compose logs --tail=1000 > weekly-logs.txt
docker stats --no-stream > weekly-stats.txt

# Monthly
docker system df  # Check disk usage
docker image prune  # Remove old images
```
