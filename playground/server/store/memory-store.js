class MemoryStore {
  constructor(initialState = {}) {
    this._state = { ...initialState };
    this._initialState = { ...initialState };
  }

  get(key) {
    return this._state[key];
  }

  set(key, value) {
    this._state = { ...this._state, [key]: value };
  }

  reset() {
    this._state = { ...this._initialState };
  }

  toJSON() {
    return { ...this._state };
  }
}

module.exports = MemoryStore;
