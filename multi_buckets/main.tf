provider "aws" {
    region = var.region

}

resource "aws_s3_bucket" "new_demo" {
    count = length(var.s3_buckets)
    bucket = var.s3_buckets[count.index]
}

output "aws_s3_bucket" {
    value = aws_s3_bucket.new_demo.*.bucket
    description = "All the created buckets"
}
