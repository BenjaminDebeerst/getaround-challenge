module Calculator
  def self.price(rental_request)
    rental = rental_request.rental
    car = rental_request.car
    options = rental_request.options

    mileage = rental.distance * car.price_per_km
    day_based_cost = degressive_per_day_price(rental.rental_days, car.price_per_day)

    commissionable_cost = mileage + day_based_cost
    commission, insurance, assistance = commission_parts(commissionable_cost, rental.rental_days)
    owner_options, drivy_options = option_costs(options, rental.rental_days)

    total_cost = commissionable_cost + owner_options + drivy_options

    return RentalPrice.new(rental.id, total_cost, insurance, assistance, commission - insurance - assistance + drivy_options, options)
  end

  def self.degressive_per_day_price(days, base_price)
    price = base_price + # day 1
            (base_price * 0.9 * [0, [days - 1, 3].min].max).to_i + # days 2-4
            (base_price * 0.7 * [0, [days - 4, 6].min].max).to_i + # days 5-9
            (base_price * 0.5 * [0, days - 10].max).to_i # days 10 ff
  end

  def self.commission_parts(commissionable_cost, days)
    commission = (0.3 * commissionable_cost).to_i
    insurance = (0.15 * commissionable_cost).to_i
    assistance = days * 100

    if assistance > insurance
      raise ArgumentError.new("Commissionable cost of #{commissionable_cost} for #{days} days too low to cover fees.")
    end

    return commission, insurance, assistance
  end

  def self.option_costs(options, days)
    options_costs = options
      .group_by { |o| o.type.payable_to }
      .transform_values { |opts| opts.map { |o| o.type.price_per_day }.sum * days }

    return (options_costs[:owner] || 0), (options_costs[:drivy] || 0)
  end
end
