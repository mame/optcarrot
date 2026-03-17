# typed: true

module Optcarrot
  # Interface for objects that can be used as CPU memory peek handlers.
  # Both Array[Integer] (for RAM) and Method (for mapped I/O) satisfy this.
  module Fetchable
    extend T::Sig
    extend T::Helpers
    interface!

    sig { abstract.params(addr: Integer).returns(Integer) }
    def [](addr); end
  end

  # Interface for objects that can be used as CPU memory poke handlers.
  # Method objects (for mapped I/O writes) satisfy this.
  module Storable
    extend T::Sig
    extend T::Helpers
    interface!

    sig { abstract.params(addr: Integer, value: Integer).void }
    def [](addr, value); end
  end
end

# Monkey-patch built-in classes to include the interfaces
class Array
  include Optcarrot::Fetchable
end

class Method
  include Optcarrot::Fetchable
  include Optcarrot::Storable
end
