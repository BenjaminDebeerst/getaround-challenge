require 'date'
require 'json'
require 'test/unit'

require './main'

class DataInputSpec < Test::Unit::TestCase
  def test_car_data
    json = JSON.parse('{ "cars": [{ "id": 4, "price_per_day": 5, "price_per_km": 6 }], "rentals": [], "options": [] }')
    cars, _, _ = InputData::from_json(json)

    assert_equal({ 4 => Car.new(4, 5, 6) }, cars)
  end

  def test_rental_data
    json = JSON.parse('{ "rentals": [{ "id": 1, "car_id": 2, "start_date": "2024-11-01", "end_date": "2024-11-03", "distance": 3 }], "cars": [], "options": []}')
    _, rentals, _ = InputData::from_json(json)

    assert_equal([Rental.new(1, 2, Date.new(2024, 11, 1), Date.new(2024, 11, 3), 3)], rentals)
  end

  def test_options_data
    json = JSON.parse('{ "options": [{ "id": 2, "rental_id": 1, "type": "baby_seat" }], "cars": [], "rentals": []}')
    _, _, options = InputData::from_json(json)

    assert_equal({ 1 => [Option.new(2, 1, OptionType::BABY_SEAT)] }, options)
  end
end

class DatabaseSpec < Test::Unit::TestCase
  def test_raises_error_for_missing_cars
    start_date = Date.new(2024, 11, 1)
    end_date = Date.new(2024, 11, 4)

    rentals = [Rental.new(2, 1, start_date, end_date, 10)]

    db = Database.new([], rentals, [])

    assert_raise(ArgumentError) do
      r = db.rentals
    end
  end

  def test_performs_options_lookup
    start_date = Date.new(2024, 11, 1)
    end_date = Date.new(2024, 11, 4)

    cars = { 1 => Car.new(1, 1000, 10) }
    rentals = [Rental.new(2, 1, start_date, end_date, 10)]
    options = { 1 => [Option.new(0, 1, OptionType::GPS)], 2 => [Option.new(1, 2, OptionType::BABY_SEAT), Option.new(2, 2, OptionType::ADDITIONAL_INSURANCE)] }

    database = Database.new(cars, rentals, options)

    assert_equal(
      [[OptionType::BABY_SEAT, OptionType::ADDITIONAL_INSURANCE]],
      database.rentals.map { |r| r.options.map { |o| o.type } }
    )
  end
end

class IntegrationSpec < Test::Unit::TestCase
  def test_with_data
    data = JSON.parse(File.read('data/input.json'))
    expected = JSON.parse(File.read('data/expected_output.json'))

    db = Database.new(*InputData.from_json(data))

    results = db.rentals
      .map { |r| Calculator::price(r) }
      .map { |p| Presentation::rental_transaction(p) }

    assert_equal(expected['rentals'], JSON.parse(JSON.generate(results)))
  end
end

class CalculatorSpec < Test::Unit::TestCase
  def test_price_calculation_single_rental
    start_date = Date.new(2024, 11, 1)
    end_date = Date.new(2024, 11, 1)

    rental = RentalRequest.new(
      Rental.new(2, 1, start_date, end_date, 10),
      Car.new(1, 1000, 10),
      []
    )

    assert_equal(2, Calculator::price(rental).id)
    assert_equal(1100, Calculator::price(rental).total_price)
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
      rental = RentalRequest.new(
        Rental.new(1, 1, start_date, end_date, 0),
        car,
        []
      )
      assert_equal(price, Calculator::price(rental).total_price)
    end
  end

  def test_computes_commission
    start_date = Date.new(2024, 11, 1)
    end_date = Date.new(2024, 11, 1)

    rental = RentalRequest.new(
      Rental.new(2, 1, start_date, end_date, 0),
      Car.new(1, 10000, 0),
      []
    )

    rp = Calculator::price(rental)

    assert_equal(1500, rp.insurance_fee) # 15% of price
    assert_equal(100, rp.assistance_fee) # 100 per day
    assert_equal(1400, rp.drivy_fee) # remainder of 30% of price
  end

  def test_fails_if_commission_is_exceeding_rental_price
    start_date = Date.new(2024, 11, 1)
    end_date = Date.new(2024, 11, 1)

    rental = RentalRequest.new(
      Rental.new(2, 1, start_date, end_date, 0),
      Car.new(1, 100, 0), # 1 euro per day means 100% would be assistance fee
      []
    )

    assert_raise(ArgumentError) do
      Calculator::price(rental)
    end
  end

  [
    ['gps', 2000],
    ['baby_seat', 800],
    ['additional_insurance', 4000],
  ].each do |option, extra_cost|
    start_date = Date.new(2024, 11, 1)
    end_date = Date.new(2024, 11, 4)
    car = Car.new(1, 1000, 10)
    rental = Rental.new(2, 1, start_date, end_date, 100)
    base_price = 4700

    define_method "test_considers_option_#{option}" do
      rental_request = RentalRequest.new(
        rental,
        car,
        [Option.new(1, 2, OptionType.from(option))]
      )

      assert_equal(base_price + extra_cost, Calculator::price(rental_request).total_price)
    end
  end
end
