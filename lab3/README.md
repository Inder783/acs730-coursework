# Lab 3
Instructions for this section will be provided in class and on Blackboard when we reach it.
Put your work for Lab 3 in this folder.


# Lab 3

In a real AWS account, OIDC is preferred because GitHub Actions can obtain temporary AWS credentials without storing access keys in GitHub Secrets.

AWS Academy does not allow the IAM changes required for OIDC, so this lab uses session-scoped credentials stored in GitHub Secrets, which expire when the lab session ends and limit the time an attacker could use leaked credentials.


## Troubleshooting

### ExpiredToken

This error occurs when the AWS Academy session credentials expire.
Start a new AWS Academy lab session, run
`./scripts/refresh-gha-creds.sh Inder783/acs730-coursework`
to update the GitHub Secrets, and rerun the failed workflow.
No repository changes are required.

### Input required and not supplied: aws-region

This error occurs when the AWS_REGION GitHub Actions variable
is missing. Run the credential refresh script or set the
variable using:

`gh variable set AWS_REGION --body us-east-1`

## Terraform Version

Terraform version used: 1.16.5

## Experiments
