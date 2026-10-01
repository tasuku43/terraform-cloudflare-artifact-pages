locals {
  normalized_path = "lower(url_decode(http.request.uri.path, \"r\"))"
  host_match      = "lower(http.host) eq \"${lower(var.public_hostname)}\""

  reserved_path_exclusions = join(" and ", [
    "${local.normalized_path} ne \"/index.html\"",
    "${local.normalized_path} ne \"/preview-bridge.js\"",
    "${local.normalized_path} ne \"/license\"",
    "${local.normalized_path} ne \"/third_party_notices.txt\"",
    "${local.normalized_path} ne \"/assets\"",
    "not starts_with(${local.normalized_path}, \"/assets/\")",
    "${local.normalized_path} ne \"/_indexes\"",
    "not starts_with(${local.normalized_path}, \"/_indexes/\")",
    "${local.normalized_path} ne \"/_artifacts\"",
    "not starts_with(${local.normalized_path}, \"/_artifacts/\")",
    "${local.normalized_path} ne \"/_previews\"",
    "not starts_with(${local.normalized_path}, \"/_previews/\")",
  ])

  logical_route_rule = {
    ref         = "artifact-pages-logical-routes"
    description = "Serve the SPA shell for logical application routes."
    expression  = "(${local.host_match} and (${local.reserved_path_exclusions}))"
    action      = "rewrite"
    enabled     = true
    action_parameters = {
      uri = {
        path = {
          value = "/index.html"
        }
      }
    }
  }

  projection_cache_paths = join(" or ", [
    "${local.normalized_path} eq \"/index.html\"",
    "${local.normalized_path} eq \"/preview-bridge.js\"",
    "${local.normalized_path} eq \"/license\"",
    "${local.normalized_path} eq \"/third_party_notices.txt\"",
    "${local.normalized_path} eq \"/assets\"",
    "starts_with(${local.normalized_path}, \"/assets/\")",
    "${local.normalized_path} eq \"/_indexes\"",
    "starts_with(${local.normalized_path}, \"/_indexes/\")",
    "${local.normalized_path} eq \"/_artifacts\"",
    "starts_with(${local.normalized_path}, \"/_artifacts/\")",
    "${local.normalized_path} eq \"/_previews\"",
    "starts_with(${local.normalized_path}, \"/_previews/\")",
  ])

  origin_cache_rule = {
    ref         = "artifact-pages-respect-origin-cache-control"
    description = "Make static projection objects cache eligible while honoring origin Cache-Control."
    expression  = "(${local.host_match} and (${local.projection_cache_paths}))"
    action      = "set_cache_settings"
    enabled     = true
    action_parameters = {
      cache = true
      edge_ttl = {
        mode = "respect_origin"
      }
      browser_ttl = {
        mode = "respect_origin"
      }
    }
  }

  trusted_artifact_csp_expression = "concat(\"default-src https://\", http.host, \"/_artifacts/\", split(http.request.uri.path, \"/\", 4)[2], \"/ https: data: blob:; script-src https://\", http.host, \"/_artifacts/\", split(http.request.uri.path, \"/\", 4)[2], \"/ https: 'unsafe-inline' 'unsafe-eval' 'wasm-unsafe-eval' data: blob:; style-src https://\", http.host, \"/_artifacts/\", split(http.request.uri.path, \"/\", 4)[2], \"/ https: 'unsafe-inline' data: blob:\")"

  trusted_preview_csp_expression = "concat(\"default-src https://\", http.host, \"/_previews/\", split(http.request.uri.path, \"/\", 6)[2], \"/revisions/\", split(http.request.uri.path, \"/\", 6)[4], \"/files/ https: data: blob:; script-src https://\", http.host, \"/_previews/\", split(http.request.uri.path, \"/\", 6)[2], \"/revisions/\", split(http.request.uri.path, \"/\", 6)[4], \"/files/ https: 'unsafe-inline' 'unsafe-eval' 'wasm-unsafe-eval' data: blob:; style-src https://\", http.host, \"/_previews/\", split(http.request.uri.path, \"/\", 6)[2], \"/revisions/\", split(http.request.uri.path, \"/\", 6)[4], \"/files/ https: 'unsafe-inline' data: blob:\")"

  trusted_html_resource_policy_rules = [
    {
      ref         = "artifact-pages-trusted-artifact-html-policy"
      description = "Allow trusted production HTML to load resources from its site namespace and HTTPS origins."
      expression  = "(${local.host_match} and starts_with(${local.normalized_path}, \"/_artifacts/\"))"
      action      = "rewrite"
      enabled     = true
      action_parameters = {
        headers = {
          "Content-Security-Policy" = {
            operation  = "set"
            expression = local.trusted_artifact_csp_expression
          }
          "X-Content-Type-Options" = {
            operation = "set"
            value     = "nosniff"
          }
        }
      }
    },
    {
      ref         = "artifact-pages-trusted-preview-html-policy"
      description = "Allow trusted raw preview HTML to load resources from its revision namespace and HTTPS origins."
      expression  = "(${local.host_match} and starts_with(${local.normalized_path}, \"/_previews/\") and ${local.normalized_path} contains \"/files/\")"
      action      = "rewrite"
      enabled     = true
      action_parameters = {
        headers = {
          "Content-Security-Policy" = {
            operation  = "set"
            expression = local.trusted_preview_csp_expression
          }
          "X-Content-Type-Options" = {
            operation = "set"
            value     = "nosniff"
          }
        }
      }
    },
  ]
}

resource "cloudflare_r2_custom_domain" "public" {
  count       = var.connect_custom_domain ? 1 : 0
  account_id  = var.account_id
  bucket_name = var.bucket_name
  domain      = lower(var.public_hostname)
  enabled     = true
  zone_id     = var.zone_id
  min_tls     = var.minimum_tls_version
}

resource "cloudflare_ruleset" "logical_routes" {
  zone_id     = var.zone_id
  name        = var.transform_ruleset_name
  description = "Serve the app shell for logical routes while preserving the object-storage URL plane."
  kind        = "zone"
  phase       = "http_request_transform"

  rules = concat(var.existing_transform_rules, [local.logical_route_rule])
}

resource "cloudflare_ruleset" "origin_cache_policy" {
  zone_id     = var.zone_id
  name        = var.cache_ruleset_name
  description = "Respect Cache-Control written by the publisher for the public projection."
  kind        = "zone"
  phase       = "http_request_cache_settings"

  rules = concat(var.existing_cache_rules, [local.origin_cache_rule])
}

resource "cloudflare_ruleset" "trusted_html_resource_policy" {
  zone_id     = var.zone_id
  name        = var.response_header_ruleset_name
  description = "Apply the production HTML resource policy to production and raw preview objects."
  kind        = "zone"
  phase       = "http_response_headers_transform"

  rules = concat(var.existing_response_header_rules, local.trusted_html_resource_policy_rules)
}
