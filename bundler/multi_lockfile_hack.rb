module Bundler::MultiLockfileHack

  Locks = Struct.new(:gemfile, :groups, :lockfile)

  def self.lockfiles; @lockfiles ||= {}; end

  def to_definition(lockfile, unlock)
    super
    DefinitionHack.new(lockfile, @dependencies, @sources, unlock, @ruby_version)
  end

  def generate_lockfile(lockfile: nil, gemfile: nil, groups: nil)
    raise 'Expected one of gemfile or groups' unless gemfile or groups

    groups &&= Array(groups)
    lockfile ||= [gemfile, groups, 'lock'].flatten.compact.join('.')
    Bundler::MultiLockfileHack.lockfiles[lockfile] = Locks.new(gemfile, groups, lockfile)
  end

  class DefinitionHack < Bundler::Definition
    def lock(*)
      result = super
      Bundler::MultiLockfileHack.lockfiles.values.each{|data| _write_lock(data)}
      result
    end

    def _write_lock(data)
      if data.gemfile
        deps = Bundler::Dsl.new.eval_gemfile(data.gemfile)
      else
        deps = @dependencies
      end

      deps = deps.select{|d| (d.groups & data.groups).any?} if data.groups
      DefinitionHack2.new(data.lockfile, deps, @sources, @unlock, @ruby_version).lock(data.lockfile)
    end
  end

  class DefinitionHack2 < Bundler::Definition
    def resolve
      super.select{|spec| @dependencies.map(&:name).include? spec.name}
    end
  end

end
