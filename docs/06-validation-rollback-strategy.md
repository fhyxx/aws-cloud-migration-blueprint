# 06 — Validation, Testing and Rollback Strategy

**ID:** CLI-AWS-VAL-006 | **Version:** 1.0 | **Status:** Proposed, not tested

## Objectives and targets

Prove infrastructure, application, database, storage, security, performance and recovery readiness. Business targets are 99.9% availability, RTO 4h, RPO 15m; none has been demonstrated.

## Severity

| Severity | Meaning | Cutover |
|---|---|---|
| Critical | Data loss, security compromise, essential service unavailable | NO-GO |
| High | Major workflow impaired | Resolve or formally risk-accept; integrity/security cannot be waived |
| Medium | Non-critical with workaround | Named owner and approval |
| Low | Cosmetic/minor | Track to closure |

## Infrastructure/network tests

- VPC and six planned subnets match `10.30.0.0/16` across two AZs.
- Route tables match design; DB has no direct internet route.
- VPN routes/tunnels work.
- Security groups permit only approved paths.
- ALB HTTPS listener/certificate and target health pass.
- App port 8080 remains provisional pending discovery.

## Application tests

Test startup, authentication, invalid credentials, order create/retrieve/update, payment/delivery test integrations, shared file read/write, background jobs and error handling. All critical workflows must pass.

## Database validation

Validate schema objects, constraints, indexes, sequences, procedures, triggers, extensions, roles and permissions. Compare table inventory and row counts; reconcile critical orders and financial records by stable IDs; test transactions; review all DMS errors and CDC latency. Row counts alone do not prove integrity.

## Storage validation

Mount EFS from both AZs; test read/write, ownership, permissions and locking; reconcile DataSync counts/sizes and errors. Validate S3 object inventory, encryption, Block Public Access, policy and retrieval.

## Security validation

Review MFA/federation, least-privilege IAM, no public SSH/DB, encryption at rest (EBS/RDS/EFS/S3), TLS, Secrets Manager, CloudTrail and CloudWatch logs.

## Performance and availability

Measure concurrent users, orders/minute, DB connections, CPU, memory, I/O, response times, API latency and file access. Test normal/peak load, concurrent order creation, app instance failure, RDS failover, AZ capacity loss and alarms. Numerical latency thresholds must be agreed after baseline measurement. Multi-AZ design alone does not prove 99.9% end-to-end availability.

## Backup and recovery

Restore RDS to an isolated target, validate critical records, test file recovery and application recovery. Measure elapsed restoration time (RTO) and age of latest recoverable consistent data (RPO). Backup configuration alone does not prove either target.

## Cutover GO/NO-GO

Require approved change, network ready, MGN test launch pass, DMS full load/CDC and DB reconciliation approved, final file sync ready, application/security/performance tests pass, monitoring/recovery evidence reviewed, rollback authority available. GO only with recorded sign-off.

## Rollback stages

| Stage | State | Response |
|---|---|---|
| A | Before cutover | Stop migration; preserve source |
| B | Traffic switched, no AWS writes | Return to source only after consistency/readiness check |
| C | AWS accepted writes | Freeze writes; preserve logs; reconcile or reverse-migrate under DBA |
| D | AWS accepted | Source retirement is a separate change |

DNS reversal alone is unsafe after target writes. Reverse replication is not assumed.

## Evidence and sign-off

Each test records ID, timestamp, environment, tester, preconditions, steps, expected/actual result, PASS/FAIL/BLOCKED/NOT RUN/WAIVED, evidence and reviewer. Waivers require rationale, impact, compensating control, owner and approval; critical integrity/security failures cannot be waived.

Approvers: AWS Solutions Architect/Infrastructure Lead; DBA; Application Lead; Security Lead; Operations Lead; Migration Lead; Business Owner.

**Status:** Proposed strategy; no tests have been executed.
