#! /usr/bin/env ruby
# -*- coding: utf-8 -*-

# This is a webserver that is suppose to handle incomming requests for Spotiserv

# Requirements
require "thin"
require "active_support/core_ext"

# Web-server that sends requests to the player-server, and sends info the users
class SpotiThin

  # Starting server, takes: ip, port and player-server (SpotiPlay)
  def initialize (ip, port, sp)
    puts "Starting thin, webserber on: http://" + ip + ":" + port.to_s

    # Registrates the resources for the web-server
    Thin::Server.start(ip, port) do
	logger = Logger.new('tmp/app.log')
      use Rack::CommonLogger,logger
      
      # /add, to add a song to the playlist: /add/<user-code>/<spotify-uri>
      map "/add" do
        run Add_song.new sp
      end
      
      # TODO add comment
      map "/add_album" do
        run Add_album.new sp
      end
      
      # /playlist, set a playlist: /playlist/<spotify-uri>
      map "/playlist" do
        run Playlist.new sp
      end

      # /queue.xml, the ajax request from the browser
      map "/queue.xml" do
        run Queue_song.new sp.playlist
      end

      # /status.xml, the ajax request from the browser
      map "/status.xml" do
        run Status.new sp
      end

      # /next, skips the current song and starts the next instead
      map "/next" do
        run Next_song.new sp
      end

      # /pp, Pause or plays a toggle
      map "/pp" do
        run Play_Pause.new sp
      end 

      # /resume, Pause or plays a toggle
      map "/resume" do
        run Resume.new sp
      end      

      # / and /index.html, page with js that loads the xml-file every 3rd second.
      map "/" do
        run Index.new
      end

      # /controllerpage with js that loads the xml-file every 3rd second.
      map "/controller" do
        run Controll.new
      end
      
    end
  end
  
  # Resource that reads a user and a sporify-uri, and adds this to the playlist of the play-server.
  class Add_song
    def initialize (sp)
      @sp = sp
    end
    
    # TODO: remove some of the console-output
    def call(env)
      rp = env["PATH_INFO"]
      puts env["HTTP_USER_AGENT"]
      puts "Addsong"
      puts "rp: #{rp}"
      user, track_uri = rp.match(/^\/(\w*)\/(.*)/)[1..2]
      puts "User: " + user
      puts "Track: " + track_uri
      track = Hallon::Track.new(track_uri).load
      @sp.playlistSpotifyUrl.push({:track=>track_uri})
      @sp.add_to_playlist ({:track => track, :user => user})
      xml = {:command=>"add", :track=>track.name, :artist=>track.artist.name,
        :album=>track.album.name, :user=>user}.to_xml
      [200, {'Content-Type'=>'text/xml'}, [xml]]
    end
  end

  class Next_song
    def initialize (sp)
      @sp = sp
    end

    def call(env)
      @sp.p_next
      xml = {:command=>"next"}.to_xml
      [200, {'Content-Type'=>'text/xml'}, [xml]]
    end
  end

  class Play_Pause
    def initialize (sp)
      @sp = sp
    end

    def call(env)
      @sp.play_pause
      xml = {:command=>"play_pause"}.to_xml
      [200, {'Content-Type'=>'text/xml'}, [xml]]
    end
  end

  class Resume
    def initialize (sp)
      @sp = sp
    end

    def call(env)
      @sp.p_resume
      xml = {:command=>"resume"}.to_xml
      [200, {'Content-Type'=>'text/xml'}, [xml]]
    end
  end

  class Add_album
    
    def initialize (sp)
      @sp = sp
    end
    
    # TODO: remove some of the console-output
    def call(env)
      rp = env["PATH_INFO"]
      puts env["HTTP_USER_AGENT"]
      puts "SptiThin.Thin.Add_album, rp: #{rp}"
      user, album_uri = rp.match(/^\/(\w*)\/(.*)/)[1..2]
      puts "User: " + user
      puts "Album: " + album_uri
      albumBrowse = Hallon::Album.new(album_uri).browse.load
      for track in albumBrowse.tracks
      binding.pry
      @sp.playlistSpotifyUrl.push({:track=>track})	
        @sp.add_to_playlist ({:track => track, :user => user})
	sleep(1)
      end
      xml = {:command=>"add_album", :track=>track.name, :artist=>track.artist.name,
        :album=>track.album.name, :user=>user}.to_xml
      [200, {'Content-Type'=>'text/xml'}, [xml]]
    end
  end
  
  class Playlist
    def initialize (sp)
      @sp = sp
    end
    
    def call(env)
      puts "SpotiThin.Thin.Playlist"
      rp = env["PATH_INFO"]
      puts "rp: #{rp}"
      playlist_uri = rp.match(/^\/(.*)/)[1]
      puts "Playlist: " + playlist_uri
      playlist = Hallon::Playlist.new(playlist_uri).load
      @sp.set_playlist(playlist)
      xml = {:command=>"playlist", :playlist=>playlist.name}.to_xml
      [200, {'Content-Type'=>'text/xml'}, [xml]]
    end
  end

  class Queue_song
    def initialize (playlist)
      @playlist = playlist
    end

    def call(env)
      xmlArray = []
      @playlist.take(20).each {|item| xmlArray.push({ :artist=>item[:track].artist.name, :song=>item[:track].name,
                                                      :album=>item[:track].album.name, :user=>item[:user], :unit=>"N/A"})}
      xml = xmlArray.to_xml(:root => "item")
      [200, {"Content-Type"=>"text/xml"}, [xml]]
    end
  end

  class Status
    def initialize (sp)
      @sp = sp
    end

    def call(env)
			xmlArray = []
			xmlArray.push({:command=>"Status", :Paused=>@sp.paused.to_s, :Playing=>@sp.playing.to_s})
			xml = xmlArray.to_xml(:root => "item")
      [200, {"Content-Type"=>"text/xml"}, [xml]]
    end
  end

	class Controll
    def call(env)
      js = %?
