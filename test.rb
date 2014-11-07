#!/usr/bin/env ruby

require './app'
require './libs/database'
require './libs/app_logger'

if File.exists? './logs/debug_log.log'
	File.delete './logs/debug_log.log'
end

AppLogger.log_path = './logs/debug_log.log'

client = Database.instance.mysql_client
client.query("SET FOREIGN_KEY_CHECKS = 0;")
client.query("TRUNCATE table mh_kml_id;")
client.query("TRUNCATE table mh_ranking;")
client.query("TRUNCATE table mh_log;")
client.query("SET FOREIGN_KEY_CHECKS = 1;")

now = Time.now

app_main "#{now.hour}:#{now.min + 1}" 
