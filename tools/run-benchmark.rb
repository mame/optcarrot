require "optparse"
require "csv"

BENCHMARK_DIR = File.join(File.dirname(__dir__), "benchmark")
Dir.mkdir(BENCHMARK_DIR) unless File.exist?(BENCHMARK_DIR)

# Dockerfile generator + helper methods
class DockerImage
  IMAGES = []
  def self.inherited(klass)
    IMAGES << klass
    super
  end

  # default
  FROM = "ruby:2.7"
  APT = []
  URL = nil
  RUN = []
  REWRITE = false
  RUBY = "ruby"
  CMD = "RUBY -v -Ilib -r ./tools/shim bin/optcarrot --benchmark $OPTIONS"
  SUPPORTED_MODE = :any
  SLOW = false

  def self.tag
    name.to_s.downcase
  end

  def self.fast?
    !self::SLOW
  end

  def self.dockerfile_text
    lines = []
    lines << "FROM " + self::FROM
    lines << "WORKDIR /root"
    apts = [*self::APT]
    apts << "wget" << "bzip2" if self::URL
    unless apts.empty?
      lines << "RUN apt-get update"
      lines << "RUN apt-get install -y #{ apts * " " }"
    end
    if self::URL
      lines << "RUN wget -q #{ self::URL }"
      lines << "RUN tar xf #{ File.basename(self::URL) }"
    end
    self::RUN.each do |line|
      lines << (line.is_a?(Array) && line[0] == :add ? "ADD #{ line.drop(1).join(" ") }" : "RUN #{ line }")
    end
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
    system("docker", "build", "-t", tag, "-f", dockerfile_path, File.dirname(BENCHMARK_DIR)) || raise
  end

  def self.run(mode, romfile, target_frame: nil, history: false)
    if self::SUPPORTED_MODE != :any && !self::SUPPORTED_MODE.include?(mode)
      puts "#{ tag } does not support the mode `#{ mode }'"
      ((@results ||= {})[mode] ||= []) << nil
      return
    end

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
    options << "--frames #{ target_frame }" if target_frame
    options << "--print-fps-history" if history
    options << romfile

    r, w = IO.pipe
    now = Time.now
    spawn(
      "docker", "run", "--security-opt=seccomp=unconfined", "-e", "OPTIONS=" + options.join(" "), "--rm", tag, out: w
    )
    w.close
    out = r.read
    elapsed = Time.now - now

    ((@elapsed_time ||= {})[mode] ||= []) << elapsed

    ruby_v, *fps_history, fps, checksum = out.lines.map {|line| line.chomp }
    if history && !fps_history.empty?
      raise "fps history broken: #{ fps_history.first }" unless fps_history.first.start_with?("frame,")
      fps_history.shift
      ((@fps_histories ||= {})[mode] ||= []) << fps_history.map {|s| s.split(",")[1].to_f }
    end
    puts ruby_v, fps, checksum
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
    system("docker", "run", "--rm", "-ti", tag, *cmd) || raise
  end

  def self.result_line(mode)
    @results ||= {}
    [tag, mode, @ruby_v, @checksum, *@results[mode]]
  end

  def self.elapsed_time(mode)
    @elapsed_time ||= {}
    [tag, mode, @ruby_v, @checksum, *@elapsed_time[mode]]
  end

  def self.fps_history(mode, count)
    @fps_histories ||= {}
    fps_history = (@fps_histories[mode] ||= [])[count]
    [tag, *fps_history]
  end
end

###############################################################################

# https://github.com/rbenv/ruby-build/wiki
MASTER_APT = %w(
  autoconf bison build-essential libssl-dev libyaml-dev libreadline6-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm6
  libgdbm-dev libdb-dev git ruby
)

class MasterMJIT < DockerImage
  FROM = "ubuntu:20.04"
  APT = MASTER_APT
  RUN = [
    "git clone --depth 1 https://github.com/ruby/ruby.git",
    "cd ruby && autoconf",
    "cd ruby && ./configure --prefix=`pwd`/local cppflags=-DNDEBUG",
    "cd ruby && make && make install",
  ]
  RUBY = "ruby/ruby --jit -Iruby"
end

class Ruby30MJIT < DockerImage
  FROM = "rubylang/ruby:3.0-focal"
  RUBY = "ruby --jit"
end

