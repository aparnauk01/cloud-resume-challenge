resource "aws_s3_bucket" "example" {
  bucket = "aparnauk.com"
}

resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.example.bucket

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.example.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "example" {
  bucket = aws_s3_bucket.example.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_object" "example1" {
  depends_on   = [aws_s3_bucket.example]
  key          = "index.html"
  bucket       = aws_s3_bucket.example.id
  source       = "index.html"
  content_type = "text/html"
  etag         = filemd5("index.html")
}

resource "aws_s3_bucket_object" "imagesfolder" {
  depends_on   = [aws_s3_bucket.example]
  for_each     = fileset("${path.module}", "images/*")
  bucket       = aws_s3_bucket.example.id
  key          = each.value
  source       = each.value
  content_type = "image/jpeg"
  etag         = filemd5("${each.value}")
}

module "template_files" {
  source   = "hashicorp/dir/template"
  base_dir = "${path.module}/assets"
}

resource "aws_s3_bucket_object" "static_files" {
  depends_on   = [aws_s3_bucket.example]
  for_each     = module.template_files.files
  bucket       = aws_s3_bucket.example.bucket
  key          = "assets/${each.key}"
  content_type = each.value.content_type
  source       = each.value.source_path
  content      = each.value.content
  etag         = filemd5("assets/${each.key}")
}

resource "aws_cloudfront_origin_access_control" "example" {
  name                              = "security_pillar_s3_ac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "example" {
  depends_on = [aws_s3_bucket.example,
  aws_cloudfront_origin_access_control.example]
  enabled             = true
  default_root_object = "index.html"
  web_acl_id          = aws_wafv2_web_acl.geo_filtering.arn
  aliases             = [var.root_domain_name]
  default_cache_behavior {
    target_origin_id       = aws_s3_bucket.example.bucket_regional_domain_name
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }
  origin {
    domain_name              = aws_s3_bucket.example.bucket_regional_domain_name
    origin_id                = aws_s3_bucket.example.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.example.id
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.domain_cert.arn
    ssl_support_method  = "sni-only"
  }
}


resource "aws_wafv2_rule_group" "geo_filter" {

  capacity = 10
  name     = "geo-filter"
  scope    = "CLOUDFRONT"

  rule {
    name     = "rule-1"
    priority = 1

    action {
      count {}
    }

    statement {
      geo_match_statement {
        country_codes = ["AF"]
      }
    }


    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "friendly-rule-metric-name"
      sampled_requests_enabled   = false
    }
  }
  tags = {
    Tag1 = "Value1"
    Tag2 = "Value2"
  }

  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = "friendly-metric-name"
    sampled_requests_enabled   = false
  }
}


resource "aws_wafv2_web_acl" "geo_filtering" {
  name  = "geo-filtering"
  scope = "CLOUDFRONT"

  default_action {
    block {}
  }

  rule {
    name     = "rule-1"
    priority = 1

    override_action {
      count {}
    }

    statement {
      rule_group_reference_statement {
        arn = aws_wafv2_rule_group.geo_filter.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "friendly-rule-metric-name"
      sampled_requests_enabled   = false
    }
  }

  tags = {
    Tag1 = "Value1"
    Tag2 = "Value2"
  }

  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = "friendly-metric-name"
    sampled_requests_enabled   = false
  }
}


resource "aws_s3_bucket_policy" "example" {
  depends_on = [data.aws_iam_policy_document.example]
  bucket     = aws_s3_bucket.example.id
  policy     = data.aws_iam_policy_document.example.json
}

data "aws_iam_policy_document" "example" {
  depends_on = [
    aws_cloudfront_distribution.example,
    aws_s3_bucket.example
  ]
  statement {
    sid    = "bucketpolicy"
    effect = "Allow"
    actions = [
      "s3:GetObject"
    ]
    principals {
      identifiers = ["cloudfront.amazonaws.com"]
      type        = "Service"

    }
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.example.bucket}/**"
    ]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.example.arn]
    }
  }
}

variable "root_domain_name" {
  type    = string
  default = "aparnauk.com"
}

data "aws_route53_zone" "selected" {
  name         = "aparnauk.com"
  private_zone = false
}

resource "aws_acm_certificate" "domain_cert" {
  domain_name       = var.root_domain_name
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "example" {
  for_each = {
    for dvo in aws_acm_certificate.domain_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.selected.zone_id
}

resource "aws_acm_certificate_validation" "example" {
  certificate_arn         = aws_acm_certificate.domain_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.example : record.fqdn]
}
