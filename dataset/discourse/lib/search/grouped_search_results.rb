require 'sanitize'

class Search

  class GroupedSearchResults
    include ActiveModel::Serialization

    class TextHelper
      extend ActionView::Helpers::TextHelper
    end

    attr_reader :type_filter,
                :posts, :categories, :users,
                :more_posts, :more_categories, :more_users,
                :term, :search_context, :include_blurbs

    def initialize(type_filter, term, search_context, include_blurbs, blurb_length)
      @type_filter = type_filter
      @term = term
      @search_context = search_context
      @include_blurbs = include_blurbs
      @blurb_length = blurb_length || 200
      @posts = []
      @categories = []
      @users = []
    end

    def blurb(post)
      GroupedSearchResults.blurb_for(post.cooked, @term, @blurb_length)
    end

    def add(object)
      type = object.class.to_s.downcase.pluralize

      #nodyna <send-288> <SD COMPLEX (change-prone variables)>
      if !@type_filter.present? && send(type).length == Search.per_facet
        #nodyna <instance_variable_set-289> <IVS COMPLEX (change-prone variable)>
        instance_variable_set("@more_#{type}".to_sym, true)
      else
        #nodyna <send-290> <SD COMPLEX (change-prone variables)>
        (send type) << object
      end
    end


    def self.blurb_for(cooked, term=nil, blurb_length=200)
      cooked = SearchObserver::HtmlScrubber.scrub(cooked).squish

      blurb = nil
      if term
        terms = term.split(/\s+/)
        blurb = TextHelper.excerpt(cooked, terms.first, radius: blurb_length / 2, seperator: " ")
      end
      blurb = TextHelper.truncate(cooked, length: blurb_length, seperator: " ") if blurb.blank?
      Sanitize.clean(blurb)
    end
  end

end
