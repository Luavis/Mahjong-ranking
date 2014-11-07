# -*- coding: utf-8 -*-
require 'open-uri'
require 'nokogiri'
require 'http'
require './libs/database'

class Record
  attr_accessor :wind, :name, :point

  def wind=(_wind)
    if _wind == '동'
      @wind = 0
    elsif _wind == '남'
      @wind = 1
    elsif _wind == '서'
      @wind = 2
    else
      @wind = 3
    end
  end
end

class Syncer

  def initialize
    @client = Database.instance.mysql_client
    @redis_client = Database.instance.redis_client
  end

  def sync
    if @redis_client.get("is_syncing") == "1"
      p "already syncing"
      return
    end

    @redis_client.set("is_syncing", 1)

    @client.query "TRUNCATE TABLE mh_kml_id"

    html = open('http://mahjong.or.kr/stat6/record_list.php?all=1').read.encode('utf-8', 'euc-kr', :invalid => :replace, :undef => :replace)
    page = Nokogiri::HTML(html)

    data = page.css 'tr.style7[bgcolor]'

    reg = /\[([동|남|서|북]{1})\]([\s\S]*):\s([0-9\-]+)/

    data.each do | row |
      begin
        desc = row.css('td')
        
        no = desc[0].text
        date = (desc[1].text)
        length = (desc[2].text)

        datum = [desc[3].text, desc[4].text, desc[5].text, desc[6].text]

        if length == '동장'
          length = "east"
        elsif length == '반장'
          length = 'half'
        elsif length == '전장'
          length = 'all'
        else 
          length = 'half'
        end

        records = []
        datum.map.with_index.each do | d, index|
          fst = reg.match(d)

          records[index] = Record.new
          records[index].wind = fst[1]
          records[index].name = fst[2]
          records[index].point = fst[3]
        end
        self.save_to_db(no, date, length, records)
      rescue Exception => e
        AppLogger.instance.fatal "error : (#{e.backtrace}) \nStacktrace\n#{e.backtrace}" 
      end
    end
     @redis_client.set("is_syncing", 0)
     @redis_client.set("latest_update", Time.now.strftime('%Y%m%d %H:%m'))
  end

  def save_to_db(no, date, length, records)
    is_exist = false
    
    @client.query("select id from `mh_ranking` where kml_id = #{no} limit 1").each do | data |
      is_exist = true
    end

    if is_exist
      return
    end
    @client.query "INSERT INTO `mh_ranking` (`is_half`, `is_recorded`, `is_deleted`, `timestamp`, `kml_id`) VALUES (\"#{length}\", 1, 0, \"#{date}\", #{no})"
    @client.query "insert into mh_kml_id (kml_id, ranking_id) values(#{no}, last_insert_id())" 

    ranking_id = nil
    @client.query("select last_insert_id() as id").each do | id |
      ranking_id = id['id']
    end
    
    log_ids = []

    records.map.with_index.each do | r, index |
      escaped_name = @client.escape r.name
      
      user_id = nil

      @client.query("select id   from mh_nickname where nickname = \"#{escaped_name}\" limit 1", :cache_rows => true).each do | id |
        user_id = id['id']
      end

      @client.query "insert into mh_log (point, wind_type, user_id, grade, ranking_id) values(#{r.point}, #{r.wind}, #{user_id}, #{index}, #{ranking_id})"
      @client.query("select last_insert_id() as id").each do | id |
        log_ids.push id['id']
      end
    end

    @client.query  "update `mh_ranking` set log_1_id = #{log_ids[0]}, log_2_id = #{log_ids[1]}, log_3_id = #{log_ids[2]}, log_4_id = #{log_ids[3]} where id = #{ranking_id}"
  end
end
