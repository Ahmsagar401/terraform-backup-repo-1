variable "region" {
   type = string
   default = "ap-south-1"
}
   
variable "s3_buckets" {
   type = list
   default = ["test-bucket1-0103", "test-bucket2-0103", "test-bucket3-0103"]
}
