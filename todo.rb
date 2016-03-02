require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"

require 'pry'

configure do
  enable :sessions
  set :session_secret, 'secret' # give 'secret' so that Sinatra's behavior isn't setting this everytime server is restarted
end

before do
  session[:lists] ||= []
  @lists = session[:lists]
end

get "/lists" do
  erb :lists, layout: :layout
end

get '/lists/new' do
  erb :new_list, layout: :layout  
end

post '/lists' do
  session[:lists] << {name: params[:list_name], todos: []}
  redirect '/lists'
end

not_found do
  redirect '/lists'
end
