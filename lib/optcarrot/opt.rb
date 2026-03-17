# rbs_inline: enabled

module Optcarrot
  # dirty methods manipulating and generating methods...
  module CodeOptimizationHelper
    # @rbs @loglevel: Integer

    # @rbs loglevel: Integer
    # @rbs enabled_opts: Array[Symbol]?
    # @rbs return: void
    def initialize(loglevel, enabled_opts)
      @loglevel = loglevel
      options = self.class::OPTIONS # steep:ignore
      opts = {} #: Hash[Symbol, bool]
      enabled_opts ||= [:all]
      default =
        (enabled_opts == [:all] || enabled_opts != [] && enabled_opts.all? {|opt| opt.to_s.start_with?("-") })
      options.each {|opt| opts[opt] = default }
      (enabled_opts - [:none, :all]).each do |opt|
        val = true
        if opt.to_s.start_with?("-")
          opt_str = opt.to_s[1..-1] #: String
          opt = opt_str.to_sym
          val = false
        end
        raise "unknown optimization: `#{ opt }'" unless options.include?(opt)
        opts[opt] = val
      end
      options.each {|opt| instance_variable_set(:"@#{ opt }", opts[opt]) }
    end

    # @rbs opt: Symbol
    # @rbs depended_opt: Symbol
    # @rbs return: void
    def depends(opt, depended_opt)
      if instance_variable_get(:"@#{ opt }") && !instance_variable_get(:"@#{ depended_opt }")
        raise "`#{ opt }' depends upon `#{ depended_opt }'"
      end
    end

    # @rbs *codes: String
    # @rbs return: String
    def gen(*codes)
      codes.map {|code| code.to_s.chomp }.join("\n") + "\n"
    end

    # change indent
    # @rbs i: Integer
    # @rbs code: String
    # @rbs return: String
    def indent(i, code)
      if i > 0
        code.gsub(/^(.+)$/) {
          m = $1 #: String
          " " * i + m
        }
      elsif i < 0
        code.gsub(/^ {#{ -i }}/, "")
      else
        code
      end
    end

    # generate a branch
    # @rbs cond: String
    # @rbs code1: String
    # @rbs code2: String
    # @rbs return: String
    def branch(cond, code1, code2)
      gen(
        "if #{ cond }",
        indent(2, code1),
        "else",
        indent(2, code2),
        "end",
      )
    end

    MethodDef = Struct.new(:params, :body)

    METHOD_DEFINITIONS_RE = /
      ^(\ +)def\s+(\w+)(?:\((.*)\))?\n
      ^((?:\1\ +.*\n|\n)*)
      ^\1end$
    /x
    # extract all method definitions
    # @rbs file: String
    # @rbs return: Hash[Symbol, MethodDef]
    def parse_method_definitions(file)
      src = File.read(file)
      mdefs = {} #: Hash[Symbol, MethodDef]
      src.scan(METHOD_DEFINITIONS_RE) do |indent_str, meth, params, body_str|
        indent_ = indent_str #: String
        meth_ = meth #: String
        body = body_str #: String
        body = indent(-indent_.size - 2, body)

        # noramlize: break `when ... then`
        body = body.gsub(/^( *)when +(.*?) +then +(.*)/) {
          m1 = $1 #: String
          m2 = $2 #: String
          m3 = $3 #: String
          m1 + "when #{ m2 }\n" + m1 + "  " + m3
        }

        # normalize: return unless
        if body =~ /\Areturn unless (.*)/
          match1 = $1 #: String
          postmatch = $' #: String
          body = "if " + match1 + indent(2, postmatch) + "end\n"
        end

        # normalize: if modifier -> if statement
        nil while body.gsub!(/^( *)((?!#)\S.*) ((?:if|unless) .*\n)/) {
          m1 = $1 #: String
          m2 = $2 #: String
          m3 = $3 #: String
          indent(m1.size, gen(m3, "  " + m2, "end"))
        }

        mdefs[meth_.to_sym] = MethodDef[params ? params.split(", ") : nil, body] # steep:ignore
      end
      mdefs
    end

    # inline method calls with no arguments
    # @rbs code: String
    # @rbs mdefs: Hash[Symbol, MethodDef]
    # @rbs meths: Array[Symbol]
    # @rbs return: String
    def expand_methods(code, mdefs, meths = mdefs.keys)
      code.gsub(/^( *)\b(#{ meths * "|" })\b(?:\((.*?)\))?\n/) do
        indent = $1 #: String
        meth = $2 #: String
        args = $3
        body = mdefs[meth.to_sym] #: MethodDef | String
        body = body.body if body.is_a?(MethodDef)
        if args
          mdefs[meth.to_sym].params.zip(args.split(", ")) do |param, arg| # steep:ignore
            body = replace_var(body, param, arg)
          end
        end
        indent(indent.size, body) # steep:ignore
      end
    end

    # @rbs code: String
    # @rbs meth: Symbol
    # @rbs mdef: MethodDef
    # @rbs return: String
    def expand_inline_methods(code, meth, mdef)
      code.gsub(/\b#{ meth }\b(?:\(((?:@?\w+, )*@?\w+)\))?/) do
        args = $1
        b = "(#{ mdef.body.chomp.gsub(/ *#.*/, "").gsub("\n", "; ") })"
        if args
          mdef.params.zip(args.split(", ")) do |param, arg|
            b = replace_var(b, param, arg)
          end
        end
        b
      end
    end

    # @rbs code: String
    # @rbs var: String
    # @rbs bool: untyped
    # @rbs return: String
    def replace_var(code, var, bool)
      re = var.start_with?("@") ? /#{ var }\b/ : /\b#{ var }\b/
      code.gsub(re) { bool }
    end

    # @rbs code: String
    # @rbs var: String
    # @rbs bool: String
    # @rbs return: String
    def replace_cond_var(code, var, bool)
      code.gsub(/(if|unless)\s#{ var }\b/) {
        m = $1 #: String
        m + " " + bool
      }
    end

    TRIVIAL_BRANCH_RE = /
      ^(\ *)(if|unless)\ (true|false)\n
      ^((?:\1\ +.*\n|\n)*)
       (?:
         \1else\n
         ((?:\1\ +.*\n|\n)*)
       )?
      ^\1end\n
    /x
    # remove "if true" or "if false"
    # @rbs code: String
    # @rbs return: String
    def remove_trivial_branches(code)
      code = code.dup
      nil while
        code.gsub!(TRIVIAL_BRANCH_RE) do
          m2 = $2 #: String
          m3 = $3 #: String
          m4 = $4 #: String
          m5 = $5
          if (m2 == "if") == (m3 == "true")
            indent(-2, m4)
          else
            m5 ? indent(-2, m5) : ""
          end
        end
      code
    end

    # replace instance variables with temporal local variables
    # CAUTION: the instance variable must not be accessed out of CPU#run
    # @rbs code: String
    # @rbs ivars: Array[String]
    # @rbs return: String
    def localize_instance_variables(code, ivars = code.scan(/@\w+/).uniq.sort)
      ivars = ivars.map {|ivar| ivar.to_s[1..-1] }

      inits, finals = [], []
      ivars.each do |ivar|
        lvar = "__#{ ivar }__"
        inits << "#{ lvar } = @#{ ivar }"
        finals << "@#{ ivar } = #{ lvar }"
      end

      code = code.gsub(/@(#{ ivars * "|" })\b/) { "__#{ $1 }__" }

      gen(
        "begin",
        indent(2, inits.join("\n")),
        indent(2, code),
        "ensure",
        indent(2, finals.join("\n")),
        "end",
      )
    end
  end
end
