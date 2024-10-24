data "aws_route53_zone" "route53_zone" {
  count        = var.use_route53_domain ? 1 : 0
  name         = var.domain_name
  private_zone = false
}

resource "aws_route53_record" "bastion_route53_record" {
  count   = var.use_route53_domain ? 1 : 0
  zone_id = data.aws_route53_zone.route53_zone[0].zone_id
  name    = "ecs_anywhere_bastion.${var.domain_name}"
  type    = "A"
  ttl     = "300"
  records = [aws_eip.bastion_eip[count.index].public_ip]
}