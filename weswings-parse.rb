require 'rubygems'
require 'Docsplit'
require 'net/http'
require 'open-uri'
require 'hpricot'
require 'fileutils'


## Some constants

WESWINGS_URL = 'http://www.weswings.com'
CLEAR = false
DOWNLOAD = false
DOC_DIR = 'ww'
PDF_DIR = "#{DOC_DIR}/pdf"
DIRTY_DIR = "#{DOC_DIR}/dirty-txt"
CLEAN_DIR = "#{DOC_DIR}/clean-txt"
BLOG_DIR = "#{DOC_DIR}/blog-txt"


## Some methods

def pdf_loc n
  "#{PDF_DIR}/#{n}.pdf"
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

# Check if `str` is composed entirely of characters in the string `chars`
def str_just_contains(str, chars)
  str.each_char.all? {|c| chars.include? c}
end

# Heuristic to see if `str` is the first line of a menu item.
def item_first_line(str)
  return str.include? '.. $'
end


#### Set up directory structure

# Remove all files if `CLEAR` is enabled
if File.exist?(DOC_DIR) && CLEAR
  FileUtils.rm_rf DOC_DIR
end

# Create necessary directories
[DOC_DIR, PDF_DIR, DIRTY_DIR, CLEAN_DIR].each do |d|
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
      puts "Downloading PDF --> #{pdf_loc n}"
      resp = http.get("/#{n}.pdf")
      open pdf_loc(n), 'wb' do |file|
        file.write resp.body
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
  ls = ls.select {|l| l.length > 2 || l == "\n"}

  # Remove day-of-the-week header
  ls.reject! {|l| ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY',
                   'SATURDAY', 'SUNDAY'].any? {|d| l.index(d) == 0}}

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

  # Ensure that there is an empty line between each menu item.
  new_ls = []
  (0..(ls.length-1)).each do |i|
    # We should only insert a newline if one didn't already exist.
    has_space = i == 0 || ls[i-1] == "\n" || ls[i-1].include?("\n\n")

    new_ls << "\n" if !has_space && (item_first_line(ls[i]) || ls[i].include?("Dinner"))
    new_ls << ls[i]
  end
  ls = new_ls

  # Ensure there aren't any extra empty lines in the middle of items.
  new_ls = []
  (0..(ls.length-1)).each do |i|
    is_empty = ls[i] == "\n"

    if !is_empty || (i != ls.length-1 && (item_first_line(ls[i+1]) || ls[i+1].include?("Dinner")))
      new_ls << ls[i]
    end
  end
  ls = new_ls

  # Write the cleaned-up version.
  File.open clean_loc(n), 'w' do |f|
    while l = ls.shift
      f.write l
    end
  end

  puts "#{dirty_loc n} --> #{clean_loc n}"
end


#### Generate formatted versions of the menu for the tumblr.

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
      items << {
        :desc => ([item_ls[0].squeeze('.').split(' - ')[-1].split(' . ')[0]] +
                  item_ls[1..-1]).join(' ').gsub(/\n/, ' ').squeeze(' ').strip,
        :name => item_ls[0].split(' - ')[0],
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
  item_print = proc do |f, item|
    f.write "## #{item[:name]} (#{item[:price]})\n"
    f.write "#{item[:desc]}\n\n"
  end

  File.open blog_loc(n), 'w' do |f|
    f.write "### Lunch\n\n"
    lunch.each {|item| item_print.call(f, item)}
    f.write "### Dinner\n\n"
    dinner.each {|item| item_print.call(f, item)}
  end
end


