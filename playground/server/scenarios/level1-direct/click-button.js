module.exports = {
  id: 'l1-click-button',
  level: 1,
  levelName: 'Direct Action',
  title: 'Click the Submit Button',
  description: 'Fill in the form with a name and click the Submit button.',
  route: '/scenarios/l1-click-button',
  initialState: { formSubmitted: false, submissionCount: 0 },
  endpoints: {
    'POST /api/l1-click-button/submit': (store, body) => {
      store.set('formSubmitted', true);
      store.set('submissionCount', store.get('submissionCount') + 1);
      return { success: true, message: 'Form submitted!' };
    },
  },
  verify: (store) => {
    const passed = store.get('formSubmitted') === true;
    return {
      passed,
      message: passed
        ? 'Form was submitted successfully.'
        : 'Form has not been submitted yet.',
      details: {
        formSubmitted: store.get('formSubmitted'),
        submissionCount: store.get('submissionCount'),
      },
    };
  },
  template: 'click-button.html',
};