class Ruby27MJIT < DockerImage
  FROM = "ruby:2.7"
  RUBY = "ruby --jit"
end

class Ruby26MJIT < DockerImage
  FROM = "ruby:2.6"
  RUBY = "ruby --jit"
end

class Master < DockerImage
  FROM = "ubuntu:20.04"
  APT = MASTER_APT
  RUN = [
    "git clone --depth 1 https://github.com/ruby/ruby.git",
    "cd ruby && autoconf",
    "cd ruby && ./configure --prefix=`pwd`/local cppflags=-DNDEBUG",
    "cd ruby && make && make install",
  ]
  RUBY = "ruby/ruby -Iruby"
end

class Ruby30 < DockerImage
  FROM = "rubylang/ruby:3.0-focal"
end

class Ruby27 < DockerImage
  FROM = "ruby:2.7"
end

class Ruby26 < DockerImage
  FROM = "ruby:2.6"
end

class Ruby25 < DockerImage
  FROM = "ruby:2.5"
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

class Ruby21 < DockerImage
  FROM = "ruby:2.1-slim"
end

class Ruby20 < DockerImage
  FROM = "ruby:2.0-slim"
end

class Ruby193 < DockerImage
  URL = "https://cache.ruby-lang.org/pub/ruby/1.9/ruby-1.9.3-p551.tar.bz2"
  RUN = ["cd ruby*/ && ./configure && make ruby"]
  RUBY = "ruby*/ruby --disable-gems"
  SLOW = true
end

class Ruby187 < DockerImage
  URL = "https://cache.ruby-lang.org/pub/ruby/1.8/ruby-1.8.7-p374.tar.bz2"
  RUN = ["cd ruby*/ && ./configure && make ruby"]
  REWRITE = true
  RUBY = "ruby*/ruby -v -W0 -I ruby*/lib"
  SLOW = true
end

class TruffleRuby < DockerImage
  URL = "https://github.com/graalvm/graalvm-ce-builds/releases/download/vm-20.1.0/graalvm-ce-java8-linux-amd64-20.1.0.tar.gz"
  FROM = "buildpack-deps:focal"
  RUN = ["cd graalvm-* && bin/gu install ruby"]
  RUBY = "graalvm-*/bin/ruby --jvm"
  SUPPORTED_MODE = %w(default)
end

class JRuby < DockerImage
  FROM = "jruby:9"
  RUBY = "jruby -Xcompile.invokedynamic=true"
  SLOW = true
end

class Rubinius < DockerImage
  FROM = "rubinius/docker"
  SLOW = true
end

class MRuby < DockerImage
  FROM = "buildpack-deps:focal"
  APT = %w(bison ruby)
  RUN = [
    "git clone --depth 1 https://github.com/mruby/mruby.git",
    [:add, "tools/mruby_optcarrot_config.rb", "mruby/"],
    "cd mruby && MRUBY_CONFIG=mruby_optcarrot_config.rb ./minirake",
  ]
  CMD = "mruby/bin/mruby --version && mruby/bin/mruby tools/shim.rb --benchmark $OPTIONS"
  SLOW = true
end

class Topaz < DockerImage
  URL = "http://builds.topazruby.com/topaz-linux64-9287c22053d4b2b5f97fa1c65d7d04d5826f9c89.tar.bz2"
  RUBY = "topaz/bin/topaz"
end

class Opal < DockerImage
  APT = "nodejs"
  RUN = [
    "gem install opal",
  ]
  REWRITE = true
  CMD = "opal -v -I . -r ./tools/shim.rb bin/optcarrot -- --benchmark -f 60 $OPTIONS"
  SLOW = true
end

# class Artichoke < DockerImage
#   APT = %w(llvm clang bison ruby)
#   FROM = "rustlang/rust:nightly-buster"
#   RUN = [
#     "git clone --depth 1 https://github.com/artichoke/artichoke.git",
#     "cd artichoke && cargo build --release",
#   ]
#   CMD = "artichoke/target/release/artichoke -V && " +
#         "artichoke/target/release/artichoke bin/optcarrot --benchmark $OPTIONS"
# end

class RuRuby < DockerImage
  FROM = "rustlang/rust:nightly-buster"
  RUN = [
    "git clone --depth 1 https://github.com/sisshiki1969/ruruby.git",
    "cd ruruby && cargo build --release",
  ]
  CMD = "git -C ruruby/ rev-parse HEAD && ruruby/target/release/ruruby bin/optcarrot --benchmark $OPTIONS"
