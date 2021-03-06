require 'spec_helper'

describe Rack::ChromeFrame do

  before :all do
    @app = Rack::Builder.parse_file(Rails.root.join('config.ru').to_s).first
  end

  before :each do
    @response = get_response_for_user_agent(@app, ua_string);
  end

  subject { @response }

  context "non-IE browser" do
    let(:ua_string) { "another browser chromeframe" }

    it "shouldn't complain about the browser and shouldn't have chrome frame" do
      expect(subject.body).not_to match(/chrome=1/)
      expect(subject.body).not_to match(/Diaspora doesn't support your version of Internet Explorer/)
    end
  end

  context "IE8 without chromeframe" do
    let(:ua_string) { "MSIE 8" }

    it "shouldn't complain about the browser and shouldn't have chrome frame" do
      expect(subject.body).not_to match(/chrome=1/)
      expect(subject.body).not_to match(/Diaspora doesn't support your version of Internet Explorer/)
    end
  end

  context "IE7 without chromeframe" do
    let(:ua_string) { "MSIE 7" }

    it "should complain about the browser" do
      expect(subject.body).not_to match(/chrome=1/)
      expect(subject.body).to match(/Diaspora doesn't support your version of Internet Explorer/)
    end
    specify {expect(@response.headers["Content-Length"]).to eq(@response.body.length.to_s)}
  end

  context "any IE with chromeframe" do
    let(:ua_string) { "MSIE number chromeframe" }

    it "shouldn't complain about the browser and should have chrome frame" do
      expect(subject.body).to match(/chrome=1/)
      expect(subject.body).not_to match(/Diaspora doesn't support your version of Internet Explorer/)
    end
    specify {expect(@response.headers["Content-Length"]).to eq(@response.body.length.to_s)}
  end

  context "Specific case with no space after MSIE" do
    let(:ua_string) { "Mozilla/4.0 (compatible; MSIE8.0; Windows NT 6.0) .NET CLR 2.0.50727" }

    it "shouldn't complain about the browser" do
      expect(subject.body).not_to match(/Diaspora doesn't support your version of Internet Explorer/)
    end
  end
end
