# encoding: UTF-8

#
#   MySQL Remote Backup Script
#
#   -----------------------------------------------------------------
#
#   Written by Greg Leuch (greg@xolator.com) * 14 Jul 2014
#   http://xolator.com
#
#



require 'rubygems'
require 'bundler'
Bundler.require

# DEFINE REQUIRE VARIABLES
APP_ROOT    = File.expand_path(File.dirname(__FILE__)) unless defined? APP_ROOT
APP_ENV     = (ENV['APP_ENV'] || 'development') unless defined? APP_ENV
TMP_FOLDER  = File.join(APP_ROOT, 'tmp') unless defined? TMP_FOLDER
DEBUG       = (ENV['DEBUG'] || false) unless defined? DEBUG

DEFAULT_MYSQL_OPTIONS = {username: 'root', sql_password: nil, host: nil, port: 3306, sql_file: nil}
S3_PREFIX = (DEBUG ? 'debug-mysql' : 'mysql')

# Ensure tmp folder exists
Dir.mkdir(TMP_FOLDER) unless File.exists?(TMP_FOLDER) 

# LOAD GEMS
%w(yaml aws-sdk cocaine).each{|r| require r}

class Object; def blank?; self !~ /\S/; end; alias_method(:empty?,:blank?); end
class String; def blank?; self !~ /\S/; end; alias_method(:empty?,:blank?); end
class Numeric; def blank?; self !~ /\S/; end; alias_method(:empty?,:blank?); end
class NilClass; def blank?; true; end; alias_method(:empty?,:blank?); end


begin
  # READ FROM YAML FILES
  @info = YAML::load( File.open( File.join(APP_ROOT, "secrets.yml") ) )[APP_ENV] rescue nil
  raise "Missing YAML info for #{APP_ENV}." if @info.nil?


  # CONNECT TO AWS
  s3_conn = AWS::S3.new( @info['s3'] ) rescue nil
  raise "Could not connect to S3" if s3_conn.nil?
  @s3 = s3_conn.buckets[ @info['s3']['bucket'] ]
  raise "Could not find S3 bucket #{@info['s3']['bucket']}" unless @s3.exists?


  # DUMP, GZIP, UPLOAD EACH DATABASE
  @info['mysql'].each do |app,db_info|
    time_now = Time.now.utc

    begin
      # Set filenames
      # TODO :: ALLOW SPECIFY S3 PATH FORMAT IN YAML
      fname = [db_info['database'], time_now.strftime('%H:%M:%S')].join('-')
      sql_filename, gzip_filename = [fname, 'sql'].join('.'), [fname, 'sql', 'gz'].join('.')
      sql_file, gzip_file = File.join(TMP_FOLDER, sql_filename), File.join(TMP_FOLDER, gzip_filename)
      s3_path = File.join(S3_PREFIX, time_now.strftime('%Y'), time_now.strftime('%m'), time_now.strftime('%d'), gzip_filename )

      # Run mysqldump
      db_info[:sql_password] = '-p' + db_info[:password] unless db_info[:password].blank?

      mysqldump = Cocaine::CommandLine.new('mysqldump', '-u :username :sql_password -h :host -P :port :database > :sql_file')
      mysqldump.send((DEBUG ? :command : :run), DEFAULT_MYSQL_OPTIONS.merge(db_info).merge({sql_file: sql_file}))


      # Gzip SQL file
      gzipcmd = Cocaine::CommandLine.new('gzip', '-c :sql_file > :gzip_file')
      gzipcmd.send((DEBUG ? :command : :run), {sql_file: sql_file, gzip_file: gzip_file})


      # Upload to S3
      s3_file = @s3.objects[ s3_path ]
      s3_file.write(file: gzip_file) unless DEBUG
      # TODO : Permissions?

    rescue => err
      puts  "Error (2): MySQL #{app}: #{err}"
      puts err.backtrace
    ensure
      # Close DB connection
      @db.close rescue nil

      # Delete SQL & GZ files
      File.unlink(sql_file) rescue nil
      File.unlink(gzip_file) rescue nil
      next
    end
  end

rescue => err
  puts "Error (1): #{err}"
  puts err.backtrace
end


