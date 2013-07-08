module EbDeployer
  class Beanstalk
    attr_reader :client
    def initialize(client=AWS::ElasticBeanstalk.new.client)
      @client = client
    end

    def create_application(app)
      @client.create_application(:application_name => app)
    end

    def application_exists?(app)
      @client.describe_applications(:application_name => app)[:applications].any?
    end

    def update_environment(app_name, env_name, version, settings)
      env_id = convert_env_name_to_id(app_name, [env_name]).first
      @client.update_environment(:environment_id => env_id,
                                 :version_label => version,
                                 :option_settings => settings)
    end

    def environment_exists?(app_name, env_name)
      alive_envs(app_name, [env_name]).any?
    end

    def create_environment(app_name, env_name, stack_name, cname_prefix, version, settings)
      request = {:application_name => app_name,
        :environment_name => env_name,
        :solution_stack_name => stack_name,
        :version_label => version,
        :option_settings => settings }
      request[:cname_prefix] = cname_prefix if cname_prefix
      @client.create_environment(request)
    end

    def create_application_version(app_name, version_label, source_bundle)
      @client.create_application_version(:application_name => app_name,
                                         :source_bundle => source_bundle,
                                         :version_label => version_label)
    end

    def application_version_labels
      @client.describe_application_versions[:application_versions].map { |apv| apv[:version_label] }
    end

    def fetch_events(app_name, env_name, params, &block)
      response = @client.describe_events(params.merge(:application_name => app_name,
                                                      :environment_name => env_name))
      return [response[:events], response[:next_token]]
    end

    def environment_cname_prefix(app_name, env_name)
      cname = environment_cname(app_name, env_name)
      if cname =~ /^(.+)\.elasticbeanstalk\.com/
        $1
      end
    end

    def environment_cname(app_name, env_name)
      env = alive_envs(app_name, [env_name]).first
      env && env[:cname]
    end

    def environment_health_state(app_name, env_name)
      env = alive_envs(app_name, [env_name]).first
      env && env[:health]
    end

    def environment_swap_cname(app_name, env1, env2)
      env1_id, env2_id = convert_env_name_to_id(app_name, [env1, env2])
      @client.swap_environment_cnam_es(:source_environment_id => env1_id,
                                       :destination_environment_id => env2_id)
    end

    private

    def convert_env_name_to_id(app_name, env_names)
      envs = alive_envs(app_name, env_names)
      envs.map { |env| env[:environment_id] }
    end

    def alive_envs(app_name, env_names=[])
      envs = @client.describe_environments(:application_name => app_name, :environment_names => env_names)[:environments]

      envs.select {|e| e[:status] != 'Terminated' }
    end

  end
end
