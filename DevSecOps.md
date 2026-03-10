Security measures

1) VPC

2) Security groups
    GuardDuty for threat detection
    AWS Config rules to detect open SGs
    SCPs in Organizations to prevent public DB
    Automated scanning via CI
    CloudFront protections :
       AWS Shield
       Rate limiting
       Bot control
       Geo blocking
    WAF rules :
       AWSManagedRulesCommonRuleSet
       AWSManagedRulesSQLiRuleSet
       AWSManagedRulesAmazonIpReputationList
    Kubernetes protections :
       NetworkPolicy
       PodSecurityStandards
       mTLS (Istio or Linkerd)

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

5) EKS
        KMS -> IAM controls Decryption
            -> CloudTrail Logs every Decrypt
            -> If KMS is disabled or deleted cluster cannot decrypt -> pods cannot access secret
            -> Restrict KMS key to specific resource
   EKS in private subnets
   Nodes in private subnets
   No public IP
   NAT Gateway for outbound
   VPC endpoints for
        -> ECR
        -> S3
        -> STS
        -> CloudWatch
        -> SSM
   This removes public internet dependency

6) S3
   Bucket Policy Deny Insecure Transport
   Deny Unencrypted Uploads
   Least Privilege IAM (No s3:* permissions.)
   Enable CloudTrail Data Events for S3 (Compliance)
   Enable AWS Config Rule (public read prohibited and server side encryption)
   Enable GuardDuty(Anomalous S3 access)

7) Transit Gateway
   Central Inspection Pattern (security vpc + firewall like palo alto -> force all traffics between vpcs to pass through it )