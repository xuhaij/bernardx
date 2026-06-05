module.exports = {
  id: 'l4-data-entry',
  level: 4,
  levelName: 'Multi-step Planning',
  title: 'Transfer Contact Data',
  description: 'Copy all contact information from the business card on the left into the form on the right.',
  route: '/scenarios/l4-data-entry',
  initialState: {
    name: null,
    title: null,
    company: null,
    email: null,
    phone: null,
    submitted: false,
  },
  endpoints: {
    'POST /api/l4-data-entry/submit': (store, body) => {
      const errors = [];
      if (body.name !== 'Sarah Chen') errors.push('Name does not match the contact card.');
      if (body.title !== 'VP of Engineering') errors.push('Title does not match the contact card.');
      if (body.company !== 'TechNova Inc.') errors.push('Company does not match the contact card.');
      if (body.email !== 'sarah.chen@technova.com') errors.push('Email does not match the contact card.');
      if (body.phone !== '(415) 555-0147') errors.push('Phone does not match the contact card.');
      if (errors.length > 0) return { success: false, errors };

      store.set('name', body.name);
      store.set('title', body.title);
      store.set('company', body.company);
      store.set('email', body.email);
      store.set('phone', body.phone);
      store.set('submitted', true);
      return { success: true, message: 'Contact data transferred successfully!' };
    },
  },
  verify: (store) => {
    const passed = store.get('submitted') === true
      && store.get('name') === 'Sarah Chen'
      && store.get('email') === 'sarah.chen@technova.com';
    return {
      passed,
      message: passed
        ? 'All contact data transferred correctly!'
        : 'Contact data has not been correctly submitted.',
      details: {
        name: store.get('name'),
        title: store.get('title'),
        company: store.get('company'),
        email: store.get('email'),
        phone: store.get('phone'),
        submitted: store.get('submitted'),
      },
    };
  },
  template: 'data-entry.html',
};
