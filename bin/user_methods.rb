require_relative '../config/environment'
require 'pry'
require 'tty-prompt'
current_user = nil
def create_user
    pastel = Pastel.new
    system("clear")
    Screen.title
    puts pastel.bold("Enter your User Name.")
    input = gets.chomp
    $current_user = CurrentUser.make_user(input)
    if $current_user == nil
        puts pastel.red.bold('Invalid input, please enter a name with at least one letter or number.')
        sleep(2)
        create_user
    end
    user_menu($current_user)
end

def log_in
    pastel = Pastel.new
    system "clear"
    Screen.title
    if User.all.count == 0 
        puts pastel.bold("No users found, please create new user.")
        sleep(1)
        create_user
    end
    prompt = TTY::Prompt.new
    choices = User.all.map{|user| user.name}
    select_user = prompt.select(pastel.bold("Select a user to log into"), choices)
    $current_user = User.find_by(name: select_user)
    user_menu($current_user)
end
    
def welcome
    pid = fork{exec 'afplay', "./Intro.mp3"}
    system "clear"
    Screen.main_title
    prompt = TTY::Prompt.new
    menu_select = prompt.select("", ["Log-in", "Create-User", "Exit"])
    if menu_select == 'Log-in'
        log_in
    elsif menu_select == 'Create-User'
        $current_user = create_user
    else
        exit!
    end
end

def select_playlist_songs(current_playlists, playlist_songs, current_user = nil, selected_playlist = nil)
    pastel = Pastel.new
    prompt = TTY::Prompt.new
    choices = playlist_songs.map{|song| "#{song.title} - #{song.artist} - #{song.album}"}

    selected_song = prompt.select(pastel.bold("Choose a Song"), choices, 'Back')
    if selected_song == 'Back'
        view_playlists(current_user)
    else
        puts selected_song
        song_name = selected_song.split("-").first.strip
        song_url = Song.where(title: song_name).first.track_url
        song_sample_url = Song.where(title: song_name).first.track_sample_url
        select = prompt.select(pastel.bold("What do you want to do?"), 'Back', 'Play Song', 'Sample Song', 'Delete Song')
        loop do
            case select
                when 'Play Song'
                    system("open", song_url)
                    system("clear")
                    Screen.title
                    select = prompt.select(pastel.bold("What do you want to do?"), 'Back', 'Play Song', 'Sample Song', 'Delete Song')
                when 'Sample Song'
                    if song_sample_url == nil
                        puts "No Sample Available"
                        sleep(1)
                        system("clear")
                        Screen.title
                        select = prompt.select(pastel.bold("What do you want to do?"), 'Play Song', 'Sample Song', 'Delete Song', 'Back')     
                    else
                        system("open", song_sample_url)
                        system("clear")
                        Screen.title
                        select = prompt.select(pastel.bold("What do you want to do?"), 'Play Song', 'Sample Song', 'Delete Song', 'Back')
                    end
                when 'Delete Song'
                    yes_or_no = prompt.select(pastel.red.bold("Delete Song?"), 'Yes', 'No')
                    if yes_or_no == 'Yes'
                        CurrentUser.delete_specific_song(current_user.name, selected_playlist, song_name)
                        system("clear")
                        Screen.title
                        view_playlists(current_user)
                    else
                        view_playlists(current_user)
                    end
                when 'Back'
                    view_playlists(current_user)
            end
        end    
    end
end
    

def view_playlists (current_user)
    pastel = Pastel.new
    system "clear"
    Screen.title
    prompt = TTY::Prompt.new
    playlist_select = prompt.select(pastel.bold("Would you like to see your playlists or other user's playlists?"), 'My Playlists', 'All Playlists', 'Back')
    user = User.where(name: current_user.name).first
    case playlist_select
        when 'My Playlists'
            current_playlists = user.playlists
            selected = prompt.select(pastel.bold("Select a playlist"), current_playlists.map{|playlist| playlist.name}, 'Back')
            if selected == 'Back'
                user_menu(current_user)
            else
                selected_playlist = selected
                system "clear"
                Screen.title
                puts pastel.bold("Viewing Playlist #{selected}")
                playlist_songs = Playlist.where(name: selected).where(user_id: current_user.id).first.songs
                select_playlist_songs(current_playlists, playlist_songs, current_user, selected_playlist)
            end
        when 'All Playlists'
            current_playlists = Playlist.where(public: true)
            selected = prompt.select(pastel.bold("Select a playlist"), current_playlists.map{|playlist| playlist.name}, 'Back')
                if selected == 'Back'
                    user_menu(current_user)
                else
                    system "clear"
                    Screen.title
                    puts pastel.bold("Viewing Playlist #{selected}")
                    filtered_songs = [] 
                    playlist_songs = Playlist.where(name: selected).select{|playlist| filtered_songs << playlist.songs unless playlist.songs == [] || playlist.public == false}
                    if playlist_songs.count == 0
                        puts pastel.bold("There are currently no songs in this playlist.")
                        sleep(2)
                        view_playlists(current_user)
                    end
                        selected_playlist = selected
                        select_playlist_songs(current_playlists, filtered_songs[0], current_user, selected_playlist)
                end
        when 'Back'
            user_menu(current_user)
    end
