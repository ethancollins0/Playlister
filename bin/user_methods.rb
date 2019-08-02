require_relative '../config/environment'
require 'pry'
require 'tty-prompt'

current_user = nil
def create_user
    system("clear")
    Screen.title
    puts "Enter your User Name."
    input = gets.chomp
    $current_user = CurrentUser.make_user(input)
    if $current_user == nil
        puts 'Invalid input, please enter a name with at least one letter or number.'
        sleep(2)
        create_user
    end
    user_menu($current_user)
end

def log_in
    system "clear"
    Screen.title
    if User.all.count == 0 
        puts "No users found, please create new user."
        sleep(2)
        create_user
    end
    prompt = TTY::Prompt.new
    choices = User.all.map{|user| user.name}
    select_user = prompt.select("Select a user to log into", choices)
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
    prompt = TTY::Prompt.new

        choices = playlist_songs.map{|song| "#{song.title} - #{song.artist} - #{song.album}"}

    selected_song = prompt.select("Choose a Song", choices, 'Back')
    if selected_song == 'Back'
        view_playlists(current_user)
    else
        puts selected_song
        song_name = selected_song.split("-").first.strip
        song_url = Song.where(title: song_name).first.track_url
        song_sample_url = Song.where(title: song_name).first.track_sample_url
        select = prompt.select("What do you want to do?", 'Play Song', 'Sample Song', 'Delete Song', 'Back')
        loop do
            case select
                when 'Play Song'
                    system("open", song_url)
                    system("clear")
                    Screen.title
                    select = prompt.select("What do you want to do?", 'Play Song', 'Sample Song', 'Delete Song', 'Back')
                when 'Sample Song'
                    if song_sample_url == nil
                        puts "No Sample Available"
                        sleep(1)
                        system("clear")
                        Screen.title
                        select = prompt.select("What do you want to do?", 'Play Song', 'Sample Song', 'Delete Song', 'Back')     
                    else
                        system("open", song_sample_url)
                        system("clear")
                        Screen.title
                        select = prompt.select("What do you want to do?", 'Play Song', 'Sample Song', 'Delete Song', 'Back')
                    end
                when 'Delete Song'
                    yes_or_no = prompt.yes?("Delete Song?")
                    if yes_or_no == true
                        CurrentUser.delete_specific_song(current_user.name, selected_playlist, song_name)
                        puts "Song deleted."
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
    system "clear"
    Screen.title
    prompt = TTY::Prompt.new
    playlist_select = prompt.select("Would you like to see your playlists or other user's playlists?", 'My Playlists', 'All Playlists', 'Back')
    user = User.where(name: current_user.name).first
    case playlist_select
        when 'My Playlists'
            current_playlists = user.playlists
            selected = prompt.select("Select a playlist", current_playlists.map{|playlist| playlist.name}, 'Back')
            if selected == 'Back'
                user_menu(current_user)
            else
                selected_playlist = selected
                system "clear"
                Screen.title
                puts "Viewing Playlist #{selected}"
                playlist_songs = Playlist.where(name: selected).where(user_id: current_user.id).first.songs
                select_playlist_songs(current_playlists, playlist_songs, current_user, selected_playlist)
            end
        when 'All Playlists'
            current_playlists = Playlist.where(public: true)
            selected = prompt.select("Select a playlist", current_playlists.map{|playlist| playlist.name}, 'Back')
                if selected == 'Back'
                    user_menu(current_user)
                else
                    system "clear"
                    Screen.title
                    puts "Viewing Playlist #{selected}"
                    filtered_songs = [] 
                    playlist_songs = Playlist.all.select{|playlist| filtered_songs << playlist.songs unless playlist.songs == [] || playlist.public == false}
                    selected_playlist = selected
                    #binding.pry
                    select_playlist_songs(current_playlists, filtered_songs.flatten, current_user, selected_playlist)
                end
        when 'Back'
            user_menu(current_user)
    end
end

