module.exports = {
  id: 'l2-select-best-value',
  level: 2,
  levelName: 'Context Understanding',
  title: 'Select Best Value Product',
  description: 'Add the best value product to your cart.',
  route: '/scenarios/l2-select-best-value',
  initialState: { cartItem: null, cartPrice: null },
  endpoints: {
    'POST /api/l2-select-best-value/add-to-cart': (store, body) => {
      store.set('cartItem', body.productName || null);
      store.set('cartPrice', body.price || null);
      return { success: true, message: `${body.productName} added to cart!` };
    },
  },
  verify: (store) => {
    const passed = store.get('cartItem') === 'StreamFit Basic';
    return {
      passed,
      message: passed
        ? 'Correct! StreamFit Basic is the best value option.'
        : store.get('cartItem')
          ? `"${store.get('cartItem')}" is not the best value product.`
          : 'No product has been added to the cart.',
      details: { cartItem: store.get('cartItem'), cartPrice: store.get('cartPrice') },
    };
  },
  template: 'select-best-value.html',
};
