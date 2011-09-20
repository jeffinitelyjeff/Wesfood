require 'rubygems'
require 'Docsplit'
require 'net/http'
require 'open-uri'
require 'hpricot'
require 'fileutils'
require 'pony'
require 'Tumblr'
# require '~/.rvm/gems/ruby-1.9.2-p290/gems/tumblr-rb-1.3.0/lib/tumblr'

require '../secrets'


## Some constants

WESWINGS_URL = 'http://www.weswings.com'
CLEAR = false
DOWNLOAD = false
EMAIL = false
DOC_DIR = 'ww'
PDF_DIR = "#{DOC_DIR}/pdf"
ARCHIVE_DIR = "#{DOC_DIR}/pdf-archive"
DIRTY_DIR = "#{DOC_DIR}/dirty-txt"
CLEAN_DIR = "#{DOC_DIR}/clean-txt"
BLOG_DIR = "#{DOC_DIR}/blog-txt"


## Some methods

def pdf_loc n
  "#{PDF_DIR}/#{n}.pdf"
end

def archive_loc n
  "#{ARCHIVE_DIR}/#{n}.pdf"
end

def dirty_loc n
  "#{DIRTY_DIR}/#{n}.txt"
end

def clean_loc n
  "#{CLEAN_DIR}/#{n}.txt"
end

def blog_loc n
  "#{BLOG_DIR}/#{n}.txt"
end

def email_subject n
  "WesWings Menu - #{n}"
end

# Check if `str` is composed entirely of characters in the string `chars`
def str_just_contains(str, chars)
  str.each_char.all? {|c| chars.include? c}
end

# Heuristic to see if `str` is the first line of a menu item.
def item_first_line(str)
  options = [
    # The most common form is:
    # Name Name Name - ............. $XX.xx
    str.include?('.. $'),
    # Sometimes, it will be formated like:
    # Name Name Name - description description $XX.xx
    str.include?(' - ') &&
      str.include?('$') &&
      str.split('$')[-1].strip.to_f.to_s == str.split('$')[-1].strip
  ]
  return options.any? {|o| o}
end

def parse_date(name)
  # I have a feeling this won't always work...
  name.split("%20")[-1]
end

def parse_day(name, prev)
  date = parse_date name
  m = date.split('-')[0].to_i
  d = date.split('-')[1].to_i
  y = date.split('-')[2].to_i + 2000
  t = Time.utc(y, m, d, 0, 0, 0, 0)
  wd = prev ? (t.wday - 1) % 7 : t.wday

  ['Sunday', 'Monday', 'Tuesday', 'Wednesday',
   'Thursday', 'Friday', 'Saturday'][wd]
end


#### Set up directory structure

# Remove all files if `CLEAR` is enabled
if File.exist?(DOC_DIR) && CLEAR
  # Leave the archive directory intact.
  [PDF_DIR, DIRTY_DIR, CLEAN_DIR, BLOG_DIR].each {|d| FileUtils.rm_rf d}
end

# Create necessary directories
[DOC_DIR, PDF_DIR, DIRTY_DIR, CLEAN_DIR, BLOG_DIR].each do |d|
  Dir.mkdir d unless File.exist? d
end


#### Download PDFs from WesWings

if DOWNLOAD

  # Load the WesWings page, get all links in the menu area, filter out empty
  # links and remove the .pdf extensions.
  doc = open(WESWINGS_URL) {|f| Hpricot f}
  links = (doc/"#table2 td:first-child > p a").collect do |e|
    e.attributes['href']
  end
  names = links.reject {|l| l == ""}.collect do |l|
    l.sub '.pdf', ''
  end.reject do |n|
    File.exist? "#{PDF_DIR}/#{n}.pdf"
  end

  # Download the PDFs
  Net::HTTP.start("weswings.com") do |http|
    names.each do |n|
      resp = http.get("/#{n}.pdf")

      puts "Downloading PDF --> #{pdf_loc n}"
      open pdf_loc(n), 'wb' do |file|
        file.write resp.body
      end

      if !File.exist? archive_loc(n)
        puts "Storing archive --> #{archive_loc n}"
        open archive_loc(n), 'wb' do |file|
          file.write resp.body
        end
      end

    end
  end

else

  names = Dir["#{PDF_DIR}/*"].collect do |n|
    n.split('/').pop.sub '.pdf', ''
  end

end

#### Dump the TXT versions of PDFs

# Delete the relevant previously generated .txt files.
names.each do |n|
  File.delete dirty_loc(n) if File.exist? dirty_loc(n)
end

# Generate dirty .txt dumps for the PDFs downloaded
names.each do |n|
  Docsplit.extract_text Dir[pdf_loc n], :output => DIRTY_DIR
  puts "#{pdf_loc n} --> #{dirty_loc n}"
end


#### Generate cleaned up TXT files

# Delete the relevant previously generated clean .txt files.
names.each do |n|
  File.delete clean_loc(n) if File.exist? clean_loc(n)
end

