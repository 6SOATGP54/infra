#########################
###  GENERAL CONFIGS  ###
#########################

variable "cluster_name" {
  description = "The name of the Amazon EKS cluster. This is a unique identifier for your EKS cluster within the AWS region."
  default     = "eks-cluster"
}

variable "aws_region" {
  description = "AWS region where the EKS cluster will be deployed. This should be set to the region where you want your Kubernetes resources to reside."
  default     = "us-east-1"
}

variable "k8s_version" {
  description = "The version of Kubernetes to use for the EKS cluster. This version should be compatible with the AWS EKS service and other infrastructure components."
  default     = "1.30"
}

variable "auto_scale_options" {
  description = "Configuration for the EKS cluster auto-scaling. It includes the minimum (min), maximum (max), and desired (desired) number of worker nodes."
  default = {
    min     = 4
    max     = 10
    desired = 6
  }
}

variable "nodes_instances_sizes" {
  description = "A list of EC2 instance types to use for the EKS worker nodes. These instance types should balance between cost, performance, and resource requirements for your workload."
  default = [
    "t3.large"
  ]
}
