require 'date'
require 'json'
require 'test/unit'

require './main'

class DataInputSpec < Test::Unit::TestCase
  def test_car_data
    json = JSON.parse('{ "cars": [{ "id": 4, "price_per_day": 5, "price_per_km": 6 }], "rentals": []}')
    cars, _ = InputData::from_json(json)

    assert_equal({ 4 => Car.new(4, 5, 6) }, cars)
  end

  def test_rental_data
    json = JSON.parse('{ "rentals": [{ "id": 1, "car_id": 2, "start_date": "2024-11-01", "end_date": "2024-11-03", "distance": 3 }], "cars": []}')
    _, rentals = InputData::from_json(json)

    assert_equal([Rental.new(1, 2, Date.new(2024, 11, 1), Date.new(2024, 11, 3), 3)], rentals)
  end
end

class CalculatorSpec < Test::Unit::TestCase
  def test_price_calculation_single_rental
    start_date = Date.new(2024, 11, 1)
    end_date = Date.new(2024, 11, 4)

    car = Car.new(1, 1000, 10)
    rental = Rental.new(2, 1, start_date, end_date, 10)

    assert_equal(RentalPrice.new(2, 4100), Calculator::rental_price(rental, car))
  end

  def test_price_calculation_multiple_rentals
    start_date = Date.new(2024, 11, 1)
    end_date = Date.new(2024, 11, 4)

    cars = { 1 => Car.new(1, 1000, 10) }
    rentals = [Rental.new(2, 1, start_date, end_date, 10), Rental.new(3, 1, start_date, end_date, 20)]

    assert_equal(
      [RentalPrice.new(2, 4100), RentalPrice.new(3, 4200)],
      Calculator::rental_prices(rentals, cars)
    )
  end

  def test_raises_error_for_missing_cars
    start_date = Date.new(2024, 11, 1)
    end_date = Date.new(2024, 11, 4)

    rentals = [Rental.new(2, 1, start_date, end_date, 10)]

    assert_raise(ArgumentError) do
      Calculator::rental_prices(rentals, {})
    end
  end
end
