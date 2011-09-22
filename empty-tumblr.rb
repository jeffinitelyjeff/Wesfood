require 'net/http'
require 'uri'
require 'date'

require 'json'
require 'hpricot'

require '../secrets'

def american(d)
  "#{d.month}/#{d.day}/#{d.year - 2000}"
end

def date(t, sep = '-')
  m = t.month
  d = t.day
  y = t.year
  "#{m}#{sep}#{d}#{sep}#{y}"
end

#  = Date.today.next_day.next_day.next_day

# 24.times do
#   post = {
#     :email => TUMBLR_USER,
#     :password => TUMBLR_PWORD,
#     :type => 'regular',
#     :state =>  :state => 'queue'
#     :format => 'markdown',
#     :tags => 'ww',
#     :slug => "weswings-#{d.to_s}",
#     :"publish-on" => "#{d.prev_day.to_s} 8PM",
#     :title => "Weswings - #{Date::DAYNAMES[d.wday]} #{american d}",
#     :body => "Sorry, no Weswings menu for today. Try going to the [Weswings website](http://www.weswings.com)."
#   }

#   res = Net::HTTP.post_form URI.parse('http://www.tumblr.com/api/write'), post
#   puts res.body

#   d = d.next_day
# end

# post = {
#   :email => TUMBLR_USER,
#   :password => TUMBLR_PWORD,
#   :num => 20,
#   :state => 'queue'
# }

# resp = Net::HTTP.post_form URI.parse('http://wesfood.com/api/read'), post
# puts resp.inspect
# doc = Hpricot::XML(resp.body)
# (doc/'post').each {|p| puts p.attributes['id']}

key = "MFu9IgLjpTPOGOg4I2p4t1r7lgo7lXl9dOhPw1mduvpS39DE1k"
resp = Net::HTTP.get_response URI.parse("http://api.tumblr.com/v2/blog/www.wesfood.com/posts?api_key=#{key}&tag=sc")
json = JSON.parse resp.body
puts json['response']['posts'].collect{|d| Date.parse(d['date']) == Date.today}
