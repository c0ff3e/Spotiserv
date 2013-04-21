#! /usr/bin/env ruby
# -*- coding: utf-8 -*-

require "hallon"
require "hallon-openal"
#require "yaml"
class SpotiPlay
  attr_accessor :player, :playlist, :playing, :external_playlist, :local_playlist, :paused, :playlistSpotifyUrl

  def initialize (username, password)
    # Setting up variables
    self.playing = false
    self.paused = false
    self.playlist = []
    self.playlistSpotifyUrl = []
    self.local_playlist = Time.new.strftime('%Y-%m-%d.txt')
    self.external_playlist = "spotify:user:c0ff3e:playlist:25y7TfzZAtxDa8Ua5AHd5c"
    
    # This is a quick sanity check, to make sure we have all the necessities in order.
    appkey_path = File.expand_path('./spotify_appkey.key')
    unless File.exists?(appkey_path)
      abort <<-ERROR
    Your Spotify application key could not be found at the path:
      #{appkey_path}

    Please adjust the path in examples/common.rb or put your application key in:
      #{appkey_path}

    You may download your application key from:
      https://developer.spotify.com/en/libspotify/application-key/
      ERROR
    end
    hallon_appkey = IO.read(appkey_path)
    :track
    # Make sure the credentials are there. We don’t want to go without them.
    if username.empty? or password.empty?
      abort "Sorry, you must supply both username and password for Hallon to be able to log in."
    end
    
    session = Hallon::Session.initialize(hallon_appkey) do
      on(:log_message) do |message|
        puts "[LOG] #{message}"
      end
      
      on(:credentials_blob_updated) do |blob|
        puts "[BLOB] #{blob}"
      end
      
      on(:connection_error) do |error|
        Hallon::Error.maybe_raise(error)
      end
      
      on(:logged_out) do
        abort "[FAIL] Logged out!"
      end
    end
    session.login!(username, password)
    
    self.player = Hallon::Player.new(Hallon::OpenAL)
    
    if File.exists?('tmp/'+ self.local_playlist + ".list")
		  m = YAML.load(File.read('tmp/'+ self.local_playlist + ".list"))
#		  binding.pry
			for tracks in m
			 track = Hallon::Track.new(tracks[:track]).load
			 olle = tracks[:track]
			 playlistSpotifyUrl.push({:track => olle})
			 self.add_to_playlist ({:track => track, :user => "Old"})
			end
		end
  end

  #TODO: INFO, Remove console output
  def p_play (track)
    Thread.new {
      puts "Playing: #{track.name} by #{track.artist.name}"
      self.player.play!(track)
      puts "Song ended: #{track.name} by #{track.artist.name}"
      self.playlist.shift
      self.playlistSpotifyUrl.shift
      self.sync_playlist
      if self.playlist.empty?
        puts "No more songs in playlist, trying to open external playlist"
        unless self.external_playlist.nil?
          puts "No more songs in playlist, playing random song from external playlist"
          self.p_play (self.external_playlist.tracks[rand(self.external_playlist.tracks.size)])
        else
          puts "else"
        end
        self.player.stop
      else
        puts "Starting next song"
        self.p_play (self.playlist.first[:track])
        self.playlistSpotifyUrl.shift
        self.sync_playlist
      end
    }
  end

  # Play the next song in the playlist
  def p_next
    unless self.playlist.empty?
      if self.playing
        puts "Next song"
        self.playlist.shift
        self.playlistSpotifyUrl.shift
        self.sync_playlist
        self.p_play (self.playlist.first[:track])
      else
        puts "player is not playing a song right now, starting playback"
        self.playing = true
        p_next
      end
    else
      self.playlistSpotifyUrl.shift
      self.sync_playlist
      "no tracks in playlist, add some please"
    end
  end

  def set_playlist (playlist = null)
    puts "Spotithin.set_playlist"
    if playlist
      self.playing = true
      self.external_playlist = playlist
      self.playlistSpotifyUrl.shift
      self.sync_playlist      
      self.p_play (self.external_playlist.tracks[rand(self.external_playlist.tracks.size)])
    else
      self.playing = false
    end
  end

  def p_pause
    self.player.pause
    self.paused = true
    self.playing = false
    puts "Pausing"
  end

  def p_resume
    self.player.play
		self.playing = true
    self.paused = false
    puts "Resuming play"
  end

  def play_pause
    if self.playing
      self.playing = false
      self.player.pause
      self.paused = true
      puts "pausing player"
    else
      self.playing = true
      self.paused = false
      self.player.play
      puts "un-pausing player"
    end
  end
  
  # Adds a track to the current playlist, takes a hash. {:track=>Hallon::Track, :user=>String}
  def add_to_playlist (item)
    self.playlist.push (item)
    self.sync_playlist
    "Added #{item[:track].name} to the playlist!"

    File.open("tmp/" + self.local_playlist, "a") do |f|
      f.write (item[:track].name + " - " +  item[:track].artist.name + "\n")
    end
    unless self.player.status == :playing
    	if self.paused == false 
	      self.p_play (self.playlist.first[:track])
  	    self.playing = true
			end
    end
  end

 def sync_playlist
  File.open('tmp/'+ self.local_playlist + ".list", 'w') do |f| 
   f.write(YAML.dump(self.playlistSpotifyUrl))
  end
  #binding.pry
 end
end
