# Migration Data-Flow View

**ID:** CLI-AWS-VIEW-012 | **Version:** 1.1 | **Status:** Proposed — not executed

This focused view separates MGN, DMS and DataSync paths so their distinct source, destination, protocols and dependencies can be reviewed independently. It complements the [canonical master architecture](target-architecture.md).

## Rendered migration-flow diagram

```mermaid
flowchart LR
  subgraph SOURCE["On-premises source environment"]
    APP_SRC["Two Linux application VMs<br/>10.50.10.0/24 • MGN sources"]
    PG_SRC[("Self-managed PostgreSQL source<br/>10.50.20.0/24")]
    NFS_SRC[("NFS file server<br/>10.50.20.0/24")]
    ARCH_SRC["Archive source<br/>type and location TBD"]
    DS_AGENT["DataSync agent VM<br/>10.50.20.50/32<br/>near NFS source"]
    NFS_SRC -->|"NFSv4.x TCP 2049<br/>or NFSv3 TCP 111 + 2049"| DS_AGENT
    ARCH_SRC -.->|"Agent and protocol path TBD"| DS_AGENT
  end

  VPN["Illustrative Site-to-Site VPN<br/>BGP ASN 65010 ↔ 64512<br/>two redundant tunnels • no VGW ECMP"]
  VGW["Virtual Private Gateway<br/>ASN 64512 • BGP"]

  subgraph AWS["AWS VPC 10.30.0.0/16 — us-east-1"]
    subgraph MGN_SUBNET["Dedicated private MGN staging subnet<br/>10.30.31.0/24 • AZ-A • migration-only"]
      MGN_REPL["MGN replication servers"]
      MGN_EGRESS["Controlled service egress<br/>same-AZ NAT or validated private endpoint"]
      MGN_REPL -->|"TCP 443"| MGN_EGRESS
    end

    subgraph DMS_SUBNETS["Dedicated private DMS migration subnets<br/>10.30.41.0/24 • AZ-A and 10.30.42.0/24 • AZ-B"]
      DMS["Provisioned AWS DMS replication instance<br/>current Terraform option; non-Multi-AZ<br/>dedicated DMS SG"]
    end

    RDS[("RDS PostgreSQL target<br/>Multi-AZ DB instance deployment")]
    EFS[("Regional EFS target")]
    S3[("S3 archive target")]
    subgraph DS_VPCE_SUBNET["DataSync endpoint subnet<br/>10.30.51.0/24 • AZ-A"]
      DS_VPCE["DataSync VPC service endpoint<br/>TCP 1024–1064"]
    end
    subgraph DS_TASK_SUBNET["DataSync task ENI subnet<br/>10.30.52.0/24 • AZ-A"]
      DS_ENI["DataSync task ENI<br/>TCP 443 from agent"]
    end
    EFS_SG["EFS mount-target SG<br/>allows TCP 2049 from task-ENI SG"]
  end

  MGN_SERVICE["AWS MGN regional service API"]
  DS_SERVICE["AWS DataSync service<br/>public or VPC service endpoint"]

  APP_SRC -->|"Replication stream TCP 1500<br/>over approved VPN route"| VPN
  VPN --> VGW
  VGW --> MGN_REPL
  APP_SRC -->|"Service connectivity TCP 443<br/>approved source egress"| MGN_SERVICE
  MGN_EGRESS -->|"HTTPS TCP 443"| MGN_SERVICE

  DMS -->|"Initiates source connection TCP 5432<br/>over VPN; source firewall allows DMS subnet path"| VGW
  VGW --> VPN
  VPN --> PG_SRC
  DMS -->|"Target connection TCP 5432<br/>temporary DB ingress from DMS SG"| RDS

  DS_AGENT -->|"DataSync control/data plane over IPsec VPN"| VPN
  VPN --> VGW
  VGW -->|"TCP 1024–1064 control plane"| DS_VPCE
  VGW -->|"TCP 443 task data plane"| DS_ENI
  DS_SERVICE -->|"Creates task data-plane ENI"| DS_ENI
  DS_ENI -->|"NFS TCP 2049<br/>task-ENI SG to EFS mount-target SG"| EFS
  DS_ENI --- EFS_SG
  VGW ---|"BGP source route only; no default route"| DS_VPCE_SUBNET
  VGW ---|"BGP source route only; no default route"| DS_TASK_SUBNET
  DS_SERVICE -->|"Service-side S3 transfer<br/>bucket policy/IAM required"| S3
```

