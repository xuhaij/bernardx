module.exports = {
  id: 'l3-price-compare',
  level: 3,
  levelName: 'Reasoning',
  title: 'Best Laptop Under Budget',
  description: 'Find the best laptop within the $800 budget and add it to your cart. Best means highest specs for the price.',
  route: '/scenarios/l3-price-compare',
  initialState: { cartItem: null, cartPrice: null },
  endpoints: {
    'POST /api/l3-price-compare/add-to-cart': (store, body) => {
      store.set('cartItem', body.productName || null);
      store.set('cartPrice', body.price || null);
      return { success: true, message: `${body.productName} added to cart!` };
    },
  },
  verify: (store) => {
    const item = store.get('cartItem');
    const price = store.get('cartPrice');
    const bestChoice = 'TechBook Air 15';
    const bestPrice = 699;
    const passed = item === bestChoice;
    return {
      passed,
      message: passed
        ? `Correct! ${bestChoice} at $${bestPrice} is the best value under $800.`
        : item
          ? `"${item}" is not the best choice. Look at RAM, SSD, and price together.`
          : 'No product has been added to the cart.',
      details: { cartItem: item, cartPrice: price },
    };
  },
  template: 'price-compare.html',
};
