MRuby::Build.new do |conf|
  toolchain :gcc
  conf.cc.flags << "-DMRB_WITHOUT_FLOAT"
  conf.gem core: "mruby-print"
  conf.gem core: "mruby-struct"
  conf.gem core: "mruby-string-ext"
  conf.gem core: "mruby-hash-ext"
  conf.gem core: "mruby-fiber"
  conf.gem core: "mruby-enumerator"
  conf.gem core: "mruby-bin-mruby"
  conf.gem core: "mruby-kernel-ext"
  conf.gem core: "mruby-eval"
  conf.gem core: "mruby-io"
  conf.gem core: "mruby-pack"
  conf.gem mgem: "mruby-gettimeofday"
  conf.gem mgem: "mruby-method"
  conf.gem mgem: "mruby-regexp-pcre"
end