## Migration path summary

| Workstream | Source to destination | Main path / protocol | Important boundary |
|---|---|---|---|
| AWS MGN | Two Linux application VMs to MGN staging replication servers | Source-to-staging TCP 1500 over approved VPN route; source and staging service connectivity TCP 443 | Dedicated private staging subnet; controlled service egress; staging CIDR/AZ and sizing pending |
| AWS DMS | Self-managed PostgreSQL to RDS PostgreSQL | DMS-to-source TCP 5432 over VPN; DMS-to-target TCP 5432 | DMS replication subnet group spans dedicated DMS-A/B subnets in two AZs; current provisioned replication instance is non-Multi-AZ; dedicated DMS SG; temporary RDS ingress from DMS SG |
| DataSync NFS | On-premises NFS to Regional EFS | Agent-to-NFS TCP 2049 for NFSv4.x or TCP 111 + 2049 for NFSv3; DataSync task ENI to EFS TCP 2049 | Agent near source; task ENI in same VPC and AZ as selected EFS mount target; dedicated task-ENI SG |
| DataSync archive | Archive source to S3 | DataSync service-side transfer | Archive source type/location and agent requirement are unknown; do not assume NFS or a particular source connector |

## Service-specific validation gates

### MGN

- Confirm supported source OS, architecture, boot mode, disk inventory and change rate.
- Allocate a dedicated private staging subnet with non-overlapping CIDR and adequate IP capacity.
- Validate source-to-staging TCP 1500 and source/staging-to-regional-service TCP 443.
- Confirm controlled staging egress through same-AZ NAT or a separately validated private endpoint design.
- Size replication servers, EBS and snapshots from measured source profiles; no migration runtime or staging cost is approved.

### DMS

- Capture exact PostgreSQL source and target versions and verify current DMS compatibility.
- Approve schema/object migration separately from row-data movement.
- Validate logical WAL, replication permissions, slots/senders, WAL headroom, table keys and replica identity.
- Benchmark provisioned versus Serverless capacity and record full-load duration and CDC lag.
- Allow TCP 5432 from DMS to the source path and target DB SG; remove temporary DMS ingress after migration when no longer needed.
- Reconcile PostgreSQL sequences after CDC stops; ongoing DMS replication does not synchronise sequence state.

### DataSync

- Confirm NFS version, agent mode, endpoint type and the corresponding service endpoint port model.
- Validate agent-to-source NFS ports and agent-to-service connectivity.
- For EFS, verify task ENI placement in a subnet/AZ with an EFS mount target and TCP 2049 from task-ENI SG to EFS mount-target SG.
- Inventory archive source type, location, bytes and connector/agent requirements before pricing or execution.
- Record initial transfer reports and final-delta reconciliation after writers/jobs are paused.

## Unknowns retained explicitly

Source CIDRs and VPN route mode, MGN staging subnet CIDR/AZ, exact PostgreSQL versions, DMS sizing/runtime, DataSync task mode and service endpoint, archive source type/bytes, final delta, transfer window and cutover sequencing remain pending validation. The diagram does not claim that any migration service has been configured or run.

## Canonical source

The editable Mermaid source for this view is [migration-data-flow.mmd](migration-data-flow.mmd). Keep the embedded Mermaid block above synchronised with that file.

## Related views

- [Runtime/network view](runtime-network-view.md)
- [Canonical master architecture](target-architecture.md)
- [Network and security design](../docs/03-network-security-design.md)
- [Data migration strategy](../docs/04-data-migration-strategy.md)
- [Migration runbook](../docs/05-migration-runbook.md)
- [Migration readiness matrix](../docs/09-migration-readiness-matrix.md)
