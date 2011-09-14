require 'rubygems'
require 'Docsplit'

# FIXME - pull PDF, set PDF filename
name = "weswings-9-12-11"

Docsplit.extract_text(Dir["pdf/#{name}.pdf"], :output => "txt/")

begin
  File.open("txt/#{name}.txt", "r") do |f|
    ls = []
    while l = f.gets do ls << l end

    lunch = []
    dinner = []
    in_dinner = false
    entree = []

    ls.reject do |l|
      ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
       "Sunday"].collect{ |d| d + "\n" }.include? l
    end.each do |l|
      if l == "Dinner Entrees\n" || l == "Lunch Specials\n"
        in_dinner = l == "Dinner Entrees\n"
      elsif l == "\n"
        ( in_dinner ? dinner : lunch ) << entree
        entree = []
      else
        entree << l
      end
    end

    puts "LUNCH TIME"
    puts lunch
    puts "DINNER TIME"
    puts dinner
  end
rescue => err
  puts "Exception: #{err}"
end
