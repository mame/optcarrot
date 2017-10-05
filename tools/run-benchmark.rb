require "optparse"
require "csv"

BENCHMARK_DIR = File.join(File.dirname(__dir__), "benchmark")
Dir.mkdir(BENCHMARK_DIR) unless File.exist?(BENCHMARK_DIR)

# Dockerfile generator + helper methods
class DockerImage
  IMAGES = []
  def self.inherited(klass)
    IMAGES << klass
  end

  # default
  FROM = "ruby:2.4"
  APT = []
  URL = nil
  RUN = []
  REWRITE = false
  RUBY = "ruby"
  CMD = "RUBY -v -Ilib -r ./tools/shim bin/optcarrot --benchmark $OPTIONS"

  def self.tag
    name.to_s.downcase
  end

  def self.dockerfile_text
    lines = []
    lines << "FROM " + self::FROM
    lines << "WORKDIR /root"
    apts = [*self::APT]
    apts << "wget" << "bzip2" if self::URL
    if apts.include?("oracle-java8-installer")
      lines <<
        "RUN echo 'deb http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main'" \
          " > /etc/apt/sources.list.d/webupd8team-java.list"
      lines << "RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys EEA14886"
      lines <<
        "RUN echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" \
          " | debconf-set-selections"
      lines << "ENV JAVA_HOME /usr/lib/jvm/java-8-oracle"
    end
    unless apts.empty?
      lines << "RUN apt-get update"
      lines << "RUN apt-get install -y #{ apts * " " }"
    end
    if self::URL
      lines << "RUN wget -q #{ self::URL }"
      lines << "RUN tar xjf #{ File.basename(self::URL) }"
    end
    self::RUN.each {|line| lines << "RUN #{ line }" }
    lines << "ADD . ."
    lines << "RUN ruby tools/rewrite.rb" if self::REWRITE
    lines << "CMD #{ self::CMD.sub("RUBY") { self::RUBY } }"
    lines.join("\n") + "\n"
  end

  def self.dockerfile_path
    File.join(BENCHMARK_DIR, "Dockerfile.#{ tag }")
  end

  def self.create_dockerfile
    File.write(dockerfile_path, dockerfile_text)
  end

  def self.pregenerate
    %w(ppu cpu).each do |type|
      %w(none all).each do |opt|
        out = File.join(BENCHMARK_DIR, "#{ type }-core-opt-#{ opt }.rb")
        next if File.readable?(out)
        optcarrot = File.join(BENCHMARK_DIR, "../bin/optcarrot")
        libpath = File.join(BENCHMARK_DIR, "../lib")
        system("ruby", "-I", libpath, optcarrot, "--opt-#{ type }=#{ opt }", "--dump-#{ type }", out: out)
      end
    end
  end

  def self.build
    create_dockerfile
    pregenerate
    system("docker", "build", "-t", tag, "-f", dockerfile_path, File.dirname(BENCHMARK_DIR))
  end

  def self.run(mode, romfile)
    options = []
    case mode
    when "default"
    when "opt-none"
      options << "--load-ppu=benchmark/ppu-core-opt-none.rb"
      options << "--load-cpu=benchmark/cpu-core-opt-none.rb"
    when "opt-all"
      options << "--load-ppu=benchmark/ppu-core-opt-all.rb"
      options << "--load-cpu=benchmark/cpu-core-opt-all.rb"
    else
      options << mode
    end
    options << romfile

    r, w = IO.pipe
    spawn("docker", "run", "-e", "OPTIONS=" + options.join(" "), "--rm", tag, out: w)
    w.close
    out = r.read

    puts out
    ruby_v, fps, checksum = out.lines.map {|line| line.chomp }
    fps = fps[/^fps: (\d+\.\d+)$/, 1] if fps
    checksum = checksum[/^checksum: (\d+)$/, 1] if checksum

    if fps && checksum
      @ruby_v ||= ruby_v
      @checksum ||= checksum
      raise "ruby version changed: #{ @ruby_v } -> #{ ruby_v }" if @ruby_v != ruby_v
      raise "checksum changed: #{ @checksum } -> #{ checksum }" if @checksum != checksum
      ((@results ||= {})[mode] ||= []) << fps.to_f
    else
      puts "FAILED."
      ((@results ||= {})[mode] ||= []) << nil
    end
  end

  def self.test(cmd = %w(bash))
    system("docker", "run", "--rm", "-ti", tag, *cmd)
  end

  def self.result_line(mode)
    @results ||= {}
    [tag, mode, @ruby_v, @checksum, *@results[mode]]
  end
