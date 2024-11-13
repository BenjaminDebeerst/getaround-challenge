require 'date'
require 'json'

module InputData
  def self.from_json(json)
    cars_data = json['cars'].to_h { |c|
      car = Car.from_json(c)
      [car.id, car]
    }
    rentals_data = json['rentals'].map { |r|
      Rental.from_json(r)
    }
    return cars_data, rentals_data
  end
end

Car = Data.define(:id, :price_per_day, :price_per_km) do
  def self.from_json(json)
    Car.new(json['id'], json['price_per_day'], json['price_per_km'])
  end
end

Rental = Data.define(:id, :car_id, :start, :end, :distance) do
  def self.from_json(json)
    r = Rental.new(
      json['id'],
      json['car_id'],
      Date.parse(json['start_date']),
      Date.parse(json['end_date']),
      json['distance']
    )

    Rental.members.each do |m|
      if (r.send(m).nil?)
        raise ArgumentError.new("Rental cannot have nil #{m}")
      end
    end

    return r
  end

  def rental_days
    (self.end - self.start).to_i + 1 # count end day inclusive
  end
end

RentalPrice = Data.define(:id, :price) do
  def to_json(*args)
    self.to_h.to_json(*args)
  end
end

module Calculator
  def self.rental_price(rental, car)
    return RentalPrice.new(
             rental.id,
             rental.rental_days * car.price_per_day + rental.distance * car.price_per_km
           )
  end

  def self.rental_prices(rentals, cars)
    rentals.map do |rental|
      car = cars[rental.car_id]
      if car.nil?
        raise ArgumentError.new("Car with id #{rental.car_id} for rental #{rental.id} not found")
      end

      rental_price(rental, car)
    end
  end
end

if $0 == __FILE__
  input = JSON.parse(File.read('data/input.json'))

  cars, rentals = InputData.from_json(input)

  output = { 'rentals' => Calculator::rental_prices(rentals, cars) }

  File.write('data/output.json', JSON.pretty_generate(output))
end
