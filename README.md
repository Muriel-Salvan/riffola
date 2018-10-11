# Riffola

Riffola - Reading extended RIFF files

## Getting Started

### Prerequisites

You just need to have Ruby installed.

### Installing

Riffola installs as any Rubygem, either using `gem` command or Bundler.

```bash
gem install riffola
```

Or using Bundler, add this in your `Gemfile` and issue `bundle install`.

```
gem 'riffola'
```

Once the gem is installed you can require its main library in your Ruby code and use its API:

```ruby
require 'riffola'

chunks = Riffola.read 'my_file.wav'
```

## RIFF format

Riffola considers a RIFF file as a list of chunks having the following structure:
1. A 4 bytes header
2. An encoded data size (on 4 or 2 bytes)
3. An optional header
4. Data of the given encoded data size

It gives ways in the `Riffola.read` method to specify different chunks formats (with header size, a correction on the data size in case it is wrongly encoded...).

Check the [`Riffola.read`](https://github.com/Muriel-Salvan/riffola/blob/master/lib/riffola.rb) method description to get a grasp on the possible options given by the API.

Among the file formats it should be able to parse, there are WAV, AVI, ESP.

## Running the tests

Executing tests is done by:

1. Cloning the repository from Github:
```bash
git clone https://github.com/Muriel-Salvan/riffola
cd riffola
```

2. Installing dependencies
```bash
bundle install
```

3. Running tests
```bash
bundle exec rspec
```

### Coding style tests

[Rubocop](https://github.com/rubocop-hq/rubocop) is used for coding style tests.

```bash
bundle exec rubocop
```

## Deployment

Like any Rubygem:
```bash
gem build riffola.gemspec
```

## Contributing

Please fork the repository from Github and submit Pull Requests. Any contribution is more than welcome! :D

## Versioning

We use [SemVer](http://semver.org/) for versioning.

## Authors

* **Muriel Salvan** - *Initial work* - [Muriel-Salvan](https://github.com/Muriel-Salvan)

## License

This project is licensed under the BSD License - see the [LICENSE](LICENSE) file for details