end

###############################################################################

class Trunk < DockerImage
  APT = "bison"
  RUN = [
    "git clone --depth 1 https://github.com/ruby/ruby.git",
    "cd ruby && autoconf",
    "cd ruby && ./configure --prefix=`pwd`/local",
    "cd ruby && make && make install",
  ]
  RUBY = "ruby/ruby -Iruby"
end

class Ruby24 < DockerImage
  FROM = "ruby:2.4"
end

class Ruby23 < DockerImage
  FROM = "ruby:2.3"
end

class Ruby22 < DockerImage
  FROM = "ruby:2.2-slim"
end

class OMRPreview < DockerImage
  # https://github.com/rubyomr-preview/rubyomr-preview
  FROM = "rubyomrpreview/rubyomrpreview"
  RUBY = "OMR_JIT_OPTIONS='-Xjit' ruby --disable-gems"
end

class Ruby21 < DockerImage
  FROM = "ruby:2.1-slim"
end

class Ruby20 < DockerImage
  FROM = "ruby:2.0-slim"
end

class Ruby193 < DockerImage
  URL = "https://cache.ruby-lang.org/pub/ruby/1.9/ruby-1.9.3-p551.tar.bz2"
  RUN = ["cd ruby*/ && ./configure && make"]
  RUBY = "ruby*/ruby --disable-gems"
end

class Ruby187 < DockerImage
  URL = "https://cache.ruby-lang.org/pub/ruby/1.8/ruby-1.8.7-p374.tar.bz2"
  RUN = ["cd ruby*/ && ./configure && make"]
  REWRITE = true
  RUBY = "ruby*/ruby -v -W0 -I ruby*/lib"
end

class JRuby9k < DockerImage
  FROM = "jruby:9"
  RUBY = "jruby --server -Xcompile.invokedynamic=true"
end

class JRuby9kOracle < DockerImage
  FROM = "jruby:9"
  APT = "oracle-java8-installer"
  RUBY = "jruby --server -Xcompile.invokedynamic=true"
end

class JRuby17 < DockerImage
  FROM = "jruby:1.7"
  RUBY = "jruby --server -Xcompile.invokedynamic=true"
end

class JRuby17Oracle < DockerImage
  FROM = "jruby:1.7"
  APT = "oracle-java8-installer"
  RUBY = "jruby --server -Xcompile.invokedynamic=true"
end

class Rubinius < DockerImage
  FROM = "rubinius/docker"
end

class MRuby < DockerImage
  APT = "bison"
  # rubocop:disable Layout/IndentHeredoc:
  CONFIG = <<-END.lines.map {|l| "echo #{ l.chomp.dump } >> mruby/optcarrot_config.rb" }
MRuby::Build.new do |conf|
  toolchain :gcc
  conf.gembox "default"
  conf.gem core: "mruby-eval"
  conf.gem mgem: "mruby-method"
  conf.gem mgem: "mruby-io"
  conf.gem mgem: "mruby-regexp-pcre"
  conf.gem mgem: "mruby-pack"
end
  END
  # rubocop:enable Layout/IndentHeredoc:
  RUN = [
    "git clone --depth 1 https://github.com/mruby/mruby.git",
    # integer division patch
    "sed -i 's:" \
      "SET_FLOAT_VALUE(mrb, regs\\[a\\], (mrb_float)x / y);:" \
      "SET_INT_VALUE(regs[a], x / y);:' mruby/src/vm.c",
    *CONFIG,
    "cd mruby && MRUBY_CONFIG=optcarrot_config.rb ./minirake",
  ]
  CMD = "mruby/bin/mruby --version && mruby/bin/mruby tools/shim.rb --benchmark $OPTIONS"
end

class Topaz < DockerImage
  URL = "http://builds.topazruby.com/topaz-linux64-019daf03d75e32124c2dfd282915b49c35f27289.tar.bz2"
  RUBY = "topaz/bin/topaz"
end

class Opal < DockerImage
  APT = "nodejs-legacy"
  RUN = [
    "gem install opal",
  ]
  REWRITE = true
  CMD = "opal -v -I . -r ./tools/shim.rb bin/optcarrot -- --benchmark -f 60 $OPTIONS"
end

###############################################################################

