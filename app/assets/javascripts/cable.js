// Action Cable provides the framework to deal with WebSockets in Rails.
// You can generate new channels where WebSocket features live using the `rails generate channel` command.
//
//= require action_cable

(function() {
  this.App || (this.App = {});

  App.initializeCable = function() {
    App.cable || (App.cable = ActionCable.createConsumer());
  };
  App.createCableSubscription = function(channelName, mixin) {
    App.initializeCable();
    return App.cable.subscriptions.create(channelName, mixin);
  };
}).call(this);
