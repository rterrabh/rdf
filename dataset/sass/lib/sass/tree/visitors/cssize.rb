class Sass::Tree::Visitors::Cssize < Sass::Tree::Visitors::Base
  def self.visit(root); super; end

  protected

  def parent
    @parents.last
  end

  def initialize
    @parents = []
    @extends = Sass::Util::SubsetMap.new
  end

  def visit(node)
    super(node)
  rescue Sass::SyntaxError => e
    e.modify_backtrace(:filename => node.filename, :line => node.line)
    raise e
  end

  def visit_children(parent)
    with_parent parent do
      parent.children = visit_children_without_parent(parent)
      parent
    end
  end

  def visit_children_without_parent(node)
    node.children.map {|c| visit(c)}.flatten
  end

  def with_parent(parent)
    @parents.push parent
    yield
  ensure
    @parents.pop
  end

  def visit_root(node)
    yield

    if parent.nil?
      if Sass::Util.ruby1_8?
        charset = node.children.find {|c| c.is_a?(Sass::Tree::CharsetNode)}
        node.children.reject! {|c| c.is_a?(Sass::Tree::CharsetNode)}
        node.children.unshift charset if charset
      end

      imports_to_move = []
      import_limit = nil
      i = -1
      node.children.reject! do |n|
        i += 1
        if import_limit
          next false unless n.is_a?(Sass::Tree::CssImportNode)
          imports_to_move << n
          next true
        end

        if !n.is_a?(Sass::Tree::CommentNode) &&
            !n.is_a?(Sass::Tree::CharsetNode) &&
            !n.is_a?(Sass::Tree::CssImportNode)
          import_limit = i
        end

        false
      end

      if import_limit
        node.children = node.children[0...import_limit] + imports_to_move +
          node.children[import_limit..-1]
      end
    end

    return node, @extends
  rescue Sass::SyntaxError => e
    e.sass_template ||= node.template
    raise e
  end

  Extend = Struct.new(:extender, :target, :node, :directives, :result)

  def visit_extend(node)
    parent.resolved_rules.populate_extends(@extends, node.resolved_selector, node,
      @parents.select {|p| p.is_a?(Sass::Tree::DirectiveNode)})
    []
  end

  def visit_import(node)
    visit_children_without_parent(node)
  rescue Sass::SyntaxError => e
    e.modify_backtrace(:filename => node.children.first.filename)
    e.add_backtrace(:filename => node.filename, :line => node.line)
    raise e
  end

  def visit_trace(node)
    visit_children_without_parent(node)
  rescue Sass::SyntaxError => e
    e.modify_backtrace(:mixin => node.name, :filename => node.filename, :line => node.line)
    e.add_backtrace(:filename => node.filename, :line => node.line)
    raise e
  end

  def visit_prop(node)
    if parent.is_a?(Sass::Tree::PropNode)
      node.resolved_name = "#{parent.resolved_name}-#{node.resolved_name}"
      node.tabs = parent.tabs + (parent.resolved_value.empty? ? 0 : 1) if node.style == :nested
    end

    yield

    result = node.children.dup
    if !node.resolved_value.empty? || node.children.empty?
      #nodyna <send-2996> <SD EASY (private methods)>
      node.send(:check!)
      result.unshift(node)
    end

    result
  end

  def visit_atroot(node)
    if @parents.none? {|n| node.exclude_node?(n)}
      results = visit_children_without_parent(node)
      results.each {|c| c.tabs += node.tabs if bubblable?(c)}
      if !results.empty? && bubblable?(results.last)
        results.last.group_end = node.group_end
      end
      return results
    end

    return Bubble.new(node) if node.exclude_node?(parent)

    bubble(node)
  end


  def visit_rule(node)
    yield

    rules = node.children.select {|c| bubblable?(c)}
    props = node.children.reject {|c| bubblable?(c) || c.invisible?}

    unless props.empty?
      node.children = props
      rules.each {|r| r.tabs += 1} if node.style == :nested
      rules.unshift(node)
    end

    rules = debubble(rules)
    unless parent.is_a?(Sass::Tree::RuleNode) || rules.empty? || !bubblable?(rules.last)
      rules.last.group_end = true
    end
    rules
  end

  def visit_keyframerule(node)
    return node unless node.has_children

    yield

    debubble(node.children, node)
  end

  def visit_directive(node)
    return node unless node.has_children
    if parent.is_a?(Sass::Tree::RuleNode)
      return node.normalized_name == '@keyframes' ? Bubble.new(node) : bubble(node)
    end

    yield

    directive_exists = node.children.any? do |child|
      next true unless child.is_a?(Bubble)
      next false unless child.node.is_a?(Sass::Tree::DirectiveNode)
      child.node.resolved_value == node.resolved_value
    end

    if directive_exists || node.name == '@keyframes'
      []
    else
      empty_node = node.dup
      empty_node.children = []
      [empty_node]
    end + debubble(node.children, node)
  end

  def visit_media(node)
    return bubble(node) if parent.is_a?(Sass::Tree::RuleNode)
    return Bubble.new(node) if parent.is_a?(Sass::Tree::MediaNode)

    yield

    debubble(node.children, node) do |child|
      next child unless child.is_a?(Sass::Tree::MediaNode)
      next child if child.resolved_query == node.resolved_query
      next child if child.resolved_query = child.resolved_query.merge(node.resolved_query)
    end
  end

  def visit_supports(node)
    return node unless node.has_children
    return bubble(node) if parent.is_a?(Sass::Tree::RuleNode)

    yield

    debubble(node.children, node)
  end

  private

  def bubble(node)
    new_rule = parent.dup
    new_rule.children = node.children
    node.children = [new_rule]
    Bubble.new(node)
  end

  def debubble(children, parent = nil)
    previous_parent = nil

    Sass::Util.slice_by(children) {|c| c.is_a?(Bubble)}.map do |(is_bubble, slice)|
      unless is_bubble
        next slice unless parent
        if previous_parent
          previous_parent.children.push(*slice)
          next []
        else
          previous_parent = new_parent = parent.dup
          new_parent.children = slice
          next new_parent
        end
      end

      slice.map do |bubble|
        next unless (node = block_given? ? yield(bubble.node) : bubble.node)
        node.tabs += bubble.tabs
        node.group_end = bubble.group_end
        results = [visit(node)].flatten
        previous_parent = nil unless results.empty?
        results
      end.compact
    end.flatten
  end

  def bubblable?(node)
    node.is_a?(Sass::Tree::RuleNode) || node.bubbles?
  end

  class Bubble
    attr_accessor :node
    attr_accessor :tabs
    attr_accessor :group_end

    def initialize(node)
      @node = node
      @tabs = 0
    end

    def bubbles?
      true
    end

    def inspect
      "(Bubble #{node.inspect})"
    end
  end
end
