# Getaround coding challenge

Some comments about the solution provided.

## Input data validation

The input data in the various levels takes a form similar to classic relational data in a database, where the access
layer typically takes care of joining data and ensuring data consistency. I have thus decided to wrap the input data
in a "Database" abstraction, allowing access in a typical denormalized way while assuming that the underlying data is
consistent and reasonable. Understanding the challenge to be concerned with the calculation and presentation aspects,
I have thus decided to leave out data input validation such as ensuring all expected json fields are present or
preventing potentially harmful data such as negative prices or distances or rental periods with start dates after
end dates.

## Implementation style

To me, the expected output format using the key 'rentals' for the price and transaction details of a rental is hinting
at an expected object-oriented implementation style where prices and transactions would become properties or methods
of a 'Rental' model. I have nevertheless chosen to follow a more functional style using data without mutations and an
entirely static calculation implementation, leading to slight naming overlapping between 'rental', 'rental price' and
'rental request' which is a little odd.

On the upside, it allows to keep the calculation logic entirely separated from the model implementations which serve
as pure data classes. The static implementation enables simpler and easily parameterized tests and do in my experience
lead to more easily debuggable systems. (In particular the calculator component would lend to property based testing,
validating invariants such as the total cost being equal to the sum of all cost components. I have left the
implementation of such test out for the sake of time though.) A result of this design is that the output formats for
the different levels become only a concern of presentation of a calculated price, entirely separate from the actual
calculation.
