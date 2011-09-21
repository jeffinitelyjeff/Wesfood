require 'fileutils'

require 'rubygems'
require 'pony'

require './util'

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
      day_ls = []
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


#### Make a blog-formatted post for each day

Dir["#{TXT_DIR}/*.txt"].each do |d|

  n = d.split('/')[-1].split('.txt')[0]

  ls = []
  File.open txt_loc(n), 'r' do |f|
    while l = f.gets
      ls << l
    end
  end

  # Collect the lunch and dinner items separately.
  lunch_ls = []
  dinner_ls = []
  in_dinner = false
  ls.each do |l|
    in_dinner ||= l.index('Dinner') == 0
    array = in_dinner ? dinner_ls : lunch_ls
    avoid = in_dinner ? "Dinner" : "Lunch"
    # Avoid the 'Dinner - bla bla' and 'Lunch - bla bla'
    if new_menu_item l
      array << l.split(avoid + ' ')[-1].split(avoid)[-1][2..-1]
    else
      array << l
    end
  end

  # Split apart the menu items into their components
  lunch = {}
  dinner = {}
  if !lunch_ls.empty?
    lunch = {
      :main => lunch_ls.reject {|l| l.index('Dessert') == 0 || l == "\n"}.collect {|l| l.strip}.join(''),
      :dessert => lunch_ls.select {|l| l.index('Dessert') == 0}[0].split('Dessert ')[-1].split('Dessert')[-1].strip[2..-1]
    }
  end
  if !dinner_ls.empty?
    dinner = {
      :dessert => dinner_ls.select {|l| l.index('Dessert') == 0}[0].split('Dessert')[-1].split('Dessert')[-1].strip[2..-1]
    }
    # this assumes that when there's no comma separating the salad there are no
    # commas at all. hopefully that'll always be the case.
    if dinner_ls[0].include? ','
      dinner[:salad] = dinner_ls[0].split(',')[0]
      dinner[:main] = (dinner_ls[0].split(',')[1..-1].join(',').strip + ' ' +
        dinner_ls[1..-1].reject {|l| l.index('Dessert') == 0 || l == "\n"}
        .collect {|l| l.strip}.join(' ')).squeeze(' ')
    elsif dinner_ls[0].downcase.include? 'dressing'
      dinner[:salad] = dinner_ls[0].split('Dressing')[0].split('dressing')[0] +
        'Dressing'
      dinner[:main] = dinner_ls[0].split('Dressing')[-1].split('dressing')[-1].strip +
        dinner_ls[1..-1].reject {|l| l.index('Dessert') == 0 || l == "\n"}
        .collect {|l| l.strip}.join(' ').squeeze(' ')
    else
      # just give up and don't provide a salad; if we're this messed up, then
      # the salad will probably just show up in the entree name, which isn't
      # the tend of the world.
      dinner[:salad] = ""
      dinner[:main] = dinner_ls.reject {|l| l.index('Dessert') == 0 || l ==
        "\n"}.collect {|l| l.strip}.join(' ').squeeze(' ')
    end
  end

  yaml = {
    'type' => 'regular',
    'state' => 'queue',
    'format' => 'markdown',
    'tags' => 's+c',
    'slug' => "s-and-c-#{n}",
    'publish-on' => "#{parse_day n, true} 8PM",
    'title' => "S&C - #{parse_day n, false} #{n.gsub('-', '/')}"
  }

  header = "---\n" + yaml.collect {|k,v| "#{k}: #{v}"}.join("\n") + "\n---\n\n"

  content = ""
  if !lunch.empty?
    content += "- - -\n# Lunch\n- - -\n\n"
    content += "**Entree:** #{lunch[:main]}  \n"
    content += "**Dessert:** #{lunch[:dessert]}  \n\n"
  end
  if !dinner.empty?
    content += "- - -\n# Dinner\n- - -\n\n"
    content += "**Salad:** #{dinner[:salad]}  \n"
    content += "**Entree:** #{dinner[:main]}  \n"
    content += "**Dessert:** #{dinner[:dessert]}  \n\n"
  end

  File.open blog_loc(n), 'w' do |f|
    f.write header + content
  end
  puts "#{txt_loc n} --> #{blog_loc n}"
end