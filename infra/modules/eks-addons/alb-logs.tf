data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "alb_logs" {
  bucket = "${local.name}-alb-logs-${data.aws_caller_identity.current.account_id}"

  # This is an ephemeral demo bucket that gets torn down along with the rest
  # of the stack - without this, `terraform destroy` fails with
  # "BucketNotEmpty" as soon as the ALB has written any real access logs.
  force_destroy = true

  tags = {
    Name        = "${local.name}-alb-logs"
    Environment = var.environment
  }

}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowALBAccess"
        Effect = "Allow"
        Principal = {
          Service = "logdelivery.elasticloadbalancing.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })

}