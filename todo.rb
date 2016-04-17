require 'sinatra'
require 'sinatra/content_for'
require 'sinatra/reloader' if development?
require 'tilt/erubis'
require 'pry'

configure do
  enable :sessions
  # give 'secret'
  # Otherwise Sinatra resets this value every time
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

helpers do
  def todos_remaining_count(list)
    list[:todos].reject { |todo| todo[:completed] }.size
  end

  def total_todos_count(list)
    list[:todos].size
  end

  def all_todos_completed?(list)
    todos_remaining_count(list) == 0 && total_todos_count(list) > 0
  end

  def list_class(list)
    "complete" if all_todos_completed?(list)
  end

  def todo_class(todo)
    "complete" if todo[:completed]
  end

  def list_path(list_id)
    "/list/#{list_id}"
  end

  def sort_lists(lists, &some_block)
    block_for_view = Proc.new { |item| yield item, lists.index(item) }
    complete_lists, incomplete_lists = lists.partition { |list| all_todos_completed? list }

    incomplete_lists.each &block_for_view
    complete_lists.each &block_for_view
  end

  def sort_todos(todos, &some_block)
    block_for_view = Proc.new { |item| yield item, todos.index(item) }
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }

    incomplete_todos.each &block_for_view
    complete_todos.each &block_for_view
  end
end

before do
  session[:lists] ||= []
  @lists = session[:lists]
end

# Loads a list and redirects if not found
def load_list(index)
  list = session[:lists][index] if index
  return list if list

  session[:error] = "The specified list was not found."
  redirect "/lists"
  halt
end

# common list setup
def list_setup
  @list_id = params[:list_id].to_i
  @list = load_list @list_id
end

# Returns an error message if the name is invalid.
def list_validation_error(name)
  if !(1..100).cover? name.size
    'List name must be between 1 and 100.'
  elsif session[:lists].any? { |list| list[:name] == name }
    "'#{name}' already exists."
  end
end

# Validate new todo to a list; returns a message if validation error
def todo_validation_error(input_todo, list)
  if !(1..50).cover? input_todo.size
    'Todo must be between 1 and 50 characters'
  elsif list[:todos].any? { |todo| todo[:name] == input_todo }
    "'#{input_todo}' already exists."
  end
end

# Validate List name while editing
def edit_list_name_validation(list_number, new_name)
  other_lists = session[:lists].map.to_a
  other_lists.delete_at list_number

  if !(1..100).cover? new_name.size
    "List name must be between 1 and 100."
  elsif other_lists.any? { |list| list[:name] == new_name }
    "'#{new_name}' already exists."
  end 
end

# GET /lists        -> view all lists
# GET /lists/new    -> new list form
# POST /lists       -> create new list
# GET /lists/1      -> view a single list
# GET /lists/1/new  -> new todo form
# POST /lists/1     -> create a new todo

# Main page showing all lists
get '/lists' do
  erb :lists, layout: :layout
end

# Render for for new list
get '/lists/new' do
  erb :new_list, layout: :layout
end

# Posting a new list; redirect to '/lists'
post '/lists' do
  list_name = params[:list_name].strip

  error = list_validation_error(list_name)

  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# Show single todo list
get '/list/:list_id' do
  list_setup
  completed_todos = Proc.new { |todo| todo[:completed] }

  @completed_todos = @list[:todos].select &completed_todos
  @incomplete_todos = @list[:todos].reject &completed_todos
  erb :list, layout: :layout
end

def next_todo_id(todos)
  # get list of todos
  # find greatest id in todos
  max = todos.map { |todo| todo[:id] }.max || 0
  # increment
  max + 1
end

# Posting a new todo to list; redirect to '/list/:number'
post '/list/:list_id/todos' do
  todo = params[:todo].strip
  list_setup
  error = todo_validation_error(todo, @list)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    id = next_todo_id(@list[:todos])
    @list[:todos] << {id: id, name: todo, completed: false}
    session[:success] = 'Todo added successfully.'
    redirect "/list/#{@list_id}"
  end
end

# Edit list name
get '/list/:list_id/edit' do
  list_setup
  erb :edit_list, layout: :layout
end

# Update edit to list_name
post '/list/:list_id' do
  list_setup
  list_name = params[:list_name].strip

  error = edit_list_name_validation(@list_id, list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout

  else
    if @list[:name].eql? list_name
      session[:success] = 'List name did not change in the update.'
    else
      @list[:name] = list_name
      session[:success] = 'List updated successfully.'
    end

    redirect "/list/#{@list_id}"
  end
end

# Delete a todo list
post '/list/:list_id/delete' do
  session[:lists].delete_at params[:list_id].to_i

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list has been deleted."
    redirect '/lists'
  end
end

# Delete a todo from a list
post '/list/:list_id/todo/:todo_id/delete' do
  list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i
  # session[:lists][list_id][:todos].delete_at todo_id
  session[:lists][list_id][:todos].reject! { |todo| todo[:id] == todo_id }
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    # ajax
    status 204 # successful but no content
  else
    session[:success] = "The todo item has been deleted."
    redirect "/list/#{list_id}"
  end
end

# Toggle completed status of a todo
post '/list/:list_id/todo/:todo_id' do
  list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i
  todo = session[:lists][list_id][:todos].find { |todo| todo[:id] == todo_id }
  is_completed = params[:completed] == "true"
  todo[:completed] =  is_completed
  session[:success] = "#{todo[:name]} has been #{is_completed ? "checked" : "unchecked"}."
  redirect "/list/#{list_id}"
end

# POST to complete all todos in a list
post '/list/:list_id/complete_all' do
  list_id = params[:list_id].to_i
  session[:lists][list_id][:todos].each do |todo|
    todo[:completed] = true
  end
  session[:success] = "All todos were marked completed."
  redirect "/list/#{list_id}"
end

not_found do
  redirect '/lists'
end

get '/' do
  redirect '/lists'
end
