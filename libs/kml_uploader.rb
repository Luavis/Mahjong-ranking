#!/usr/bin/env ruby 
# -*- encoding: utf-8 -*-
# KML Automatic ranking uploader
# Written by Luavis

require 'http'
require 'nokogiri'
require 'json'
require 'mysql2'
require './libs/app_logger'
require './configs/app_config'

class KMLUploader
  #include Singleton

  attr_reader :domain, :url, :cookie_name, :password, :upload_count, :done_count, :is_running

  def initialize
    @client = Database.instance.mysql_client
    @domain = 'http://mahjong.or.kr'
    @url = @domain + '/stat6'
    @cookie_name = 'mstat6'
    @password = AppConfig.instance.kml_password
    @cookie = ''
    @done_count = 0

    self.get_cookie
    self.login
  end
  
  def finalize

  end

  def get_cookie
  	res = HTTP.get(@url + '/record.php');
  	@cookie = CGI::Cookie::parse(res.headers['Set-Cookie'])[@cookie_name][0]
  end

  def login
  	res = self.post('/login.php', :passwd => @password)
  end

  def update_user_list
    AppLogger.instance.info "update user list"
    @is_running = true
  	res = self.get('/record.php')
  	page = Nokogiri::HTML(res.to_s.encode('utf-8', 'euc-kr', :invalid => :replace, :undef => :replace))
  	page.css("select[name='nick0'] > option").each do |nick|
      nickname = @client.escape(nick.text)
      kml_id = @client.escape(nick['value'])

  		@client.query("insert into mh_nickname (nickname, kml_id) values('#{nickname}', '#{kml_id}') on duplicate key update kml_id = values(kml_id)")
    end
    @is_running = false
    AppLogger.instance.info "update user ended"
  end

  def upload_all
    AppLogger.instance.info "upload all data"

    self.update_user_list()
    @is_running = true
    @done_count = 0

  	unrecord_list = @client.query "SELECT mh_ranking.id as id, mh_ranking.is_half as is_half,
			  mh_log1.point as log_1_point, mh_log1.kml_id as log_1_kml_id, mh_log1.wind_type as log_1_wind,
			  mh_log2.point as log_2_point, mh_log2.kml_id as log_2_kml_id, mh_log2.wind_type as log_2_wind,
			  mh_log3.point as log_3_point, mh_log3.kml_id as log_3_kml_id, mh_log3.wind_type as log_3_wind,
			  mh_log4.point as log_4_point, mh_log4.kml_id as log_4_kml_id, mh_log4.wind_type as log_4_wind
			  FROM mh_ranking 
			  left join (select mh_log.id, point, wind_type, kml_id from mh_log left join mh_nickname on (mh_nickname.id = user_id) ) mh_log1 on (mh_log1.id = log_1_id)
			  left join (select mh_log.id, point, wind_type, kml_id from mh_log left join mh_nickname on (mh_nickname.id = user_id) ) mh_log2 on (mh_log2.id = log_2_id)
			  left join (select mh_log.id, point, wind_type, kml_id from mh_log left join mh_nickname on (mh_nickname.id = user_id) ) mh_log3 on (mh_log3.id = log_3_id)
			  left join (select mh_log.id, point, wind_type, kml_id from mh_log left join mh_nickname on (mh_nickname.id = user_id) ) mh_log4 on (mh_log4.id = log_4_id)
			  where is_recorded=0 and is_deleted=0", :cache_rows => true

    @upload_count = unrecord_list.count

    unrecord_list.each do | row |
      # id, is_half, log_1_point, log_1_kml_id, log_1_wind, log_2_point, log_2_kml_id, log_2_wind, log_3_point, log_3_kml_id, log_3_wind, log_4_point, log_4_kml_id, log_4_wind
		  self.update row['id'], row['is_half'],
		  				{:point => row['log_1_point'], :kml_id => row['log_1_kml_id'], :wind_type => row['log_1_wind']}, 
		  				{:point => row['log_2_point'], :kml_id => row['log_2_kml_id'], :wind_type => row['log_2_wind']},
		  				{:point => row['log_3_point'], :kml_id => row['log_3_kml_id'], :wind_type => row['log_3_wind']},
		  				{:point => row['log_4_point'], :kml_id => row['log_4_kml_id'], :wind_type => row['log_4_wind']}
      @done_count += 1
		end

    @is_running = false

    AppLogger.instance.info "upload ended"
  end

  def update(id, is_half, log_1, log_2, log_3, log_4)
    AppLogger.instance.info 
  	game_length = 0

  	if is_half == 'half'
  		game_length = 1
  	elsif is_half == 'all'
  		game_length = 3
  	end

  	res = self.post('/record_ok.php', 
  				:game_length => game_length,
  				'wind[0]' => log_1[:wind_type],
  				'wind[1]' => log_2[:wind_type],
  				'wind[2]' => log_3[:wind_type],
  				'wind[3]' => log_4[:wind_type],
  				'nick0' => log_1[:kml_id],
  				'nick1' => log_2[:kml_id],
  				'nick2' => log_3[:kml_id],
  				'nick3' => log_4[:kml_id],
  				'point[0]' => log_1[:point],
  				'point[1]' => log_2[:point],
  				'point[2]' => log_3[:point],
  				'point[3]' => log_4[:point],
  				'common_point' => 0
  			 )
    ret_msg = res.to_s.encode('utf-8', 'euc-kr', :invalid => :replace, :undef => :replace)
    ret_msg_match = /record\_modify\.php\?modify\_id\=([0-9]+)/.match ret_msg

  	if ret_msg['등록 되었습니다.']
  		@client.query "update mh_ranking set is_recorded = 1, kml_id = #{ret_msg_match[1]} where id = " + id.to_s
  	end
  end

  def get(path)
  	HTTP.with('Cookie' => @cookie_name + '=' + @cookie + ';').get(@url + path)
  end

  def post(path, form)
  	HTTP.with('Cookie' => @cookie_name + '=' + @cookie + ';').post(@url + path, :form => form)
  end

end
