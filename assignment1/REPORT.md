# ACS730 - Assignment 1
## Multi-Environment Deployment

## 1. Introduction

The purpose of this assignment is to implement a multi-environment
deployment pipeline using Terraform, GitHub Actions and AWS.

The infrastructure was refactored into a reusable Terraform module
and deployed into three separate environments: dev, staging and
production. GitHub Environments were used to control deployments
and manage temporary AWS credentials. SSM Parameter Store and
CloudWatch were also implemented for secrets management and
monitoring.

## 2. Reusable Terraform Module

The existing Terraform configuration was refactored into a reusable
module located at terraform/modules/web.

The module provisions:

- One VPC
- Two public subnets in different availability zones
- Internet gateway
- Public route table
- Route table associations
- Security group
- Amazon Linux 2023 EC2 instance running Nginx
- CloudWatch CPU utilization alarm

### Module Inputs

| Input | Purpose |
|---|---|
| environment | Identifies dev, staging or prod |
| vpc_cidr | Defines the network address range |
| instance_type | Defines the EC2 instance size |
| app_version | Defines the application version |

Input variables have defined types and validation rules to reduce
configuration errors.

### Module Outputs

The module provides the VPC ID, subnet IDs, EC2 instance ID,
public IP address, website URL, environment name and application
version.

### Design Decisions

The for_each expression was used for subnet creation and route
table associations because each subnet has a unique key. This
provides more stable resource addresses than count when individual
subnets are added or removed.

Common naming conventions and resource tags are defined using
local values to avoid unnecessary duplication.

The security group allows HTTP traffic on port 80 but does not
allow inbound SSH traffic. The EC2 instance uses LabInstanceProfile,
encrypted root storage and IMDSv2.

## 3. Environment Configuration

Each environment calls the same Terraform module with its own
configuration.

| Environment | VPC CIDR | Instance Type | Final Version |
|---|---|---|---|
| Dev | 10.10.0.0/16 | t3.micro | v2 |
| Staging | 10.20.0.0/16 | t3.micro | v2 |
| Prod | 10.30.0.0/16 | t3.micro | v2 |

Separate VPCs provide network isolation between environments.

### Remote State Management

All three environments use the existing S3 backend bucket:

acs730-tfstate-622080298024

Each environment has a separate state key:

- assignment1/dev/terraform.tfstate
- assignment1/staging/terraform.tfstate
- assignment1/prod/terraform.tfstate

Encryption and S3 state locking are enabled.

Separate state files allow each environment to be managed
independently without changing the infrastructure of another
environment.

Evidence: evidence/backend-state-keys.txt

## 4. GitHub Environments

Two GitHub Environments were configured: staging and prod.

Staging deploys automatically after changes are merged into main
and Terraform validation is successful.

Production deployment requires staging to complete successfully
and a manual reviewer to approve the deployment.

The production deployment branch policy allows only the main
branch. Administrator bypass was disabled.

Self-review was allowed because this is an individual assignment.
In a real organization, an independent reviewer should approve
production deployments.

Evidence:

- evidence/environments.json
- evidence/prod-branch-policy.json
- evidence/prod-approval-pending.png
- evidence/prod-approval-approved.png

## 5. Scoped Credentials and OIDC Trust Policy

The following temporary AWS credentials were configured separately
in the staging and prod GitHub Environments:

- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY
- AWS_SESSION_TOKEN

The staging credentials were tested successfully before removing
the repository-level copies.

The following command is used to refresh temporary AWS Academy
credentials at the beginning of a lab session:

    ./scripts/refresh-gha-creds.sh Inder783/acs730-coursework staging prod

No long-lived AWS credentials are required by this pipeline.

### Proposed Production OIDC Trust Policy

In a real AWS account, GitHub Actions could use OpenID Connect
instead of manually refreshing temporary credentials.

