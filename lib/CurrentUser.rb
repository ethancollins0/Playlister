require 'rest-client'
require 'json'
require 'pry'

class CurrentUser
    def self.make_user name
        if User.where(name: name).count == 0
            user = User.create(name: name)
            CurrentUser.create_playlist(name, 'Default Playlist')           
            user
        end
    end
  
    def self.get_playlist_id(username, playlistName)
        userId = User.where(name: username).first.id
        Playlist.where(user_id: userId).where(name: playlistName).first.id
    end

    def self.create_playlist username, playlistName
        inputId = User.where(name: username).first.id
        if Playlist.where(user_id: inputId).where(name: playlistName).count == 0
            Playlist.create(user_id: inputId, name: playlistName)
        else 
            "A playlist of that name already exists, please choose a different name or delete this playlist first."
        end
    end

    def self.save_song h, username, playlistName # takes in hash, username, playlistName
        if Song.where(title: h[:title]).where(artist: h[:artist]).count == 0
            song = Song.create(title: h[:title], artist: h[:artist], album: h[:album], genre: h[:genre], year: h[:year]) #adds songs, attr values nil by default
        else
            song = Song.where(title: h[:title]).where(artist: h[:artist]).first
        end
        playlistId = CurrentUser.get_playlist_id(username, playlistName)
        Playlistsong.create(song_id: song.id, playlist_id: playlistId)
    end

    def self.get_playlist_id(username, playlistName)
        userId = User.where(name: username).first.id
        Playlist.where(user_id: userId).where(name: playlistName).first.id
    end

    def self.delete_playlist_songs username, playlistName
        playlistId = CurrentUser.get_playlist_id(username, playlistName)
        Playlistsong.where(playlist_id: playlistId).destroy_all
    end

    def self.delete_playlist username, playlistName #deletes playlist and songs
        playlistId = CurrentUser.get_playlist_id(username, playlistName)
        CurrentUser.delete_playlist_songs(username, playlistName)
        Playlist.where(id: playlistId).destroy_all   
    end

    def self.delete_playlist_songs username, playlistName #deletes all songs from a playlist (but leaves playlist)
        playlistId = CurrentUser.get_playlist_id(username, playlistName)
        Playlistsong.where(playlist_id: playlistId).destroy_all
    end
    
    def self.delete_specific_song username, playlistName, songTitle
        songId = Song.where(title: songTitle).first.id
        playlistId = CurrentUser.get_playlist_id(username, playlistName)
        if songId != nil
            Playlistsong.where(playlist_id: playlistId).where(song_id: songId).destroy_all
        end
    end

    def self.delete_user username
        playlistArray = []
        CurrentUser.find_playlists(username).each_with_index do |value, index|
            playlistArray << CurrentUser.find_playlists('bob')[index].name
        end
        playlistArray.each do |playlist|
            CurrentUser.delete_playlist(username, playlist)
        end
        User.where(name: username).destroy_all
    end
    
end