end

###############################################################################

# A simple command-line interface
class CLI
  def initialize
    # default
    @mode = "default"
    @count = 1
    @romfile = "examples/Lan_Master.nes"
    @history = nil

    o = OptionParser.new
    o.on("-m MODE", "mode (default/opt-none/opt-all/all/each)") {|v| @mode = v }
    o.on("-c NUM", Integer, "iteration count") {|v| @count = v }
    o.on("-r FILE", String, "rom file") {|v| @romfile = v }
    o.on("-f FRAME", Integer, "target frame") {|v| @target_frame = v }
    o.on("-h", Integer, "fps history mode") {|v| @history = v }
    o.separator("")
    o.separator("Examples:")
    latest = DockerImage::IMAGES.find {|n| !n.tag.start_with?("master") && !n.tag.include?("mjit") }.tag
    o.separator("  ruby tools/run-benchmark.rb #{ latest } -m all       " \
                "# run #{ latest } (default mode, opt-none mode, opt-all mode)")
    o.separator("  ruby tools/run-benchmark.rb #{ latest }              # run #{ latest } (default mode)")
    o.separator("  ruby tools/run-benchmark.rb #{ latest } -m opt-none  # run #{ latest } (opt-none mode)")
    o.separator("  ruby tools/run-benchmark.rb #{ latest } -m opt-all   # run #{ latest } (opt-all mode)")
    o.separator("  ruby tools/run-benchmark.rb all -m all          # run all (default mode)")
    o.separator("  ruby tools/run-benchmark.rb all -c 30 -m all    # run all (default mode) (30 times for each image)")
    o.separator("  ruby tools/run-benchmark.rb not,master,#{ latest }   # run all but master and #{ latest }")
    o.separator("  ruby tools/run-benchmark.rb #{ latest } bash         # custom command")
    o.separator("  ruby tools/run-benchmark.rb -r foo.nes #{ latest }")

    @argv = o.parse(ARGV)

    if @argv.empty?
      print o.help
      exit
    end

    @tags = @argv.shift.split(",")
    @tags = DockerImage::IMAGES.map {|img| img.tag } if @tags == %w(all)
    @tags = DockerImage::IMAGES.map {|img| img.tag if img.fast? }.compact if @tags == %w(fastimpls)
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
    @timestamp = Time.now.strftime("%Y%m%d%H%M%S")
    each_target_image do |img|
      banner("build #{ img.tag }")
      img.build
    end
    @count.times do |i|
      each_mode do |mode|
        each_target_image do |img|
          banner("measure #{ img.tag } / #{ mode } (#{ i + 1 } / #{ @count })")
          img.run(mode, @romfile, target_frame: @target_frame, history: @history)
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
    out = File.join(BENCHMARK_DIR, "#{ @timestamp }-oneshot-#{ @target_frame || 180 }.csv")
    CSV.open(out, "w") do |csv|
      csv << ["name", "mode", "ruby -v", "checksum", *(1..@count).map {|i| "run #{ i }" }]
      each_mode do |mode|
        each_target_image do |img|
          csv << img.result_line(mode)
        end
      end
    end

    out = File.join(BENCHMARK_DIR, "#{ @timestamp }-elapsed-time-#{ @target_frame || 180 }.csv")
    CSV.open(out, "w") do |csv|
      csv << ["name", "mode", "ruby -v", "checksum", *(1..@count).map {|i| "run #{ i }" }]
      each_mode do |mode|
        each_target_image do |img|
          csv << img.elapsed_time(mode)
        end
      end
    end

    return unless @history

    each_mode do |mode|
      @count.times do |i|
        out = File.join(BENCHMARK_DIR, "#{ @timestamp }-fps-history-#{ mode }-#{ i + 1 }.csv")
        CSV.open(out, "w") do |csv|
          columns = []
          each_target_image do |img|
            fps_history = img.fps_history(mode, i)
            fps_history << nil until fps_history.size == @history + 1
            columns << fps_history
          end
          columns.unshift(["frame", *(1..@history)])
          columns.transpose.each do |row|
            csv << row
          end
        end
      end
    end
  end
end

CLI.new.main