The proposed IAM role trust policy is:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<AWS_ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:Inder783/acs730-coursework:environment:prod"
        }
      }
    }
  ]
}
```

The federated principal identifies GitHub's OIDC identity provider.

The sts:AssumeRoleWithWebIdentity action allows GitHub Actions
to obtain temporary AWS credentials.

The audience condition ensures that the token is intended for
AWS Security Token Service.

The subject condition restricts role assumption to the specified
repository and its production environment.

Using a repository-wide wildcard would allow other matching
workflow contexts to request the production role.

The production environment also restricts deployment to main
and requires manual approval.

This OIDC policy is a proposed design only because AWS Academy
restricts IAM role creation and modification.

Evidence:
- evidence/credentials-check.txt
- evidence/secrets-scope.txt

## 6. Real AWS Deployment

The deployment workflow is located at
.github/workflows/assignment1-deploy.yml.

The pipeline validates Terraform, automatically deploys staging,
verifies the application, waits for production approval and
then deploys production.

The dev environment was initially deployed with version v1.
The application was then updated to v2.

Terraform replaced the EC2 instance because
user_data_replace_on_change was enabled. The existing networking
resources remained unchanged.

After successful testing in dev, version v2 was promoted to
staging and production as their initial deployment.

| Environment | Instance ID | Version |
|---|---|---|
| Dev | i-0d433538d9c101b62 | v2 |
| Staging | i-0c66ebddfef567771 | v2 |
| Prod | i-0d15ef49c16f863b7 | v2 |

Pull request: #11

Deployment workflow run: 46083087438

All three workflow jobs completed successfully.

Evidence:
- evidence/dev-web-v1.png
- evidence/dev-web-v2.png
- evidence/staging-apply.txt
- evidence/prod-apply.txt
- evidence/prod-approval-pending.png
- evidence/prod-approval-approved.png

## 7. Secrets Management

AWS SSM Parameter Store was used to store a demonstration
database password as a SecureString parameter.

The parameter was created outside Terraform using:

    aws ssm put-parameter \
      --name "/acs730/assignment1/db-password" \
      --type SecureString \
      --value "<DEMONSTRATION_VALUE>" \
      --region us-east-1

Terraform reads the parameter using the following data source:

    data "aws_ssm_parameter" "db_password" {
      name            = "/acs730/assignment1/db-password"
      with_decryption = true
    }

The parameter value is not hardcoded in Terraform or exposed
through the application webpage.

However, decrypted values can be stored in Terraform state.
Therefore, backend encryption and restricted access are important.

In production, the application could retrieve secrets directly
from Parameter Store using an IAM role.

The application demonstrates secret retrieval through Terraform
but does not connect to an actual database.

Evidence: evidence/ssm-parameter.txt

## 8. CloudWatch Monitoring

A CloudWatch alarm was created through the reusable module
for each environment.

| Setting | Configuration |
|---|---|
| Namespace | AWS/EC2 |
| Metric | CPUUtilization |
| Statistic | Average |
| Threshold | Greater than 80 percent |
| Period | 300 seconds |
| Evaluation periods | 2 |
| Dimension | EC2 InstanceId |

All three alarms reached the OK state.

When the dev instance was replaced, Terraform updated the alarm
to monitor the new instance.

Notification actions were not configured because the assignment
focuses on basic monitoring.

Evidence:
- evidence/cloudwatch-alarm.json
- evidence/cloudwatch-alarm.png

## 9. Pipeline Recommendation

For a team fully committed to AWS with no multi-cloud plans,
I would recommend AWS CodePipeline and CodeBuild.

### Identity and Access Management

AWS-native pipelines use IAM service roles to access AWS resources.
This reduces the need to manage credentials in an external platform.

GitHub Actions also supports temporary credentials through OIDC,
but AWS-native services provide direct IAM integration.

### Runner Management and Cost

CodeBuild provides managed build environments, reducing the need
to maintain and patch build servers.

GitHub-hosted runners also provide managed infrastructure.
The cost of both platforms depends on build duration, frequency
and compute requirements.

### Private Network Access

CodeBuild can be configured to access resources inside an AWS VPC.

GitHub-hosted runners require additional networking arrangements
to access private AWS resources. Self-hosted runners are another
option but introduce maintenance responsibilities.

### AWS Integration

AWS-native services integrate with CloudWatch, CloudTrail,
IAM and S3. This allows the organization to manage deployment,
monitoring and auditing within AWS.

GitHub Actions remains a suitable option for teams with strong
GitHub experience or multi-cloud requirements.

However, for an AWS-only organization, I would select an
AWS-native pipeline because of IAM integration, private network
access and centralized AWS service integration.

## 10. Conclusion

This assignment demonstrated how Terraform modules can be reused
across multiple environments and how GitHub Actions can automate
deployments with production approval controls.

Testing changes in dev before production reduces deployment risk.
Separate state files and environment-scoped credentials improve
isolation.

An important lesson is that infrastructure automation should
include security, monitoring and cleanup.

Future improvements include OIDC authentication, independent
production reviewers, private networking, runtime secret retrieval
and automated alarm notifications.

## 11. Infrastructure Cleanup

After successful deployment and evidence collection, all three
environments were destroyed using Terraform.

| Environment | Resources Destroyed |
|---|---|
| Production | 10 |
| Staging | 10 |
| Dev | 10 |
| Total | 30 |

All three Terraform states were verified to be empty.

The manually created SSM parameter was deleted separately.
All assignment CloudWatch alarms were removed.

The cleanup-check.sh script was executed successfully.
Only the course workstation remained running. No unattached
EBS volumes, owned AMIs or snapshots were reported.

Pre-existing security groups from earlier labs were retained.
The existing S3 backend bucket was also retained for future labs.

Evidence:
- evidence/destroy-complete.txt
- evidence/cleanup-check.txt