<script>
function loadQueues2() {
	var xmlhttp;
	var x,xx,txt,paused,play;
	if (window.XMLHttpRequest) {// code for IE7+, Firefox, Chrome, Opera, Safari
		xmlhttp=new XMLHttpRequest();
	} else {// code for IE6, IE5
		xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
	}
	xmlhttp.onreadystatechange=function() {
		if (xmlhttp.readyState==4 && xmlhttp.status==200) {
			x=xmlhttp.responseXML.documentElement.getElementsByTagName("item");
			for (i=0;i<x.length;i++) {
			xx=x[i].getElementsByTagName("Playing"); {
				play=xx[0].firstChild.nodeValue;
			}
			xx=x[i].getElementsByTagName("Paused"); {
				paused=xx[0].firstChild.nodeValue;
			}
			}
			}
			if (play == "true") {
				txt='<img onclick="switcha()" src="http://79.102.148.111:8002/pause.png" hight="72" width="72">';
			} else {
				txt='<img onclick="switcha()" src="http://79.102.148.111:8002/play.png" hight="72" width="72">';			
			}
			document.getElementById("queueInfo2").innerHTML=txt;
	}
	xmlhttp.open("GET","status.xml",true);
	xmlhttp.send();
}

function switcha() {
	var xmlhttp2;
	if (window.XMLHttpRequest) {// code for IE7+, Firefox, Chrome, Opera, Safari
		xmlhttp2=new XMLHttpRequest();
	} else {// code for IE6, IE5
		xmlhttp2=new ActiveXObject("Microsoft.XMLHTTP");
	}
	xmlhttp2.onreadystatechange=function() {
	}
	xmlhttp2.open("GET","pp",true);
	xmlhttp2.send();
}

function nexta() {
	var xmlhttp2;
	if (window.XMLHttpRequest) {// code for IE7+, Firefox, Chrome, Opera, Safari
		xmlhttp3=new XMLHttpRequest();
	} else {// code for IE6, IE5
		xmlhttp3=new ActiveXObject("Microsoft.XMLHTTP");
	}
	xmlhttp3.onreadystatechange=function() {
	}
	xmlhttp3.open("GET","next",true);
	xmlhttp3.send();
}

function looper() {
	setInterval(function(){loadQueues2()},3000);
}

window.onload = looper;

</script>
    ?

      head = %%
    <title>SpotiServ, Controller</title>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">

    <link href='http://fonts.googleapis.com/css?family=Merriweather+Sans:400,700,800' rel='stylesheet' type='text/css'>
%

      css = """
    <style>
      body {background-color:white; font-family: 'Merriweather Sans', sans-serif; font-weight: 700; font-size:175%;}
      h1 {font-family: 'Merriweather Sans', sans-serif; font-weight: 800; font-size:300%;}
      table {border-collapse:collapse;width:100%}
      th, td {border: 2px solid #98bf21; padding:3px 7px 2px 7px;}
      th {text-align:center; padding-top:5px; padding-bottom:4px; background-color:#A7C942; color:#ffffff;}
      tr.alt td{color:#000000; background-color:#EAF2D3;}

      #queueInfo {margin:40px;}
    </style>
"""

      html = %%<!DOCTYPE html>
