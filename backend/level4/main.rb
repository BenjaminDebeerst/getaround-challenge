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

RentalPrice = Data.define(:id, :price, :insurance_fee, :assistance_fee, :drivy_fee)

Transaction = Data.define(:who, :type, :amount) do
  def to_json(*args)
    self.to_h.to_json(*args)
  end
end

module Presentation
  def self.rental_price_components(rental)
    {
      'id' => rental.id,
      'price' => rental.price,
      'commission' => {
        'insurance_fee' => rental.insurance_fee,
        'assistance_fee' => rental.assistance_fee,
        'drivy_fee' => rental.drivy_fee,
      },
    }
  end

  def self.rental_transaction(rental)
    {
      'id' => rental.id,
      'actions' => transactions(rental),
    }
  end

  private

  def self.transactions(rental)
    [
      Transaction.new('driver', 'debit', rental.price),
      Transaction.new('owner', 'credit', rental.price - rental.insurance_fee - rental.assistance_fee - rental.drivy_fee),
      Transaction.new('insurance', 'credit', rental.insurance_fee),
      Transaction.new('assistance', 'credit', rental.assistance_fee),
      Transaction.new('drivy', 'credit', rental.drivy_fee),
    ]
  end
end

module Calculator
  def self.rental_price(rental, car)
    mileage_cost = rental.distance * car.price_per_km

    days = rental.rental_days
    price = car.price_per_day
    day_based_cost = price + # day 1
                     (price * 0.9 * [0, [days - 1, 3].min].max).to_i + # days 2-4
                     (price * 0.7 * [0, [days - 4, 6].min].max).to_i + # days 5-9
                     (price * 0.5 * [0, days - 10].max).to_i # days 10 ff

    total_cost = mileage_cost + day_based_cost

    commission = (0.3 * total_cost).to_i
    insurance = (0.15 * total_cost).to_i
    assistance = days * 100

    if assistance > insurance
      raise ArgumentError.new("Rental price of #{total_cost} for #{days} days too low to cover fees from 30%.")
    end

    return RentalPrice.new(rental.id, total_cost, insurance, assistance, commission - insurance - assistance)
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

  output = { 'rentals' => Calculator::rental_prices(rentals, cars).map { |r| Presentation::rental_transaction(r) } }

  File.write('data/output.json', JSON.pretty_generate(output))
end
