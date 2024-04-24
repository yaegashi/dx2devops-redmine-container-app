class EasyauthController < AccountController
  include RedmineEasyauthHelper

  def easyauth_failure
    flash['error'] = "#{l('easyauth.error.authentication_failed')}: #{params[:message]}"
    redirect_to signin_path
  end

  def easyauth_login
    unless settings['enabled']
      flash['error'] = l('easyauth.error.disabled')
      redirect_to signin_path
      return
    end

    login, name, claims = easyauth_claims
    if login.blank? or name.blank?
      logger.info 'easyauth unavailable'
      flash['error'] = l('easyauth.error.authentication_unavailable')
      redirect_to signin_path
      return
    end

    oid1 = claims.fetch('groups', [])
    oid2 = claims.fetch('oid', [])
    oid3 = claims.fetch('http://schemas.microsoft.com/identity/claims/objectidentifier', [])
    claim_groups = (oid1 + oid2 + oid3).map(&:strip).map(&:downcase).reject(&:blank?).uniq
    logger.info "easyauth claim groups: #{claim_groups.inspect}"

    allowed_groups = settings['allowed_principal_list'].to_s.split(',').map(&:strip).map(&:downcase).reject(&:blank?).uniq
    logger.info "easyauth allowed groups: #{allowed_groups.inspect}"

    if allowed_groups.any? && (allowed_groups & claim_groups).empty?
      logger.info 'easyauth disallowed'
      flash['error'] = l('easyauth.error.authentication_disallowed')
      redirect_to signin_path
      return
    end

    user = User.joins(:email_addresses)
               .where('email_addresses.address' => name, 'email_addresses.is_default' => true)
               .first_or_initialize

    if user.new_record?
      unless settings['auto_registration']
        logger.info 'easyauth auto registration disabled'
        flash['error'] = l('easyauth.error.auto_registration_disabled')
        redirect_to signin_path
        return
      end
      user.login = (claims.fetch('preferred_username', []) + [name]).first
      user.mail = name
      user.firstname = (claims.fetch('name', []) + [name]).first
      user.lastname =  easyauth_mail_org_translate(name) || EASYAUTH_MAIL_ORG_RULE_DEFAULT
      user.admin = false
      user.register
      user.activate
      user.last_login_on = Time.now
      if user.save
        self.logged_user = user
        flash[:notice] = l(:notice_account_activated)
        redirect_to my_account_path
        return
      end
      logger.info 'easyauth auto registration failed'
      flash['error'] = l('easyauth.error.auto_registration_failed')
      redirect_to signin_path
      return
    end

    if user.active?
      successful_authentication(user)
      return
    end

    account_pending(user)
  end

  def settings
    @settings ||= Setting.plugin_redmine_easyauth
  end
end
