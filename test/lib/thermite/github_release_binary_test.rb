require 'tmpdir'
require 'test_helper'
require 'thermite/github_release_binary'
require 'thermite/util'

module Thermite
  class GithubReleaseBinaryTest < Minitest::Test
    include Thermite::ModuleTester

    class Tester
      include Thermite::GithubReleaseBinary
      include Thermite::TestHelper
      include Thermite::Util
    end

    def test_no_downloading_when_github_releases_is_false
      mock_module(github_releases: false)
      mock_module.expects(:download_latest_binary_from_github_release).never
      mock_module.expects(:download_cargo_version_from_github_release).never

      assert !mock_module.download_binary
    end

    def test_github_release_type_defaults_to_cargo
      mock_module(github_releases: true)
      mock_module.expects(:download_latest_binary_from_github_release).never
      mock_module.expects(:download_cargo_version_from_github_release).once

      mock_module.download_binary
    end

    def test_download_cargo_version_from_github_release
      mock_module(github_releases: true)
      mock_module.config.stubs(:toml).returns(package: { version: '4.5.6' })
      mock_module.expects(:github_download_uri).with('v4.5.6', '4.5.6').returns('github://')
      Net::HTTP.stubs(:get_response).returns('location' => 'redirect')
      mock_module.stubs(:http_get).returns('tarball')
      mock_module.expects(:unpack_tarball).once

      assert mock_module.download_binary
    end

    def test_download_cargo_version_from_github_release_with_custom_git_tag_format
      mock_module(github_releases: true, git_tag_format: 'VER_%s')
      mock_module.config.stubs(:toml).returns(package: { version: '4.5.6' })
      mock_module.expects(:github_download_uri).with('VER_4.5.6', '4.5.6').returns('github://')
      Net::HTTP.stubs(:get_response).returns('location' => 'redirect')
      mock_module.stubs(:http_get).returns('tarball')
      mock_module.expects(:unpack_tarball).once

      assert mock_module.download_binary
    end

    def test_download_cargo_version_from_github_release_with_client_error
      mock_module(github_releases: true)
      mock_module.config.stubs(:toml).returns(package: { version: '4.5.6' })
      Net::HTTP.stubs(:get_response).returns(Net::HTTPClientError.new('1.1', 403, 'Forbidden'))

      assert !mock_module.download_binary
    end

    def test_download_cargo_version_from_github_release_with_server_error
      mock_module(github_releases: true)
      mock_module.config.stubs(:toml).returns(package: { version: '4.5.6' })
      server_error = Net::HTTPServerError.new('1.1', 500, 'Internal Server Error')
      Net::HTTP.stubs(:get_response).returns(server_error)

      assert_raises Net::HTTPServerException do
        mock_module.download_binary
      end
    end

    def test_download_latest_binary_from_github_release
      mock_module(github_releases: true, github_release_type: 'latest', git_tag_regex: 'v(.*)-rust')
      stub_releases_atom
      mock_module.stubs(:download_binary_from_github_release).returns(StringIO.new('tarball'))
      mock_module.expects(:unpack_tarball).once

      assert mock_module.download_binary
    end

    def test_download_latest_binary_from_github_release_no_releases_match_regex
      mock_module(github_releases: true, github_release_type: 'latest')
      stub_releases_atom
      mock_module.expects(:github_download_uri).never

      assert !mock_module.download_binary
    end

    def test_download_latest_binary_from_github_release_no_tarball_found
      mock_module(github_releases: true, github_release_type: 'latest', git_tag_regex: 'v(.*)-rust')
      stub_releases_atom
      mock_module.stubs(:download_binary_from_github_release).returns(nil)
      mock_module.expects(:unpack_tarball).never

      assert !mock_module.download_binary
    end

    private

    def described_class
      Tester
    end

    def stub_releases_atom
      atom = File.read(fixtures_path('github', 'releases.atom'))
      project_uri = 'https://github.com/user/project'
      releases_uri = "#{project_uri}/releases.atom"
      mock_module.config.stubs(:toml).returns(package: { repository: project_uri })
      mock_module.expects(:http_get).with(releases_uri).returns(atom)
    end
  end
end