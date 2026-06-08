########################################################
# CloudFront関連リソース
########################################################

locals {
  ## CloudFrontログ用バケットポリシー生成
  bucket_policy_cloudfront_log = templatefile(
    "${path.module}/s3_bucket_policy/common.json", {
      s3_bucket_name = module.s3_bucket_for_cloudfront_log.s3_bucket_name
  })

  ## WAFログ用バケットポリシー生成
  bucket_policy_waf_log = templatefile(
    "${path.module}/s3_bucket_policy/common.json", {
      s3_bucket_name = module.s3_bucket_for_waf_log.s3_bucket_name
  })

  ## コンテンツ用バケットポリシー生成
  bucket_policy_static_website = templatefile(
    "${path.module}/s3_bucket_policy/common.json", {
      s3_bucket_name = module.s3_bucket_static_website.s3_bucket_name
  })
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

########################################################
# CloudFrontログ用S3バケット
########################################################
module "s3_bucket_for_cloudfront_log" {
  source = "../../../modules/S3"

  name_prefix             = var.name_prefix
  env                     = var.env
  s3_bucket_name_interfix = "cloudfront-access-log"
  type                    = "cloudfront_log"
  transition_in_days      = 180
  expiration_in_days      = 365
  policy                  = local.bucket_policy_cloudfront_log
}

########################################################
# WAFログ用S3バケット
########################################################
module "s3_bucket_for_waf_log" {
  source = "../../../modules/S3"

  type                    = "waf_log"
  name_prefix             = var.name_prefix
  env                     = var.env
  s3_bucket_name_interfix = ""
  transition_in_days      = 180
  expiration_in_days      = 365
  policy                  = local.bucket_policy_waf_log
}

########################################################
# コンテンツ用S3バケット
# index.html / error-pages/404.html を格納
########################################################
module "s3_bucket_static_website" {
  source = "../../../modules/S3"

  name_prefix             = var.name_prefix
  env                     = var.env
  s3_bucket_name_interfix = "static-website"
  type                    = "cloudfront_log"
  transition_in_days      = 180
  expiration_in_days      = 365
  policy                  = local.bucket_policy_static_website
}

########################################################
# CloudFront
########################################################
module "cloudfront" {
  source = "../../../modules/CloudFront"

  acm_arn                    = module.acm.acm_certificate_arn
  alternate_domain_names     = var.alternate_domain_names
  cloudfront_log_bucket_name = module.s3_bucket_for_cloudfront_log.s3_bucket_name
  env                        = var.env
  name_prefix                = var.name_prefix

  origins = [
    {
      domain              = var.origin_domain
      name                = "${var.name_prefix}-${var.env}-origin"
      type                = "reverse_proxy"
      custom_header_name  = "X-Origin-Verify"
      custom_header_value = var.custom_header_value
    }
  ]

  web_acl_arn = module.waf_for_cloudfront.wafv2_arn

  default_behavior = {
    target_origin_id = "${var.name_prefix}-${var.env}-origin"
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods   = ["GET", "HEAD"]
    cache_policy_id  = data.aws_cloudfront_cache_policy.caching_disabled.id
    compress         = true
  }

  ordered_behaviors = [
    # パターン1: /s3/*
    {
      path_pattern     = "/s3/*"
      target_origin_id = "${var.name_prefix}-${var.env}-origin"
      allowed_methods  = ["GET", "HEAD"]
      cached_methods   = ["GET", "HEAD"]
      cache_policy_id  = data.aws_cloudfront_cache_policy.caching_optimized.id
      compress         = true
    }
  ]

  query_strings = var.domain_cloudfront

  depends_on = [
    module.waf_for_cloudfront,
    module.s3_bucket_for_cloudfront_log
  ]
}

########################################################
# ACM
########################################################
module "acm" {
  source = "../../../modules/ACM"

  name_prefix       = var.name_prefix
  env               = var.env
  certificate_body  = file("${path.module}/cert/certificate.crt")
  private_key       = file("${path.module}/cert/private.key")
  certificate_chain = file("${path.module}/cert/certificate-chain.pem")

  providers = {
    aws = aws.virginia
  }
}

########################################################
# WAF（CloudFront用）
########################################################
module "waf_for_cloudfront" {
  source = "../../../modules/WAF"

  name_prefix                    = "${var.name_prefix}-cloudfront"
  env                            = var.env
  log_destination_s3_bucket_name = module.s3_bucket_for_waf_log.s3_bucket_name
  scope                          = "CLOUDFRONT"
  default_action                 = "block"
  enable_ip_whitelist_rule       = true
  enable_geo_blocking_rule       = true
  ip_white_list                  = yamldecode(
    file("${path.module}/waf_config/IPWhiteList-DeloitteNW.yml")
  )

  providers = {
    aws = aws.virginia
  }

  depends_on = [module.s3_bucket_for_waf_log]
}