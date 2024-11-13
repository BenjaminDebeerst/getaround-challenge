require 'date'
require 'json'

require_relative './calculator'
require_relative './data'
require_relative './model'
require_relative './presentation'

if $0 == __FILE__
  input = JSON.parse(File.read('data/input.json'))

  database = Database.new(*InputData.from_json(input))

  output = {
    'rentals' => (database.rentals
      .map { |r| Calculator::price(r) }
      .map { |p| Presentation::rental_transactions(p) }),
  }

  File.write('data/output.json', JSON.pretty_generate(output))
end
