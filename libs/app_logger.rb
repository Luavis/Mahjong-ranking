require 'singleton'
require 'logger'

class AppLogger < Logger
  include Singleton
  @@log_path = "./logs/app_log.log"

  def initialize
    super @@log_path
  end

  def self.log_path=(log_path)
  	@@log_path = log_path
  end
end
