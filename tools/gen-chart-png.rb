%w(optimized default).zip(ARGF.read.scan(%r{^data:image/png;base64,(.*)$})) do |name, data|
  name = "doc/benchmark-#{ name }.png"
  data = data[0].unpack("m")[0]
  File.binwrite(name, data)
  system("optipng", "-fix", "-i0", "-o7", "-strip", "all", name)
  system("advdef", "-z4", name)
  system("advpng", "-z4", name)
end
