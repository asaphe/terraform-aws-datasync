# TODO

* AWS Datasync Agent, currently, is activated only once. (can break subsequent runs)
  >This means the agent is already activated and port 80 is refused, currently escalated to AWS support since this is happening with their AMI
* VPC Endpoint support is not available via the Terraform provider (need to learn GO and open a PR to upstream repo)
* Limit SG even further, depends on VPC Endpoint support
* Consider: ASG or EC2 Fleet for the instance to ensure HA
