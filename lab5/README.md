
# ACS730 Lab 5 — Terraform Infrastructure and GitHub Actions CI

## 1. Introduction

This lab demonstrates how to create AWS infrastructure using Terraform and test it automatically using GitHub Actions and LocalStack.

Terraform is an Infrastructure as Code (IaC) tool that allows cloud resources to be defined in configuration files instead of creating them manually.

LocalStack simulates AWS services locally, allowing Terraform configurations to be tested without deploying resources to a real AWS account.

The main objectives of this lab were to:

- Create reusable Terraform infrastructure using variables.
- Use `for_each`, `count`, `dynamic`, and `depends_on`.
- Configure Terraform to support LocalStack and real AWS.
- Deploy and destroy simulated AWS infrastructure.
- Create a GitHub Actions CI workflow.
- Demonstrate how branch protection prevents invalid code from being merged.
- Perform two Terraform experiments and document the results.

## 2. Infrastructure Architecture

The Terraform configuration defines the following infrastructure:

| Resource | Configuration |
|----------|---------------|
| VPC | 10.42.0.0/16 |
| Public Subnets | Two subnets |
| Internet Gateway | One |
| Route Table | One public route table |
| Route Table Associations | Two |
| Security Group | Dynamic inbound rules |
| EC2 Instance | Web server using user data |
| S3 Bucket | Optional, controlled by a variable |

The VPC provides the network for the infrastructure. The two public subnets are created using `for_each`.

The Internet Gateway and route table provide the routing configuration for public internet access.

The security group controls inbound traffic, while the EC2 instance uses a user-data script to configure a web server.

An optional S3 bucket is included to demonstrate conditional resource creation using `count`.

## 3. Terraform Files

The `lab5` directory contains the following main files:

| File | Purpose |
|------|---------|
| `versions.tf` | Defines Terraform and provider requirements |
| `variables.tf` | Declares configurable input variables |
| `providers.tf` | Configures AWS or LocalStack connectivity |
| `network.tf` | Creates the VPC, subnets, routing, and security group |
| `compute.tf` | Defines the EC2 instance and optional S3 bucket |
| `outputs.tf` | Displays infrastructure information |
| `localstack.tfvars` | Provides variables for LocalStack testing |

Separating the configuration into multiple files makes it easier to understand, maintain, and troubleshoot.

## 4. Terraform Design Decisions

### 4.1 Using for_each Instead of count

I used `for_each` to create the two public subnets.

Each subnet has a unique key, such as `a` or `b`.

Terraform identifies these resources using stable addresses, such as:

`aws_subnet.public["a"]`

`aws_subnet.public["b"]`

This is useful because adding or removing another subnet does not automatically change the addresses of the existing subnets.

In comparison, `count` uses numeric indexes such as `[0]` and `[1]`. Changes to an ordered list can shift these indexes and cause unnecessary resource changes.

Therefore, `for_each` was selected for the subnets because each subnet has its own identity.

### 4.2 Using count for the Optional S3 Bucket

The S3 bucket uses the following expression:

```hcl
count = var.create_artifact_bucket ? 1 : 0
```

When `create_artifact_bucket` is `true`, Terraform creates one S3 bucket.

When it is `false`, Terraform creates no S3 bucket.

This is a simple way to make an individual resource optional.

### 4.3 Dynamic Security Group Rules

The security group uses a `dynamic "ingress"` block.

Instead of manually writing separate inbound rule blocks for every port, Terraform generates the rules using the `ingress_rules` variable.

This makes the configuration easier to reuse and modify.

### 4.4 Explicit Dependencies

The EC2 resource includes:

```hcl
depends_on = [aws_route_table_association.public]
```

This tells Terraform to wait for the public route table associations before creating the EC2 instance.

Terraform automatically identifies many dependencies through resource references. However, `depends_on` is useful when an additional dependency needs to be specified explicitly.

### 4.5 Switching Between LocalStack and AWS

