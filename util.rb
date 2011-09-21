def parse_day(date, prev)
  m = date.split('-')[0].to_i
  d = date.split('-')[1].to_i
  y = date.split('-')[2].to_i + 2000
  t = Time.utc(y, m, d, 0, 0, 0, 0)
  wd = prev ? (t.wday - 1) % 7 : t.wday

  ['Sunday', 'Monday', 'Tuesday', 'Wednesday',
   'Thursday', 'Friday', 'Saturday'][wd]
end
