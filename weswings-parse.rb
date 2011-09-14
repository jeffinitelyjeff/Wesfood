require 'rubygems'
require 'Docsplit'

def pdf_to_txt(n)
  Docsplit.extract_text(Dir["pdf/#{n}.pdf"], :output => "txt/")
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
        ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
         "Sunday"].collect{|d| d + "\n"}.include? l
      end.each do |l|
        if l == "Dinner Entrees\n" || l == "Lunch Specials\n"
          in_dinner = l == "Dinner Entrees\n"
        elsif l == "\n"
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
  desc = ([lines[0].squeeze(".").split(" - ")[1].split(" . ")[0]] +
          lines[1..-1]).join(" ").gsub(/\n/, " ").squeeze(" ").strip
  return {
    :name => lines[0].split(" - ")[0],
    :price => lines[0].split("$")[1].to_f,
    :desc => desc
  }
end

# FIXME - pull PDF, set PDF filename
name = "weswings-9-12-11"
pdf_to_txt name
items = gather_items_from_txt name
items.each {|i| puts "#{i[:name]} ($#{i[:price]}) for #{i[:meal]}"}



