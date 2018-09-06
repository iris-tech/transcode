module GoogleAuthHelper
    def login?
        if session[:user].nil?
            return false
        else
            return true
        end
    end

    def user_name
        login? ? session[:user]['name'] : ''
    end

    def user_email
        login? ? session[:user]['email'] : ''
    end

    def user_domain
        login? ? user_email.split('@').last : ''
    end

    def user_image
        login? ? session[:user]['image'] : ''
    end

end