# A simple command-line interface
class CLI
  def initialize
    # default
    @mode = "default"
    @count = 1
    @romfile = "examples/Lan_Master.nes"

    o = OptionParser.new
    o.on("-m=MODE", "mode (default/opt-none/opt-all/all/each)") {|v| @mode = v }
    o.on("-c=NUM", Integer, "iteration count") {|v| @count = v }
    o.on("-r=FILE", String, "rom file") {|v| @romfile = v }
    o.separator("")
    o.separator("Examples:")
    o.separator("  ruby tools/run-benchmark.rb ruby23 -m=all      " \
                "# run ruby23 (default mode, opt-none mode, opt-all mode)")
    o.separator("  ruby tools/run-benchmark.rb ruby23             # run ruby23 (default mode)")
    o.separator("  ruby tools/run-benchmark.rb ruby23 -m=opt-none # run ruby23 (opt-none mode)")
    o.separator("  ruby tools/run-benchmark.rb ruby23 -m=opt-all  # run ruby23 (opt-all mode)")
    o.separator("  ruby tools/run-benchmark.rb all -m=all         # run all (default mode)")
    o.separator("  ruby tools/run-benchmark.rb all -c 30 -m=all   # run all (default mode) (30 times for each image)")
    o.separator("  ruby tools/run-benchmark.rb not,trunk,ruby23   # run all but trunk and ruby23")
    o.separator("  ruby tools/run-benchmark.rb ruby23 bash        # custom command")
    o.separator("  ruby tools/run-benchmark.rb -r foo.nes ruby23")

    @argv = o.parse(ARGV)

    if @argv.empty?
      print o.help
      exit
    end

    @tags = @argv.shift.split(",")
    @tags = DockerImage::IMAGES.map {|img| img.tag } if @tags == %w(all)
    @tags = DockerImage::IMAGES.map {|img| img.tag } - @tags[1..-1] if @tags.first == "not"
  end

  def main
    if @argv.empty?
      run_benchmark
    else
      run_test
    end
  end

  def run_benchmark
    @out = File.join(BENCHMARK_DIR, Time.now.strftime("bm-%Y%m%d%H%M%S.csv"))
    each_target_image do |img|
      banner("build #{ img.tag }")
      img.build
    end
    @count.times do |i|
      each_mode do |mode|
        each_target_image do |img|
          banner("measure #{ img.tag } / #{ mode } (#{ i + 1 } / #{ @count })")
          img.run(mode, @romfile)
          save_csv
        end
      end
    end
  end

  def run_test
    raise "you must specify one tag or test-run" if @tags.size >= 2
    each_target_image do |img|
      banner("build #{ img.tag }")
      img.build
      banner("run #{ img.tag }")
      img.test(@argv)
    end
  end

  def each_target_image
    DockerImage::IMAGES.each do |img|
      next unless @tags.include?(img.tag)
      yield img
    end
  end

  def each_mode
    if @mode == "each"
      opt_ppu = []
      %w(
        none
        method_inlining
        ivar_localization
        split_show_mode
        split_a12_checks
        fastpath
        batch_render_pixels
        clock_specialization
      ).each do |opt|
        opt_ppu << opt
        yield "--opt-ppu=#{ opt_ppu.join(",") }"
        opt_ppu.clear if opt_ppu == ["none"]
      end

      opt_cpu = []
      %w(
        none
        method_inlining
        constant_inlining
        ivar_localization
        trivial_branches
      ).each do |opt|
        opt_cpu << opt
        yield "--opt-ppu=#{ opt_ppu.join(",") } --opt-cpu=#{ opt_cpu.join(",") }"
        opt_cpu.clear if opt_cpu == ["none"]
      end
    else
      %w(default opt-none opt-all).each do |mode|
        next unless @mode == mode || @mode == "all"
        yield mode
      end
    end
  end

  def banner(msg)
    puts "+" + "-" * (msg.size + 2) + "+"
    puts "| #{ msg } |"
    puts "+" + "-" * (msg.size + 2) + "+"
  end

  def save_csv
    CSV.open(@out, "w") do |csv|
      csv << ["name", "mode", "ruby -v", "checksum", *(1..@count).map {|i| "run #{ i }" }]
      each_mode do |mode|
        each_target_image do |img|
          csv << img.result_line(mode)
        end
      end
    end

    link = File.join(BENCHMARK_DIR, "bm-latest.csv")
    File.unlink(link) if File.exist?(link)
    File.symlink(@out, link)
  end
end

CLI.new.main