<html>
  <head>
    #{head}
    #{css}
    #{js}
  </head>
  <body>
  <center>
    <div id="queueInfo2">
    </div>
    <div id="next"> <img onclick="nexta()" src="http://79.102.148.111:8002/next.png" hight="72" width="72">
    </div>
  </center>
  </body>
</html>
%
      
      [200, {"Content-Type"=>"text/html"}, [html]]
    end
  end



  class Index
    def call(env)
      js = %?
<script>
    function loadQueues() {
	var xmlhttp;
	var txt,x,xx,i;
	if (window.XMLHttpRequest) {// code for IE7+, Firefox, Chrome, Opera, Safari
	    xmlhttp=new XMLHttpRequest();
	} else {// code for IE6, IE5
	    xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
	}
	xmlhttp.onreadystatechange=function() {
	    if (xmlhttp.readyState==4 && xmlhttp.status==200) {
		txt="<table><tr><th>Artist</th><th>Track</th><th>Album</th><th>Name</th><th>Device</th></tr>";
		x=xmlhttp.responseXML.documentElement.getElementsByTagName("item");
		for (i=0;i<x.length;i++) {
		    if (i%2 == 1)
			txt=txt + "<tr>";
		    else
			txt=txt + "<tr class='alt'>";
		    xx=x[i].getElementsByTagName("artist"); {
			try {
			    txt=txt + "<td>" + xx[0].firstChild.nodeValue + "</td>";
			} catch (er) {
			    txt=txt + "<td> </td>";
			}
                    }
		    xx=x[i].getElementsByTagName("song"); {
			try {
			    txt=txt + "<td>" + xx[0].firstChild.nodeValue + "</td>";
			} catch (er) {
			    txt=txt + "<td> </td>";
			}
                    }
		    xx=x[i].getElementsByTagName("album"); {
			try {
			    txt=txt + "<td>" + xx[0].firstChild.nodeValue + "</td>";
			} catch (er) {
			    txt=txt + "<td> </td>";
			}
                    }

		    xx=x[i].getElementsByTagName("user"); {
			try {
			    txt=txt + "<td>" + xx[0].firstChild.nodeValue + "</td>";
			} catch (er) {
			    txt=txt + "<td> </td>";
			}
                    }
		    xx=x[i].getElementsByTagName("unit"); {
			try {
			    txt=txt + "<td>" + xx[0].firstChild.nodeValue + "</td>";
			} catch (er) {
			    txt=txt + "<td> </td>";
			}
                    }

		    txt=txt + "</tr>";
		}
		txt=txt + "</table>";
		document.getElementById("queueInfo").innerHTML=txt;
	    }
        }
	xmlhttp.open("GET","queue.xml",true);
	xmlhttp.send();
    }

    function looper() {
      setInterval(function(){loadQueues()},3000);
    }

    window.onload = looper;
</script>
    ?

      head = %%
    <title>SpotiServ, Playlist</title>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">

    <link href='http://fonts.googleapis.com/css?family=Merriweather+Sans:400,700,800' rel='stylesheet' type='text/css'>
%

      css = """
    <style>
      body {background-color:white; font-family: 'Merriweather Sans', sans-serif; font-weight: 700; font-size:175%;}
      h1 {font-family: 'Merriweather Sans', sans-serif; font-weight: 800; font-size:300%;}
      table {border-collapse:collapse;width:100%}
      th, td {border: 2px solid #98bf21; padding:3px 7px 2px 7px;}
      th {text-align:center; padding-top:5px; padding-bottom:4px; background-color:#A7C942; color:#ffffff;}
      tr.alt td{color:#000000; background-color:#EAF2D3;}

      #queueInfo {margin:40px;}
    </style>
"""

      html = %%<!DOCTYPE html>
<html>
  <head>
    #{head}
    #{css}
    #{js}
  </head>
  <body>
    
  <center>
    <div id="head"><h1>SpotiServ, PlayQueue</h1></div>
    <div id="queueInfo">
    </div>
    <div id="queueInfo2">
    </div>
  </center>
    
  </body>
</html>
%
      
      [200, {"Content-Type"=>"text/html"}, [html]]
    end
  end

end
