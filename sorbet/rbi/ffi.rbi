# typed: true

module FFI
  module Library
    sig { params(args: T.untyped).void }
    def ffi_lib(*args); end

    sig { params(args: T.untyped, opts: T.untyped).void }
    def attach_function(*args, **opts); end
  end

  class Struct
    sig { params(args: T.untyped).void }
    def self.layout(*args); end

    sig { returns(T.untyped) }
    def self.by_value; end

    sig { returns(T.untyped) }
    def self.by_ref; end

    sig { returns(T.untyped) }
    def self.ptr; end

    sig { params(member: Symbol).returns(Integer) }
    def self.offset_of(member); end

    sig { params(key: Symbol).returns(T.untyped) }
    def [](key); end

    sig { params(key: Symbol, value: T.untyped).void }
    def []=(key, value); end
  end

  class MemoryPointer
    sig { params(type: Symbol, count: Integer).returns(FFI::MemoryPointer) }
    def self.new(type, count = 1); end

    sig { params(bytes: String).returns(T.untyped) }
    def write_bytes(bytes); end

    sig { params(value: Integer).void }
    def write_int32(value); end

    sig { params(value: Integer).void }
    def write_int16(value); end

    sig { params(length: Integer).returns(String) }
    def read_bytes(length); end

    sig { returns(Integer) }
    def read_int; end

    sig { params(offset: Integer).returns(Integer) }
    def get_uint8(offset); end

    sig { params(offset: Integer).returns(Integer) }
    def get_int(offset); end

    sig { params(offset: Integer).returns(Integer) }
    def get_uint32(offset); end

    sig { params(offset: Integer).returns(Integer) }
    def get_int16(offset); end

    sig { params(values: T::Array[Integer]).void }
    def write_array_of_uint32(values); end

    sig { params(str: String, len: Integer).void }
    def write_string_length(str, len); end

    sig { params(offset: Integer, str: String).void }
    def put_string(offset, str); end

    sig { void }
    def clear; end
  end

  class Function
    sig { params(args: T.untyped, opts: T.untyped).returns(T.untyped) }
    def self.new(*args, **opts); end
  end
end
