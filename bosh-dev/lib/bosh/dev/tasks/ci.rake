namespace :ci do
  namespace :run do
    desc 'Meta task to run spec:unit and rubocop'
    task unit: %w(spec:unit)

    desc 'Meta task to run spec:integration'
    task integration: %w(spec:integration)

    desc 'Task that installs a go binary locally and runs go agent tests'
    task :go_agent_tests do
      FileUtils.mkdir_p('tmp')
      sh 'curl https://go.googlecode.com/files/go1.2.linux-amd64.tar.gz > tmp/go.tgz'
      sh 'tar xzf tmp/go.tgz -C tmp'

      path = [File.absolute_path('tmp/go/bin'), ENV['PATH']].join(':')
      env = { 'PATH' => path }
      sh(env, 'which', 'go')
      sh(env, 'go_agent/bin/go', 'version')
      sh(env, 'go_agent/bin/test')
    end
  end

  desc 'Publish CI pipeline gems to S3'
  task :publish_pipeline_gems do
    require 'bosh/dev/build'
    require 'bosh/dev/gems_generator'
    build = Bosh::Dev::Build.candidate
    gems_generator = Bosh::Dev::GemsGenerator.new(build)
    gems_generator.generate_and_upload
  end

  desc 'Publish CI pipeline BOSH release to S3'
  task publish_bosh_release: [:publish_pipeline_gems] do
    require 'bosh/dev/build'
    require 'bosh/dev/bosh_release_publisher'
    build = Bosh::Dev::Build.candidate
    Bosh::Dev::BoshReleasePublisher.setup_for(build).publish
  end

  desc 'Build a stemcell for the given :infrastructure, :operating_system, and :agent_name and publish to S3'
  task :publish_stemcell, [:stemcell_path] do |_, args|
    require 'bosh/dev/stemcell_publisher'

    stemcell_publisher = Bosh::Dev::StemcellPublisher.for_candidate_build
    stemcell_publisher.publish(args.stemcell_path)
  end

  desc 'Build a stemcell for the given :infrastructure, :operating_system, :agent_name, :s3 bucket_name, and :s3 os image key on a stemcell building vm and publish to S3'
  task :publish_stemcell_in_vm, [:infrastructure_name, :operating_system_name, :vm_name, :agent_name, :os_image_s3_bucket_name, :os_image_s3_key] do |_, args|
    require 'bosh/dev/build'
    require 'bosh/dev/stemcell_vm'
    require 'bosh/stemcell/definition'
    require 'bosh/stemcell/build_environment'

    definition = Bosh::Stemcell::Definition.for(args.infrastructure_name, args.operating_system_name, args.agent_name)
    environment = Bosh::Stemcell::BuildEnvironment.new(ENV.to_hash, definition, Bosh::Dev::Build.candidate.number, nil, nil)

    stemcell_vm = Bosh::Dev::StemcellVm.new(args.to_hash, ENV, environment)
    stemcell_vm.publish
  end

  desc 'Promote from pipeline to artifacts bucket'
  task :promote_artifacts do
    require 'bosh/dev/build'
    build = Bosh::Dev::Build.candidate
    build.promote_artifacts
  end

  desc 'Promote candidate sha to stable branch outside of the promote_artifacts task'
  task :promote, [:candidate_build_number, :candidate_sha, :stable_branch] do |_, args|
    require 'logger'
    require 'bosh/dev/promoter'
    promoter = Bosh::Dev::Promoter.build(args.to_hash)
    promoter.promote
  end
end
