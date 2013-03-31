# SmtpProxy

A small SMTP Proxy Server

## Installation

Add this line to your application's Gemfile:

    gem 'smtp_proxy'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install smtp_proxy


Generate the initializer

    $ ruby script/generate smtp_proxy install

  or

    $ rails g smtp_proxy install

## Usage

  Call the smtp_proxy from the root of your rails application.

  Implement the allowed? function in the generated initializer to restrict the IP addresses that can use your proxy.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
