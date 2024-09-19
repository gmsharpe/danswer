
locals { }

resource "nomad_job" "danswer_web" {
  jobspec = file("${path.module}/danswer_web.nomad.hcl")
 # depends_on = [vault_kv_secret_v2.danswer_vault]
}

resource "nomad_job" "danswer_other" {
  jobspec = file("${path.module}/danswer.nomad.hcl")
}

resource "nomad_namespace" "danswer" {
  name = "danswer"
  #meta = local.namespace_meta
}


resource "vault_kv_secret_v2" "danswer_vault" {
  mount     = "secret"
  name      = "danswer"
  data_json      = jsonencode(local.namespace_meta)

}

resource "vault_policy" "danswer_policy" {
  name   = "danswer-policy"
  policy = <<EOF
path "secret/data/danswer" {
  capabilities = ["read"]
}
EOF
}

# resource "nomad_acl_policy" "danswer_namespace_read" {
#   name        = "danswer-namespace-read"
#   rules_hcl = <<EOR
# namespace "danswer" {
#   variables {
#     policy = "read"
#   }
# }
# EOR
#   description = "Allows jobs in the danswer namespace to read namespace metadata"
  
# }

# # resource "nomad_acl_token" "danswer_job_token" {
# #   name     = "danswer-job-token"
# #   type     = "client"
# #   policies = [nomad_acl_policy.danswer_namespace_read.name]
# # }

# # resource "nomad_acl_role" "danswer_namespace_role" {
# #   name = "danswer-namespace-role"
# #   policy {
# #     name = nomad_acl_policy.danswer_namespace_read.name
# #   }
# # }