end
def get_recommendations (current_user)
    pastel = Pastel.new
    prompt = TTY::Prompt.new
    user = User.where(name: current_user.name).first
    users_playlists = user.playlists.map{|playlist| playlist.name}
    current_playlists = user.playlists
    selected = prompt.select(pastel.bold("Select a playlist"), current_playlists.map{|playlist| playlist.name}, 'Back')
    if selected == 'Back'
        user_menu(current_user)
    else
        system "clear"
        Screen.title

        if Playlist.where(name: selected).first.songs.count == 0
            puts pastel.bold("No songs found in playlist, please add songs then try again.")
            sleep(2)
            user_menu(current_user)
        end

        puts pastel.bold("Viewing Playlist #{selected}")
        playlist_songs = Playlist.where(name: selected).where(user_id: current_user.id).first.songs
        choices = playlist_songs.map{|song| "#{song.title} - #{song.artist} - #{song.album}"}
        selected_songs = prompt.multi_select(pastel.bold("Choose up to five songs for recommendations"), choices)
        while selected_songs.count == 0 || selected_songs.count > 5
            puts pastel.red.bold("Please select only up to five songs with the 'spacebar'")
            sleep(1.5)
            system("clear")
            Screen.title
            selected_songs = prompt.multi_select(pastel.bold("Choose up to five songs for recommendations"), choices)
        end
            song_array = playlist_songs.map{|song| song.title}
            song_names = selected_songs.map{|song| song.split(" - ").first.strip}
            songs = []
            song_array.select do |song|
                song_names.each do |name|
                    if song.include?(name)
                     songs << song
                    end
                end
            end
            song_ids = CurrentUser.get_song_ids(songs.uniq).join("%2C")
            rest_client = RestClient.get("https://api.spotify.com/v1/recommendations?seed_tracks=#{song_ids}", 'Authorization' => "Bearer #{GetData.access_token}")
            rec_tracks_response = JSON.parse(rest_client)
            rec_tracks_parse = rec_tracks_response['tracks']
            Search.tracks_select(rec_tracks_parse, users_playlists, nil, nil, true)
            user_menu($current_user)
    end
end

def user_menu(current_user)
    pastel = Pastel.new
    system "clear"
    Screen.title
    prompt = TTY::Prompt.new
    puts pastel.cyan.bold("Welcome, #{current_user.name}!")
    puts ""
    choices = ["View Playlists", "Create Playlist", "Delete Playlist", "Search For Songs", "Get Recommendations", "Delete User", "Log-out"]
    user_menu_select = prompt.select(pastel.bold("What would you like to do?"), choices)
    case user_menu_select
        when 'View Playlists'
            view_playlists ($current_user)
        when 'Create Playlist'
            prompt = TTY::Prompt.new
            choice = prompt.select(pastel.bold("Would you like to create a public or private playlist?"), "Public Playlist", "Private Playlist")
            if choice == "Public Playlist"
                puts pastel.bold("What would you like to call this playlist?")
                playlist_name = gets.chomp
                CurrentUser.create_playlist(current_user.name, playlist_name, true)
            else
                puts pastel.bold("What would you like to call this playlist?")
                playlist_name = gets.chomp
                CurrentUser.create_playlist(current_user.name, playlist_name, false)
            end
            user_menu(current_user)
        when 'Delete Playlist'
            user = User.where(name: current_user.name).first
            choices = user.playlists.map{|playlist| playlist.name}
            playlist_select = prompt.select(pastel.bold("Which Playlist would you like to delete?"), choices, 'Back')
            if playlist_select == 'Back'
                user_menu(current_user)
            else
                yes_or_no = prompt.select(pastel.red.bold("***Delete Playlist #{playlist_select}. Are you sure?***"), 'Yes', 'No')
                if yes_or_no == 'Yes'
                    CurrentUser.delete_playlist(current_user.name, playlist_select)
                    user_menu(current_user)
                else
                    user_menu(current_user)
                end
            end           
        when 'Search For Songs'
            Search.search_menu
        when 'Get Recommendations'
            get_recommendations($current_user)
        when 'Delete User'
            prompt = TTY::Prompt.new
            yes_or_no = prompt.select(pastel.red.bold("***Delete user #{$current_user.name}. Are you sure?***"), 'Yes', 'No')
            if yes_or_no == 'Yes'
                CurrentUser.delete_user($current_user.name)
                welcome
            else
                user_menu($current_user)
            end
        when 'Log-out'
            welcome
        end
end
    
    welcome
