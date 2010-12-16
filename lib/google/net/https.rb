require "net/http"
require "net/https"

module Net

  # Helper Method for using SSL
  #
  class HTTPS < HTTP

    # Setup a secure connection with defaults
    #
    def initialize(address, port = nil)
      super(address, port)
      self.use_ssl = true
      self.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
  end

end