require 'mysql2'
require 'redis'
require 'singleton'
require './configs/app_config'

class Database
	include Singleton

	def mysql_client
		config = AppConfig.instance

		Mysql2::Client.new :host => config.sql_host, 
						   :username => config.sql_user_name,
						   :password => config.sql_user_pw,
						   :socket => config.sql_sock,
						   :database => config.sql_db_name, 
						   :reconnect => true
	end

	def redis_client
		config = AppConfig.instance

		redis = Redis.new :path => config.redis_path, :db => config.redis_db
		if redis.get("latest_update") == nil
			redis.set("latest_update", Time.parse("1970-01-01").strftime("%Y%m%d"))
		end
		if redis.get("is_syncing") == nil
			redis.set("is_syncing", 0)
		end

		redis # retuen it
	end
end
