//= require cable

App.activateGameChannel = function() {

  App.initializeCable();

  return App.cable.subscriptions.create('GameChannel', {
    received: function(data) {
      console.log('GameChannel');
      console.log(data);
    }
  });
};