names.each do |n|

  # Read in the dirty file.
  ls = []
  File.open dirty_loc(n), 'r' do |f|
    while l = f.gets
      ls << l
    end
  end

  # Remove short lines; sometimes the text is formatted strangely and creates
  # single-character artifact lines.
  # FIXME: Ruby 1.8.7 doesn't have Array::select!, but should be moving to
  # 1.9.2 anyway.
  ls = ls.select {|l| l.length > 5 || l == "\n"}

  # Clean up lines that look mostly like "Lunch Specials" or "Dinner Entrees".
  # This is necessary in case the weird formatting moved some letters to
  # their own line. Also add an extra newline to separate them from the items.
  ls.collect! do |l|
    if l == "\n"
      "\n"
    elsif str_just_contains l, "Lunch Specials\n"
      "Lunch Specials\n\n"
    elsif str_just_contains l, "Breakfast Specials\n"
      "Breakfast Specials\n\n"
    elsif str_just_contains l, "Dinner Entrees\n"
      "Dinner Entrees\n\n"
    else
      l
    end
  end

  # Remove everything that's not in a lunch, breakfast, or dinner section. This gets
  # rid of miscellaneous stuff that they put at the top, namely the day of the week
  # formatted some crazy way.
  in_lunch = false
  in_breakfast = false
  in_dinner = false
  ls = ls.select do |l|
    in_lunch ||= l.include? "Lunch Specials"
    in_breakfast ||= l.include? "Breakfast Specials"
    in_dinner ||= l.include? "Dinner Entrees"
    in_lunch || in_breakfast || in_dinner
  end

  # Ensure that there is an empty line between each menu item.
  new_ls = []
  ls.each_with_index do |l, i|
    # We should only insert a newline if one didn't already exist.
    has_space = i == 0 || ls[i-1] == "\n" || ls[i-1].include?("\n\n")

    new_ls << "\n" if !has_space && (item_first_line(l) || l.include?("Dinner"))
    new_ls << l
  end
  ls = new_ls

  # Ensure there aren't any extra empty lines in the middle of items.
  new_ls = []
  ls.each_with_index do |l, i|
    is_empty = l == "\n"

    if !is_empty || (i != ls.length-1 && (item_first_line(ls[i+1]) || ls[i+1].include?("Dinner")))
      new_ls << l
    end
  end
  ls = new_ls

  # Ensure there is a trailing newline.
  ls << "\n"

  # Write the cleaned-up version.
  File.open clean_loc(n), 'w' do |f|
    while l = ls.shift
      f.write l
    end
  end

  puts "#{dirty_loc n} --> #{clean_loc n}"
end


#### Generate formatted versions of the menu for the tumblr, post on

# Delete the relevant previously generated blog .txt files.
names.each do |n|
  File.delete blog_loc(n) if File.exist? blog_loc(n)
end

names.each do |n|

  # Read in the clean txt file.
  ls = []
  File.open clean_loc(n), 'r' do |f|
    while l = f.gets
      ls << l
    end
  end

  # Get an array of menu item dicts
  items = []
  in_dinner = false
  item_ls = []
  ls.each do |l|
    if l.include?("Dinner Entrees")
      in_dinner = true
    elsif !item_ls.empty? && l == "\n"
      # Strip apart menu into component parts. This shouldn't need to be
      # modified too much; should strive to fix things at the
      # dirty -> clean stage.
      items << {
        :desc => ([item_ls[0].squeeze('.').split(' . ')[0].split(' - ')[1] || ""] +
                  item_ls[1..-1]).join(' ').gsub(/\n/, ' ').squeeze(' ').strip,
        :name => item_ls[0].split('.')[0].split(' - ')[0].strip,
        :price => item_ls[0].split('$')[1].to_f,
        :meal => in_dinner ? :dinner : :lunch
      }
      item_ls.clear
    elsif l != "\n" &&
        !l.include?("Dinner Entrees") &&
        !l.include?("Lunch Specials") &&
        !l.include?("Breakfast Specials")
      item_ls << l
    end
  end

  lunch = items.select {|i| i[:meal] == :lunch}
  dinner = items.select {|i| i[:meal] == :dinner}
  item_print = proc do |item|
    "## #{item[:name]} (#{item[:price]})\n" + "#{item[:desc]}\n\n"
  end

  # FIXME: look into HTML to do better hovering, though not that necessary.
  yaml = {
    'type' => 'regular',
    'state' => 'queue',
    'format' => 'markdown',
    'tags' => 'ww',
    'slug' => "weswings-#{parse_date n}",
    'publish-on' => "#{parse_day n, true} 8PM",
    'title' => "Weswings - #{parse_day n, false} #{parse_date(n).gsub('-', '/')}"
  }
  contents = "---\n" + yaml.collect {|k,v| "#{k}: #{v}"}.join("\n") + "\n---\n"
  contents += "- - -\n# Lunch\n- - -\n\n"
  contents += (lunch.collect &item_print).join('')
  contents += "- - -\n# Dinner\n- - -\n\n"
  contents += (dinner.collect &item_print).join('')

  # Write blog contents to local file.
  File.open blog_loc(n), 'wb' do |f|
    f.write contents
  end
  puts "#{clean_loc n} --> #{blog_loc n}"

  # Fire off notification email.
  if EMAIL
    Pony.mail(:to => 'rubergly@gmail.com', :from => TUMBLR_EMAIL, :subject => email_subject(n), :body => "!m\n\n" + contents, :via => :smtp, :via_options => {
      :address => 'smtp.gmail.com',
      :port => '587',
      :enable_starttls_auto => true,
      :user_name => 'rubergly',
      :password => GMAIL_PWORD,
      :authentication => :plain,
      :domain => "localhost.localdomain"
    })
    puts "Emailed: #{email_subject n}"
  end

  # TODO: schedule posts on Tumblr.
  req = Tumblr::Post.new(TUMBLR_USER, TUMBLR_PWORD).post(contents)
  req.perform do |resp|
    if resp.success?
      puts resp.body
    else
      puts "Something went wrong: #{resp.code} #{resp.message}"
    end
  end

end
