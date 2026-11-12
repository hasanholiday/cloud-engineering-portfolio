variable "region" {
  type    = string
  default = "us-east-1"
}
variable "env" {
  type    = string
  default = "dev"
}
variable "ecr_repo_url" {
  type        = string
  description = "ECR repo URL created by bootstrap.sh"
}
variable "image_tag" {
  type        = string
  description = "Docker image tag to run. The pipeline passes the git SHA."
}
variable "instance_type" {
  type    = string
  default = "t3.micro"
}
variable "min_size" {
  type    = number
  default = 2
}
variable "max_size" {
  type    = number
  default = 4
}
