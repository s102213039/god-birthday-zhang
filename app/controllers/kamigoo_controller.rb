
require 'line/bot'
require 'json'
class KamigooController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false
  protect_from_forgery with: :null_session
  before_action :verify_header, only: :webhook
  
  def webhook
    if check_received_text == "text"
      # 查氣溫
      reply_temperature = get_temperature(received_text)
    
      unless reply_temperature.nil?
         # 傳送訊息到 line
        response = reply_to_line(reply_temperature)
      
        # 回應200
        head :ok
      
        return
      end
    
      # 查天氣
      reply_image = get_weather(received_text)
    
      #有查到的話 後面的事情就不作了
      unless reply_image.nil?
        # 傳送訊息到 line
        response = reply_image_to_line(reply_image)
      
        # 回應200
        head :ok
      
        return
      end
  
      # 紀錄頻道
      Channel.find_or_create_by(channel_id: channel_id)
    
      # 刪除學過的話
      reply_text =  delete_learn(received_text)
    
      # 學說話
      reply_text = learn(channel_id, received_text)
    
      # 關鍵字回覆
      reply_text = keyword_reply(channel_id, received_text) if reply_text.nil?
    
      # 推齊
      reply_text = echo2(channel_id, received_text) if reply_text.nil?
    
      # 紀錄對話
      save_to_received(channel_id, received_text)
      save_to_reply(channel_id, reply_text)
    
      # 傳送訊息到 line
      response = reply_to_line(reply_text)
    
      # 回應 200
      head :ok
      
    end   
  end
  
  def get_temperature(received_text)
    return nil unless ["天氣","!天氣","三義天氣","三義氣溫","三義 天氣","天氣 三義"].include?(received_text)
    json_pretty(get_temperature_from_cwb)
  end
  
  def get_temperature_from_cwb
    uri = URI("https://works.ioa.tw/weather/api/weathers/109.json")
    response = Net::HTTP.get(uri)
    end_index = response.index(',"specials"')-1
    
    response = response[0..end_index] + "}"
    
    JSON.parse(response)
  end
  
  def json_pretty(json)
    "更新時間: " << json["at"] << "\n敘述: " << json["desc"] << "\n溫度: " << json["temperature"].to_s << "℃\n體感溫度: " << json["felt_air_temp"].to_s << "℃\n濕度: " << json["humidity"].to_s << "%\n雨量: " << json["rainfall"].to_s << "mm"
  end
  
  def get_weather(received_text)
    return nil unless received_text == '現在天氣'
    upload_to_imgur(get_weather_from_cwb)
  end
  
  def get_weather_from_cwb
    uri = URI('https://www.cwb.gov.tw/V7/js/HDRadar_1000_n_val.js')
    response = Net::HTTP.get(uri)
    start_index = response.index('","') + 3
    end_index = response.index('"),') - 1
    
    "https://www.cwb.gov.tw" + response[start_index..end_index]
  end
  
  def upload_to_imgur(image_url)
    url = URI("https://api.imgur.com/3/image")
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(url)
    request["authorization"] = 'Client-ID d0ebd24444c7770'
    
    request.set_form_data({"image" => image_url})
    response = http.request(request)
    json = JSON.parse(response.read_body)
    begin
      json['data']['link'].gsub("http:","https:")
    rescue
      nil
    end
  end
  
  # 傳送圖片到 line
  def reply_image_to_line(reply_image)
    return nil if reply_image.nil?
    
    # 取得 reply token
    reply_token = params['events'][0]['replyToken']
    
     # 設定回覆訊息
    message = {
      type: "image",
      originalContentUrl: reply_image,
      previewImageUrl: reply_image
    }

    # 傳送訊息
    line.reply_message(reply_token, message)
  end
  
  # 頻道ID
  def channel_id
    source = params['events'][0]['source']
    #return source['groupId'] unless source['groupId'].nil?
    #return source['roomId'] unless source['roomId'].nil?
    source['groupId']||source['roomId']||source['userId']
  end
  
  # 儲存對話
  def save_to_received(channel_id, received_text)
    return if received_text.nil?
    Received.create(channel_id: channel_id, text: received_text)
  end
  
  # 儲存回應
  def save_to_reply(channel_id, reply_text)
    return if reply_text.nil?
    Reply.create(channel_id: channel_id,text: reply_text)
  end
  
  def echo2(channel_id, received_text)
    # 如果在 channel_id 最近沒人講過 received_text，就不回應
    recent_received_texts = Received.where(channel_id: channel_id).last(5)&.pluck(:text)
    return nil unless received_text.in? recent_received_texts
    
    # 如果在 channel_id 上一句回應是 received_text，就不回應
    last_reply_text = Reply.where(channel_id: channel_id).last&.text
    return nil if last_reply_text == received_text
    
    received_text
  end
  
  # 取得對方說的話
  def received_text
    message = params['events'][0]['message']
    message['text'] unless message.nil?
  end
  
  def check_received_text
    params['events'][0]['message']["type"]
  end
  
  # 學說話
  def learn(channel_id, received_text)
    #如果開頭不是 '學 ' 就跳出
    return nil unless received_text[0..1] == '學 '
    
    received_text = received_text[2..-1]
    semicolon_index = received_text.index(' ')

    # 找不到空白就跳出
    return nil if semicolon_index.nil?

    keyword = received_text[0..semicolon_index-1]
    message = received_text[semicolon_index+1..-1]

    KeywordMapping.create(channel_id: channel_id, keyword: keyword, message: message)
    '又學到一招 嘻嘻=='
  end
  
  # 學說話
  def delete_learn(received_text)
    #如果開頭不是 '刪 ' 就跳出
    return nil unless received_text[0..1] == '刪 '
  
    received_text = received_text[2..-1]
  
    # 找不到關鍵字就跳出
    return nil if received_text.nil?
  
    id = KeywordMapping.where(keyword: received_text).ids
    
    KeywordMapping.delete(id)
    '刪除學過的話'
  end
  
  # 關鍵字回覆
  def keyword_reply(channel_id, received_text)
    if ["請客","!請客","換誰請客?","請客!"].include?(received_text)
      name = ["邱彥瑜","張慶生","劉易儒","邱彥華","我們還是AA吧"].sample
      #Random.rand(0...4)
      message = "根據我專業的推斷這次請客輪到的是........#{name}!"
    else
      message = KeywordMapping.where(channel_id: channel_id, keyword: received_text).last&.message
    end
    
    return message unless message.nil?
    KeywordMapping.where(keyword: received_text).last&.message
  end
  
  # 傳送訊息到 line
  def reply_to_line(reply_text)
    return nil if reply_text.nil?
    
    
    # 取得 reply token
    reply_token = params['events'][0]['replyToken']
    
    # 設定回覆訊息
    message = {
      type: 'text',
      text: reply_text
    }
    
    # 傳送訊息
    line.reply_message(reply_token, message)
  end
  
  # Line Bot API 物件初始化
  def line
    return @line unless @line.nil?
    @line = Line::Bot::Client.new{ |config|
      config.channel_secret = ENV['CHANNEL_SECRET']
      config.channel_token = ENV['CHANNEL_TOKEN']
    }
  end
  
  def eat
    render plain: "吃土拉"
  end
  
  def request_headers
    render plain: request.headers.to_h.reject{ |key, value|
      key.include? '.'
    }.map{ |key, value|
      "#{key}: #{value}"
    }.sort.join("\n")
  end
  
  def response_headers
    response.headers['5566'] = 'QQ'
    render plain: response.headers.to_h.map{|key,value|
      "#{key}: #{value}"
    }.sort.join("\n")
  end
  
  def request_body
    render plain: request_body
  end
  
  def show_response_body
    puts "===這是設定前的response.body:#{response.body}==="
    render plain: "虎哇花哈哈哈"
    puts "===這是設定後的response.body:#{response.body}==="
  end
  
  def sent_request
    uri = URI('http://localhost:3000/kamigoo/response_body')
    response = Net::HTTP.get(uri).force_encoding("UTF-8")
    render plain: translate_to_korean(response)
  end
  
  def sent_request1
    uri = URI('http://localhost:3000/kamigoo/eat')
    http = Net::HTTP.new(uri.host, uri.port)
    http_request = Net::HTTP::Get.new(uri)
    http_response = http.request(http_request)
    
    render plain: JSON.pretty_generate({
      request_class: request.class,
      response_class: response.class,
      http_request_class: http_request.class,
      http_response_class: http_response.class
    })
  end
  
  def translate_to_korean(message)
    "#{message}油~"
  end
  
  def random_number(message)
    "#{message}+#{Random.rand(0...4)}"
  end
  
  # 判斷來原是否為 line
  def verify_header
    channel_secret = ENV['CHANNEL_SECRET'] # Channel secret string
    http_request_body = request.raw_post # Request body string
    hash = OpenSSL::HMAC::digest(OpenSSL::Digest::SHA256.new, channel_secret, http_request_body)
    signature = Base64.strict_encode64(hash)

    # Compare X-Line-Signature request header string and the signature
    if signature != request.headers["X-Line-Signature"]
      redirect_to root_path
    end
  end
  
end
