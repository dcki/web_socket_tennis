//= require cable

App.activateAppearanceChannel = function(awaySelector, returnSelector, dataSelector, disconnectSelector) {

  App.initializeCable();

  return App.cable.subscriptions.create('AppearanceChannel', {
    // Called when the subscription is ready for use on the server.
    connected: function() {
      this.install();
      this.appear();
    },
    // Called when the WebSocket connection is closed.
    disconnected: function() {
      this.uninstall();
    },
    // Called when the subscription is rejected by the server.
    rejected: function() {
      this.uninstall();
    },
    received: function(data) {
      console.log('Received data:');
      console.log(data);
    },
    appear: function() {
      // Calls `AppearanceChannel#appear(data)` on the server.
      this.perform('appear', {
        appearing_on: document.querySelector(dataSelector).dataset.appearingOn
      });
    },
    away: function() {
      // Calls `AppearanceChannel#away` on the server.
      this.perform('away');
    },
    return_from_away: function() {
      // Calls `AppearanceChannel#away` on the server.
      this.perform('return_from_away');
    },
    install: function() {
      document.querySelector(awaySelector).addEventListener('click', (event) => {
        this.away();
        return false;
      });
      document.querySelector(returnSelector).addEventListener('click', (event) => {
        this.return_from_away();
        return false;
      });
      document.querySelector(disconnectSelector).addEventListener('click', (event) => {
        this.disconnect();
        return false;
      });
      document.querySelector(awaySelector).classList.remove('hidden');
      document.querySelector(returnSelector).classList.remove('hidden');
      document.querySelector(disconnectSelector).classList.remove('hidden');
    },
    uninstall: function() {
      document.querySelector(awaySelector).classList.add('hidden');
      document.querySelector(returnSelector).classList.add('hidden');
      document.querySelector(disconnectSelector).classList.add('hidden');
    },
    disconnect: function() {
      App.cable.subscriptions.remove(this);
      this.uninstall();
    }
  });
};
