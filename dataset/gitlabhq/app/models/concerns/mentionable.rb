module Mentionable
  extend ActiveSupport::Concern

  module ClassMethods
    def attr_mentionable(*attrs)
      mentionable_attrs.concat(attrs.map(&:to_s))
    end

    def mentionable_attrs
      @mentionable_attrs ||= []
    end
  end

  def gfm_reference(from_project = nil)
    friendly_name = self.class.to_s.underscore.humanize.downcase

    "#{friendly_name} #{to_reference(from_project)}"
  end

  def mentionable_text
    #nodyna <send-521> <SD MODERATE (array)>
    self.class.mentionable_attrs.map { |attr| send(attr) }.compact.join("\n\n")
  end

  def local_reference
    self
  end

  def has_mentioned?(target)
    SystemNoteService.cross_reference_exists?(target, local_reference)
  end

  def mentioned_users(current_user = nil)
    return [] if mentionable_text.blank?

    ext = Gitlab::ReferenceExtractor.new(self.project, current_user)
    ext.analyze(mentionable_text)
    ext.users.uniq
  end

  def references(p = project, current_user = self.author, text = mentionable_text)
    return [] if text.blank?

    ext = Gitlab::ReferenceExtractor.new(p, current_user)
    ext.analyze(text)

    (ext.issues + ext.merge_requests + ext.commits).uniq - [local_reference]
  end

  def create_cross_references!(p = project, a = author, without = [])
    refs = references(p)

    refs.reject! { |ref| without.include?(ref) }

    refs.each do |ref|
      SystemNoteService.cross_reference(ref, local_reference, a)
    end
  end

  def create_new_cross_references!(p = project, a = author)
    changes = detect_mentionable_changes

    return if changes.empty?

    original_text = changes.collect { |_, vals| vals.first }.join(' ')

    preexisting = references(p, self.author, original_text)
    create_cross_references!(p, a, preexisting)
  end

  private

  def detect_mentionable_changes
    source = (changes.present? ? changes : previous_changes).dup

    mentionable = self.class.mentionable_attrs

    source.select { |key, val| mentionable.include?(key) }
  end
end
