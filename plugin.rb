# frozen_string_literal: true

# name: discourse-local-site-contacts
# about: Allows the 'site contact username' to be customized on a per-locale basis
# version: 1.0
# authors: Discourse Team
# url: https://github.com/discourse/discourse-local-site-contacts
# transpile_js: true

enabled_site_setting :local_site_contacts_enabled

module ::LocalSiteContacts
  class JsonSchemaSiteSetting
    def self.schema
      @schema ||= {
        "title": "Localised Links",
        "type": "array",
        "items": {
          "type": "object",
          "title": "Local Site Contact",
          "properties": {
            "locale": {
              "type": "string",
              "default": "en"
            },
            "username": {
              "type": "string",
              "default": "system"
            }
          }
        }
      }
    end
  end

  class InvalidSettingError < StandardError; end

  def self.for_locale(locale)
    options = JSON.parse(SiteSetting.local_site_contacts)
    raise InvalidSettingError if !options.is_a?(Array)
    raise InvalidSettingError if !options.all? { |o| o.is_a?(Hash) }

    current_item = options.find { |o| o["locale"] == locale.to_s }

    if current_item
      user = User.find_by_username(current_item["username"])
      if user && user.staff?
        return user
      elsif user
        Rails.logger.error("local_site_contact user for #{locale} is not a staff member: #{current_item["username"]}")
      else
        Rails.logger.error("Unable to find local_site_contacts user for #{locale}: #{current_item["username"]}")
      end
    end

    Discourse.site_contact_user
  rescue JSON::ParserError, InvalidSettingError
    Rails.logger.error("Unable to parse local_site_contacts: #{SiteSetting.local_site_contacts}")
    Discourse.site_contact_user
  end
end

after_initialize do
  on(:before_system_message_sent) do |message_type:, recipient:, post_creator_args:, params:|
    if SiteSetting.local_site_contacts_enabled? && !params[:from_system]
      locale = recipient.effective_locale
      post_creator_args[0] = LocalSiteContacts.for_locale(locale)
    end
  end
end
