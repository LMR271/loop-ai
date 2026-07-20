module Users
  class RegistrationsController < Devise::RegistrationsController
    def create
      super do |resource|
        UserMailer.welcome(resource).deliver_later if resource.persisted?
      end
    end
  end
end
