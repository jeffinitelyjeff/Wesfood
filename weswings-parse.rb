require 'rubygems'
require 'Docsplit'
require 'net/http'
require 'open-uri'
require 'hpricot'

WESWINGS_URL = 'http://www.weswings.com'
CLEAR = true

# Check if `str` is composed entirely of characters in the string `chars`
def str_just_contains(str, chars)
  str.length > 2 && str.each_char.all? {|c| chars.include? c}
end

# Clear previously downloaded PDFs if `CLEAR` is enabled.
File.delete *Dir['pdf/weswings/*']

#### Download PDFs from WesWings

# Load the WesWings page, get all links in the menu area, filter out empty
# links and remove the .pdf extensions. Also filter out any PDFs we already
# have.
doc = open(WESWINGS_URL) {|f| Hpricot f}
links = (doc/"#table2 td:first-child > p a").collect {|e| e.attributes['href']}
names = links.reject {|l| l == ""}.collect {|l| l.sub '.pdf', ''}.reject do |n|
  File.exist? "pdf/weswings/#{n}.pdf"
end

# Download the PDFs
Net::HTTP.start("weswings.com") do |http|
  names.each do |n|
    puts "Downloading PDF - pdf/weswings/#{n}.pdf"
    resp = http.get("/#{n}.pdf")
    open("pdf/weswings/#{n}.pdf", "wb") do |file|
      file.write resp.body
    end
  end
end

#### Dump the TXT versions of PDFs

# Delete the relevant previously generated .txt files.
names.each do |n|
  f = "txt/weswings/dirty/#{n}.txt"
  File.delete f if File.exist? f
end

# Generate dirty .txt dumps for the PDFs downloaded
names.each do |n|
  Docsplit.extract_text Dir["pdf/weswings/#{n}.pdf"], :output => 'txt/weswings/dirty/'
  puts "pdf/weswings/#{n}.pdf --> txt/weswings/dirty/#{n}.txt"
end

# Clean up the dirty .txt dumps.

#### Generate cleaned up TXT files

# Delete the relevant previously generated clean .txt files.
names.each do |n|
  f = "txt/weswings/clean/#{n}.txt"
  File.delete f if File.exist? f
end

names.each do |n|

  # Read in the dirty file.
  ls = []
  File.open "txt/weswings/dirty/#{n}.txt", "r" do |f|
    while l = f.gets
      ls << l
    end
  end

  # Remove short lines; sometimes the text is formatted strangely and creates
  # single-character artifact lines.
  ls = ls.select {|l| l.length > 2 || l == "\n"}

  # Remove day-of-the-week header
  ls.reject! {|l| ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY',
                   'SATURDAY', 'SUNDAY'].any? {|d| l.index(d) == 0}}

  # Clean up lines that look mostly like "Lunch Specials" or "Dinner Entrees".
  # This is necessary in case the weird formatting moved some letters to
  # their own line.
  ls.collect! do |l|
    if str_just_contains(l, "Lunch Specials\n")
      "Lunch Specials\n"
    elsif str_just_contains(l, "Dinner Entrees\n")
      "Dinner Entrees\n"
    else
      l
    end
  end

  # Write the cleaned-up version.
  File.open "txt/weswings/clean/#{n}.txt", "w" do |f|
    while l = ls.shift
      f.write l
    end
  end

  puts "txt/weswings/dirty/#{n}.txt --> txt/weswings/clean/#{n}.txt"
end

# def gather_items_from_txt(n)
#   begin
#     File.open("txt/#{n}.txt", "r") do |f|
#       ls = []
#       while l = f.gets do ls << l end

#       items = []
#       in_dinner = false
#       entree = []

#       ls.reject do |l| && l != "\n"}
#         ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
#          'Sunday'].collect{|d| d + "\n"}.include? l
#       end.each do |l|
#         if l == "Dinner Entrees\n" || l == "Lunch Specials\n"
#           in_dinner = l == "Dinner Entrees\n"
#         elsif l == "\n"
#           puts entree
#           item = menu_item entree
#           item[:meal] = in_dinner ? :dinner : :lunch
#           items << item
#           entree = []
#         else
#           entree << l
#         end
#       end

#       return items
#     end
#   rescue IOError => err
#     puts "Exception: #{err}"
#   end
# end

# def menu_item(lines)
#   desc = ([lines[0].squeeze('.').split(' - ')[1].split(' . ')[0]] +
#           lines[1..-1]).join(' ').gsub(/\n/, ' ').squeeze(' ').strip
#   return {
#     :name => lines[0].split(' - ')[0],
#     :price => lines[0].split('$')[1].to_f,
#     :desc => desc
#   }
# end

# def parse_txt(ns)
#   ns.each do |n|
#     items = gather_items_from_txt n
#     File.open("parsed/#{n}.txt", "w") do |f|
#       puts "DUMPING PARSED TXT"
#       f.write("### Lunch")
#       items.select {|item| item[:meal] == :lunch}.each do |item|
#         f.write "#### #{item[:name]} (#{item[:price]})"
#         f.write item[:desc]
#       end
#       f.write("### Dinner")
#       items.select {|item| item[:meal] == :dinner}.each do |item|
#         f.write "#### #{item[:name]} (#{item[:price]})"
#         f.write item[:desc]
#       end
#     end
#   end
# end

# # FIXME - pull PDF, set PDF filename
# # name = 'weswings-9-12-11'
# names = download_pdfs
# puts names
# pdf_to_txt names
# parse_txt names
