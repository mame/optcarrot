require "ripper"

# Code rewriter for 1.8/opal compatibility
#   foo(1, 2, 3,) => foo(1, 2, 3)
#   foo(label: 42) => foo(:label => 42)
#   /.../x => (removed)
#   dynamic require => (removed)
class Rewriter < Ripper::Filter
  def on_default(event, tok, out)
    if @comma
      case event
      when :on_sp, :on_ignored_nl
        @comma << tok
        return out
      end
      out << @comma if event != :on_rparen
      @comma = nil
    end

    case event
    when :on_label
      out << ":#{ tok[0..-2] } =>"
    when :on_comma
      @comma = ","
    else
      out << tok
    end

    out
  end
end

Dir[File.join(File.dirname(File.dirname(__FILE__)), "lib/**/*.rb")].each do |f|
  s = File.read(f)
  s = s.gsub(/^( +)class OptimizedCodeBuilder\n(?:\1 .*\n|\n)*\1end/) do
    $1 + "class OptimizedCodeBuilder; OPTIONS = {}; end # disabled for 1.8/opal"
  end
  s = s.gsub(%r{^( +)[A-Z_]+ = /\n(?:\1 .*\n)*\1/x|^( +)require .*}) do
    $&.gsub(/.+/) { "##{ $& } # disable for opal" }
  end
  out = ""
  Rewriter.new(s).parse(out)
  File.write(f, out)
end
