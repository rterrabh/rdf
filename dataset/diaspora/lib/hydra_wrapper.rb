
class HydraWrapper
  include Diaspora::Logging

  OPTS = {
    maxredirs: 3,
    timeout: 25,
    method: :post,
    verbose: AppConfig.settings.typhoeus_verbose?,
    cainfo: AppConfig.environment.certificate_authorities.get,
    headers: {
      'Expect'            => '',
      'Transfer-Encoding' => '',
      'User-Agent'        => "Diaspora #{AppConfig.version_string}"
    }
  }

  attr_reader :people_to_retry , :user, :encoded_object_xml
  attr_accessor :dispatcher_class, :people
  delegate :run, to: :hydra

  def initialize user, people, encoded_object_xml, dispatcher_class
    @user = user
    @people_to_retry = []
    @people = people
    @dispatcher_class = dispatcher_class
    @encoded_object_xml = encoded_object_xml
    @keep_for_retry_proc = Proc.new do |response|
      true
    end
  end

  def enqueue_batch
    grouped_people.each do |receive_url, people_for_receive_url|
      if xml = xml_factory.xml_for(people_for_receive_url.first)
        insert_job(receive_url, xml, people_for_receive_url)
      end
    end
  end

  def keep_for_retry_if &block
    @keep_for_retry_proc = block
  end

  private

  def hydra
    @hydra ||= Typhoeus::Hydra.new(max_concurrency: AppConfig.settings.typhoeus_concurrency.to_i)
  end

  def xml_factory
    @xml_factory ||= @dispatcher_class.salmon @user, Base64.decode64(@encoded_object_xml)
  end

  def grouped_people
    @people.group_by { |person|
      @dispatcher_class.receive_url_for person
    }
  end

  def insert_job url, xml, people
    request = Typhoeus::Request.new url, OPTS.merge(body: {xml: CGI.escape(xml)})
    prepare_request request, people
    hydra.queue request
  end

  def prepare_request request, people_for_receive_url
    request.on_complete do |response|
      Pod.find_or_create_by(url: response.effective_url)

      if redirecting_to_https? response
        Person.url_batch_update people_for_receive_url, response.headers_hash['Location']
      end

      unless response.success?
        logger.warn "event=http_multi_fail sender_id=#{@user.id} url=#{response.effective_url} " \
                    "return_code=#{response.return_code} response_code=#{response.response_code}"

        if @keep_for_retry_proc.call(response)
          @people_to_retry += people_for_receive_url.map(&:id)
        end

      end
    end
  end

  def redirecting_to_https? response
    response.code >= 300 && response.code < 400 &&
    response.headers_hash['Location'] == response.request.url.sub('http://', 'https://')
  end
end
