module.exports = {
  id: 'l5-server-errors',
  level: 5,
  levelName: 'Exception Handling',
  title: 'Handle Server Errors',
  description: 'Submit the form. The server may return errors — keep retrying until it succeeds.',
  route: '/scenarios/l5-server-errors',
  initialState: {
    attempts: 0,
    data: null,
    submitted: false,
    failUntilAttempt: Math.floor(Math.random() * 4) + 2,
  },
  endpoints: {
    'POST /api/l5-server-errors/submit': (store, body) => {
      const attempts = store.get('attempts') + 1;
      store.set('attempts', attempts);
      const failUntil = store.get('failUntilAttempt');

      if (attempts < failUntil) {
        return {
          success: false,
          error: 'Service Unavailable (503)',
          retryAfter: 3,
          message: 'Server error. Please try again.',
        };
      }

      store.set('data', body.feedback || null);
      store.set('submitted', true);
      return { success: true, message: 'Feedback submitted successfully!' };
    },
  },
  verify: (store) => {
    const passed = store.get('submitted') === true && store.get('attempts') >= 2;
    return {
      passed,
      message: passed
        ? `Feedback submitted after ${store.get('attempts')} attempts!`
        : 'Feedback has not been successfully submitted yet.',
      details: {
        attempts: store.get('attempts'),
        submitted: store.get('submitted'),
      },
    };
  },
  template: 'server-errors.html',
};
