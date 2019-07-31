require_relative '../config/environment'
require 'pry'
require 'tty-prompt'

current_user = nil
def create_user
    puts "Enter your User Name."
    input = gets.chomp
    $current_user = CurrentUser.make_user(input)
    user_menu($current_user)
end

def log_in
    prompt = TTY::Prompt.new
        puts "Select a user to log into"
        choices = User.all.map{|user| user.name}
        select_user = prompt.select("Select a user to log in", choices)
        $current_user = User.find_by(name: select_user)
        user_menu($current_user)
    end
    
    def welcome
        prompt = TTY::Prompt.new
        menu_select = prompt.select("Welcome to Playlister!", %w(Log-in Create-User))
        if menu_select == 'Log-in'
            log_in
        elsif menu_select == 'Create-User'
            $current_user = create_user
        end
    end

    def view_playlists (current_user)
        prompt = TTY::Prompt.new
        user = User.where(name: current_user.name).first
        current_playlists = user.playlists
        selected = prompt.select("Select a playlist", current_playlists.map{|playlist| playlist.name}, 'Back')
        if selected == 'Back'
            user_menu(current_user)
        else
            playlist_songs = Playlist.where(name: selected).where(user_id: current_user.id).first.songs
            choices = playlist_songs.map{|song| "#{song.title} - #{song.artist} - #{song.album}"}
            selected_song = prompt.select("Choose a Song", choices, 'Back')
            if selected_song == 'Back'
                view_playlists(current_user)
            else
                puts selected_song
                yes_or_no = prompt.yes?("Delete Song?")
                song_name = selected_song.split("-").first.strip
                binding.pry
            end
            if yes_or_no == true
                CurrentUser.delete_specific_song(current_user.name, selected, song_name)
            else
                view_playlists(current_user)
            end
        end
    end

    def user_menu (current_user)
        prompt = TTY::Prompt.new
        puts "Welcome, #{current_user.name}"
        choices = ["View Playlists", "Create Playlist", "Delete Playlist", "Search For Songs", "Log-out"]
        user_menu_select = prompt.select("What would you like to do?", choices)
      
        loop do
            case user_menu_select
                when 'View Playlists'
                    view_playlists ($current_user)
                when 'Create Playlist'
                    puts "What would you like to call this playlist?"
                    playlist_name = gets.chomp
                    CurrentUser.create_playlist(current_user.name, playlist_name)
                    user_menu(current_user)

                when 'Delete Playlist'
                    user = User.where(name: current_user.name).first
                    choices = user.playlists.map{|playlist| playlist.name}
                    playlist_select = prompt.select("Which Playlist would you like to delete?", choices, 'Back')
                    if playlist_select == 'Back'
                        user_menu(current_user)
                    else
                        CurrentUser.delete_playlist(current_user.name, playlist_select)
                        user_menu(current_user)
                    end           
                when 'Search For Songs'
                    Search.search_menu
                when 'Log-out'
                    welcome
            end
        end
    end

    welcome

    binding.pry