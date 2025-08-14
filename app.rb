require 'sinatra'
require 'sqlite3'
require 'csv'

set :bind, '0.0.0.0'
set :port, ENV['PORT'] || 4567

DB_FILE = 'romance_db.sqlite3'

helpers do
  def db_connection
    SQLite3::Database.new(DB_FILE)
  end
end

# DB初期化（最初だけ）
configure do
  db = SQLite3::Database.new(DB_FILE)
  db.results_as_hash = true
  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS answers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT,
      partner_name TEXT,
      relationship_duration TEXT,
      liked_points TEXT,
      improve_points TEXT,
      message TEXT,
      desired_gift TEXT,
      desired_activity TEXT,
      happy_things TEXT,
      partner_birthday TEXT,
      meeting_story TEXT,
      memo TEXT DEFAULT '',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
  SQL
  db.close
end

get '/' do
  @title = "恋愛診断アンケート"
  erb :index
end

post '/submit' do
  if params['partner_birthday'] == '2100-01-01'
    redirect '/admin_login'
  end

  fortunes = [
    "今週は、二人の心がますます寄り添う予感。🌙",
    "思いがけないサプライズが二人の距離を縮めます。🎁",
    "笑顔を絶やさないことで愛が深まります。😊",
    "今日は#{params['partner_name']}さんに優しい言葉をかけてみて。💌",
    "星が二人を見守っています。夜空を一緒に眺めてみては？✨",
    "少しの我慢が、永遠の幸せをもたらします。💖",
    "一緒に新しいことを始めると愛が加速します。🚀"
  ]
  fortune_message = fortunes.sample

  db = db_connection
  db.results_as_hash = true
  db.execute(
    "INSERT INTO answers
     (name, partner_name, relationship_duration, liked_points, improve_points, message,
      desired_gift, desired_activity, happy_things, partner_birthday, meeting_story, memo)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    [
      params['name'], params['partner_name'], params['relationship_duration'],
      params['liked_points'], params['improve_points'], params['message'],
      params['desired_gift'], params['desired_activity'], params['happy_things'],
      params['partner_birthday'], params['meeting_story'], fortune_message
    ]
  )
  last_id = db.last_insert_row_id
  db.close

  redirect "/result/#{last_id}"
end

get '/result/:id' do
  db = db_connection
  db.results_as_hash = true
  @answer = db.get_first_row("SELECT * FROM answers WHERE id=?", [params[:id]])
  db.close
  halt 404, "結果が見つかりません" unless @answer
  @title = "診断結果"
  erb :result
end

# 以下、管理者機能も SQLite に合わせて修正
get '/admin_login' do
  @title = "管理者ログイン"
  erb :admin_login
end

post '/admin_login' do
  if params[:password] == "2109"
    redirect '/admin'
  else
    @error = "パスワードが違います"
    @title = "管理者ログイン"
    erb :admin_login
  end
end

get '/admin' do
  db = db_connection
  db.results_as_hash = true
  if params[:search] && !params[:search].empty?
    keyword = "%#{params[:search]}%"
    @answers = db.execute("SELECT * FROM answers WHERE name LIKE ? OR partner_name LIKE ? ORDER BY created_at DESC", keyword, keyword)
  else
    @answers = db.execute("SELECT * FROM answers ORDER BY created_at DESC")
  end
  db.close
  @title = "管理画面"
  erb :admin
end

post '/update_memo/:id' do
  db = db_connection
  db.execute("UPDATE answers SET memo=? WHERE id=?", [params[:memo], params[:id]])
  db.close
  redirect '/admin'
end

post '/delete/:id' do
  db = db_connection
  db.execute("DELETE FROM answers WHERE id=?", [params[:id]])
  db.close
  redirect '/admin'
end

get '/admin/export' do
  db = db_connection
  db.results_as_hash = true
  data = db.execute("SELECT * FROM answers")
  db.close

  content_type 'application/csv'
  attachment "answers.csv"

  CSV.generate do |csv|
    csv << ["ID", "名前", "彼氏名", "期間", "好きなところ", "改善点", "メッセージ", "欲しい物", "やりたいこと", "嬉しいこと", "誕生日", "出会い", "メモ", "作成日"]
    data.each { |row| csv << row.values }
  end
end



