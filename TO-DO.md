# TO-DO

* AWS Datasync Agent, currently, is activated only once. (can break subsequent runs)
* VPC Endpoint support is not available via the Terraform provider (need to learn GO and open a PR to upstream repo)
* Limit SG even further, depends on VPC Endpoint support
* Consider: ASG or EC2 Fleet for the instance to ensure HA
