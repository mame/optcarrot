MRuby::Build.new do |conf|
  toolchain :gcc
  conf.gembox "default"
  conf.gem mgem: "mruby-gettimeofday"
  conf.gem mgem: "mruby-regexp-pcre"
end
