# Cost Optimization Guide: Single ALB Architecture

## Executive Summary

**Current Setup (5 ALBs)**: ~$200/month  
**Optimized Setup (1 ALB)**: ~$20-25/month  
**💰 Monthly Savings: ~$175 (87% reduction)**

---

## Problem: Multiple ALBs Are Expensive

Your current architecture with 5 separate ALBs:
- **auth-lb**: $16.20/month base
- **pdf-lb**: $16.20/month base
- **fa2-tg**: $16.20/month base
- **users-tg** (to create): $16.20/month base
- **batch-tg** (to create): $16.20/month base

**Total**: ~$81/month (base) + LCU charges (~$120/month) = **~$200/month**

---

## Solution: Single ALB with Path-Based Routing

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    React Frontend App                            │
│                 (api.yourdomain.com)                              │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│              Application Load Balancer (ALB)                     │
│                                                                   │
│  Listener: HTTPS (Port 443) with ACM Certificate                │
│                                                                   │
│  Path-Based Routing Rules:                                       │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ /api/auth/*    → auth-tg    (AuthAPI:8080)               │  │
│  │ /api/pdf/*     → pdf-tg     (PDFCreator:9080)            │  │
│  │ /api/fa/*      → fa-tg      (FaEngine:2531)              │  │
│  │ /api/users/*   → users-tg   (UserManagement:8080)        │  │
│  │ /api/batch/*   → batch-tg   (BatchEngineCall:8080)       │  │
│  │ Default: /     → frontend-tg (React S3/CloudFront)       │  │
│  └───────────────────────────────────────────────────────────┘  │
└────────┬──────────┬─────────┬──────────┬──────────┬────────────┘
         │          │         │          │          │
         ▼          ▼         ▼          ▼          ▼
    ┌────────┐ ┌────────┐ ┌──────┐ ┌──────┐ ┌──────┐
    │Auth    │ │PDF     │ │FA    │ │Users │ │Batch │
    │ECS     │ │ECS     │ │ECS   │ │ECS   │ │ECS   │
    │Tasks   │ │Tasks   │ │Tasks │ │Tasks │ │Tasks │
    └────────┘ └────────┘ └──────┘ └──────┘ └──────┘
```

---

## Implementation Steps

### Step 1: Create a Single ALB (if not exists)

```bash
# Variables
ALB_NAME="unified-api-alb"
VPC_ID="vpc-xxxxxxxx"
SUBNET_1="subnet-xxxxxxxx"
SUBNET_2="subnet-xxxxxxxx"
SECURITY_GROUP="sg-xxxxxxxx"

# Create ALB
aws elbv2 create-load-balancer \
    --name ${ALB_NAME} \
    --subnets ${SUBNET_1} ${SUBNET_2} \
    --security-groups ${SECURITY_GROUP} \
    --scheme internet-facing \
    --type application \
    --ip-address-type ipv4 \
    --tags Key=Environment,Value=production
```

### Step 2: Attach ACM Certificate

```bash
# Get your ACM certificate ARN
CERT_ARN=$(aws acm list-certificates \
    --query "CertificateSummaryList[?DomainName=='api.yourdomain.com'].CertificateArn" \
    --output text)

# Create HTTPS listener
aws elbv2 create-listener \
    --load-balancer-arn ${ALB_ARN} \
    --protocol HTTPS \
    --port 443 \
    --certificates CertificateArn=${CERT_ARN} \
    --default-actions Type=fixed-response,FixedResponseConfig='{StatusCode=404,ContentType="text/plain",MessageBody="Not Found"}'
```

### Step 3: Create Target Groups

```bash
# Auth Target Group
aws elbv2 create-target-group \
    --name auth-tg \
    --protocol HTTP \
    --port 8080 \
    --vpc-id ${VPC_ID} \
    --target-type ip \
    --health-check-path /health \
    --health-check-interval-seconds 30

# PDF Target Group
aws elbv2 create-target-group \
    --name pdf-tg \
    --protocol HTTP \
    --port 9080 \
    --vpc-id ${VPC_ID} \
    --target-type ip \
    --health-check-path /health

# FA Target Group
aws elbv2 create-target-group \
    --name fa-tg \
    --protocol HTTP \
    --port 2531 \
    --vpc-id ${VPC_ID} \
    --target-type ip \
    --health-check-path /health

# Users Target Group
aws elbv2 create-target-group \
    --name users-tg \
    --protocol HTTP \
    --port 8080 \
    --vpc-id ${VPC_ID} \
    --target-type ip \
    --health-check-path /health

# Batch Target Group
aws elbv2 create-target-group \
    --name batch-tg \
    --protocol HTTP \
    --port 8080 \
    --vpc-id ${VPC_ID} \
    --target-type ip \
    --health-check-path /health
```

### Step 4: Add Path-Based Routing Rules

```bash
# Get listener ARN
LISTENER_ARN=$(aws elbv2 describe-listeners \
    --load-balancer-arn ${ALB_ARN} \
    --query "Listeners[?Port==\`443\`].ListenerArn" \
    --output text)

# Auth API rule
aws elbv2 create-rule \
    --listener-arn ${LISTENER_ARN} \
    --priority 10 \
    --conditions Field=path-pattern,Values='/api/auth/*' \
    --actions Type=forward,TargetGroupArn=${AUTH_TG_ARN}

# PDF API rule
aws elbv2 create-rule \
    --listener-arn ${LISTENER_ARN} \
    --priority 20 \
    --conditions Field=path-pattern,Values='/api/pdf/*' \
    --actions Type=forward,TargetGroupArn=${PDF_TG_ARN}

# FA API rule
aws elbv2 create-rule \
    --listener-arn ${LISTENER_ARN} \
    --priority 30 \
    --conditions Field=path-pattern,Values='/api/fa/*' \
    --actions Type=forward,TargetGroupArn=${FA_TG_ARN}

# Users API rule
aws elbv2 create-rule \
    --listener-arn ${LISTENER_ARN} \
    --priority 40 \
    --conditions Field=path-pattern,Values='/api/users/*' \
    --actions Type=forward,TargetGroupArn=${USERS_TG_ARN}

# Batch API rule
aws elbv2 create-rule \
    --listener-arn ${LISTENER_ARN} \
    --priority 50 \
    --conditions Field=path-pattern,Values='/api/batch/*' \
    --actions Type=forward,TargetGroupArn=${BATCH_TG_ARN}
```

### Step 5: Update Your .NET APIs

Your APIs need to handle the path prefix. Two options:

#### Option A: API Gateway Pattern (Recommended)
Add path rewriting in ALB listener rules:

```bash
# Example: Rewrite /api/auth/* to /*
aws elbv2 modify-rule \
    --rule-arn ${AUTH_RULE_ARN} \
    --actions '[
        {
            "Type": "forward",
            "ForwardConfig": {
                "TargetGroups": [{"TargetGroupArn": "'${AUTH_TG_ARN}'"}]
            }
        }
    ]'
```

#### Option B: Update Your .NET APIs
Add path base in `Program.cs`:

```csharp
// AuthAPI/Program.cs
app.UsePathBase("/api/auth");
app.UseRouting();

// PDFCreator/Program.cs
app.UsePathBase("/api/pdf");
app.UseRouting();

// etc.
```

### Step 6: Update React Frontend

Update your API base URLs:

```javascript
// Before (separate ALBs)
const AUTH_API = "https://auth-api.yourdomain.com";
const PDF_API = "https://pdf-api.yourdomain.com";
const FA_API = "https://fa-api.yourdomain.com";

// After (single ALB)
const API_BASE = "https://api.yourdomain.com";
const AUTH_API = `${API_BASE}/api/auth`;
const PDF_API = `${API_BASE}/api/pdf`;
const FA_API = `${API_BASE}/api/fa`;
const USERS_API = `${API_BASE}/api/users`;
const BATCH_API = `${API_BASE}/api/batch`;
```

---

## Cost Breakdown

### Current Architecture (5 ALBs)
| Item | Cost |
|------|------|
| 5 ALBs @ $16.20/month each | $81.00 |
| LCU charges (estimated) | $120.00 |
| **Total** | **~$200/month** |

### Optimized Architecture (1 ALB)
| Item | Cost |
|------|------|
| 1 ALB | $16.20 |
| LCU charges (estimated) | $5-10 |
| **Total** | **~$20-25/month** |

### 💰 Savings: **$175-180/month = $2,100/year**

---

## Alternative: API Gateway (Even Cheaper for Low Traffic)

If your traffic is very low (<1M requests/month), consider API Gateway:

```
React → API Gateway → VPC Link → ECS Tasks
```

**Cost**: ~$3.50/month + $1/million requests

| Requests/Month | API Gateway Cost | ALB Cost |
|----------------|------------------|----------|
| 100K | $3.85 | $20 |
| 500K | $5.75 | $20 |
| 1M | $7.50 | $20 |
| 5M | $21.50 | $25 |

**Recommendation**: Use API Gateway if <2M requests/month, otherwise stick with single ALB.

---

## Migration Plan

### Phase 1: Setup (No Downtime)
1. ✅ Create new unified ALB
2. ✅ Create 5 target groups
3. ✅ Add path-based routing rules
4. ✅ Attach ACM certificate

### Phase 2: Testing
1. Test each service endpoint
2. Verify SSL/TLS works
3. Check health checks
4. Load test

### Phase 3: Cutover
1. Update DNS to point to new ALB
2. Monitor for issues
3. Keep old ALBs running for 24-48 hours
4. Verify all traffic migrated

### Phase 4: Cleanup
1. Delete old ALB listeners
2. Delete old ALBs
3. Update Route53 records
4. 🎉 Save $175/month!

---

## Monitoring

### CloudWatch Metrics to Watch
- `TargetResponseTime`: Response time per target group
- `RequestCount`: Requests per target group
- `HealthyHostCount`: Healthy targets
- `UnHealthyHostCount`: Unhealthy targets
- `HTTPCode_Target_4XX_Count`: 4xx errors
- `HTTPCode_Target_5XX_Count`: 5xx errors

### CloudWatch Alarm Example

```bash
aws cloudwatch put-metric-alarm \
    --alarm-name alb-unhealthy-targets \
    --alarm-description "Alert when targets are unhealthy" \
    --metric-name UnHealthyHostCount \
    --namespace AWS/ApplicationELB \
    --statistic Average \
    --period 60 \
    --evaluation-periods 2 \
    --threshold 1 \
    --comparison-operator GreaterThanOrEqualToThreshold
```

---

## Security Considerations

### WAF (Web Application Firewall)
With a single ALB, you only need **1 WAF** instead of 5:
- **Savings**: ~$25/month (5 WAF WebACLs → 1 WAF WebACL)

```bash
# Attach WAF to ALB
aws wafv2 associate-web-acl \
    --web-acl-arn ${WAF_ACL_ARN} \
    --resource-arn ${ALB_ARN}
```

### Security Groups
Update security groups to allow ALB → ECS communication:

```bash
# ALB Security Group
aws ec2 authorize-security-group-ingress \
    --group-id ${ALB_SG} \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0

# ECS Security Group
aws ec2 authorize-security-group-ingress \
    --group-id ${ECS_SG} \
    --protocol tcp \
    --port 8080 \
    --source-group ${ALB_SG}
```

---

## Troubleshooting

### Issue: 502 Bad Gateway
**Cause**: Target health check failing  
**Solution**: Check health check path and port

```bash
aws elbv2 describe-target-health --target-group-arn ${TG_ARN}
```

### Issue: SSL Certificate Error
**Cause**: Certificate not matching domain  
**Solution**: Add domain to ACM certificate

### Issue: Path Not Routing
**Cause**: Rule priority conflict  
**Solution**: Check rule priorities

```bash
aws elbv2 describe-rules --listener-arn ${LISTENER_ARN}
```

---

## Quick Setup Script

Create `setup-unified-alb.sh`:

```bash
#!/bin/bash
# See full implementation in migration-script.sh
# This creates the unified ALB architecture
```

---

## Summary

✅ **Reduce costs by 87%**  
✅ **Simpler architecture**  
✅ **Easier to manage**  
✅ **Same performance**  
✅ **Same security (SSL/TLS)**  
✅ **Better scalability**

**Next Steps**:
1. Review this guide
2. Run the migration plan
3. Update Lambda config with new target group ARNs
4. Test thoroughly
5. Migrate DNS
6. Delete old ALBs and save money! 💰