The Terraform configuration supports a variable named `use_localstack`.

When this variable is enabled, the AWS provider is configured to communicate with LocalStack at:

`http://localhost:4566`

This allows the infrastructure configuration to be tested against simulated AWS services.

The real AWS deployment path was not used during this lab.

## 5. Why LocalStack Was Used in CI

LocalStack was selected because running Terraform against real AWS for every pull request could introduce unnecessary costs and additional risks.

Real AWS testing would require credentials and sufficient IAM permissions.

AWS Academy credentials may expire, and cloud resources can continue generating charges if they are not removed.

Real AWS tests may also be affected by service quotas and API availability.

LocalStack provides a more controlled environment for testing Terraform planning, resource creation, and cleanup.

However, LocalStack does not perfectly reproduce all AWS features. Successful LocalStack testing does not guarantee identical behavior in real AWS.

## 6. LocalStack Deployment Results

The Terraform configuration was successfully tested using LocalStack 3.8.

The deployment was performed using Terraform plan and apply.

Terraform reported:

`Apply complete! Resources: 10 added, 0 changed, 0 destroyed.`

The resulting outputs included:

| Output | Value |
|--------|-------|
| VPC ID | vpc-a9b4a56b |
| Public Subnet A | subnet-417ac30c |
| Public Subnet B | subnet-e5002a9b |
| Artifact Bucket | acs730-lab5-isingh210-artifacts |
| Provider Target | localstack (http://localhost:4566) |

The public IP address and web URL returned by LocalStack were simulated values, not proof of a publicly reachable AWS web server.

After testing, Terraform destroy completed successfully:

`Destroy complete! Resources: 10 destroyed.`

The VPC list was checked after destruction. The Lab 5 VPC was no longer present, and only LocalStack's default VPC remained.

## 7. Experiment 1 — Removing depends_on

### Objective

To understand whether the explicit `depends_on` statement is required for Terraform configuration validation.

### Prediction

Removing `depends_on` from the EC2 instance should not cause Terraform validation to fail.

Terraform can still identify dependencies on the subnet and security group through resource references.

However, removing the explicit dependency would mean Terraform no longer has a direct dependency requiring the route table associations to finish first.

### Procedure

1. Created a backup of `compute.tf`.
2. Temporarily removed the `depends_on` statement.
3. Executed `terraform fmt -recursive`.
4. Executed `terraform validate`.
5. Restored the original `compute.tf` file.
6. Executed Terraform validation again.
7. Verified that `depends_on` was restored.

### Actual Observation

Without `depends_on`, Terraform returned:

`Success! The configuration is valid.`

After restoring `depends_on`, Terraform again returned:

`Success! The configuration is valid.`

The restored file was checked using `grep`, which confirmed:

```hcl
depends_on = [aws_route_table_association.public]
```

### Conclusion

The experiment confirmed that an explicit `depends_on` statement is not necessary for the configuration to pass validation.

However, this experiment did not measure the actual resource creation order.

The original dependency was restored to maintain the intended deployment sequence.

## 8. Experiment 2 — Disabling the Optional S3 Bucket

### Objective

To test how Terraform's conditional `count` controls whether an S3 bucket is included in an infrastructure plan.

### Prediction

When `create_artifact_bucket = false`, Terraform should not plan an S3 bucket.

When `create_artifact_bucket = true`, Terraform should plan one additional S3 bucket.

### Procedure

1. Verified that the original `localstack.tfvars` file contained `create_artifact_bucket = true`.
2. Created a temporary copy of the variables file.
3. Changed the temporary configuration to `create_artifact_bucket = false`.
4. Started LocalStack.
5. Ran Terraform plan using the temporary configuration.
6. Ran Terraform plan again using the original configuration.
7. Compared the results.

### Actual Observation

| Test | Setting | Resources to Add | S3 Bucket |
|------|---------|------------------|-----------|
| Test 1 | false | 9 | Not planned |
| Test 2 | true | 10 | Planned |

With the bucket disabled, Terraform reported:

`Plan: 9 to add, 0 to change, 0 to destroy.`

The plan did not contain an S3 bucket resource.

With the bucket enabled, Terraform reported:

`Plan: 10 to add, 0 to change, 0 to destroy.`

The plan also showed:

```text
# aws_s3_bucket.artifacts[0] will be created
```

The S3 bucket output was:

`acs730-lab5-isingh210-artifacts`

### Conclusion

The experiment confirmed that Terraform's conditional `count` works as expected.

Disabling the bucket reduced the planned resource count from 10 to 9.

Both experiments used Terraform plan only; no additional infrastructure was applied during these comparisons.

## 9. GitHub Actions CI Workflow

The GitHub Actions workflow is located at:

`.github/workflows/lab5-ci.yml`

The workflow contains two main jobs.

### Job 1 — gates

This job checks the Terraform configuration before deployment testing.

It performs formatting checks, Terraform initialization, and validation.

If validation fails, the next job is not allowed to run.

### Job 2 — localstack

This job starts LocalStack and tests the infrastructure.

It performs Terraform initialization, planning, applying, and destroying the simulated resources.

The workflow uses:

```yaml
needs: gates
```

This ensures that the LocalStack job only runs after the validation job succeeds.

No real AWS credentials are required for the LocalStack tests.

## 10. CI Failure and Recovery Demonstration

To test the CI pipeline, I deliberately introduced an error in `network.tf`.

I changed:

`var.vpc_cidr`

to:

`var.vpc_cdir`

Because `vpc_cdir` was not a declared variable, Terraform validation failed.

The GitHub Actions workflow detected the error.

The `fmt and validate` job failed, and the LocalStack job was skipped.

I also configured `fmt and validate` as a required status check for the `main` branch.

GitHub blocked the pull request from merging while the required check was failing.

After restoring the correct variable name, Terraform validation succeeded.

The corrected code was committed and pushed to the `lab5` branch.

### CI Run Results

| Run | Status | Duration |
|-----|--------|----------|
| Initial workflow | Success | 2m 03s |
| Deliberately broken Terraform | Failure | 16s |
| Corrected Terraform | Success | 2m 11s |

The final successful run confirmed that both the validation and LocalStack jobs passed.

### Conclusion

This demonstrated that GitHub Actions can automatically detect Terraform errors and that branch protection can prevent invalid infrastructure code from being merged into `main`.

## 11. Evidence Files

The `evidence` directory contains:

| File | Description |
|------|-------------|
| `terraform-outputs.txt` | Outputs from the successful LocalStack deployment |
| `describe-vpcs-after-destroy.json` | Verification of VPC cleanup |
| `ci-runs.txt` | GitHub Actions success and failure history |
| `required-check-blocked.png` | Screenshot showing the failed required check and blocked merge |
| `experiment-bucket-disabled.txt` | Terraform plan with the optional S3 bucket disabled |
| `experiment-bucket-enabled.txt` | Terraform plan with the optional S3 bucket enabled |

These files document the Terraform deployment, experiments, CI validation, and branch protection behavior.

## 12. Cleanup

After the initial infrastructure test, Terraform successfully destroyed all 10 simulated resources.

The optional S3 bucket experiment used Terraform plans only and did not create additional infrastructure.

The temporary LocalStack container was removed after testing.

No real AWS resources were deployed by the Lab 5 Terraform configuration.

## 13. Final Summary

This lab provided practical experience with Terraform, Infrastructure as Code, LocalStack, GitHub Actions, and branch protection.

I learned how to create reusable infrastructure using variables, `for_each`, `count`, dynamic blocks, and explicit dependencies.

The two experiments demonstrated how Terraform handles dependency validation and optional resources.

The CI failure demonstration showed how automated validation and required status checks can protect the main branch from incorrect infrastructure changes.

Overall, the lab demonstrated a repeatable approach to developing, testing, and validating Terraform infrastructure before merging code.
