require 'rest-client'
require 'json'
require 'pry'

class CurrentUser
    def self.make_user name
        if name[/[a-zA-Z0-9]+/]  == name
            user = User.create(name: name)
            CurrentUser.create_playlist(name, 'Default Playlist', false)  
            user  
        else
            return nil
        end
    end

    def self.get_playlist_id(username, playlistName)
        userId = User.where(name: username).first.id
        Playlist.where(user_id: userId).where(name: playlistName).first.id
    end

    def self.create_playlist username, playlistName, isPublic
        inputId = User.where(name: username).first.id
        if Playlist.where(user_id: inputId).where(name: playlistName).count == 0
            Playlist.create(user_id: inputId, name: playlistName, public: isPublic)
        else
            "A playlist of that name already exists, please choose a different name or delete this playlist first."
        end
    end

    def self.save_song h, username, playlistName # takes in hash, username, playlistName
        if Song.where(title: h[:title]).where(artist: h[:artist]).count == 0
            song = Song.create(title: h[:title], artist: h[:artist], album: h[:album], genre: h[:genre], year: h[:year], track_id: h[:track_id], track_url: h[:track_url], track_sample_url: h[:track_sample_url]) #adds songs, attr values nil by default
        else
            song = Song.where(title: h[:title]).where(artist: h[:artist]).first
        end
        playlistId = CurrentUser.get_playlist_id(username, playlistName)
        Playlistsong.create(song_id: song.id, playlist_id: playlistId)
    end

    def self.delete_playlist username, playlistName, userDelete=false #deletes playlist and songs
        user = User.where(name: username).first
        if user.playlists.count > 1 || userDelete == true
            playlistId = CurrentUser.get_playlist_id(username, playlistName)
            CurrentUser.delete_playlist_songs(username, playlistName)
            Playlist.where(id: playlistId).destroy_all
            userDelete = false
        else
            puts "You shouldn't delete your only playlist! Where would you save songs?"
            sleep(3)
        end
    end

    def self.delete_playlist_songs username, playlistName #deletes all songs from a playlist (but leaves playlist)
        playlistId = CurrentUser.get_playlist_id(username, playlistName)
        Playlistsong.where(playlist_id: playlistId).destroy_all
    end

    def self.delete_specific_song username, playlistName, songTitle
        songId = Song.where(title: songTitle).first.id
        playlistId = CurrentUser.get_playlist_id(username, playlistName)
        if songId != nil
            delete_id = Playlistsong.where(playlist_id: playlistId).where(song_id: songId).first.id
            Playlistsong.destroy(delete_id)
        end
    end

    def self.get_song_ids songArray
        songArray.map {|song| Song.where(title: song).first.track_id}
    end

    def self.delete_user username
        user = User.where(name: username).first
        playlistArray = user.playlists
        playlistArray.each do |playlist|
            CurrentUser.delete_playlist(username, playlist.name, true)
        end
        User.where(name: username).destroy_all
    end

end
