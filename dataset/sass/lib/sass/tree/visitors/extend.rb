class Sass::Tree::Visitors::Extend < Sass::Tree::Visitors::Base
  def self.visit(root, extends)
    return if extends.empty?
    #nodyna <send-2994> <not yet classified>
    new(extends).send(:visit, root)
    check_extends_fired! extends
  end

  protected

  def initialize(extends)
    @parent_directives = []
    @extends = extends
  end

  def visit(node)
    super(node)
  rescue Sass::SyntaxError => e
    e.modify_backtrace(:filename => node.filename, :line => node.line)
    raise e
  end

  def visit_children(parent)
    @parent_directives.push parent if parent.is_a?(Sass::Tree::DirectiveNode)
    super
  ensure
    @parent_directives.pop if parent.is_a?(Sass::Tree::DirectiveNode)
  end

  def visit_rule(node)
    node.resolved_rules = node.resolved_rules.do_extend(@extends, @parent_directives)
  end

  private

  def self.check_extends_fired!(extends)
    extends.each_value do |ex|
      next if ex.result == :succeeded || ex.node.optional?
      message = "\"#{ex.extender}\" failed to @extend \"#{ex.target.join}\"."
      reason =
        if ex.result == :not_found
          "The selector \"#{ex.target.join}\" was not found."
        else
          "No selectors matching \"#{ex.target.join}\" could be unified with \"#{ex.extender}\"."
        end

      raise Sass::SyntaxError.new(<<MESSAGE, :filename => ex.node.filename, :line => ex.node.line)
Use "@extend #{ex.target.join} !optional" if the extend should be able to fail.
MESSAGE
    end
  end
end
