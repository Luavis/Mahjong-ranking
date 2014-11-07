require 'yaml'
require 'singleton'

class AppConfig
	include Singleton

	attr_reader :kml_password, :sql_user_name, :sql_user_pw, :sql_host, :sql_db_name, :sql_sock, :redis_path, :redis_db, :redis_path

	def initialize
		conf = YAML.load (open "./configs/config.yml")
		@sql_user_name = conf['mysql_id']
		@sql_user_pw = conf['mysql_pw']
		@sql_host = conf['mysql_host']
		@sql_db_name = conf['mysql_db_name']
		@sql_sock = conf['mysql_sock']

		@redis_path = conf['redis_path']
		@redis_db = conf['redis_db_num']
		@kml_password = conf['kml_pw']
	end
end