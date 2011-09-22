require 'net/http'
require 'uri'
require 'date'

require 'json'

require '../secrets'

def american(d)
  "#{d.month}/#{d.day}/#{d.year - 2000}"
end

d = Date.today

restaurant = {
  'ww' => 'WesWings',
  'sc' => 'S&C'
}

slug = {
  'ww' => 'weswings',
  'sc' => 's-and-c'
}

extra_text = {
  'ww' => "Try going to the [WesWings website](http://www.weswings.com).",
  'sc' => "Guess you'll just have to join Alpha Delt."
}

Dir.mkdir "log" unless File.exist? "log"
log = Time.now.to_s + "\n"

['ww', 'sc'].each do |tag|
  resp = Net::HTTP.get_response URI.parse("http://api.tumblr.com/v2/blog/www.wesfood.com/posts?api_key=#{CONSUMER_KEY}&tag=#{tag}")
  json = JSON.parse resp.body
  if !Date.parse(json['response']['posts'][0]['date']) == d
    log += "#{tag} - posting"
    post = {
      :email => TUMBLR_USER,
      :password => TUMBLR_PWORD,
      :type => 'regular',
      :format => 'markdown',
      :tags => tag,
      :slug => "#{slug[tag]}-#{d.to_s}",
      :title => "#{restaurant[tag]} - #{Date::DAYNAMES[d.wday]} #{american d}",
      :body => "Sorry, no #{restaurant[tag]} menu for today. #{extra_text[tag]}"
    }
    resp = Net::HTTP.post_form URI.parse('http://www.tumblr.com/api/write'), post
    log += resp.inspect + "\n" + resp.body + "\n---\n"
  else
    log += "#{tag} - no post necessary\n"
  end
end

File.open('log/daily-fill.log', 'a') {|f| f.write log + "\n"}
