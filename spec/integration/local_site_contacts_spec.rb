# frozen_string_literal: true

describe "discourse-local-site-contacts" do
  let(:en_contact) { Fabricate(:admin) }
  let(:fr_contact) { Fabricate(:admin) }
  let(:recipient) { Fabricate(:user) }

  def system_message_sender
    system_message = SystemMessage.new(recipient)
    post = system_message.create(:welcome_invite)
    post.user
  end

  before do
    SiteSetting.allow_user_locale = true
    SiteSetting.local_site_contacts = [
      { locale: "en", username: en_contact.username },
      { locale: "fr", username: fr_contact.username }
    ].to_json
  end

  it "does nothing when disabled" do
    expect(I18n.locale).to eq(:en)
    expect(system_message_sender.username).to eq("system")
  end

  context "when enabled" do
    before { SiteSetting.local_site_contacts_enabled = true }

    it "uses the configured users when enabled" do
      expect(system_message_sender.username).to eq(en_contact.username)

      recipient.update(locale: "fr")
      expect(system_message_sender.username).to eq(fr_contact.username)

      recipient.update(locale: "de")  # No local contact for this locale
      expect(system_message_sender.username).to eq("system")
    end

    it "ignores missing users" do
      SiteSetting.local_site_contacts = [
        { locale: "en", username: SecureRandom.hex },
      ].to_json
      expect(system_message_sender.username).to eq("system")
    end

    it "ignores non-admin" do
      en_contact.update(admin: false)
      expect(system_message_sender.username).to eq("system")
    end

    it "ignores invalid json" do
      SiteSetting.stubs(:local_site_contacts).returns("[{")
      expect(system_message_sender.username).to eq("system")
    end

    it "ignores invalid values" do
      SiteSetting.stubs(:local_site_contacts).returns("[{somekey: 'blah'}]")
      expect(system_message_sender.username).to eq("system")
    end
  end

end
