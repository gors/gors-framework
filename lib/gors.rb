require 'rack'
require 'erb'
require 'tilt'
require 'json'

module Gors
  class Server
    def initialize
      @settings = Settings.new
      @logger = Logger.new(@settings)
      @routesklass = Routes.new(@logger)
    end
    def call env
      @logger.log env["REQUEST_METHOD"]+" "+env["REQUEST_PATH"]
      controller = @routesklass.routes[env["PATH_INFO"]]
      if(controller == nil)
        if(@settings.server != "thin")
          response = ["<h1>404 Not Found</h1>"]
        else
          response = "<h1>404 Not Found</h1>"
        end
        return @errorhandler.call "404"
      end

      if(controller.include? "Gors::")
        ctrl = controller.split("#")
        params = ctrl[1].split(":")

        req = Rack::Request.new(env)

        data = Model.new(req).call(params[1])
        return ["200",{"Content-type" => "application/json"},[data]]
      end

      # Call the Controller
      request = Request.new
      request.request.params = Rack::Utils.parse_query(env["QUERY_STRING"])
      request.request.params.default = ""

      infoctrl = controller.split("#")
      ctrl = Object.const_get(infoctrl[0]).new(request) 

      response = ctrl.send(infoctrl[1])
      if(@settings.server != "thin")
        response = [response]
      end
      [ctrl.info.response.status_code,ctrl.info.response.headers,response]
    end

    def start
      if(@settings.errorhandler != nil)
        @errorhandler = Object.const_get(@settings.errorhandler).new
      else
        @errorhandler = Gors::DefaultErrorHandler.new
      end

      if(@settings.daemon)
        puts "Sending Gors to background"
        system("kill `cat running.pid`")
        Process.daemon true
        File.write("running.pid",Process.pid)
      end
      @logger.log @routesklass.inspect
      Rack::Server.new({:app => self,:server => @settings.server, :Port => @settings.port}).start
    end

    def routes &block
      @routesklass.instance_eval &block
    end

    def settings
      yield(@settings)
    end

    def autoimport
      Dir.glob("controllers/*").each do |file|
        require './'+file
      end

      Dir.glob("models/*").each do |file|
        require './'+file
      end
    end

  end
  class Routes
    attr_accessor :routes
    attr_accessor :models
    attr_accessor :posts

    def initialize logger
      @routes = {}
      @models = {}
      @logger = logger
      @routespost = {}
    end

    def get hash
      @routes[hash.keys.first.to_s] = hash[hash.keys.first.to_s]
      @logger.log "Adding route GET "+hash.keys.first.to_s
    end

    def post hash
      @routespost[hash.keys.first.to_s] = hash[hash.keys.first.to_s]
      @logger.log "Adding route POST "+hash.keys.first.to_s
    end

    def post

    end

    def model hash
      @routes["/api/"+hash.keys.first.to_s] = "Gors::Model#call:"+hash[hash.keys.first.to_s];
      puts "Adding model with path "+hash.keys.first.to_s
    end

  end
  class Controller
    attr_accessor :info

    def initialize(context)
      @info = context
       if(self.respond_to? "before")
        self.before
       end
    end

    def erb template
      renderer = Tilt::ERBTemplate.new("views/layout.erb")
      output = renderer.render(self){ Tilt::ERBTemplate.new("views/"+template+".erb").render(self) }
      return output
    end
  end

  class Request
    attr_accessor :response
    attr_accessor :request

    def initialize
       @response = OpenStruct.new ({:headers => {}, :status_code => "200"})
       @request =  OpenStruct.new ({:ip => "",:user_agent => "",:headers => {},:params => {}})
    end

    def info
      return @info
    end 
  end

  class Model
    def initialize req
      @req = req
    end

    def call modelname
      case @req.request_method
        when "GET"
          if(Object.const_get(modelname.capitalize).respond_to? "append")
            model = Object.const_get(modelname.capitalize).all.send(Object.const_get(modelname.capitalize).append)
          else
            model = Object.const_get(modelname.capitalize).all
          end
          model.to_json
        when "POST"
          if(Object.const_get(modelname.capitalize).respond_to? "append")
            model = Object.const_get(modelname.capitalize).create(JSON.parse(@req.body.string))
          else
            model = Object.const_get(modelname.capitalize).create(JSON.parse(@req.body.string))
          end
          model.to_json
        else
         
        end
    end

  end

  class Settings
    attr_accessor :port
    attr_accessor :server
    attr_accessor :verbose
    attr_accessor :daemon
    attr_accessor :errorhandler

    def initialize
      @port = 8080
      @server = "thin"
      @verbose = true
      @daemon = false
      @errorhandler = nil
    end
  end
  class Logger

    def initialize(settings)
      @settings = settings
    end

    def log msg
      if(@settings.daemon)
        return
      end
      if(@settings.verbose)
        puts msg
      end
    end

  end
  
  class ErrorHelper
    def call(errortype)
      if(self.respond_to? "error_"+errortype)
        [errortype, {},[self.send("error_"+errortype)]]
      else
        Gors::DefaultErrorHandler.new.send("error_"+errortype)
      end
    end
  end

  class DefaultErrorHandler < Gors::ErrorHelper
      def error_404
        "<h1>404 Not Found</h1>"
      end
      def error_500
        "<h1>500 Internal server error</h1>"
      end
      def error_403
        "<h1>403 Forbidden</h1>"
      end
  end

 
end

at_exit do
  puts "Exiting..."
  if(File.exists? "running.pid")
    File.delete("running.pid")
  end
end