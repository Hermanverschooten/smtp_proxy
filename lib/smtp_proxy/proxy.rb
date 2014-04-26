require "optparse"

module SmtpProxy
  class Proxy
    class RailsEnvironmentFailed < StandardError; end

    def self.allowed?(ip)
      raise "Implement allowed? function"
    end


    @@pid_file = nil

    def self.remove_pid_file
      if @@pid_file
        require "shell"
        sh = Shell.new
        sh.rm @@pid_file
      end
    end

    def self.process_args(args)
      name = File.basename $0

      options={}
      options[:Chdir] = "."
      options[:Daemon] = false
      options[:ListenPort] = 25
      options[:RemotePort] = 25
      options[:RailsEnv] = ENV["RAILS_ENV"]
      options[:Pidfile] = '/log/smtp_proxy.pid'
      options[:Verbose]=true
      options[:ListenIp] = "0.0.0.0"
      options[:Threads] = 2
      options[:Username] = "smtp_proxy"
      options[:Password] = "password"

      opts = OptionParser.new do |opts|
        opts.banner = "Usage: #{name} [options]"
        opts.separator  ''
        opts.separator  "#{name} calls the allowed method of the Proxy class to determine"
        opts.separator  "if the connecting ip address is allowed to use the proxy."
        opts.separator  ''
        opts.separator "#{name} must be run from the Rails application's root."
        opts.separator ''
        opts.separator "#{name} options:"

        opts.on("-l", "--listen_ip IP", "IP to listen on.", "Default: #{options[:ListenIp]}",String) do |listen_ip|
          options[:ListenIp] = listen_ip
        end

        opts.on("-p", "--listen_port PORT", "The port to listen on", "Default: #{options[:ListenPort]}",Integer) do |listen_port|
          options[:ListenPort] = listen_port
        end

        opts.on("-r", "--remote-ip IP", "The smtp server to connect to", String) do |remote_ip|
          options[:RemoteIp] = remote_ip
        end

        opts.on("-q", "--remote-port PORT", "The port of the remote smtp server","Default: #{options[:RemotePort]}",Integer) do |remote_port|
          options[:RemotePort] = remote_port
        end

        opts.on("-t", "--threads NUM", "The number of threads to use", "Default: #{options[:Threads]}", Integer) do |threads|
          options[:Threads] = threads
        end

        opts.on("-d", "--daemonize", "Run as a daemon", "Default: #{options[:Daemon]}") do |daemon|
          options[:Daemon] = true
        end

        opts.on("-f", "--pid-file PIDFILE", "Set the pidfile location", "Default: #{options[:Chdir]}#{options[:Pidfile]}",String) do |pidfile|
          options[:Pidfile] = pidfile
        end

        opts.on("-u", "--username USERNAME", "The username for authenticated SMTP", "Default: #{options[:Username]}",String) do |username|
          options[:Username] = username
        end

        opts.on("-w", "--password PASSWORD", "The password for authenticated SMTP", "Default: #{options[:Password]}",String) do |password|
          options[:Password] = password
        end

        opts.separator ''
        opts.separator "Generic Options:"

        opts.on("-v", "--[no-]verbose", "Be verbose", "Default: #{options[:Verbose]}") do |verbose|
          options[:Verbose] = verbose
        end

        opts.on("-c", "--chdir PATH", "Use PATH for the application path", "Default: #{options[:Chdir]}") do |path|
          usage opts, "#{path} is not a directory" unless File.directory? path
          usage opts, "#{path} is not readable" unless File.readable? path
          options[:Chdir] = path
        end

        opts.on("-e", "--environment RAILS_ENV", "Set the RAILS_ENV constant", "Default: #{options[:RailsEnv]}") do |env|
          options[:RailsEnv] = env
        end

        opts.on("-h", "--help", "This help message") do
          usage opts
        end

        opts.on("--version", "Version of SmtpProxy") do
          usage "smtp_proxy #{VERSION}"
        end

        opts.separator ''

      end

      opts.parse! args

      ENV['RAILS_ENV'] = options[:RailsEnv]

      begin
        load_rails_environment(options[:Chdir])
      rescue RailsEnvironmentFailed
        usage opts, "#{name} must be run from a Rails application's root to function properly.\n#{Dir.pwd} does not appear to be a Rails application's root."
      end

      return options
    end

    def self.load_rails_environment(base_path)
      Dir.chdir(base_path) do
        require "config/environment"
      end
      rescue LoadError
        raise RailsEnvironmentFailed
    end

    def default_log_path
      File.join(root_path, 'log', "#{environment}.log")
    end

    def default_log_level
      environment == 'production' ? :info : :debug
    end

    def self.run(args = ARGV)
      options = process_args(args)

      if options[:Daemon]
        require 'webrick/server'
        @@pid_file = File.expand_path(options[:Pidfile], options[:Chdir])
        if File.exists? @@pid_file
          pid = ''
          File.open(@@pid_file, 'r') {|f| pid = f.read.chomp}
          if system("ps -p #{pid} | grep #{pid}")
            $stderr.puts "Warning: The pid file #{@@pid_file} exists and smtp_proxy is running. Exiting."
            exit -1
          else
            self.remove_pid_file
            $stderr.puts "smtp_proxy is not runing. Removing existing pid file and starting up."
          end
        end
        WEBrick::Daemon.start
        File.open(@@pid_file, 'w') {|f| f.write "#{Process.pid}\n"}
      end

      new(options).run

    rescue SystemExit
      raise
    rescue SignalException
      exit
    rescue Exception => e
      $stderr.puts "Unhandled exception #{e.message} (#{e.class}):"
      $stderr.puts "\t#{e.backtrace.join("\n\t")}"
      exit -2
    end

    def self.usage(opts, message = nil)
      if message
        $stderr.puts message
        $stderr.puts
      end

      $stderr.puts opts
      exit 1
    end

    def initialize(options = {})
      @remote_host = options[:RemoteIp]
      @remote_port = options[:RemotePort]
      @listen_ip = options[:ListenIp]
      @listen_port = options[:ListenPort]
      @max_threads = options[:Threads]
      @verbose = options[:Verbose]
      @username = Base64.encode64(options[:Username])
      @password = Base64.encode64(options[:Password])
    end

    def do_exit
      log "Caught signal, shutting down"
      self.class.remove_pid_file
      exit 130
    end

    def install_signal_handlers
      trap 'TERM' do do_exit end
      trap 'INT' do do_exit end
    end

    def log(message)
      $stderr.puts message if @verbose
      Rails.logger.info "smtp_proxy: #{message}"
    end

    def new_thread(server)
      Thread.new(server.accept) do |client_socket|
        begin
          remote_addr = client_socket.peeraddr.last.split(':').last
          log "#{Thread.current.object_id}: got a client connection from #{remote_addr}"
          begin
            if self.class.allowed?(remote_addr)
              server_socket = TCPSocket.new(@remote_host, @remote_port, @listen_ip)
            else
              log "#{Thread.current.object_id}: Denied connection to #{remote_addr}"
              raise Errno::ECONNREFUSED
            end
          rescue Errno::ECONNREFUSED
            client_socket.close
            raise
          end

          log "#{Thread.current.object_id}: connected to server at #{@remote_host}:#{@remote_port}"
          wait_username = false
          wait_password = false
          loop do
            (ready_sockets, dummy, dummy) = IO.select([client_socket, server_socket])
            begin
              ready_sockets.each do |socket|
                data = socket.readpartial(4096)
                if socket == client_socket
                  if wait_username
                    wait_username = false
                    data ="#{@username}\r\n"
                  end
                  if wait_password
                    wait_password=false
                    data="#{@password}\r\n"
                  end
                  log "#{Thread.current.object_id}: client->server #{data.inspect}" if @verbose
                  server_socket.write data
                  server_socket.flush
                else
                  # Read from server, write to client.
                  # Adapt to remove authentication
                  wait_username=(data =~ /334.VXNlcm5hbWU6/)!=nil
                  wait_password=(data =~ /334.UGFzc3dvcmQ6/)!=nil
                  log "#{Thread.current.object_id}: server->client #{data.inspect}" if @verbose
                  client_socket.write data
                  client_socket.flush
                end
              end
            rescue EOFError
              break
            end
          end
        rescue StandardError => e
          log "#{Thread.current.object_id} got exception #{e.message}"
        end
        log "#{Thread.current.object_id}: closing the connection"
        client_socket.close
        server_socket.close
      end
    end

    def threads_alive(threads)
      threads.select { |t| t.alive? ? true : (t.join); false}
    end

    def run
      install_signal_handlers
      threads = []
      log "SMTP Proxy Server Starting"
      server = TCPServer.new(@listen_ip, @listen_port)
      loop do
        log "Waiting for connections on #{@listen_ip}:#{@listen_port}"
        threads << new_thread(server)
        log "#{threads.size} threads running"
        threads = threads_alive(threads)
        while threads.size >= @max_threads
          sleep 1
          threads = threads_alive(threads)
        end
      end
    end
  end
end
