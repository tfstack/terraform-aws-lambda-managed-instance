# WAF → S3 → LMI → Loki → Grafana demo

End-to-end walkthrough example: AWS WAF log objects land in S3, an S3 event triggers a **Node.js 24 Lambda Managed Instance function** that decompresses and pushes each log line to **Loki** running on EC2, and **Grafana** surfaces a live log stream behind a public ALB.

## What this stack creates

| Resource | Purpose |
|----------|---------|
| VPC (3 AZs, public + private subnets) | All resources run here |
| `lambda_managed_instance` | LMI capacity provider |
| `lambda_managed_function_waf` (Node.js 24) | Reads gzip WAF log objects from S3, pushes lines to Loki |
| Existing S3 bucket (`var.waf_logs_bucket_name`) | **Not created here** — you provision the bucket separately; this stack adds the event notification and (optionally) WAF logging to it |
| IAM policy `waf_s3_read` | Scoped to the WAF log bucket; attached to the WAF Lambda only |
| EC2 (`t3.small`, private subnet) | Runs Loki + Grafana via Docker Compose; Loki data on root EBS |
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
cd examples/waf-loki
cp terraform.tfvars.example terraform.tfvars   # set waf_logs_bucket_name (required); edit region / name_prefix
terraform init
terraform plan
terraform apply
```

First apply takes several minutes: capacity provider creation and the EC2 Docker Compose startup both take time. Grafana becomes reachable when the ALB target group health check passes (`/api/health`).

## Outputs

```bash
terraform output grafana_url          # http://<alb-dns> — open in browser
terraform output waf_logs_bucket      # bucket name for WAF delivery or manual test uploads
terraform output obs_instance_id      # EC2 ID — connect via SSM Session Manager
terraform output loki_push_url        # Loki HTTP push endpoint used by Lambda
```

## Grafana access

Open the `grafana_url` output in a browser. Default credentials: **admin / admin**. Grafana prompts to change the password on first login.

Two dashboards are provisioned under the **WAF** folder: **WAF Logs** (raw stream) and **WAF overview** (rates by action, terminating rule, top client IPs, HTTP method, and a BLOCK-only log panel). Dashboard JSON lives in `templates/dashboards/` and is injected into `user_data` at `terraform apply` time (base64 via `templatefile`), so the instance always gets the same bytes as those files. Queries use `| json` where fields are top-level on the WAF line; client IP and HTTP method panels use a regexp on the raw JSON line for nested `httpRequest` fields.

## Testing the ingest path

Upload any gzip-compressed WAF log file to the WAF log bucket. By default the S3 notification only fires for keys ending in **`.gz`** (`waf_logs_object_suffix`). The Lambda splits large files into multiple Loki push requests so a single object does not exceed a safe payload size.

Set `waf_logs_object_suffix = ""` in `terraform.tfvars` if you want every new object to invoke the function (only on buckets dedicated to this flow).

```bash
# Create a sample WAF log in WAF JSONL format
echo '{"timestamp":1735700000000,"action":"ALLOW","terminatingRuleId":"Default_Action","httpRequest":{"clientIp":"1.2.3.4","uri":"/","httpMethod":"GET"}}' \
  | gzip > /tmp/test-waf.log.gz

aws s3 cp /tmp/test-waf.log.gz \
  "s3://$(terraform output -raw waf_logs_bucket)/test/test-waf.log.gz"
```

After a few seconds, the log line appears in Grafana Explore under the `{source="waf"}` query.

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

The observability EC2 uses **`user_data_replace_on_change = true`**. Any change to `templates/user_data.sh.tftpl` or `templates/dashboards/*.json` plans a **new instance** (user data only runs at launch). Expect brief Grafana/Loki downtime while the replacement registers with the ALB target group.

### Grafana: missing **WAF overview** after replace

User data must finish and both JSON files must be valid before `docker compose up` runs.

1. SSM to the instance and list files: `ls -la /opt/obs/grafana/dashboards/` (expect `waf.json` and `waf-overview.json`).
2. Read bootstrap output: `sudo tail -n 200 /var/log/cloud-init-output.log` — look for `validated dashboard json:` or a Python `JSONDecodeError`.
3. Check Grafana: `sudo docker compose -f /opt/obs/docker-compose.yaml logs --tail 100 grafana` for provisioning errors.

`/var/log/cloud-init.log` is not world-readable on Amazon Linux (typically `root:adm`, mode `640`). Use **`sudo cat`** / **`sudo tail`**; for script output, prefer **`cloud-init-output.log`** as in step 2.

To confirm the instance received the **current** Terraform user data, search the debug log for the IMDS fetch line, for example: `sudo grep user-data /var/log/cloud-init.log | head -1`. With the `templatefile` + `filebase64` dashboards, the line should report on the order of **11 KiB** (e.g. `... user-data (200, 11267b)`). A value around **5 KiB** means the launch used an **older** user-data payload; run **`terraform apply`** from the updated example so `user_data_replace_on_change` provisions a new instance.

If dashboards are missing locally but JSON validates, confirm you ran **`terraform apply`** after pulling changes (the rendered `user_data` string must include the new base64 payloads). On Windows, ensure `templates/**/*.json` and `*.tftpl` use LF line endings (see repo `.gitattributes`).

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

The WAF log bucket is **not** managed by Terraform; `terraform destroy` removes the notification and other stack resources but **does not delete** the bucket or its objects.

If you previously applied an older revision of this example that **created** the bucket with Terraform, run `terraform state rm` on the removed bucket resources (`aws_s3_bucket.waf_logs` and any related `aws_s3_bucket_*` blocks) before the next `apply`, so Terraform does not plan to destroy a bucket you still need.

## Documentation

Walkthrough site: [aws-lambda-managed-instance-walkthrough](https://github.com/jajera/aws-lambda-managed-instance-walkthrough)
