require 'rubygems'
require 'mechanize'
require 'json'
require 'axlsx'

Game = Struct.new(
  :title, 
  :developer, 
  :type,
  :release_date,
  :price,
  :price_for_plus,
  :ratings,
  :star_ratings,
  :has_demo,
  :genre,
  :file_size,
  :description,
  :season_pass,
  :number_of_addons,
  :price_of_season_pass
  )

PAGE_SIZE = 500
INDEX_TOKEN = '{{INDEX}}'
GAME_ID_TOKEN = '{{GAME_ID}}'
GAME_LIST_URL = "https://store.sonyentertainmentnetwork.com/chihiroview/viewfinder?https%3A%2F%2Fstore.sonyentertainmentnetwork.com%2Fstore%2Fapi%2Fchihiro%2F00_09_000%2Fcontainer%2FUS%2Fen%2F999%2FSTORE-MSF77008-ALLGAMES%3Fplatform%3Dps4%2Cps3%26size%3D#{PAGE_SIZE}%26start%3D#{INDEX_TOKEN}"
GAME_INFO_URL = "https://store.sonyentertainmentnetwork.com/chihiroview/viewfinder?https%3A%2F%2Fstore.sonyentertainmentnetwork.com%2Fstore%2Fapi%2Fchihiro%2F00_09_000%2Fcontainer%2FUS%2Fen%2F999%2F#{GAME_ID_TOKEN}%2F0%3Fsize%3D30"

def get_game_ids(params)
  page = params[:page]
  page ||= 1
  page_start = page == 0 ? 0 : PAGE_SIZE * page - 1
  page_start = page_start.to_s
  url = GAME_LIST_URL.sub(INDEX_TOKEN, page_start)
  puts "making request to #{url}"
  game_list_json = JSON.parse($a.get(url).body)
  game_list_json['links'].map { |link| link['id'] }
end

def get_game_info(game_id)
  game_url = GAME_INFO_URL.sub(GAME_ID_TOKEN, game_id)
  game_json = JSON.parse($a.get(game_url).body)
  game = Game.new
  game.title = game_json['name']
  game.developer = game_json['provider_name']
  game.type = game_json['gameContentTypesList'].first['name']
  game.release_date = game_json['release_date']
  skus = game_json['skus']
  game.price = skus.first['display_price'] if skus && skus.size > 0
  rewards = skus.first['rewards'] if skus && skus.size > 0
  if rewards && rewards.size > 0
    game.price_for_plus = rewards.first['display_price']
  end
  star_ratings = game_json['links'].last['star_ratings'] if game_json['links'].size > 0
  if star_ratings && star_ratings.size > 0
    game.ratings = star_ratings['total']
    game.star_ratings = star_ratings['count'].max_by { |o| o['count']}['star']
  end
  metadata = game_json['metadata']
  if metadata
    genre = metadata['genre']
    game.genre = genre['values'].first if genre
  end
  game.file_size = game_json['size']
  game.description = game_json['long_desc']

  game
end

def populate_xlsx_file(game_infos)
  package = Axlsx::Package.new
  workbook = package.workbook
  workbook.add_worksheet(name: 'Game List') do |sheet|
    sheet.add_row [
      'Title', 'Developer', 'Type', 'Release Date', 'Price', 'Price for Plus', 
      'Ratings', 'Star Rating', 'Has Demo', 'Genre', 'File Size', 'Description', 
      'Season Pass', 'Number of Addons', 'Price of Season Pass'
    ]
    for info in game_infos
      sheet.add_row [
        info.title, info.developer, info.type, info.release_date, info.price, info.price_for_plus,
        info.ratings, info.star_ratings, info.has_demo, info.genre, info.file_size, info.description,
        info.season_pass, info.number_of_addons, info.price_of_season_pass
      ]
    end
  end
  package.serialize 'game-list.xlsx'
end

$a = Mechanize.new
$a.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE
$a.keep_alive = false
$a.redirect_ok = false

game_ids = []
page = 0
puts 'getting game ids...'
loop do
  ids = get_game_ids(page: page)
  puts "gots ids with count: #{ids.size}"
  break if ids.size == 0 || !ids
  game_ids += ids
  page += 1
  break # TESTING PURPOSES
end
puts "got all game ids with count: #{game_ids.size}"

game_infos = []
game_ids.each_with_index do |id, index|
  puts "getting info on game ##{index} with id #{id}"
  info = get_game_info(id)
  puts info
  sleep 1
  break if index == 5 # TESTING PURPOSES
  game_infos << info
end

populate_xlsx_file(game_infos)