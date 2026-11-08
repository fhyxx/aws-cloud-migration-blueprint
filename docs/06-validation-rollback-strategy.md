# 06 — Validation, Testing and Rollback Strategy

**ID:** CLI-AWS-VAL-006 | **Version:** 1.1 | **Status:** Proposed, not tested

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

- VPC and six steady-state subnets match `10.30.0.0/16` across two AZs; dedicated MGN staging subnet is separately allocated and validated.
- Route tables match design; DB has no direct internet route.
- VPN routes/tunnels work.
- Security groups permit only approved paths, including EFS TCP 2049 and MGN replication flows.
- ALB HTTPS listener, ACM certificate, Route 53 records and target health pass.
- App port 8080 remains provisional pending discovery.

## Application tests

Test startup, authentication, invalid credentials, order create/retrieve/update, payment/delivery test integrations, shared file read/write, background jobs and error handling. All critical workflows must pass.

## Database validation

Validate schema objects, constraints, indexes, sequences, procedures, triggers, extensions, roles and permissions. Confirm DMS full load/CDC prerequisites and inspect task errors. Verify primary keys/replica identity for all CDC tables; reconcile sequence values after replication stops; compare table inventory and row counts; reconcile critical orders and financial records by stable IDs; test transactions. Row counts alone do not prove integrity. Explicitly test foreign-key/trigger handling during full load and restore normal enforcement before application acceptance.

## Storage validation

Mount EFS from both AZs; test read/write, ownership, permissions and locking; confirm mount targets in each AZ and security-group TCP 2049 path; reconcile DataSync counts/sizes and errors. Validate S3 object inventory, encryption, Block Public Access, policy and retrieval.

## Security validation

Review MFA/federation, least-privilege IAM, no public SSH/DB, encryption at rest (EBS/RDS/EFS/S3), TLS, Secrets Manager, CloudTrail and CloudWatch logs.

## Performance and availability

Measure concurrent users, orders/minute, DB connections, CPU, memory, I/O, response times, API latency and file access. Test normal/peak load, concurrent order creation, app instance failure, RDS failover, AZ capacity loss and alarms. Numerical latency thresholds must be agreed after baseline measurement. Multi-AZ design alone does not prove 99.9% end-to-end availability.

## Provisional monitoring, health checks and scaling baseline

The following values are **initial engineering proposals**, not measured workload requirements or a promise of 99.9% availability. Validate them with application owners and representative load tests before production approval.

| Area | Initial proposal | Alert / action |
|---|---|---|
| ALB target health | Readiness path `/health/ready` (confirm with app team); HTTP 200; 30-second interval; 5-second timeout; healthy threshold 2; unhealthy threshold 3 | Alert when `UnHealthyHostCount` is above 0 for 2 consecutive 1-minute periods; investigate failed dependency/readiness checks |
| App ASG | Target tracking on average EC2 CPU at 60%; min 2, desired 2, provisional max 6; 300-second instance warm-up | Revisit max and CPU target after peak-load test; ensure scale-in protection/draining for in-flight work |
| App compute | CloudWatch Agent for memory and disk; CPU >75% for 10 minutes, memory >80% for 10 minutes, disk used >80% for 10 minutes | Warning thresholds; >90% memory or disk is critical; correlate with latency and application errors |
| ALB / application | Target 5xx rate >1% for 5 minutes using metric math; target response-time p95 >1 second for 5 minutes | Page Operations Lead; thresholds are provisional until baseline and business latency SLO are agreed |
| RDS PostgreSQL | CPU >75% for 10 minutes; free storage below 20% of configured capacity; freeable memory below 3 GiB; connections above 70% of the approved `max_connections` | Alert DBA; connection threshold cannot be activated until parameter group and connection-pool design are confirmed |
| EFS | Track `MeteredIOBytes`, throughput utilization and client connections; use `BurstCreditBalance` only if Bursting throughput is selected | Establish thresholds after throughput mode and load profile are approved; Elastic throughput is currently provisional |
| VPN | Alarm on tunnel state; one tunnel down is degraded, both down is critical | Alert Infrastructure Lead and verify alternate tunnel and route behaviour |
| Logs | Centralise application, OS, ALB and relevant database logs with approved retention | Alert on sustained application error spikes and critical service failures; retention and ingestion cost remain unapproved |

The ALB readiness endpoint must be lightweight and safe for frequent polling. Keep liveness and readiness semantics separate. Do not make every target unhealthy because an optional downstream integration is temporarily unavailable; define which dependencies are essential to serve a valid request. Set the Auto Scaling Group health-check grace period to the measured application startup time, not an arbitrary production default.

## Recovery acceptance criteria

The business objectives remain **RTO ≤4 hours** and **RPO ≤15 minutes**. They become accepted only after timed tests demonstrate them:

1. **RDS recovery:** restore an encrypted RDS PostgreSQL point-in-time recovery copy into an isolated environment. Record incident start, restore request, database availability, application reconnect and successful business transaction. Confirm the latest recoverable committed transaction is no more than 15 minutes before the declared recovery point.
2. **EFS recovery:** restore a representative directory/file set from an approved backup into an isolated path; compare file counts, sizes, ownership/permissions and checksums where appropriate. Define and approve an EFS backup policy first.
3. **S3 recovery:** confirm versioning or another approved object-recovery control for records that require protection from overwrite/deletion; test restoration of a representative object and its metadata. Versioning and lifecycle are open design decisions, not current deployed controls.
4. **Application/AZ recovery:** simulate one application instance loss and a controlled RDS Multi-AZ failover in a non-production test window. Record ALB recovery, connection retry behaviour, failed/in-flight order handling and data consistency.
5. **Business acceptance:** prove login and create/read/update of a test order plus any critical payment/delivery integration in the recovered environment. RTO stops only when the Business Owner accepts the service; RPO is measured from recoverable committed business data, not merely from infrastructure status.

A recovery test passes only if measured RTO and RPO meet the targets, critical business records reconcile, security controls remain effective, and evidence is reviewed by the DBA, Operations Lead and Business Owner. Backup configuration alone is not proof of recoverability. No recovery or failover test has been executed for this design.
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
