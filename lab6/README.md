# ACS730 Week 8 — Lab 6

## Architecture

Terraform provisions two tagged AL2023 t3.micro instances in us-east-1 with LabInstanceProfile. The security group permits HTTP/80 and outbound connections, **never inbound SSH/22**. The amazon.aws.aws_ec2 dynamic inventory selects running Lab=lab6, Role=web instances by instance ID, creating role_web.

The GitHub Actions runner uses **AWS Systems Manager Session Manager**, because it avoids both inbound port 22 and long-lived SSH private keys in GitHub secrets. The community.aws.aws_ssm connection stages Ansible module files through an S3 transfer bucket in us-east-1, matching the SSM region. Supply LAB6_SSM_BUCKET at runtime; do not commit an account ID. Packer uses an ephemeral build-instance SSH connection only for its own disposable image builder.

The reusable webserver role installs packages with state: present, creates a non-root acs730web service account, renders Jinja2 HTML and systemd unit files, and starts/enables the service. The handler restarts the service only if the unit changes. **changed=0 on a second run proves** every task found the target already in its desired state, without modifying it again.

**Deregistering an AMI is not enough** because its underlying EBS snapshot persists and can continue costing money; capture the snapshot ID before deregistration and delete it separately after approval.

## Setup and validation (AWS Academy workstation)

```bash
cd ~/acs730-coursework
git fetch origin && git switch lab6
source ~/lab6-venv/bin/activate
python -m pip install boto3 botocore
ansible-galaxy collection install -r lab6/ansible/requirements.yml
aws sts get-caller-identity
export AWS_DEFAULT_REGION=us-east-1
export ACCT=$(aws sts get-caller-identity --query Account --output text)
export LAB6_SSM_BUCKET="acs730-lab6-ssm-${ACCT}"
aws s3api head-bucket --bucket "$LAB6_SSM_BUCKET" 2>/dev/null || aws s3api create-bucket --bucket "$LAB6_SSM_BUCKET" --region us-east-1
terraform -chdir=lab6/terraform init -backend=false
terraform -chdir=lab6/terraform validate
(cd lab6/ansible && ansible-playbook --syntax-check site.yml)
(cd lab6/packer && packer init web.pkr.hcl && packer fmt -check -diff web.pkr.hcl && packer validate web.pkr.hcl)
bash -n lab6/scripts/boot-to-ready.sh
./scripts/check-lab.sh lab6
```

The pinned Ansible collections are in ansible/requirements.yml; Core 2.16.20 is required. Check ansible-galaxy collection list and session-manager-plugin --version. The helper install-lab-tools.sh may install unconstrained versions, so use the pinned requirements.

## Live AWS testing and evidence

Only when ready to incur AWS Academy charges:

```bash
terraform -chdir=lab6/terraform apply
aws ssm describe-instance-information --filters "Key=tag:Lab,Values=lab6" --query 'InstanceInformationList[].[InstanceId,PingStatus]' --output table
cd lab6/ansible
ansible-inventory -i inventory/ --graph | tee ../evidence/inventory-graph.txt
ansible -i inventory/ role_web -m ansible.builtin.ping
set -o pipefail
ansible-playbook -i inventory/ site.yml -l role_web | tee ../evidence/idempotency-run1.txt
ansible-playbook -i inventory/ site.yml -l role_web | tee ../evidence/idempotency-run2.txt
```

Both hosts must show changed=0 and failed=0 in the second recap. Confirm HTTP 200 from both public IPs and different host names/private IPs.

For converge-on-boot timing, record START=$(date +%s) immediately before an approved `terraform apply -replace='aws_instance.web[0]'`; get the new ID and public IP from Terraform outputs, wait for SSM ping, run the role, then run `../scripts/boot-to-ready.sh converge-on-boot "$NEW_IP" "$START" | tee ../evidence/boot-to-ready-ansible.txt` from ansible/.

From lab6/packer run `packer build web.pkr.hcl`, record the resulting AMI and snapshot IDs, and capture a real EC2 AMI screenshot as evidence/golden-ami.png. Launch a separate instance from that AMI using the Terraform security group and LabInstanceProfile, but **without** Lab=lab6 or Role=web tags. Record START immediately before run-instances, wait for its public IP, then run `./scripts/boot-to-ready.sh golden-ami "$GIP" "$START" | tee evidence/boot-to-ready-golden.txt`. Verify `/baked.html` returns HTTP 200 and the index page says Build: golden-ami. Record its ID for cleanup.

Before a live GitHub Actions run, refresh the temporary Academy secrets using `./scripts/refresh-gha-creds.sh Inder783/acs730-coursework`, and set repository secret AWS_ACCOUNT_ID to the Academy account number. Dispatch `gh workflow run lab6-configure.yml --ref lab6 -f apply=true` and capture an authentic successful Actions screenshot as evidence/pipeline-run.png. **Important:** the hosted runner's local Terraform state is separate from workstation state. Do not apply from both places against the same resources without a shared backend and an agreed cleanup owner.

## Timing comparison

| Path | Launch to HTTP ready | Includes |
| --- | --- | --- |
| Stock AL2023 plus Ansible | Not measured yet | Launch, SSM registration, dnf, configuration, service start |
| Golden AMI | Not measured yet | Launch, boot, preconfigured service start |

Convergence pays SSM and package download latency at each launch and can fail if mirrors are unavailable. Golden AMIs shift that work to the build and improve repeat launches, but cost build time and snapshot storage, and require regular rebuilding to avoid stale packages. **Recommendation:** use a golden AMI for repeated deployments, and Ansible convergence for small or frequently changing fleets; reconsider after actual timing measurements.

## Experiments

At least two experiments are required; **these are predictions, not observed results**.

1. **Break idempotency:** Predict a shell-based mkdir task reports changed on repeated runs, but adding creates: prevents repeated changes. Test, record actual output, restore the original role, and reconfirm changed=0. Observed: pending.
2. **Shrink inventory:** Predict stopping one instance removes it from the graph due to instance-state-name: running. Test the graph, restore the instance, and reconfirm both hosts. Observed: pending.

Write 2–3 sentences per experiment with prediction, observation and explanation once run.

## Cleanup — do not execute without approval

Record the golden AMI ID, EBS snapshot ID, separate golden instance ID and Terraform state location first. Terminate the separate golden instance, destroy Terraform-owned resources using the same state that created them, deregister the AMI, delete its recorded snapshot, remove only this lab's SSM bucket, then run the read-only `./scripts/cleanup-check.sh`. Save genuine logs as evidence/teardown.txt. Never destroy the workstation, unrelated resources, or merge the PR without approval.

Required genuine evidence: inventory-graph.txt, idempotency-run1.txt, idempotency-run2.txt, pipeline-run.png, golden-ami.png, teardown.txt. Do not fabricate any of them.
