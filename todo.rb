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

# GET /lists        -> view all lists
# GET /lists/new    -> new list form
# POST /lists       -> create new list
# GET /lists/1      -> view a single list
# GET /lists/1/new  -> new todo form
# POST /lists/1     -> create a new todo

get "/lists" do
  erb :lists, layout: :layout
end

# Render for for new list
get '/lists/new' do
  erb :new_list, layout: :layout  
end

# Returns an error message if the name is invalid.
def list_validation_error(name)
  if !(1..100).cover? name.size
    'List name must be between 1 and 100.'
  elsif session[:lists].any? { |list| list[:name] == name}
    "'#{name}' already exists."
  end
end

# Posting a new list; redirect to '/lists'
post '/lists' do
  list_name = params[:list_name].strip
  
  if error = list_validation_error(list_name)
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << {name: list_name, todos: []}
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# not_found do
#   redirect '/lists'
# end

get '/' do
  redirect '/lists'
end