module ForemanOpentofu
  module HclFormat
    def default_opts(opts = {})
      {
        indent: 2,
        depth: 0,
        snippet: false,
      }.merge opts
    end

    # possible `opts`:
    #   `indent` : number of whitespace to indent; default 2
    #   `depth`  : start value of depth (for indentation); default: 0
    #   `snippet`: if `true` and var is a `Hash` string will not be framed with `{}`
    def to_hcl(var, opts = {})
      opts = default_opts.merge(opts)

      case var
      when Hash then hash_to_hcl(var, opts)
      when Array then array_to_hcl(var, opts)
      when String then var.inspect
      else var.to_s
      end
    end

    def prefix_hcl(opts)
      "\n#{' ' * opts[:indent] * opts[:depth]}"
    end

    # output a hcl-block:
    # hello "how" "are" "you" { ... }
    # the above would be created by: block_to_hcl(['hello,'how', 'are', 'you'], { .. })
    def block_to_hcl(names, content = nil, opts = {})
      opts = default_opts(opts)

      hcl = prefix_hcl(opts)
      hcl << names[0]
      hcl << ' '
      # sub-block-names are quoted
      hcl << names[1..].map(&:to_s).map(&:inspect).join(' ')
      hcl << ' ' if hcl[-1] != ' '
      hcl << to_hcl(content, opts)
    end

    def hash_to_hcl(hsh, opts)
      opts = default_opts(opts)
      hcl = ''
      new_opts = opts.merge(snippet: false)

      unless opts[:snippet]
        hcl << '{'
        new_opts[:depth] = opts[:depth] + 1
      end

      close_block_on_newline = false

      hsh.each do |key, value|
        hcl << prefix_hcl(new_opts)
        hcl << "#{key} = #{to_hcl(value, new_opts)}"
        close_block_on_newline = true
      end
      hcl << prefix_hcl(opts) if close_block_on_newline
      hcl << '}' unless opts[:snippet]
      hcl
    end

    def array_to_hcl(hsh, opts)
      opts = default_opts(opts)
      hcl = '['
      new_opts = opts.merge(
        depth: opts[:depth] + 1
      )
      close_block_on_newline = false

      hsh.each do |value|
        hcl << prefix_hcl(new_opts)
        hcl << to_hcl(value, new_opts)
        hcl << ','
        close_block_on_newline = true
      end
      hcl.chomp!(',')
      hcl << prefix_hcl(opts) if close_block_on_newline
      hcl << ']'
    end
  end
end
