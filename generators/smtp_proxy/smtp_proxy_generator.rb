class SmtpProxyGenerator < Rails::Generator::NamedBase

  def initialize(runtime_args, runtime_options = {})
    runtime_args.unshift('install') if runtime_args.empty?
    super
  end

  def manifest
    record do |m|
      m.template 'initializer.rb', File.join('config/initializers',  "smtp_proxy.rb")
    end
  end

  protected
    def banner
      "Usage: #{$0} #{spec.name}"
    end

end
