require 'puppet'
require 'puppet/face'

Puppet::Face.define(:bucket, '0.0.1') do
  summary "Interact with the filebucket"
  copyright "David Gwilliam", 2014
  license "Apache 2"

  action :list do
    summary "List all the files in the filebucket"

    option '--date' do
      summary "Sort by date instead of filename"
      default_to { false }
    end

    option '--reverse' do
      summary "Reverse sort order"
      default_to { false }
    end

    when_invoked do |options|
      list = Bucket.scan_md5.map {|m| BucketFile.new(:md5 => m)}

      if options[:date] and options[:reverse]
        list.sort! {|f, g| g.date <=> f.date}
      elsif options[:date] and !options[:reverse]
        list.sort_by! {|f| f.date}
      elsif !options[:date] and options[:reverse]
        list.sort! {|f, g| g.path <=> f.path}
      else
        list.sort_by! {|f| f.path}
      end

      list.each do |file|
        puts "#{file.md5}\t#{file.human_date}\t#{file.path}"
      end
      nil
    end
  end

  action :view do
    summary "Display the contents of a file (by md5)"
    arguments "<md5>"

    when_invoked do |md5, options|
      exec("less #{BucketFile.new(:md5 => md5).absolute_path}/contents") if md5
    end

  end

  action :copy do
    summary "Copy the contents of a BucketFile to another location"
    arguments "<md5> <dest>"

    when_invoked do |md5, dest, options|
      exec("cp #{BucketFile.new(:md5 => md5).absolute_path}/contents #{dest}")
    end
  end
end


class BucketFile
  def initialize(args)
    if args[:md5]
      @md5      = args[:md5] ? args[:md5] : md5
      @abs_path = absolute_path
    elsif args[:path]
      @abs_path = args[:path] ? args[:path] : absolute_path
      @md5      = md5
    end
    @date     = date
    @path     = path
  end

  def md5
    @md5 || absolute_path.slice(/[a-f0-9]{32}/)
  end

  def absolute_path
    @abs_path || Bucket.scan_file.select {|f| f.match(/#{md5}/)}.first
  end

  def md5_dir
    m = md5
    "#{m[0]}/#{m[1]}/#{m[2]}/#{m[3]}/#{m[4]}/#{m[5]}/#{m[6]}/#{m[7]}"
  end

  def basename
    @basename || File.basename(path)
  end

  def path
    @path || File.read("#{absolute_path}/paths").chomp
  end

  def date
    @date || File.mtime(absolute_path + "/contents")
  end

  def human_date
    date.strftime('%F %H:%M')
  end

  def self.bucket
    Bucket.path
  end
end

class Bucket
  def self.path
    if File.exist?('/var/opt/lib/pe-puppet/bucket')
      [ '/var/opt/lib/pe-puppet/bucket', '/var/opt/lib/pe-puppet/clientbucket' ]
    else
      [ '/var/lib/puppet/bucket' , '/var/lib/puppet/clientbucket']
    end
  end

  def self.scan_md5
    Bucket.path.map {|path|
      Dir.glob("#{path}/**/*").select {|p| File.file?(p) }.
        map {|f| f.slice(/[a-f0-9]{32}/)}.uniq
    }.flatten
  end

  def self.scan_file
    Bucket.path.map {|path|
      Dir.glob("#{path}/**/*/").select {|p| File.directory?(p) and p.match(/[a-f0-9]{32}/) }
    }.flatten.map{|p| p.chop if p.end_with?('/')}
  end
end