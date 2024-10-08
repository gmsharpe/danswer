resource "aws_eip" "bastion" {
  count    = var.use_route53_domain ? 1 : 0
  instance = aws_instance.bastion_host.id
}

data "aws_route53_zone" "route53_zone" {
  count        = var.use_route53_domain ? 1 : 0
  name         = var.domain_name
  private_zone = false
}
resource "aws_route53_record" "bastion_route53_record" {
  count   = var.use_route53_domain ? 1 : 0
  zone_id = data.aws_route53_zone.route53_zone[0].zone_id
  name    = "nomad-bastion.${var.domain_name}"
  type    = "A"
  ttl     = "300"
  records = [aws_eip.bastion[count.index].public_ip]
}
variable "domain_name" {
  // this is my domain name, you should change it to your own domain name
  default = "edumore.io"
}
variable "use_route53_domain" {
  description = "Flag to indicate whether Route 53 domain related resources should be created"
  type        = bool
  default     = false
}