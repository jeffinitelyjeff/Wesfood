require 'rubygems'
require 'Docsplit'
require 'net/http'
require 'open-uri'
require 'hpricot'

WESWINGS_URL = 'http://www.weswings.com'

def download_pdfs

  doc = open(WESWINGS_URL) { |f| Hpricot(f) }
  pdfs = (doc/"table#table2 td:first-child > p a").collect do |e|
    e.attributes['href']
  end.reject do |p|
    p == ""
  end.collect do |p|
    p.sub '.pdf', ''
  end

  Net::HTTP.start("weswings.com") do |http|
    pdfs.reject {|pdf| File.exists?("pdf/weswings-#{pdf}.pdf")}.each do |pdf|
      puts "Downloading PDF - #{pdf}.pdf"
      resp = http.get("/#{pdf}.pdf")
      open("pdf/weswings-#{pdf}.pdf", "wb") do |file|
        file.write resp.body
      end
    end
  end

  return pdfs.collect {|pdf| "weswings-#{pdf}"}
end

def pdf_to_txt(ns)
  ns.each do |n|
    if !File.exists? "txt/#{n}.txt"
      # use docsplit to convert to text
      puts "#{n}.txt --> #{n}.pdf"
      Docsplit.extract_text(Dir["pdf/#{n}.pdf"], :output => 'txt/')

      # read in text output
      ls = []
      File.open("txt/#{n}.txt", "r") do |f|
        while l = f.gets do ls << l end
      end

      # potentially filter out some garbage lines
      ls.reject! {|l| l.length <= 2}

      puts "CLEANING UP"

      # fix up some potentially mangled "Lunch Specials" and "Dinner Entrees"
      ls.collect! do |l|
        if str_just_contains(l, "Lunch Specials\n")
          return "Lunch Specials"
        elsif str_just_contains(l, "Dinner Entrees\n")
          return "Dinner Entrees"
        else
          return l
        end
      end

      # write back the cleaned up text
      File.open("txt/#{n}'txt", "w") do |f|
        while l = ls.shift do f.write l end
      end
    end
  end
end

# check if str is composed entirely of characters in the str chars
def str_just_contains(str, chars)
  puts str.inspect, chars.inspect
  str.each_char.all? {|c| chars.include? c}
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
