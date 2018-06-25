//= require cable

App.activateMatchMakingChannel = function() {

  App.initializeCable();

  return App.cable.subscriptions.create('MatchMakingChannel', {
    connected: function() {
      this.perform('create_game');
    },
    received: function(data) {
      console.log('MatchMakingChannel');
      console.log(data);
    }
  });
};
