local az = require("kong.plugins.jwks-oauth-plugin.authorization")
local utils = require("kong.plugins.oidc.utils")

local _M = {

}
local function trim(s)
    return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

local function trimAndUpper(input)
    if input ~= nil then
        return string.upper(trim(input))
    else
        return ""
    end
end

local function verify_scopes(conf, claims)
    local authorized = false
    if claims ~= nil then
        print("Condetion verified")
        for iuc, uc in ipairs(claims) do
            print("claims :", uc)
            for ic, c in ipairs(conf.scopes) do
                print("Config Scopes: ", trimAndUpper(c))
                if trimAndUpper(c) == uc then
                    authorized = true
                    print("Authurized value: ", authorized)
                    break
                end
            end
            if authorized then
                break
            end
        end
    end
    print("Final Authurized value: ", authorized)
    if not authorized then
        local err = "Access denied!. Invalid Scopes: "
        ngx.log(ngx.DEBUG, "JwksAwareJwtAccessTokenHandler - " .. err)
        utils.exit(ngx.HTTP_UNAUTHORIZED, "Access denied!, Invalid Scopes", ngx.HTTP_UNAUTHORIZED)
    end
end

function _M.validate_scopes(conf, json)
    local raw_claims = json[conf.authorization_scope_claim_name]
    print("Validating scopes")
    local claims = {}
    if type(raw_claims) == "string" then
        claims[1] = trimAndUpper(raw_claims)
    elseif type(raw_claims) == "array" or type(raw_claims) == "table" then
        claims = raw_claims
        for i, c in pairs(raw_claims) do
            claims[i] = trimAndUpper(c)
        end
    end
    verify_scopes(conf, claims)
end

return _M
