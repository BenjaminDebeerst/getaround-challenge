RentalRequest = Data.define(:rental, :car, :options)

RentalPrice = Data.define(:id, :total_price, :insurance_fee, :assistance_fee, :drivy_fee, :options)

Car = Data.define(:id, :price_per_day, :price_per_km) do
  def self.from_json(json)
    Car.new(json['id'], json['price_per_day'], json['price_per_km'])
  end
end

Rental = Data.define(:id, :car_id, :start, :end, :distance) do
  def self.from_json(json)
    Rental.new(
      json['id'],
      json['car_id'],
      Date.parse(json['start_date']),
      Date.parse(json['end_date']),
      json['distance']
    )
  end

  def rental_days
    (self.end - self.start).to_i + 1 # count end day inclusive
  end
end

module OptionType
  Value = Data.define(:name, :price_per_day, :payable_to)

  GPS = Value.new('gps', 500, :owner)
  BABY_SEAT = Value.new('baby_seat', 200, :owner)
  ADDITIONAL_INSURANCE = Value.new('additional_insurance', 1000, :drivy)

  ALL = [GPS, BABY_SEAT, ADDITIONAL_INSURANCE]

  def self.from(name)
    type = ALL.select { |o| o.name == name }.first
    if type.nil?
      raise ArgumentError.new("Unknown option of name #{name}")
    end
    type
  end
end

Option = Data.define(:id, :rental_id, :type) do
  def self.from_json(json)
    Option.new(json['id'], json['rental_id'], OptionType.from(json['type']))
  end

  def to_json(*args)
    self.type.name.to_json(*args)
  end
end

Transaction = Data.define(:who, :type, :amount) do
  def to_json(*args)
    self.to_h.to_json(*args)
  end
end
