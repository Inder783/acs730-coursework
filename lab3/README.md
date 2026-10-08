# Lab 3
Instructions for this section will be provided in class and on Blackboard when we reach it.
Put your work for Lab 3 in this folder.


# Lab 3

In a real AWS account, OIDC is preferred because GitHub Actions can obtain temporary AWS credentials without storing access keys in GitHub Secrets.

AWS Academy does not allow the IAM changes required for OIDC, so this lab uses session-scoped credentials stored in GitHub Secrets, which expire when the lab session ends and limit the time an attacker could use leaked credentials.
