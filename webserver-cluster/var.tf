variable "ami" {
    description = "ubuntu server."
    default     = "ami-0d382e80be7ffdae5"
}

variable "server_port" {
    description = "HTTP Port"
    default     = "80"
    type        = number
}

variable "cluster_name" {
  description = "The name to use for all cluster resources"
  type = string
}

variable "db_remote_state_bucket" {
  description = "The name of the S3 bucket."
  type = string
}

variable "db_remote_state_key" {
  description = "The path for the database remote's state in S3."
  type = string
}

variable "db_remote_state_region" {
  description = "region where db resides."
  type = string
}

variable "instance_type" {
  description = "the type of ec2 instances to run e.g t2.micro."
  type = string
}

variable "min_size" {
  description = "The minimum number of EC2 instacnes in the ASG."
  type = number
}

variable "max_size" {
  description = "The maximum number of EC2 instances in the ASG"
  type = number
}

variable "custom_tags" {
    description = "custom tags to set on the instances in the ASG"
    type = map(string)
    default = {}
}

variable "enable_autoscaling" {
  description = "allow servers to scale horizontally in or out"
  type = bool
}

