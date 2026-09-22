# Lab 1

## create-instance.sh
This script launches an Amazon Linux EC2 instance using the latest Amazon Linux 2023 AMI. It creates a t3.micro instance and attaches the LabInstanceProfile IAM role. The instance is also given the name tag acs730-week1 so it can be identified later.

## create-security-group.sh
This script creates a security group for the Lab 1 EC2 instance. It checks the current public IP address and allows SSH access only from that IP address using port 22. This follows the principle of least privilege instead of allowing SSH access from anywhere.

## delete-instance.sh
This script finds EC2 instances with the acs730-week1 name tag that are pending, running, or stopped. It then terminates those instances. If no matching instances are found, it displays a message saying there is nothing to delete.

## delete-security-group.sh
This script deletes the acs730-week1 security group that was created for the lab. It then displays a confirmation message showing that the security group was deleted.
Instructions for this section will be provided in class and on Blackboard when we reach it.


