# typed: true
module Optcarrot
  # Audio output driver saving a WAV file
  class WAVAudio < Audio
    extend T::Sig

    sig { params(conf: Config).void }
    def initialize(conf)
      @buff = T.let([], T::Array[Integer])
      super
    end

    sig { void }
    def init
      @buff = []
    end

    sig { void }
    def dispose
      buff = @buff.pack(@pack_format)
      wav = [
        "RIFF", 44 + buff.bytesize, "WAVE", "fmt ", 16, 1, 1,
        @rate, @rate * @bits / 8, @bits / 8, @bits, "data", buff.bytesize, buff
      ].pack("A4VA4A4VvvVVvvA4VA*")
      File.binwrite("audio.wav", wav)
    end

    sig { params(output: T.untyped).void }
    def tick(output)
      @buff.concat output
    end
  end
end
