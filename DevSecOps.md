Security measures

1) VPC

2) Security groups

    GuardDuty for threat detection
    AWS Config rules to detect open SGs
    SCPs in Organizations to prevent public DB
    Automated scanning via CI

3) IAM
    Limit maximum permissions a role can ever have. (Even if someone attaches AdministratorAccess,boundary prevents escalation.)
    SCPs restrict accounts at org level.(example deny deleting CloudTrail)
    Conditional Policies
    Tag-Based Access Control

4) EC2
    IMDSv2 prevents credential theft
    IAM least privilege limits damage
    Encrypted EBS protects snapshots
    CloudTrail logs API actions
    GuardDuty alerts anomalies