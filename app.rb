require './libs/kml_uploader'
require './libs/syncer'
require './libs/database'
require './libs/app_logger'

def app_main(syncer_time = "03:00")
	AppLogger.instance.info "started"
	
	sync_time = Time.parse(syncer_time, Time.now)
	sync_hour = sync_time.hour

	loop do
		begin
			uploader = KMLUploader.new
			uploader.upload_all

			r_client = Database.instance.redis_client

			unless r_client.get('is_syncing') == "1"
				if Time.now.hour > sync_hour and Time.parse(r_client.get("latest_update")) < Time.parse(syncer_time, Time.now)
					AppLogger.instance.info "sync start"
					Syncer.new.sync
					AppLogger.instance.info "sync end"
				end
			end

		rescue Exception => e
			AppLogger.instance.fatal (e.to_s)
		end

		sleep 60
	end

	AppLogger.instance.info "started" "dead"
end
