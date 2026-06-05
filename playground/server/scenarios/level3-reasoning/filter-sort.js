module.exports = {
  id: 'l3-filter-sort',
  level: 3,
  levelName: 'Reasoning',
  title: 'Filter and Sort Products',
  description: 'Show Electronics with 4+ stars, sort by price (low to high), then add the top result to your cart.',
  route: '/scenarios/l3-filter-sort',
  initialState: { cartItem: null, cartPrice: null, filtersApplied: [] },
  endpoints: {
    'POST /api/l3-filter-sort/filter': (store, body) => {
      const filters = store.get('filtersApplied') || [];
      store.set('filtersApplied', [...filters, body.filter]);
      return { success: true, filter: body.filter };
    },
    'POST /api/l3-filter-sort/add-to-cart': (store, body) => {
      store.set('cartItem', body.productName || null);
      store.set('cartPrice', body.price || null);
      return { success: true, message: `${body.productName} added to cart!` };
    },
  },
  verify: (store) => {
    const item = store.get('cartItem');
    const correctItem = 'USB-C Hub';
    const passed = item === correctItem;
    return {
      passed,
      message: passed
        ? 'Correct! USB-C Hub is the cheapest 4+ star electronics item.'
        : item
          ? `"${item}" is not the correct result after filtering and sorting.`
          : 'No product has been added to the cart.',
      details: {
        cartItem: store.get('cartItem'),
        cartPrice: store.get('cartPrice'),
        filtersApplied: store.get('filtersApplied'),
      },
    };
  },
  template: 'filter-sort.html',
};
