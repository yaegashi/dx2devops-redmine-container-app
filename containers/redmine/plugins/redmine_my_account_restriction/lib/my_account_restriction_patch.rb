module MyAccountRestrictionPatch
  USER_PARAMS_TO_DELETE = [:firstname, :lastname, :mail].freeze
  PREF_PARAMS_TO_DELETE = [:hide_mail].freeze

  def self.included(base)
    base.send :include, InstanceMethods
    base.class_eval do
      unloadable
      before_action :restrict_parameters, only: :account
    end
  end

  module InstanceMethods
    private
    def restrict_parameters
      if request.put?
        USER_PARAMS_TO_DELETE.each { |k| params[:user]&.delete(k) }
        PREF_PARAMS_TO_DELETE.each { |k| params[:pref]&.delete(k) }
      end
    end
  end
end
