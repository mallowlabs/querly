require_relative "../test_helper"
require "querly/cli/console"
require "pty"

class ConsoleTest < Minitest::Test
  include TestHelper

  def exe_path
    Pathname(__dir__) + "../../exe/querly"
  end

  def read_for(read, pattern:)
    timeout_at = Time.now + 3
    result = ""

    while true
      if Time.now > timeout_at
        raise "Timedout waiting for #{pattern}"
      end

      buf = ""
      read.read_nonblock 1024, buf rescue IO::EAGAINWaitReadable

      if buf == ""
        sleep 0.1
      else
        result << buf.force_encoding(Encoding::UTF_8)
      end

      if pattern =~ result
        break
      end
    end

    result
  end

  def test_console
    mktmpdir do |path|
      (path + "foo.rb").write(<<-EOF)
class UsersController
  def create
    user = User.create!(params[:user])
    redirect_to user_path(user)
  end
end
      EOF

      homedir = path + "home"
      homedir.mkdir

      history = path + "home/.querly/history"

      PTY.spawn({ "NO_COLOR" => "true", "QUERLY_HISTORY_SIZE" => "2", "HOME" => homedir.to_s }, exe_path.to_s, "console", chdir: path.to_s) do |read, write, pid|
        read_for(read, pattern: /^> $/)

        write.puts "reload!"
        read.gets
        read_for(read, pattern: /^> $/)

        write.puts "find create!"
        read.gets
        output = read_for(read, pattern: /^> $/)
        assert_match %r/#{Regexp.escape "User.create!(params[:user])"}/, output

        write.puts "find redirect_to"
        read.gets
        output = read_for(read, pattern: /^> $/)
        assert_match %r/#{Regexp.escape "redirect_to user_path(user)"}/, output

        write.puts "find User.find_each"
        read.gets
        output = read_for(read, pattern: /^> $/)
        assert_match %r/#{Regexp.escape "0 results"}/, output

        write.puts "find crea te !!"
        read.gets
        output = read_for(read, pattern: /^> $/)
        assert_match %r/#{Regexp.escape "parse error on value"}/, output

        write.puts "no such command"
        read.gets
        output = read_for(read, pattern: /^> $/)
        assert_match %r/#{Regexp.escape "Commands:"}/, output

        write.puts "quit"
        read.gets

        Process.wait pid
      end

      assert_equal ["find redirect_to", "find User.find_each"], history.readlines.map(&:chomp)

      PTY.spawn({ "NO_COLOR" => "true", "QUERLY_HISTORY_SIZE" => "2", "HOME" => homedir.to_s }, exe_path.to_s, "console", chdir: path.to_s) do |read, write, pid|
        read_for(read, pattern: /^> $/)

        write.puts "reload!"
        read.gets
        read_for(read, pattern: /^> $/)

        write.puts "find create!"
        read.gets
        output = read_for(read, pattern: /^> $/)
        assert_match %r/#{Regexp.escape "User.create!(params[:user])"}/, output

        write.puts "exit"
        read.gets

        Process.wait pid
      end

      assert_equal ["find User.find_each", "find create!"], history.readlines.map(&:chomp)
    end
  end

  def test_history_location_override
    mktmpdir do |path|
      (path + "foo.rb").write(<<-EOF)
class UsersController
  def create
    user = User.create!(params[:user])
    redirect_to user_path(user)
  end
end
      EOF

      homedir = path + "querly"
      homedir.mkdir

      PTY.spawn({ "NO_COLOR" => "true", "QUERLY_HISTORY_SIZE" => "2", "QUERLY_HOME" => homedir.to_s }, exe_path.to_s, "console", chdir: path.to_s) do |read, write, pid|
        read_for(read, pattern: /^> $/)

        write.puts "find create!"
        read.gets
        output = read_for(read, pattern: /^> $/)
        assert_match %r/#{Regexp.escape "User.create!(params[:user])"}/, output

        write.puts "quit"
        read.gets

        Process.wait pid
      end

      history = path + "querly/history"
      assert_equal ["find create!"], history.readlines.map(&:chomp)
    end
  end
end