def get_recommendations (current_user)
    prompt = TTY::Prompt.new
    user = User.where(name: current_user.name).first
    users_playlists = user.playlists.map{|playlist| playlist.name}
    current_playlists = user.playlists
    selected = prompt.select("Select a playlist", current_playlists.map{|playlist| playlist.name}, 'Back')
    if selected == 'Back'
        user_menu(current_user)
    else
        system "clear"
        Screen.title

        if Playlist.where(name: selected).first.songs.count == 0
            puts "No songs found in playlist, please add songs then try again."
            sleep(2)
            user_menu(current_user)
        end

        puts "Viewing Playlist #{selected}"
        playlist_songs = Playlist.where(name: selected).where(user_id: current_user.id).first.songs
        choices = playlist_songs.map{|song| "#{song.title} - #{song.artist} - #{song.album}"}.uniq
        selected_songs = prompt.multi_select("Choose up to five songs to get recommendations", choices)
        
        while selected_songs.count == 0 || selected_songs.count > 5
            puts "Please select up to five songs with the 'spacebar'"
            sleep(1.5)
            system("clear")
            Screen.title
            selected_songs = prompt.multi_select("Choose up to five songs to get recommendations", choices)
        end

            song_names = selected_songs.map{|song| song.split(" - ").first.strip}
            song_ids = CurrentUser.get_song_ids(song_names).join("%2C")
            rest_client = RestClient.get("https://api.spotify.com/v1/recommendations?seed_tracks=#{song_ids}", 'Authorization' => "Bearer #{GetData.access_token}")
            rec_tracks_response = JSON.parse(rest_client)
            if rec_tracks_response['tracks'].count == 0
                puts "No recommendations found, please try again with different songs."
                sleep(2)
                user_menu(current_user)
            end
            rec_tracks_parse = rec_tracks_response['tracks']
            #binding.pry
            Search.tracks_select(rec_tracks_parse, users_playlists)
            user_menu($current_user)
    end
end

def user_menu(current_user)
    system "clear"
    Screen.title
    prompt = TTY::Prompt.new
    puts "Welcome, #{current_user.name}"
    choices = ["View Playlists", "Create Playlist", "Delete Playlist", "Search For Songs", "Get Recommendations", "Delete User", "Log-out"]
    user_menu_select = prompt.select("What would you like to do?", choices)
    case user_menu_select
        when 'View Playlists'
            view_playlists ($current_user)
        when 'Create Playlist'
            prompt = TTY::Prompt.new
            choice = prompt.select("Would you like to create a public or private playlist?", "Public Playlist", "Private Playlist")
            if choice == "Public Playlist"
                puts "What would you like to call this playlist?"
                playlist_name = gets.strip
                while playlist_name[/[a-zA-Z0-9 ']+/]  != playlist_name || playlist_name == ""
                    puts "Please enter a valid playlist name."
                    sleep(2)
                    system('clear')
                    Screen.title
                    puts "What would you like to call this playlist?"
                    playlist_name = gets.chomp
                end
                CurrentUser.create_playlist(current_user.name, playlist_name, true)
            else
                puts "What would you like to call this playlist?"
                playlist_name = gets.strip
                while playlist_name[/[a-zA-Z0-9 ']+/]  != playlist_name || playlist_name == ""
                    puts "Please enter a valid playlist name."
                    sleep(2)
                    system('clear')
                    Screen.title
                    puts "What would you like to call this playlist?"
                    playlist_name = gets.chomp
                end
                CurrentUser.create_playlist(current_user.name, playlist_name, false)
            end
            user_menu(current_user)
        when 'Delete Playlist'
            user = User.where(name: current_user.name).first
            choices = user.playlists.map{|playlist| playlist.name}
            playlist_select = prompt.select("Which Playlist would you like to delete?", choices, 'Back')
            if playlist_select == 'Back'
                user_menu(current_user)
            else
                yes_or_no = prompt.yes?("Delete Playlist #{playlist_select}.      Are you sure?")
                if yes_or_no == true
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
            yes_or_no = prompt.yes?("Delete user #{$current_user.name}.    Are you sure?")
            if yes_or_no == true
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
