module Jekyll

  class Pagination < Generator
    safe true

    def generate(site)
      site.pages.dup.each do |page|
        paginate(site, page) if Pager.pagination_enabled?(site.config, page)
      end
    end

    def paginate(site, page)
      all_posts = site.site_payload['site']['posts']
      pages = Pager.calculate_pages(all_posts, site.config['paginate'].to_i)
      page_dir = page.destination('').sub(/\/[^\/]+$/, '')
      page_dir_config = site.config['pagination_dir']
      dir = ((page_dir_config || page_dir) + '/').sub(/^\/+/, '')

      (1..pages).each do |num_page|
        pager = Pager.new(site.config, num_page, all_posts, page_dir+'/', '/'+dir, pages)
        if num_page > 1
          newpage = Page.new(site, site.source, page_dir, page.name)
          newpage.pager = pager
          newpage.dir = File.join(page.dir, "#{dir}page/#{num_page}")
          site.pages << newpage
        else
          page.pager = pager
        end
      end
    end
  end

  class Pager
    attr_reader :page, :per_page, :posts, :total_posts, :total_pages, :previous_page, :next_page

    def self.calculate_pages(all_posts, per_page)
      (all_posts.size.to_f / per_page.to_i).ceil
    end

    def self.pagination_enabled?(config, file)
      file.name == 'index.html' && !config['paginate'].nil? && file.content =~ /paginator\./
    end

    def initialize(config, page, all_posts, index_dir, pagination_dir, num_pages = nil)
      @page = page
      @per_page = config['paginate'].to_i
      @page_dir = pagination_dir + 'page/'
      @total_pages = num_pages || Pager.calculate_pages(all_posts, @per_page)
      @previous_page = nil

      if @page > @total_pages
        raise RuntimeError, "page number can't be greater than total pages: #{@page} > #{@total_pages}"
      end

      init = (@page - 1) * @per_page
      offset = (init + @per_page - 1) >= all_posts.size ? all_posts.size : (init + @per_page - 1)

      @total_posts = all_posts.size
      @posts = all_posts[init..offset]
      @previous_page = @page != 1 ? @page_dir + (@page - 1).to_s + '/' : nil
      @previous_page = index_dir if @page - 1 == 1
      @next_page = @page != @total_pages ? @page_dir + (@page + 1).to_s + '/' : nil
    end

    def to_liquid
      {
        'page' => page,
        'per_page' => per_page,
        'posts' => posts,
        'total_posts' => total_posts,
        'total_pages' => total_pages,
        'previous_page' => previous_page,
        'next_page' => next_page
      }
    end
  end

end

