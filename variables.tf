variable "project_id" {
    description = "The ID of the project in which to provision resources."
    type        = string
    default     = ""
    sensitive   =  true
}

variable "region" {
    description = "The region of the project in which to provision resources."
    type        = string
    default     = "us-central1"
    sensitive   =  true
}