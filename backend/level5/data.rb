module InputData
  def self.from_json(json)
    cars_data = json['cars'].to_h { |c|
      car = Car.from_json(c)
      [car.id, car]
    }
    rentals_data = json['rentals'].map { |r|
      Rental.from_json(r)
    }
    options_data = json['options'].map { |o|
      Option.from_json(o)
    }.group_by { |o| o.rental_id }

    return cars_data, rentals_data, options_data
  end
end

class Database
  def initialize(cars, rentals, options)
    @cars = cars
    @rentals = rentals
    @options = options
  end

  def rentals
    @rentals.map do |rental|
      rental_options = (@options[rental.id] || [])
      car = @cars[rental.car_id]
      if car.nil?
        raise ArgumentError.new("Car with id #{rental.car_id} for rental #{rental.id} not found")
      else
        RentalRequest.new(rental, car, rental_options)
      end
    end
  end
end
