data "aws_route53_zone" "route53_parent_zone" {
  count = var.use_route53_domain ? 1 : 0
  name  = var.domain_name
}

resource "aws_route53_zone" "public_danswer_zone" {
  count   = var.use_route53_domain ? 1 : 0
  name    = "danswer.${var.domain_name}"
  comment = "Public hosted zone for danswer.${var.domain_name}"
}

resource "aws_route53_zone" "private_danswer_internal_zone" {
  count = var.use_route53_domain ? 1 : 0
  name  = "danswer-internal.danswer.${var.domain_name}"
  vpc {
    vpc_id = aws_vpc.ecs_anywhere_vpc.id
  }
  comment = "Private hosted zone for danswer-internal.${var.domain_name}"
}

resource "aws_route53_record" "danswer_ns" {
  count   = var.use_route53_domain ? 1 : 0
  zone_id = data.aws_route53_zone.route53_parent_zone[0].zone_id
  name    = "danswer"
  type    = "NS"
  ttl     = 300

  records = aws_route53_zone.public_danswer_zone[0].name_servers
}

# test A record
resource "aws_route53_record" "test_a_record" {
  count   = var.use_route53_domain ? 1 : 0
  zone_id = aws_route53_zone.private_danswer_internal_zone[0].zone_id
  name    = "test.danswer-internal.danswer.${var.domain_name}"
  type    = "A"
  ttl     = "300"
  records = ["10.0.1.9"]
}

