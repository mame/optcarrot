# typed: true

module Optcarrot
  module Driver
    sig { params(colors: T::Array[T::Array[Integer]], limit: Integer).returns([T::Array[Integer], T::Array[T::Array[Integer]]]) }
    def self.quantize_colors(colors, limit = 256); end

    sig { params(colors: T::Array[T.untyped]).void }
    def self.cutoff_overscan(colors); end

    sig { params(colors: T::Array[T.untyped], fps: Integer, palette: T::Array[T.untyped], blk: T.nilable(T.proc.params(c: T.untyped).returns(T.untyped))).void }
    def self.show_fps(colors, fps, palette, &blk); end

    sig { returns([Integer, Integer, T.untyped]) }
    def self.icon_data; end
  end
end
