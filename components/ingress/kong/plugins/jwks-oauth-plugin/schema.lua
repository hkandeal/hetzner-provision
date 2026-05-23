local typedefs = require "kong.db.schema.typedefs"
local utils = require "kong.tools.utils"
local Errors = require "kong.db.errors"
-- local az = require("kong.plugins.jwks-oauth-plugin.authorization")

return {
  name = "jwks-oauth-plugin",
  fields = {
    { consumer = typedefs.no_consumer },
    { protocols = typedefs.protocols_http },
    { config = {
        type = "record",
        fields = {
          { token_header_name = {type = "string", required = true, default = "Authorization"}, },
          { discovery = {type = "string", required = true}, },
          { auto_discover_issuer = {type = "boolean", required = false, default = false}, },
          { expected_issuers = {type = "array", required = false, elements = { type = "string" } }, },
          { accepted_audiences = {type = "array", required = false, elements = { type = "string" } }, },
          { ssl_verify = {type = "string", default = "no"}, },
          { jwk_expires_in = {type = "number", required = false, default = 7200 }, },
          { ensure_consumer_present = {type = "boolean", required = false, default = false}, },
          { consumer_claim_name = {type = "string", default = "appid"}, },
          { run_on_preflight = {type = "boolean", required = false, default = false}, },
          { upstream_jwt_header_name = {type = "string", required = true, default = "validated_jwt"}, },
          { accept_none_alg = {type = "boolean", required = false, default = false}, },
          { iat_slack = {type = "number", required = false, default = 120 }, },
          { timeout = {type = "number", required = false, default = 3000 }, },
          { anonymous = {type = "string" }, },
          { filters = { type = "string" }, },
          { enable_authorization_rules = { type = "boolean", required = true, default = false }, },
          { authorization_claim_name = { type = "string", required = true, default = "roles" }, },
          { implicit_authorize = { type = "boolean", required = true, default = false }, },
          { whitelist = { type = "array", required = false, elements = { type = "string" } }, },
          { blacklist = { type = "array", required = false, elements = { type = "string" } }, },
          { enable_scope_validation = { type = "boolean", required = true, default = false }, },
          { authorization_scope_claim_name = { type = "string", required = true, default = "scp" }, },
          { scopes = { type = "array", required = false, elements = { type = "string" } }, },
        },
      },
    },
  },
}
