class User < ActiveRecord::Base
  has_many :organization_memberships, dependent: :destroy
  has_many :organizations, through: :organization_memberships

  class << self
    def authenticate(auth)
      external_id = "#{auth.fetch("provider")}-#{auth.fetch("uid")}"
      where(:external_id => external_id).first || begin
        User.create!(
          name: auth["info"]["name"] || auth["info"]["nickname"] || "No name",
          email: auth["info"]["email"],
          external_id: external_id,
          organizations: github_organizations(auth.fetch("credentials").fetch("token"))
        )
      end
    end

    private

    def github_organizations(token)
      conn = Faraday.new(url: 'https://api.github.com')
      conn.headers["Authorization"] = "token #{token}"
      response = conn.get('/user/orgs')
      raise "Bad response #{response.status} -- #{response.body}" unless response.status == 200

      orgs = JSON.parse(response.body)
      orgs.map { |x| Organization.find_or_create_by!(name: x.fetch("login")) }
    end
  end

  # md5 is not safe, but we are only hiding the email ... and only showing it to yourself
  def gravatar_url
    md5 = (email.blank? ? "default" : Digest::MD5.hexdigest(email))
    "https://www.gravatar.com/avatar/#{md5}"
  end
end
