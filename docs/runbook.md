# Operational Runbook

## Quick Reference

### Service URLs
- Flask Application: http://localhost:5000
- Grafana: http://localhost:3000 (admin/admin)
- Prometheus: http://localhost:9090

### Common Commands

```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# View logs
docker-compose logs -f [service-name]

# Restart a service
docker-compose restart [service-name]

# Check service health
curl http://localhost:5000/health
```

## Deployment Procedures

### Initial Setup

1. **Clone repository**
   ```bash
   git clone <repo-url>
   cd hybrid-infrastructure-platform
   ```

2. **Configure environment**
   ```bash
   cp .env.example .env
   # Edit .env with your settings
   ```

3. **Initialize PKI**
   ```bash
   cd pki/scripts
   ./setup-ca.sh
   ```

4. **Generate service certificates**
   ```bash
   ./generate-cert.sh flask-app
   ./generate-cert.sh nginx
   ```

5. **Deploy services**
   ```bash
   cd ../..
   docker-compose up -d
   ```

### Using Ansible

1. **Update inventory**
   ```bash
   vim ansible/inventory/hosts.ini
   ```

2. **Deploy to remote hosts**
   ```bash
   cd ansible
   ansible-playbook -i inventory/hosts.ini playbooks/deploy.yml
   ```

## Monitoring

### Checking Service Health

**Via API:**
```bash
curl http://localhost:5000/health
```

**Via Docker:**
```bash
docker-compose ps
```

**Via Prometheus:**
- Navigate to http://localhost:9090/targets
- All targets should show "UP"

### Grafana Dashboards

1. Access Grafana at http://localhost:3000
2. Login with admin/admin (change on first login)
3. Navigate to Dashboards

**Key Metrics to Monitor:**
- Service uptime
- Response times
- Error rates
- Resource utilization (CPU, Memory, Disk)
- Certificate expiration dates

## Certificate Management

### Certificate Expiration Monitoring

**Check certificate expiration:**
```bash
openssl x509 -in pki/certs/service-name/service-name.crt -noout -enddate
```

**Automated monitoring:**
- Prometheus scrapes certificate expiration metrics
- Grafana alerts when certificates expire in < 30 days

### Certificate Renewal

**Manual renewal:**
```bash
cd pki/scripts
./generate-cert.sh [service-name]
docker-compose restart [service-name]
```

**Automated renewal:**
- TODO: Set up cron job or systemd timer
- Trigger renewal at 60 days before expiration
- Automatic service restart after renewal

## Troubleshooting

### Common Issues

#### Services Won't Start

**Symptoms:** Docker containers exit immediately

**Check:**
```bash
docker-compose logs [service-name]
docker-compose ps
```

**Common causes:**
- Port conflicts
- Missing environment variables
- Database not ready

**Solution:**
```bash
# Check ports
sudo lsof -i :5000
# Verify .env file
cat .env
# Restart in order
docker-compose up -d postgres redis
sleep 5
docker-compose up -d flask-app
```

#### Database Connection Errors

**Symptoms:** Flask app can't connect to PostgreSQL

**Check:**
```bash
docker-compose logs postgres
docker exec -it postgres pg_isready
```

**Solution:**
```bash
# Verify database is healthy
docker-compose exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB
# Check connection string in .env
```

#### Certificate Issues

**Symptoms:** SSL/TLS handshake failures

**Check:**
```bash
openssl s_client -connect localhost:443 -CAfile pki/ca/root/certs/ca.crt
```

**Solution:**
- Verify certificate chain
- Check certificate expiration
- Ensure correct file permissions (600 for keys)

#### Prometheus Not Scraping Metrics

**Symptoms:** No data in Grafana

**Check:**
```bash
curl http://localhost:9090/targets
curl http://localhost:5000/metrics
```

**Solution:**
- Verify service is exposing /metrics endpoint
- Check Prometheus config
- Restart Prometheus

### Log Locations

```bash
# Docker logs
docker-compose logs [service-name]

# Application logs (if mounted)
tail -f logs/flask-app.log

# Nginx logs
docker-compose exec nginx tail -f /var/log/nginx/access.log
```

## Backup Procedures

### What to Back Up

1. **PKI Materials** (CRITICAL)
   - Root CA private key (offline storage)
   - Intermediate CA materials
   - Certificate database

2. **Application Data**
   - PostgreSQL database
   - Configuration files

3. **Monitoring Data** (optional)
   - Grafana dashboards
   - Prometheus data

### Backup Commands

```bash
# PostgreSQL backup
docker-compose exec postgres pg_dump -U $POSTGRES_USER $POSTGRES_DB > backup.sql

# PKI backup
tar -czf pki-backup-$(date +%Y%m%d).tar.gz pki/ca/

# Configuration backup
tar -czf config-backup-$(date +%Y%m%d).tar.gz .env docker-compose.yml ansible/
```

## Disaster Recovery

### Service Restoration

1. Stop all services
2. Restore from backup
3. Verify .env configuration
4. Start services in order: postgres → redis → flask-app → nginx
5. Verify health endpoints

### PKI Restoration

1. Restore PKI directory from backup
2. Verify certificate chain integrity
3. Regenerate any expired certificates
4. Distribute renewed certificates
5. Restart affected services

## Maintenance Windows

### Regular Maintenance Tasks

**Weekly:**
- Review logs for errors
- Check certificate expiration dates
- Verify backup integrity

**Monthly:**
- Update Docker images
- Review security advisories
- Test disaster recovery procedures

**Quarterly:**
- Rotate secrets/passwords
- Review and update documentation
- Performance testing

## Scaling Considerations

### Horizontal Scaling

**Flask App:**
```yaml
# In docker-compose.yml
flask-app:
  deploy:
    replicas: 3
```

**Database:**
- Consider PostgreSQL replication
- Redis clustering for high availability

### Vertical Scaling

Adjust resource limits in docker-compose.yml:
```yaml
services:
  flask-app:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
```

## Security Incident Response

1. **Identify** - Alert triggered or issue reported
2. **Contain** - Isolate affected services
3. **Investigate** - Review logs, check for unauthorized access
4. **Remediate** - Apply fixes, rotate credentials
5. **Document** - Record incident and response
6. **Review** - Post-mortem and improvements

## Contact Information

**On-Call:** [Your contact]
**Escalation:** [Manager/Team lead]
**Documentation:** [Wiki/Confluence link]
