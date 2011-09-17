require 'rubygems'
require 'Docsplit'
require 'net/http'
require 'open-uri'
require 'hpricot'

WESWINGS_URL = 'http://www.weswings.com'

# Check if `str` is composed entirely of characters in the string `chars`
def str_just_contains(str, chars)
  puts str.inspect, chars.inspect
  str.each_char.all? {|c| chars.include? c}
end


#### Download PDFs from WesWings

# Load the WesWings page, get all links in the menu area, filter out empty
# links and remove the .pdf extensions.
doc = open WESWINGS_URL {|f| Hpricot f}
links = (doc/"#table2 td:first-child > p a").collect {|e| e.attributes['href']}
names = links.reject {|l| p == ""}.collect {|l| l.sub '.pdf', ''}

# Download the PDFs
Net::HTTP.start("weswings.com") do |http|
  names.reject {|n| File.exists? "pdf/weswings-#{n}.pdf"}.each do |n|
    puts "Downloading PDF - #{n}.pdf"
    resp = http.get("/#{n}.pdf")
    open("pdf/weswings-#{n}.pdf", "wb") do |file|
      file.write resp.body
    end
  end
end

#### Dump the TXT versions of PDFs

# Delete all previously generated .txt files.
File.delete *Dir['txt/*']

# Generate dirty .txt dumps for the PDFs downloaded
names.each do |n|
  puts "weswings-#{n}.pdf --> weswings-#{n}.txt"
  Docsplit.extract_text Dir["pdf/weswings-#{n}.pdf"], :output => 'txt/'
end

# Clean up the dirty .txt dumps.
names.each do |n|

  # Read in the dirty file.
  ls = []
  File.open "txt/weswings-#{n}.txt", "r" do |f|
    while l = f.gets
      ls << l
    end
  end

  # Remove short lines; sometimes the text is formatted strangely and creates
  # single-character artifact lines.
  ls.reject! {l| l.lenght <= 2}

  # Clean up lines that look mostly like "Lunch Specials" or "Dinner Entrees".
  # This is necessary in case the weird formatting moved some letters to
  # their own lines.
  ls.collect! do |l|
    if str_just_contains l, "Lunch Specials\n"
      return "Lunch Specials\n"
    elsif str_just_contains l, "Dinner Entrees\n"
      return "Dinner Entrees\n"
    else
      return l
    end
  end

  # Write the cleaned-up version.
  File.open "txt/weswings-clean-#{n}.txt", "w" do |f|
    while l = ls.shift
      f.write l
    end
  end
end


def gather_items_from_txt(n)
  begin
    File.open("txt/#{n}.txt", "r") do |f|
      ls = []
      while l = f.gets do ls << l end

      items = []
      in_dinner = false
      entree = []

      ls.reject do |l|
        ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
         'Sunday'].collect{|d| d + "\n"}.include? l
      end.each do |l|
        if l == "Dinner Entrees\n" || l == "Lunch Specials\n"
          in_dinner = l == "Dinner Entrees\n"
        elsif l == "\n"
          puts entree
          item = menu_item entree
          item[:meal] = in_dinner ? :dinner : :lunch
          items << item
          entree = []
        else
          entree << l
        end
      end

      return items
    end
  rescue IOError => err
    puts "Exception: #{err}"
  end
end

def menu_item(lines)
  desc = ([lines[0].squeeze('.').split(' - ')[1].split(' . ')[0]] +
          lines[1..-1]).join(' ').gsub(/\n/, ' ').squeeze(' ').strip
  return {
    :name => lines[0].split(' - ')[0],
    :price => lines[0].split('$')[1].to_f,
    :desc => desc
  }
end

def parse_txt(ns)
  ns.each do |n|
    items = gather_items_from_txt n
    File.open("parsed/#{n}.txt", "w") do |f|
      puts "DUMPING PARSED TXT"
      f.write("### Lunch")
      items.select {|item| item[:meal] == :lunch}.each do |item|
        f.write "#### #{item[:name]} (#{item[:price]})"
        f.write item[:desc]
      end
      f.write("### Dinner")
      items.select {|item| item[:meal] == :dinner}.each do |item|
        f.write "#### #{item[:name]} (#{item[:price]})"
        f.write item[:desc]
      end
    end
  end
end

# FIXME - pull PDF, set PDF filename
# name = 'weswings-9-12-11'
names = download_pdfs
puts names
pdf_to_txt names
parse_txt names
