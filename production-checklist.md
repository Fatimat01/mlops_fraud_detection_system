# Production Deployment Checklist

## Pre-Deployment
- [ ] Model tested locally with sample data
- [ ] Unit tests passing (pytest tests/test_inference.py)
- [ ] AWS credentials configured
- [ ] IAM role has necessary permissions:
  - SageMaker full access
  - S3 read/write for model artifacts
  - CloudWatch metrics and logs
  - SNS for alerts

## Deployment
- [ ] Model packaged correctly (model.tar.gz)
- [ ] Endpoint deployed successfully
- [ ] Auto-scaling configured (1-3 instances)
- [ ] CloudWatch dashboard created
- [ ] Email alerts configured

## Post-Deployment
- [ ] Integration tests passing
- [ ] Performance within SLA (<1s latency)
- [ ] Monitoring dashboard accessible
- [ ] Test predictions returning expected results
- [ ] API server tested (if using)

## Security
- [ ] Endpoint not publicly accessible
- [ ] IAM roles follow least privilege
- [ ] No credentials in code
- [ ] Environment variables used for configuration

## Documentation
- [ ] README updated with endpoint details
- [ ] API documentation current
- [ ] Runbook created for troubleshooting

## Monitoring Thresholds
- [ ] Latency: Alert if >1000ms average
- [ ] Errors: Alert if >10 4xx errors in 5 minutes
- [ ] Availability: 99.9% uptime target
- [ ] Cost: Alert if >$100/day

## Rollback Plan
1. Keep previous endpoint configuration
2. Test rollback procedure:
   ```bash
   aws sagemaker update-endpoint \
     --endpoint-name fraud-detection-endpoint \
     --endpoint-config-name previous-config-name
   ```
3. Document rollback steps in runbook