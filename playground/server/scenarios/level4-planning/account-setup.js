module.exports = {
  id: 'l4-account-setup',
  level: 4,
  levelName: 'Multi-step Planning',
  title: 'Complete Account Setup',
  description: "Register an account with username 'johndoe', set up your profile, and configure preferences.",
  route: '/scenarios/l4-account-setup',
  initialState: {
    currentStep: 1,
    username: null,
    email: null,
    bio: null,
    timezone: null,
    notifications: null,
    theme: null,
    accountCreated: false,
  },
  endpoints: {
    'POST /api/l4-account-setup/credentials': (store, body) => {
      const errors = [];
      if (body.username !== 'johndoe') errors.push('Username must be "johndoe".');
      if (!body.email || !body.email.includes('@')) errors.push('A valid email is required.');
      if (errors.length > 0) return { success: false, errors };
      store.set('username', body.username);
      store.set('email', body.email);
      store.set('currentStep', 2);
      return { success: true, step: 2 };
    },
    'POST /api/l4-account-setup/profile': (store, body) => {
      if (!body.bio || body.bio.length < 10) {
        return { success: false, errors: ['Bio must be at least 10 characters.'] };
      }
      if (!body.timezone) {
        return { success: false, errors: ['Timezone is required.'] };
      }
      store.set('bio', body.bio);
      store.set('timezone', body.timezone);
      store.set('currentStep', 3);
      return { success: true, step: 3 };
    },
    'POST /api/l4-account-setup/preferences': (store, body) => {
      store.set('notifications', body.notifications === true || body.notifications === 'true');
      store.set('theme', body.theme || null);
      store.set('accountCreated', true);
      store.set('currentStep', 4);
      return { success: true, step: 4, message: 'Account created successfully!' };
    },
  },
  verify: (store) => {
    const passed = store.get('accountCreated') === true
      && store.get('username') === 'johndoe'
      && store.get('bio') !== null
      && store.get('theme') !== null;
    return {
      passed,
      message: passed
        ? 'Account fully set up with all steps completed!'
        : 'Account setup is incomplete.',
      details: {
        username: store.get('username'),
        bio: store.get('bio'),
        timezone: store.get('timezone'),
        notifications: store.get('notifications'),
        theme: store.get('theme'),
        accountCreated: store.get('accountCreated'),
      },
    };
  },
  template: 'account-setup.html',
};
