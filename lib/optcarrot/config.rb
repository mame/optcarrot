module Optcarrot
  # config manager and logger
  class Config
    OPTIONS = {
      emulation: {
        sprite_limit:      { type: :switch, desc: "enable/disable sprite limit", default: false },
        frames:            { type: :int, desc: "execute N frames (0 = no limit)", default: 0, aliases: [:f, :frame] },
        audio_sample_rate: { type: :int, desc: "set audio sample rate", default: 44100 },
        audio_bit_depth:   { type: :int, desc: "set audio bit depth", default: 16 },
        nestopia_palette:  { type: :switch, desc: "use Nestopia palette instead of de facto", default: false },
      },
      driver: {
        video:  { type: :driver, desc: "select video driver", candidates: [] }, # Driver::DRIVER_DB[:video].keys
        audio:  { type: :driver, desc: "select audio driver", candidates: [] }, # Driver::DRIVER_DB[:audio].keys
        input:  { type: :driver, desc: "select input driver", candidates: [] }, # Driver::DRIVER_DB[:input].keys
        list_drivers: { type: :info, desc: "print available drivers" },
        sdl2:      { shortcut: %w(--video=sdl2 --audio=sdl2 --input=sdl2) },
        sfml:      { shortcut: %w(--video=sfml --audio=sfml --input=sfml) },
        headless:  { shortcut: %w(--video=none --audio=none --input=none) },
        video_output: { type: "FILE", desc: "save video to file", default: "video.EXT" },
        audio_output: { type: "FILE", desc: "save audio to file", default: "audio.wav" },
        show_fps: { type: :switch, desc: "show fps in the right-bottom corner", default: true },
        key_log: { type: "FILE", desc: "use recorded input file" },
        # key_config: { type: "KEY", desc: "key configuration" },
      },
      profiling: {
        print_fps: { type: :switch, desc: "print fps of last 10 frames", default: false },
        print_p95fps: { type: :switch, desc: "print 95th percentile fps", default: false },
        print_fps_history: { type: :switch, desc: "print all fps values for each frame", default: false },
        print_video_checksum: { type: :switch, desc: "print checksum of the last video output", default: false },
        stackprof: { shortcut: "--stackprof-mode=cpu", aliases: :p },
        stackprof_mode: { type: "MODE", desc: "run under stackprof", default: nil },
        stackprof_output: { type: "FILE", desc: "stackprof output file", default: "stackprof-MODE.dump" }
      },
      misc: {
        benchmark: { shortcut: %w(--headless --print-fps --print-video-checksum --frames 180), aliases: :b },
        loglevel: { type: :int, desc: "set loglevel", default: 1 },
        quiet:    { shortcut: "--loglevel=0", aliases: :q },
        verbose:  { shortcut: "--loglevel=2", aliases: :v },
        debug:    { shortcut: "--loglevel=3", aliases: :d },
        version: { type: :info, desc: "print version" },
        help:    { type: :info, desc: "print this message", aliases: :h },
      },
    }

    DEFAULT_OPTIONS = {
      sprite_limit:         false,
      frames:               0,
      audio_sample_rate:    44100,
      audio_bit_depth:      16,
      nestopia_palette:     false,
      video_output:         "video.EXT",
      audio_output:         "audio.wav",
      show_fps:             true,
      print_fps:            false,
      print_p95fps:         false,
      print_fps_history:    false,
      print_video_checksum: false,
      stackprof_mode:       nil,
      stackprof_output:     "stackprof-MODE.dump",
      loglevel:             1,
    }.freeze

    attr_reader :romfile,
                :sprite_limit, :frames,
                :audio_sample_rate, :audio_bit_depth, :nestopia_palette,
                :video, :audio, :input,
                :video_output, :audio_output, :show_fps, :key_log,
                :print_fps, :print_p95fps, :print_fps_history, :print_video_checksum,
                :stackprof_mode, :stackprof_output,
                :loglevel

    def initialize(opt)
      opt = { romfile: opt } if opt.is_a?(String)
      opt = Parser.new(opt).options if opt.is_a?(Array)
      opt = DEFAULT_OPTIONS.merge(opt)
      # `.to_s` / `.to_i` / `!!` casts pin each ivar to a single
      # type for AOT type inference; Ruby semantics are preserved
      # because every value coming in via DEFAULT_OPTIONS / Parser
      # already has the matching shape.
      @romfile              = opt[:romfile].to_s
      @sprite_limit         = !!opt[:sprite_limit]
      @frames               = opt[:frames].to_i
      @audio_sample_rate    = opt[:audio_sample_rate].to_i
      @audio_bit_depth      = opt[:audio_bit_depth].to_i
      @nestopia_palette     = !!opt[:nestopia_palette]
      @video                = opt[:video]
      @audio                = opt[:audio]
      @input                = opt[:input]
      @video_output         = opt[:video_output]
      @audio_output         = opt[:audio_output]
      @show_fps             = !!opt[:show_fps]
      @key_log              = opt[:key_log]
      @print_fps            = !!opt[:print_fps]
      @print_p95fps         = !!opt[:print_p95fps]
      @print_fps_history    = !!opt[:print_fps_history]
      @print_video_checksum = !!opt[:print_video_checksum]
      # Pin to nil so spinel-aot static-fold knows `if @conf.stackprof_mode`
      # is dead.  The CLI parser path does not run StackProf in spinel-aot.
      @stackprof_mode       = nil # opt[:stackprof_mode]
      @stackprof_output     = nil # opt[:stackprof_output]
      @loglevel             = opt[:loglevel].to_i
    end

    def debug(msg)
      puts "[DEBUG] " + msg if @loglevel >= 3
    end

    def info(msg)
      puts "[INFO] " + msg if @loglevel >= 2
    end

    def warn(msg)
      puts "[WARN] " + msg.to_s if @loglevel >= 1
    end

    def error(msg)
      puts "[ERROR] " + msg.to_s
    end

    def fatal(msg)
      puts "[FATAL] " + msg
      abort
    end

    # command-line option parser.  Trimmed-down form for spinel-aot:
    # handles the bin/optcarrot-bench style invocation (`-b ROM`,
    # `--no-X` switches, `--frames=N`, bare ROM path).  Plain Ruby
    # uses this same trimmed Parser too (so any CLI feature relying
    # on `-Xy` chained shorts, `--driver=name` validation, or `-h` /
    # `-v` info handlers is no longer available — those weren't
    # exercised by the standard `bin/optcarrot --frames=N path`
    # workflow).
    class Parser
      attr_reader :options

      def initialize(argv)
        @options = {}
        DEFAULT_OPTIONS.each {|k, v| @options[k] = v }
        # Pre-scan for `-b` / `--benchmark`: apply the shortcut as
        # defaults *before* processing the rest of argv, so later flags
        # (e.g. `--frames=3000`, `--no-print-video-checksum`) can
        # override.  The original optcarrot Parser achieves this via
        # `@argv.unshift(*opt[:shortcut])`; the inline pre-scan is the
        # spinel-friendly equivalent.
        argv.each do |a|
          if a == "-b" || a == "--benchmark"
            @options[:headless] = true
            @options[:print_fps] = true
            @options[:print_video_checksum] = true
            @options[:frames] = 180
          end
        end
        i = 0
        while i < argv.length
          a = argv[i].to_s
          if a == "-b" || a == "--benchmark"
            # already applied as defaults above
          elsif a.start_with?("--no-")
            sym = a[5, a.length - 5].tr("-", "_").to_sym
            @options[sym] = false
          elsif a.start_with?("--")
            # `--X=Y` or `--X Y` (operand on next arg).  Default to
            # treating value as String / Integer based on the existing
            # default in DEFAULT_OPTIONS.  spinel-aot's String#index
            # returns -1 (not nil) on no match; coerce to a single
            # Integer domain (`|| -1` is a no-op there but normalises
            # CRuby's nil to -1) and branch on `eq >= 0`.
            eq = a.index("=") || -1
            if eq >= 0
              key = a[2, eq - 2].tr("-", "_").to_sym
              val = a[(eq + 1), a.length - eq - 1]
            else
              key = a[2, a.length - 2].tr("-", "_").to_sym
              # Boolean switch (default true/false) takes no argument;
              # otherwise consume the next argv element as the value.
              cur0 = @options[key]
              if cur0 == true || cur0 == false
                val = nil
              else
                i += 1
                val = i < argv.length ? argv[i].to_s : ""
              end
            end
            current = @options[key]
            if current == true || current == false
              @options[key] = true
            elsif current.is_a?(Integer)
              @options[key] = val.to_i
            else
              @options[key] = val
            end
          elsif a.start_with?("-")
            # Unknown short flag — ignored under spinel-aot.
          else
            @options[:romfile] = a
          end
          i += 1
        end
      end

      # The original Parser had `help` / `version` / `list_drivers` /
      # `list_opts` / `dump_ppu` / `dump_cpu` info methods routed via
      # `:info`-typed options.  spinel-aot doesnt route through those
      # paths and the bodies use class-level meta-programming (poly
      # iteration, OptimizedCodeBuilder.new dispatch) that spinel
      # cant lower.  They are dropped from the for-spinel branch.
    end
  end
end
