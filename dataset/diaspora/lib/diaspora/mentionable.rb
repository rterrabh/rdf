
module Diaspora::Mentionable

  REGEX = /(@\{([^\}]+)\})/

  PERSON_HREF_CLASS = "mention hovercardable"

  def self.mention_attrs(mention_str)
    mention = mention_str.match(REGEX)[2]
    del_pos = mention.rindex(/;/)

    name   = mention[0..(del_pos-1)].strip
    handle = mention[(del_pos+1)..-1].strip

    [name, handle]
  end

  def self.format(msg_text, people, opts={})
    people = [*people]

    msg_text.to_s.gsub(REGEX) {|match_str|
      name, handle = mention_attrs(match_str)
      person = people.find {|p| p.diaspora_handle == handle }

      ERB::Util.h(MentionsInternal.mention_link(person, name, opts))
    }
  end

  def self.people_from_string(msg_text)
    identifiers = msg_text.to_s.scan(REGEX).map do |match_str|
      _, handle = mention_attrs(match_str.first)
      handle
    end

    return [] if identifiers.empty?
    Person.where(diaspora_handle: identifiers)
  end

  def self.filter_for_aspects(msg_text, user, *aspects)
    aspect_ids = MentionsInternal.get_aspect_ids(user, *aspects)

    mentioned_ppl = people_from_string(msg_text)
    aspects_ppl = AspectMembership.where(aspect_id: aspect_ids)
                                  .includes(:contact => :person)
                                  .map(&:person)

    msg_text.to_s.gsub(REGEX) {|match_str|
      name, handle = mention_attrs(match_str)
      person = mentioned_ppl.find {|p| p.diaspora_handle == handle }
      mention = MentionsInternal.profile_link(person, name) unless aspects_ppl.include?(person)

      mention || match_str
    }
  end

  private

  module MentionsInternal
    extend ::PeopleHelper

    def self.mention_link(person, fallback_name, opts)
      return fallback_name unless person.present?

      if opts[:plain_text]
        person.name
      else
        person_link(person, class: PERSON_HREF_CLASS)
      end
    end

    def self.profile_link(person, fallback_name)
      return fallback_name unless person.present?

      "[#{person.name}](#{local_or_remote_person_path(person)})"
    end

    def self.get_aspect_ids(user, *aspects)
      return [] if aspects.empty?

      if (!aspects.first.is_a?(Integer)) && aspects.first.to_s == 'all'
        return user.aspects.pluck(:id)
      end

      ids = aspects.reject {|id| Integer(id) == nil } # only numeric

      user.aspects.where(id: ids).pluck(:id)
    end
  end

end
