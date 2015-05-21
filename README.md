# bundler-multi-lockfile-hack

[![Build Status](https://travis-ci.org/lincheney/bundler-multi-lockfile-hack.svg?branch=master)](https://travis-ci.org/lincheney/bundler-multi-lockfile-hack)

Hack to make bundler generate multiple lockfiles (e.g. for a particular group or sub-gemfile).
The generated lockfiles will be in 'sync' with your master `Gemfile.lock`,
i.e. they will specify the same gem versions.


## Usage

The simplest way to get the hack module is to just download it straight into your project.

```
curl -o multi_lockfile_hack.rb https://raw.githubusercontent.com/lincheney/bundler-multi-lockfile-hack/master/bundler/multi_lockfile_hack.rb
```

(You can also include it as a git submodule or build it into a gem, but that's significantly more complicated.)

Then, include the module into your Gemfile and extend:

```ruby
# put this in your Gemfile
require 'multi_lockfile_hack.rb'
extend Bundler::MultiLockfileHack
```

You can now have the hack automatically generate lockfiles for certain groups or gemfiles:

```ruby
# also in your Gemfile

# generate a lockfile for all your test gems
generate_lockfile(groups: :test)  # lockfile will be named test.lock

# generate a lockfile for all gems specified in some other gemfile
generate_lockfile(gemfile: 'other.gemfile')  # lockfile will be named other.gemfile.lock

# generate a lockfile for test gems specified in some other gemfile
generate_lockfile(groups: :test, gemfile: 'other.gemfile')  # lockfile will be named other.gemfile.test.lock

# generate a lockfile for all your test gems and specify the name of the lockfile
generate_lockfile(groups: :test, lockfile: 'test.gems.lock')
```

Generating lockfiles for gemfiles is best used in conjunction with the `eval_gemfile` method that Bundler already provides.

## Purpose

This hack was designed with the sole purpose of taking better advantage of Dockerfile caching.

The standard way to `bundle install` gems in a Gemfile in a Dockerfile is:

```
COPY Gemfile /path/to/app/
COPY Gemfile.lock /path/to/app/
RUN bundle install --without test development
COPY . /path/to/app
```

The Gemfile and lockfile are copied in first and the rest of the source is copied in only after `bundle install`
has been run. If any your source code has changed (apart from the Gemfile and lockfile), then it still won't
invalidate the cache and `bundle install` won't have to be re-run.

However, this approach suffers from a few problems:
* even though we don't `bundle install` test or development gems, adding/changing test or development gems *will* modify the Gemfile(.lock), invalidate the cache and cause `bundle install` to be run again, even if none of your production gems changed!
* we may update different gems at different frequencies, e.g. core Rails gems get be updated rarely whereas gems developed in-house get updated frequently. Changing any of these gems causes *every* gem to be re-installed.

## Excluding test and development gems

The best way to do this is to place all non-test and development gems in a separate gemfile and generate an additional lockfile for that. For example:

```ruby
# production.gemfile
gem 'rails'
```

```ruby
# Gemfile
gem 'rspec', group: :test
eval_gemfile('production.gemfile') # include the production gems

# include the hack and generate the lockfile
require 'multi_lockfile_hack.rb'
extend Bundler::MultiLockfileHack
generate_lockfile(gemfile: 'production.gemfile')
```

`bundle install` this and you will have a `production.gemfile.lock`. We will now use that and `production.gemfile` in the Dockerfile:

```
# Dockerfile
COPY production.gemfile /path/to/app/Gemfile
COPY production.gemfile.lock /path/to/app/Gemfile.lock
RUN bundle install
COPY . /path/to/app
```

Notice also how it is no longer necessary to specify `--without test development` for `bundle install`
since test and development gems *don't appear* in `production.gemfile` and its lockfile at all.

### Separating gems based on update frequency

The principle is to separate gems into multiple gemfiles and generate lockfiles for each.
This can viewed as a more complex variation on the above problem since test/development gems are
updated with a frequency of zero (in production at least).

In this example, we will have a `rspec` test gem (never updated in production), `rails` (rarely updated) and `custom-inhouse-gem` (frequently updated).

```ruby
# Gemfile
gem 'rspec'

eval_gemfile('inhouse.gemfile')

require 'multi_lockfile_hack.rb'
extend Bundler::MultiLockfileHack
generate_lockfile(gemfile: 'rails.gemfile')
generate_lockfile(gemfile: 'inhouse.gemfile')
```

```ruby
# rails.gemfile
gem 'rails'
```

```ruby
# inhouse.gemfile
gem 'custom-inhouse-gem'
eval_gemfile('rails.gemfile')
```

`bundle install` this and you will have `rails.gemfile.lock` and `inhouse.gemfile.lock`. Now the Dockerfile:

```
# Dockerfile
COPY rails.gemfile /path/to/app/Gemfile
COPY rails.gemfile.lock /path/to/app/Gemfile.lock
# install and rename gemfile back to original name
# otherwise the eval_gemfile in inhouse.gemfile won't work.
RUN bundle install && mv Gemfile rails.gemfile

COPY inhouse.gemfile /path/to/app/Gemfile
COPY inhouse.gemfile.lock /path/to/app/Gemfile.lock
RUN bundle install

COPY . /path/to/app
```

We separate the rarely and frequently updated gems into separate gemfiles and generate their respective lockfiles.
When building the docker image, we add them in one at a time (most frequently updated last) and run bundle install each time.

Notice how we include `rails.gemfile` in the `inhouse.gemfile` so that the `inhouse.gemfile.lock` will also
contain all the Rails dependencies.

Now when the in-house gem is updated, the cache is invalidated at the `COPY inhouse.gemfile /path/to/app/Gemfile` step
when the rails gem has already been installed.
