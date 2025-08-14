# app.rb (PostgreSQL用)
require 'sinatra'
require 'pg'
require 'erb'

# データベース接続用メソッド
def db_connection
  conn = PG.connect(ENV['DATABASE_URL'])
end

# 初期化：テーブルがなければ作る
configure do
  conn = db_connection
  conn.exec <<-SQL
    CREATE TABLE IF NOT EXISTS answers (
      id SERIAL PRIMARY KEY,
      name TEXT,
      partner_name TEXT,
      relationship_duration TEXT,
      liked_points TEXT,
      improve_points TEXT,
      message TEXT,
      desired_gift TEXT,
      desired_activity TEXT,
      happy_things TEXT,
      partner_birthday DATE,
      meeting_story TEXT,
      memo TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  SQL
  conn.close
end

# トップページ（アンケートフォーム）
get '/' do
  erb :index
end

# フォーム送信
post '/submit' do
  fortune_message = "こうしたらもっと仲良くなれるかも！"

  conn = db_connection
  conn.exec_params(
    "INSERT INTO answers
     (name, partner_name, relationship_duration, liked_points, improve_points, message, desired_gift, desired_activity, happy_things, partner_birthday, meeting_story, memo)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
     RETURNING id",
    [
      params['name'], params['partner_name'], params['relationship_duration'],
      params['liked_points'], params['improve_points'], params['message'],
      params['desired_gift'], params['desired_activity'], params['happy_things'],
      params['partner_birthday'], params['meeting_story'], fortune_message
    ]
  ) do |result|
    @last_id = result[0]['id']
  end
  conn.close

  redirect "/result/#{@last_id}"
end

# 結果表示ページ
get '/result/:id' do
  conn = db_connection
  @answer = conn.exec_params("SELECT * FROM answers WHERE id=$1", [params[:id]])[0]
  conn.close
  erb :result
end

# 管理者ページ
get '/admin' do
  password = params['password'] || ''
  if password != ENV['ADMIN_PASSWORD']
    return "パスワードが違います"
  end
  conn = db_connection
  @answers = conn.exec("SELECT * FROM answers ORDER BY created_at DESC").to_a
  conn.close
  erb :admin
end

# 削除機能（管理者専用）
post '/delete/:id' do
  password = params['password'] || ''
  if password != ENV['ADMIN_PASSWORD']
    return "パスワードが違います"
  end
  conn = db_connection
  conn.exec_params("DELETE FROM answers WHERE id=$1", [params[:id]])
  conn.close
  redirect "/admin?password=#{password}"
end

# Render対応のポート設定
set :port, ENV.fetch('PORT', 4567)
set :bind, '0.0.0.0'

