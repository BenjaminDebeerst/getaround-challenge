module Presentation
  def self.rental_price_components(rental)
    {
      'id' => rental.id,
      'price' => rental.total_price,
      'commission' => {
        'insurance_fee' => rental.insurance_fee,
        'assistance_fee' => rental.assistance_fee,
        'drivy_fee' => rental.drivy_fee,
      },
    }
  end

  def self.rental_transactions(rental)
    {
      'id' => rental.id,
      'options' => rental.options,
      'actions' => transactions(rental),
    }
  end

  def self.transactions(rental)
    [
      Transaction.new('driver', 'debit', rental.total_price),
      Transaction.new('owner', 'credit', rental.total_price - rental.insurance_fee - rental.assistance_fee - rental.drivy_fee),
      Transaction.new('insurance', 'credit', rental.insurance_fee),
      Transaction.new('assistance', 'credit', rental.assistance_fee),
      Transaction.new('drivy', 'credit', rental.drivy_fee),
    ]
  end
end
