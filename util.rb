# Determines the day of the week from input like `9-17-11`. If `:prev` is true, then
# will return the previous day of the week.
def parse_day(date, o = {})
  prev = o[:prev] || false
  # Make sure we're dealing with `9-17-11`, not `9/17/11`
  date = date.gsub '/', '-' if date.include? '/'
  m = date.split('-')[0].to_i
  d = date.split('-')[1].to_i
  y = date.split('-')[2].to_i + 2000
  t = Time.utc(y, m, d, 0, 0, 0, 0)
  wd = prev ? (t.wday - 1) % 7 : t.wday

  ['Sunday', 'Monday', 'Tuesday', 'Wednesday',
   'Thursday', 'Friday', 'Saturday'][wd]
end

def header(s)
  "- - -\n# #{s}\n- - -\n\n"
end
