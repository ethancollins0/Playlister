require 'rest-client'
require 'json'

class Search
    @@is_album = false
    @@base_url = "https://api.spotify.com/v1"
    def self.search_menu
        pastel = Pastel.new
        system "clear"
        Screen.title
        prompt = TTY::Prompt.new
        choices = ["Track", "Artist", "Album", "Back"]
        search_select = prompt.select(pastel.bold("What would you like to search for?"), choices)
        case search_select
        when 'Track'
            @@is_album == false
            Search.search_track(search_select.downcase)
        when 'Artist'
            @@is_album == false
            Search.search_artist(search_select.downcase)
        when 'Album'
            @@is_album == true
            Search.search_album(search_select.downcase)
        when 'Back'
            user_menu($current_user)
        end
    end
    
    def self.tracks_select (track_parse, users_playlists, album_name = nil, album_year = nil, is_rec = false)
        pastel = Pastel.new
        system "clear"
        Screen.title
        prompt = TTY::Prompt.new
        display_tracks = []
            if album_name == nil
                track_parse.each do |item|
                    tracks_hash = {title: item['name'], artist: item['artists'][0]['name'], album: item['album']['name'].split(' - ').first, year: item['album']['release_date'].first(4), track_id: item['id'], track_url: item['external_urls']['spotify'], track_sample_url: item['preview_url'], duration: item['duration_ms']}
                    display_tracks << tracks_hash
                end
            else
                track_parse.each do |item|
                    tracks_hash = {title: item['name'], artist: item['artists'][0]['name'], album: album_name.split(' - ').first, year: album_year, track_id: item['id'], track_url: item['external_urls']['spotify'], track_sample_url: item['preview_url'], duration: item['duration_ms']}
                    display_tracks << tracks_hash
                end
            end
        loop do
            system("clear")
            Screen.title        
            choices = display_tracks.map.with_index(1) do |track| 
                "#{track[:title]} - #{track[:artist]} - #{track[:album]}"
            end
            selected_song = prompt.select(pastel.bold("Select a song to save"), 'Back', choices)
            if selected_song == 'Back'
                if is_rec == false
                Search.search_menu
                else
                get_recommendations($current_user)
                end
            else
                puts selected_song
                song_index = choices.index{|song| song == selected_song}
                yes_or_no = prompt.select(pastel.bold("Save this song to a playlist?"), %w[Yes No])
                if yes_or_no == 'Yes'
                selected_playlist = prompt.select(pastel.bold("Select a playlist to add this song to"), users_playlists)
                current_song = display_tracks[song_index]
                CurrentUser.save_song(current_song, $current_user.name, selected_playlist)
                puts pastel.bright_green.bold("Saved Song to #{selected_playlist}!")
                sleep(1)
                end
            end
        end
    end

    def self.search_track(search_type)
        pastel = Pastel.new
        @@is_album = false
        system "clear"
        Screen.title
        prompt = TTY::Prompt.new
        user = User.where(name: $current_user.name).first
        users_playlists = user.playlists.map{|playlist| playlist.name}
        puts pastel.bold("Enter a Song Name")
        user_input = gets.chomp.gsub(' ', '%20')
        while user_input == "" || user_input[/\A[a-zA-Z1-9%20'-]*\z/] == nil
            puts pastel.red.bold("Error: Please enter a valid search query.")
            sleep(2)
            system('clear')
            Screen.title
            puts pastel.bold("Enter a Song Name")
            user_input = gets.chomp.gsub(' ', '%20')
        end
        rest_client = RestClient.get(@@base_url + "/search?q=#{user_input}&type=#{search_type}&limit=10",
            'Authorization' => "Bearer #{GetData.access_token}")
        track_response = JSON.parse(rest_client)
        if track_response['tracks']['items'].count > 0
            track_parse = track_response['tracks']['items']
            Search.tracks_select(track_parse, users_playlists)
        else
            puts pastel.bold("No Results Found")
            sleep(2)
            Search.search_menu
        end
    end
    
    def self.search_artist(search_type)
        pastel = Pastel.new
        @@is_album = false
        system "clear"
        Screen.title
        prompt = TTY::Prompt.new
        user = User.where(name: $current_user.name).first
        users_playlists = user.playlists.map{|playlist| playlist.name}
        puts pastel.bold("Enter an Artist Name")
        user_input = gets.chomp.gsub(' ', '%20')
        while user_input == "" || user_input[/\A[a-zA-Z1-9%20'-]*\z/] == nil
            puts pastel.red.bold("Error: Please enter a valid search query.")
            sleep(2)
            system('clear')
            Screen.title
            puts pastel.bold("Enter an Artist Name")
            user_input = gets.chomp.gsub(' ', '%20')
        end
        rest_client = RestClient.get(@@base_url + "/search?q=#{user_input}&type=#{search_type}&limit=10",
            'Authorization' => "Bearer #{GetData.access_token}")
        artist_parse = JSON.parse(rest_client)
        # binding.pry
        if artist_parse['artists']['items'].count > 0
            artist_results = artist_parse['artists']['items']
            display_artists = artist_results.map{|artist| artist['name']}
            selected_artist = prompt.select(pastel.bold("Select an Artist"), display_artists)
            artist_index = display_artists.index{|artist| artist == selected_artist}
            artist_id = artist_results[artist_index]['id']
            top_tracks_or_albums = prompt.select(pastel.bold("View #{selected_artist}'s:'"), ["Top Tracks", "Albums"])
            if top_tracks_or_albums == 'Top Tracks'
                tt_rest_client = RestClient.get(@@base_url + "/artists/#{artist_id}/top-tracks?country=ES",
                            'Authorization' => "Bearer #{GetData.access_token}")
                top_tracks_response = JSON.parse(tt_rest_client)
                top_tracks_parse = top_tracks_response['tracks']
                Search.tracks_select(top_tracks_parse, users_playlists)
            else
                @@is_album = true
                arist_album_rest_client = RestClient.get(@@base_url + "/artists/#{artist_id}/albums/",
                    'Authorization' => "Bearer #{GetData.access_token}")
                artist_albums_parse = JSON.parse(arist_album_rest_client)
                display_artist_albums = artist_albums_parse['items'].map{|album| album['name']}
                selected_album = prompt.select(pastel.bold("Select an Album"), display_artist_albums)
                album_index = display_artist_albums.index{|album| album == selected_album}
                album_id = artist_albums_parse['items'][album_index]['id']
                base_url = "https://api.spotify.com/v1/"
                album_tracks_rest_client = RestClient.get(@@base_url + "/albums/#{album_id}/tracks",
                                        'Authorization' => "Bearer #{GetData.access_token}")
                album_tracks_response = JSON.parse(album_tracks_rest_client)
                album_tracks_parse = album_tracks_response['items']
                album_year = artist_albums_parse['items'][album_index]['release_date'].first(4)
                Search.tracks_select(album_tracks_parse, users_playlists, selected_album, album_year)
            end
        else
            puts pastel.bold("No Results Found")
            sleep(1)
            Search.search_menu
        end
    end
    
    def self.search_album(search_type)
        pastel = Pastel.new
        system "clear"
        Screen.title
        prompt = TTY::Prompt.new
        @@is_album = true
        user = User.where(name: $current_user.name).first
        users_playlists = user.playlists.map{|playlist| playlist.name}
        puts pastel.bold("Enter an Album Name")
        user_input = gets.chomp.gsub(' ', '%20')
        while user_input == "" || user_input[/\A[a-zA-Z1-9%20'-]*\z/] == nil
            puts pastel.red.bold("Error: Please enter a valid search query.")
            sleep(2)
            system('clear')
            Screen.title
            puts pastel.bold("Enter a Song Name")
            user_input = gets.chomp.gsub(' ', '%20')
        end
        album_rest_client = RestClient.get(@@base_url + "/search?q=#{user_input}&type=#{search_type}&limit=10",
            'Authorization' => "Bearer #{GetData.access_token}")
        album_parse = JSON.parse(album_rest_client)
        if album_parse['albums']['items'].count > 0
            display_albums = album_parse['albums']['items'].map{|album| album['name']}
            album_results = album_parse['albums']['items']
            display_albums = album_results.map{|album| "#{album['name']} - #{album['artists'][0]['name']}"}
            selected_album = prompt.select(pastel.bold("Select an Album"), display_albums)
            album_index = display_albums.index{|album| album == selected_album}
            album_id = album_results[album_index]['id']
            base_url = "https://api.spotify.com/v1/"
            checker = RestClient.get("https://api.spotify.com/v1/albums/#{album_id}/tracks",
                        'Authorization' => "Bearer #{GetData.access_token}")
            album_tracks_response = JSON.parse(checker)
            album_tracks_parse = album_tracks_response['items']
            album_year = album_parse['albums']['items'][album_index]['release_date'].first(4)
            Search.tracks_select(album_tracks_parse, users_playlists, selected_album, album_year)
        else
            puts pastel.bold("No Results Found")
            sleep(1)
            Search.search_menu
        end
    end

end
