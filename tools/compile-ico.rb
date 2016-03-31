require "chunky_png"

dat = []
png = ChunkyPNG::Image.from_file(ARGV[0])
png.height.times do |y|
  png.width.times do |x|
    clr = "%02x%02x%02x%02x" % [
      ChunkyPNG::Color.a(png[x, y]),
      ChunkyPNG::Color.b(png[x, y]),
      ChunkyPNG::Color.g(png[x, y]),
      ChunkyPNG::Color.r(png[x, y]),
    ]
    dat << clr.hex
  end
end

offset = 35
palette = dat.sort.uniq
dat = dat.map {|clr| palette.index(clr) + offset }.pack("C*")
tbl = ""
(palette.size + offset).upto(256) do |c|
  count = Hash.new(0)
  dat.chars.each_cons(2) {|a| count[a.join] += 1 }
  max = count.values.max
  break if max == 2
  k, = count.find {|_, v| v == max }
  tbl = k + tbl
  dat = dat.gsub(k, c.chr)
end

code = DATA.read
code.sub!("PALETTE") { "[#{ palette.map {|clr| "0x%08x" % clr }.join(", ") }]" }
code.sub!("STR") { dat.dump }
code.sub!("NUM") { tbl.size / 2 + palette.size + offset - 1 }
code.sub!("TBL") { tbl.dump }
code.sub!("OFFSET") { offset }
puts code

__END__
palette = PALETTE
dat = STR
i = NUM
TBL.scan(/../) do
  dat = dat.gsub(i.chr, $&)
  i -= 1
end
ICO = dat.bytes.map {|clr| palette[clr - OFFSET] }
