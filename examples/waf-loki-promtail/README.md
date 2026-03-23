# WAF → S3 → LMI → Loki → Grafana (+ WAF country geomap)

This example matches **`examples/waf-loki`** (Lambda ingests WAF objects from S3 into Loki) and adds a third Grafana dashboard: **WAF geographic (country)**. The observability host runs **Docker Compose with Loki and Grafana only** — no Promtail and no Docker-socket log scraping.

A dedicated **S3 bootstrap bucket** holds dashboard JSON; first-boot `user_data` runs `aws s3 cp` so the rendered `user_data` string stays under the EC2 **16 KiB** limit.

**Further reading — different architecture:** [cloudbuildlab/grafana-waf-analytics](https://github.com/cloudbuildlab/grafana-waf-analytics/tree/1-first-release) (1-first-release) uses **systemd timers**, **`aws s3 sync`** of WAF logs onto the instance, **host-installed** Loki/Promtail/Grafana, the **Infinity** datasource, and static **country coordinate** JSON. This repository’s example keeps the **LMI Lambda → Loki** path and adds **`geo_lat` / `geo_lon`** on each line at ingest (see below) so Grafana can use **coordinate** mode on the geomap (reliable) instead of panel-side country lookup.

End-to-end flow: WAF log objects land in S3, an S3 event triggers a **Node.js 24 Lambda Managed Instance function** that decompresses and pushes each log line to **Loki** on EC2; **Grafana** shows WAF logs, overview metrics, and a country map behind a public ALB.

## What this stack creates

| Resource | Purpose |
|----------|---------|
| VPC (3 AZs, public + private subnets) | All resources run here |
| `lambda_managed_instance` | LMI capacity provider |
| `lambda_managed_function_waf` (Node.js 24) | Reads gzip WAF log objects from S3, pushes lines to Loki |
| Existing S3 bucket (`var.waf_logs_bucket_name`) | **Not created here** — you provision the bucket separately; this stack adds the event notification and (optionally) WAF logging to it |
| IAM policy `waf_s3_read` | Scoped to the WAF log bucket; attached to the WAF Lambda only |
| EC2 (`t3.small`, private subnet) | Runs **Loki + Grafana** via Docker Compose; Loki data on root EBS |
| S3 bucket (`obs_bootstrap`, `force_destroy`) | Holds Grafana dashboard JSON; the obs instance runs `aws s3 cp` at bootstrap |
| ALB (public, HTTP 80) | Fronts Grafana port 3000; restricted to deployer IP by default (TLS not configured; use for demos only) |

## Prerequisites

- Terraform >= 1.7, AWS provider >= 6.0, **archive** provider >= 2.4 (declared in `versions.tf`)
- An AWS account in a [region where LMI is available](https://docs.aws.amazon.com/lambda/latest/dg/lambda-managed-instances.html)
- AWS credentials with IAM, Lambda, EC2, S3, ALB, and SSM permissions
- An **existing** S3 bucket whose name you set as `waf_logs_bucket_name` in `terraform.tfvars`. The bucket must exist before `terraform apply`. For [WAFv2 logging to S3](https://docs.aws.amazon.com/waf/latest/developerguide/logging-s3.html), the name must start with `aws-waf-logs-`.
- IAM for the Terraform principal: permission to update **bucket notifications** on that bucket (`s3:PutBucketNotificationConfiguration` and related reads), in addition to the usual Lambda / EC2 / ALB permissions.

## Apply

The WAF ingest code is plain ESM (`function-waf/index.mjs`). **Node.js 24 on Lambda includes AWS SDK for JavaScript v3**, so you do not need `npm install` in `function-waf/` for deployment; the zip excludes any local `node_modules` if present.

`alb_ingress_cidrs` defaults to your current public IP via `checkip.amazonaws.com`. Plan/apply must reach that URL from the machine running Terraform, or set `alb_ingress_cidrs` explicitly in `terraform.tfvars`.

```bash
cd examples/waf-loki-promtail
cp terraform.tfvars.example terraform.tfvars   # set waf_logs_bucket_name (required); edit region / name_prefix
terraform init
terraform plan
terraform apply
```

First apply takes several minutes: capacity provider creation and the EC2 Docker Compose startup both take time. Grafana becomes reachable when the ALB target group health check passes (`/api/health`).

## Outputs

```bash
terraform output grafana_url           # http://<alb-dns> — open in browser
terraform output waf_logs_bucket       # bucket name for WAF delivery or manual test uploads
terraform output obs_bootstrap_bucket  # S3 bucket for dashboard JSON at first boot
terraform output obs_instance_id       # EC2 ID — connect via SSM Session Manager
terraform output loki_push_url         # Loki HTTP push endpoint used by Lambda
```

## Grafana access

Open the `grafana_url` output in a browser. Default credentials: **admin / admin**. Grafana prompts to change the password on first login.

Three dashboards are provisioned under the **WAF** folder:

| Dashboard | Data |
|-----------|------|
| **WAF Logs** | `{source="waf"}` — raw stream |
| **WAF overview** | `{source="waf"}` — rates by action, rule, client IP, method |
| **WAF geographic (country)** | `{source="waf"}` — geomap plots **`geo_lat` / `geo_lon`** (numeric coordinates) |

**Geomap (why coordinates):** Grafana’s country **lookup** mode with Loki log lines is easy to misconfigure. The WAF Lambda therefore adds **`geo_lat`** and **`geo_lon`** to each JSON line when **`httpRequest.country`** is a known ISO 3166-1 alpha-2 code: it looks up a **bounding-box centre** from `function-waf/country-centroids.json` (~241 codes). Those positions are **country-level**, not exact client locations. The dashboard uses **one** JSON extract from `Line` and geomap **coordinates** mode.

Centroids were generated by merging public datasets from [samayo/country-json](https://github.com/samayo/country-json) (`country-by-geo-coordinates.json` + `country-by-abbreviation.json`); regenerate by re-running the merge script if you change sources.

AWS documents WAF log fields in [Logging field list](https://docs.aws.amazon.com/waf/latest/developerguide/logging-fields.html).

**Already-ingested data** in Loki from **before** this change has no `geo_lat` / `geo_lon`; the map query uses `|= "geo_lat"`. Re-upload a test object or wait for new WAF delivery after **`terraform apply`** updates the function.

## Testing the ingest path

Upload any gzip-compressed WAF log file to the WAF log bucket. By default the S3 notification only fires for keys ending in **`.gz`** (`waf_logs_object_suffix`). The Lambda splits large files into multiple Loki push requests so a single object does not exceed a safe payload size.

Set `waf_logs_object_suffix = ""` in `terraform.tfvars` if you want every new object to invoke the function (only on buckets dedicated to this flow).

```bash
# Sample line includes httpRequest.country so the geomap has something to plot
echo '{"timestamp":1735700000000,"action":"ALLOW","terminatingRuleId":"Default_Action","httpRequest":{"clientIp":"1.2.3.4","country":"US","uri":"/","httpMethod":"GET"}}' \
  | gzip > /tmp/test-waf.log.gz

aws s3 cp /tmp/test-waf.log.gz \
  "s3://$(terraform output -raw waf_logs_bucket)/test/test-waf.log.gz"
```

After a few seconds, the line appears under `{source="waf"}` in Grafana Explore. The geomap shows a point once the Lambda has added **`geo_lat` / `geo_lon`** for that country code.

## WAFv2 log delivery (optional)

If you have an existing WAFv2 Web ACL, pass its ARN to enable automatic log delivery:

```hcl
web_acl_arn = "arn:aws:wafv2:ap-southeast-2:123456789012:regional/webacl/my-acl/..."
```

WAF delivers gzip log files to the S3 bucket, which the Lambda picks up automatically. The bucket must still satisfy [WAF logging requirements](https://docs.aws.amazon.com/waf/latest/developerguide/logging-s3.html) (naming, optional dedicated bucket, and resource policy for the delivery service).

## Connecting to the EC2 host (no SSH required)

```bash
aws ssm start-session --target "$(terraform output -raw obs_instance_id)"
```

Check Compose status:

```bash
docker compose -f /opt/obs/docker-compose.yaml ps
docker compose -f /opt/obs/docker-compose.yaml logs --tail 50 loki
```

## Data durability notes

Loki stores chunks and index on the **EC2 root EBS volume** (30 GB gp3). Data survives instance stop/start (same volume retained). **Instance replacement** (Terraform `taint`, terminated by AWS, etc.) provisions a new root volume — Loki query history is lost, but all raw WAF log objects remain in S3 and can be re-uploaded to re-drive ingestion.

The observability EC2 uses **`user_data_replace_on_change = true`**. Any change to `templates/user_data.sh.tftpl` plans a **new instance**. Changes to dashboard JSON under `templates/dashboards/` update **S3 objects**; replace the instance (or re-run apply when `user_data` changes) to re-fetch files at boot.

### Grafana: missing dashboards or empty geomap

1. SSM to the instance: `ls -la /opt/obs/grafana/dashboards/` (expect `waf.json`, `waf-overview.json`, `waf-geomap.json`).
2. `sudo tail -n 200 /var/log/cloud-init-output.log` — `aws s3 cp`, Python JSON validation, or Compose errors.
3. **Empty map:** confirm lines include **`geo_lat`** (expand JSON in the log row). If not, the line was ingested by an **older** Lambda revision — run **`terraform apply`** and **re-drive** an S3 object (new upload or re-copy) so ingest runs again. Confirm **`httpRequest.country`** is a **known ISO2** code present in `country-centroids.json`.

## Approximate cost (ballpark, us-east-1-style pricing, running 24/7)

| Component | ~Monthly |
|-----------|---------|
| LMI capacity (t3 equivalent, minimal) | $15–40 |
| EC2 `t3.small` | ~$15 |
| ALB | ~$18 |
| NAT Gateway | ~$35 |
| S3 + data transfer | < $5 |
| **Total** | **~$90–115** |

Costs scale with Lambda invocations and WAF log volume.

## Destroy

```bash
terraform destroy
```

The WAF log bucket is **not** managed by Terraform; `terraform destroy` removes the notification and other stack resources but **does not delete** the bucket or its objects. The **obs bootstrap** bucket is managed here with **`force_destroy = true`**, so `terraform destroy` empties and removes it along with the uploaded dashboard objects.

If you previously applied an older revision of this example that **created** the bucket with Terraform, run `terraform state rm` on the removed bucket resources (`aws_s3_bucket.waf_logs` and any related `aws_s3_bucket_*` blocks) before the next `apply`, so Terraform does not plan to destroy a bucket you still need.

## Documentation

Walkthrough site: [aws-lambda-managed-instance-walkthrough](https://github.com/jajera/aws-lambda-managed-instance-walkthrough)
