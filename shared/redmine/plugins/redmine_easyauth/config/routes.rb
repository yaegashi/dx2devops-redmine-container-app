match 'auth/failure', controller: :easyauth, action: :easyauth_failure, via: %i[get post]
match 'auth/easyauth/login', controller: :easyauth, action: :easyauth_login, via: [:get], as: :easyauth_signin
