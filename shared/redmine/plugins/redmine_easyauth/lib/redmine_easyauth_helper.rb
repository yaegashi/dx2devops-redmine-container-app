# frozen_string_literal: true

module RedmineEasyauthHelper
  # Easy Auth: Extract user principal information from request headers
  # https://learn.microsoft.com/en-us/azure/app-service/configure-authentication-user-identities
  # X-MS-CLIENT-PRINCIPAL: Base64 encoded JSON object
  # X-MS-CLIENT-PRINCIPAL-NAME: User's mail address
  PRINCIPAL_HEADER = 'HTTP_X_MS_CLIENT_PRINCIPAL'.freeze
  NAME_HEADER = 'HTTP_X_MS_CLIENT_PRINCIPAL_NAME'.freeze

  def easyauth_claims
    name = ENV[NAME_HEADER] || request.headers[NAME_HEADER]
    logger.info "easyauth name: #{name.inspect}"

    principal_raw = ENV[PRINCIPAL_HEADER] || request.headers[PRINCIPAL_HEADER]
    logger.info "easyauth principal raw: #{principal_raw.inspect}"

    begin
      principal = JSON.parse(Base64.decode64(principal_raw))
      raise 'not a hash' unless principal.is_a?(Hash)
    rescue => e
      logger.error "easyauth principal decode error: #{e}"
      principal = {}
    end
    logger.info "easyauth principal decoded: #{principal.inspect}"

    claims = {}
    if principal['auth_typ'] == 'aad'
      principal.fetch('claims', []).each do |claim|
        k = claim['typ'].to_s
        v = claim['val'].to_s
        next if k.blank? || v.blank?
        claims[k] = claims.fetch(k, []) + [v]
      end
    end

    login = (claims.fetch('preferred_username', []) + [name]).first
    logger.info "easyauth login: #{login.inspect}"

    [login, name, claims]
  end
end
