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

class IntegrationSpec < Test::Unit::TestCase
  def test_with_data
    data = JSON.parse(File.read('data/input.json'))
    expected = JSON.parse(File.read('data/expected_output.json'))

    cars, rentals = InputData.from_json(data)

    assert_equal(expected['rentals'], JSON.parse(JSON.generate(Calculator::rental_prices(rentals, cars))))
  end
end

class CalculatorSpec < Test::Unit::TestCase
  def test_price_calculation_single_rental
    start_date = Date.new(2024, 11, 1)
    end_date = Date.new(2024, 11, 1)

    car = Car.new(1, 1000, 10)
    rental = Rental.new(2, 1, start_date, end_date, 10)

    assert_equal(2, Calculator::rental_price(rental, car).id)
    assert_equal(1100, Calculator::rental_price(rental, car).price)
  end

  [
    [1, 1000],
    [2, 1900], # 1000 + 900
    [5, 4400], # 1000 + 3*900 + 700
    [11, 8400], # 1000 + 3*900 + 6*700 + 500
  ].each do |days, price|
    price_per_day = 1000
    start_date = Date.new(2024, 11, 1)
    car = Car.new(1, price_per_day, 0)

    define_method "test_price_calculation_decreasing_price_per_day_#{days}_#{price}" do
      end_date = Date.new(2024, 11, days)
      rental = Rental.new(1, 1, start_date, end_date, 0)
      assert_equal(price, Calculator::rental_price(rental, car).price)
    end
  end

  def test_price_calculation_multiple_rentals
    start_date = Date.new(2024, 11, 1)
    end_date = Date.new(2024, 11, 4)

    cars = { 1 => Car.new(1, 1000, 10) }
    rentals = [Rental.new(2, 1, start_date, end_date, 10), Rental.new(3, 1, start_date, end_date, 20)]

    assert_equal(
      [2, 3],
      Calculator::rental_prices(rentals, cars).map { |r| r.id }
    )
    assert_equal(
      [3800, 3900],
      Calculator::rental_prices(rentals, cars).map { |r| r.price }
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

  def test_computes_commission
    start_date = Date.new(2024, 11, 1)
    end_date = Date.new(2024, 11, 1)

    car = Car.new(1, 10000, 0)
    rental = Rental.new(2, 1, start_date, end_date, 0)

    rp = Calculator::rental_price(rental, car)

    assert_equal(1500, rp.insurance_fee) # 15% of price
    assert_equal(100, rp.assistance_fee) # 100 per day
    assert_equal(1400, rp.drivy_fee) # remainder of 30% of price
  end

  def test_fails_if_commission_is_exceeding_rental_price
    start_date = Date.new(2024, 11, 1)
    end_date = Date.new(2024, 11, 1)

    car = Car.new(1, 100, 0) # 1 euro per day means 100% would be assistance fee
    rental = Rental.new(2, 1, start_date, end_date, 0)

    assert_raise(ArgumentError) do
      Calculator::rental_price(rental, car)
    end
  end
end
