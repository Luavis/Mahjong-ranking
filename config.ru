set :static, true
set :server, 'thin'
set :public_folder, File.dirname(__FILE__) + '/static'

set :production
