require File.expand_path(File.dirname(__FILE__) + "/../../spec_helper")

describe Webrat::Session do

  it "should not have a doc_root" do
    session = Webrat::Session.new
    session.doc_root.should be_nil
  end

  it "should expose the current_dom" do
    session = Webrat::Session.new

    def session.response
      Object.new
    end

    def session.response_body
      "<html></html>"
    end

    session.should respond_to(:current_dom)
  end

  it "should open the page in the browser in MacOSX" do
    session = Webrat::Session.new
    session.stub!(:ruby_platform => 'darwin')
    session.should_receive(:`).with("open path")
    session.open_in_browser("path")
  end

  it "should open the page in the browser in cygwin" do
    session = Webrat::Session.new
    session.stub!(:ruby_platform => 'i386-cygwin')
    session.should_receive(:`).with("rundll32 url.dll,FileProtocolHandler path\\to\\file")
    session.open_in_browser("path/to/file")
  end

  it "should open the page in the browser in Win32" do
    session = Webrat::Session.new
    session.stub!(:ruby_platform => 'win32')
    session.should_receive(:`).with("rundll32 url.dll,FileProtocolHandler path\\to\\file")
    session.open_in_browser("path/to/file")
  end

  it "should provide a current_page for backwards compatibility" do
    session = Webrat::Session.new
    current_page = session.current_page
    current_page.should_not be_nil
    current_page.should respond_to(:url)
  end

  it "should allow custom headers to be set" do
    session = Webrat::Session.new
    session.header('Accept', 'application/xml')

    session.instance_variable_get(:@custom_headers)['Accept'].should == 'application/xml'
  end

  it "should return a copy of the headers to be sent" do
    session = Webrat::Session.new
    session.instance_eval {
      @default_headers = {'HTTP_X_FORWARDED_FOR' => '192.168.1.1'}
      @custom_headers = {'Accept' => 'application/xml'}
    }
    session.headers.should == {'HTTP_X_FORWARDED_FOR' => '192.168.1.1', 'Accept' => 'application/xml'}
  end

  describe "#http_accept" do
    before(:each) do
      webrat_session = Webrat::Session.new
    end

    it "should set the Accept header with the string Mime type" do
      webrat_session.http_accept('application/xml')
      webrat_session.headers['Accept'].should == 'application/xml'
    end

    it "should set the Accept head with the string value of the symbol Mime type" do
      webrat_session.http_accept(:xml)
      webrat_session.headers['Accept'].should == 'application/xml'
    end

    it "should raise an error if a symbol Mime type is passed that does not exist" do
      lambda { webrat_session.http_accept(:oogabooga) }.should raise_error(ArgumentError)
    end
  end

  describe "#request_page" do
    before(:each) do
      webrat_session = Webrat::Session.new
    end

    it "should raise an error if the request is not a success" do
      webrat_session.stub!(:get)
      webrat_session.stub!(:response_body => "Exception caught")
      webrat_session.stub!(:response_code => 500)
      webrat_session.stub!(:formatted_error => "application error")
      webrat_session.stub!(:save_and_open_page)

      lambda { webrat_session.request_page('some url', :get, {}) }.should raise_error(Webrat::PageLoadError)
    end

    it "should raise an error but not open if the request is not a success and config quashes save_and_open" do
      Webrat.configure do |config|
        config.open_error_files = false
      end
      webrat_session.stub!(:get)
      webrat_session.stub!(:response_body => "Exception caught")
      webrat_session.stub!(:response_code => 500)
      webrat_session.stub!(:formatted_error => "application error")
      webrat_session.should_not_receive(:save_and_open_page)

      lambda { webrat_session.request_page('some url', :get, {}) }.should raise_error(Webrat::PageLoadError)
    end

    it "should follow internal redirects" do
      webrat_session.should_receive(:internal_redirect?).twice.and_return(true, false)
      webrat_session.response.should_receive(:headers).once.and_return({ "Location" => "/newurl" })

      webrat_session.request_page("/oldurl", :get, {})

      webrat_session.current_url.should == "/newurl"
    end

    it "should now follow external redirects" do
      webrat_session.should_receive(:internal_redirect?).and_return(false)

      webrat_session.request_page("/oldurl", :get, {})

      webrat_session.current_url.should == "/oldurl"
    end
  end

  describe "#redirect?" do
    before(:each) do
      webrat_session = Webrat::Session.new
    end

    it "should return true if the last response was a redirect" do
      webrat_session.stub!(:response_code => 301)
      webrat_session.redirect?.should be_true
    end

    it "should return false if the last response wasn't a redirect" do
      webrat_session.stub!(:response_code => 200)
      webrat_session.redirect?.should be_false
    end
  end
  
  describe "#internal_redirect?" do
    before(:each) do
      webrat_session = Webrat::Session.new
    end

    it "should return true if the last response was a redirect and the host of the current_url matches that of the response location" do
      webrat_session.stub!(:redirect?         => true)
      webrat_session.stub!(:current_url       => "http://example.com")
      webrat_session.stub!(:response_location => "http://example.com")
      webrat_session.internal_redirect?.should be_true
    end
    
    it "should return false if the last response was not a redirect" do
      webrat_session.stub!(:redirect? => false)
      webrat_session.internal_redirect?.should be_false
    end
    
    it "should return false if the last response was a redirect but the host of the current_url doesn't matches that of the response location" do
      webrat_session.stub!(:redirect?         => true)
      webrat_session.stub!(:current_url       => "http://example.com")
      webrat_session.stub!(:response_location => "http://google.com")
      webrat_session.internal_redirect?.should be_false
    end
  end
end