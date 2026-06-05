module.exports = {
  id: 'l5-disappearing-elements',
  level: 5,
  levelName: 'Exception Handling',
  title: 'Catch the Disappearing Button',
  description: 'A "Claim Reward" button appears and disappears periodically. Wait for it to appear, then click it before it vanishes.',
  route: '/scenarios/l5-disappearing-elements',
  initialState: {
    rewardClaimed: false,
    attempts: 0,
  },
  endpoints: {
    'POST /api/l5-disappearing-elements/claim': (store, body) => {
      const attempts = store.get('attempts') + 1;
      store.set('attempts', attempts);

      if (body.visible !== 'true') {
        return { success: false, errors: ['Button was not visible when clicked. Try again.'] };
      }

      store.set('rewardClaimed', true);
      return { success: true, message: 'Reward claimed!' };
    },
  },
  verify: (store) => {
    const passed = store.get('rewardClaimed') === true;
    return {
      passed,
      message: passed
        ? `Reward claimed after ${store.get('attempts')} attempt(s)!`
        : 'The reward has not been claimed yet.',
      details: {
        rewardClaimed: store.get('rewardClaimed'),
        attempts: store.get('attempts'),
      },
    };
  },
  template: 'disappearing-elements.html',
};
