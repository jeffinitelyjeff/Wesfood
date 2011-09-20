require 'rubygems'
require 'FileUtils'
require 'pony'


## Some constants

EMAIL = false
CLEAR = true
DOC_DIR = 'sc'
DIGEST_DIR = "#{DOC_DIR}/digest"
TXT_DIR = "#{DOC_DIR}/txt"
BLOG_DIR = "#{DOC_DIR}/blog"


## Some methods

def txt_loc(n)
  "#{TXT_DIR}/#{n}.txt"
end

def blog_loc(n)
  "#{BLOG_DIR}/#{n}.txt"
end

def date_s(l)
  d = date(l)
  return 'invalid date' if d.empty?
  "#{d[:m]}-#{d[:d]}-#{d[:y]}"
end

def date(l)
  m = month(l.split(' ')[0])
  return {} if m == 0
  d = l.split(' ')[1].each_char.select {|c| c.to_i.to_s == c}.join('').to_i
  y = m > 8 ? 11 : 12
  return { :m => m, :d => d, :y => y }
end

def month(s)
  months = {
    :jan => 1, :feb => 2,  :mar => 3,  :apr => 4,
    :may => 5, :jun => 6,  :jul => 7,  :aug => 8,
    :sep => 9, :oct => 10, :nov => 11, :dec => 12
  }
  months.select {|k,v| (s || "").downcase.include?(k.to_s)}.values[0] || 0
end

def new_menu_item(l)
  return l.index("Lunch") == 0 || l.index("Dinner") == 0
end

def date_line(l)
  date_s(l) != 'invalid date'
end


#### Set up directory structure

# Remove all files if `CLEAR` is enabled
if File.exist?(DOC_DIR) && CLEAR
  # Leave the archive directory intact.
  [TXT_DIR, BLOG_DIR].each {|d| FileUtils.rm_rf d}
end

# Create necessary directories
[DOC_DIR, DIGEST_DIR, TXT_DIR, BLOG_DIR].each do |d|
  Dir.mkdir d unless File.exist? d
end


#### Split apart each digest file

Dir["#{DIGEST_DIR}/*.txt"].each do |d|

  ls = []
  File.open d, 'r' do |f|
    while l = f.gets
      ls << l
    end
  end

  files = {}
  day_ls = []
  current_day = ''
  ls.each do |l|
    if date_line(l)
      files[current_day] = day_ls unless day_ls.empty?
      current_day = date_s(l)
      day_ls.clear
    else
      day_ls << l
    end
  end
  files[current_day] = day_ls

  files.each do |k,v|
    File.open txt_loc(k), 'w' do |f|
      while l = v.shift
        f.write l
      end
    end
    puts "--> #{txt_loc k}"
  end



end
