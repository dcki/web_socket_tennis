//= require cable

App.newGame = function(options) {
  var game = {
    initialize: function(options) {
      this.element = options.gameElement;
      this.matchMakingElement = options.matchMakingElement;
      this.messageEl = this.matchMakingElement.querySelector('.message');
      this.subscribeToMatchMaking();
      this.subscribeToGame();
      this.initializeEventHandlers();
    },
    subscribeToMatchMaking: function() {
      if (this.subscribedToMatchMaking) {
        return;
      }
      this.subscribedToMatchMaking = true;

      this.matchMakingSubscription = App.createCableSubscription('MatchMakingChannel', {
        received: function(data) {
          if (data.error) {
            alert(data.error);
          }
        }
      });
      this.subscriptionsToRemove.push(this.matchMakingSubscription);
    },
    subscribeToGame: function() {
      if (this.subscribedToGame) {
        return;
      }
      this.subscribedToGame = true;

      var self = this;

      this.gameSubscription = App.createCableSubscription('GameChannel', {
        received: function(data) {
          if (data.game_over) {
            (self.getOnEndCallback())();
          }
          if (data.game_objects) {
            self.updateDimensions(data.game_objects);
          }
          if (data.game_object_positions) {
            self.updatePositions(data.game_object_positions);
          }
        }
      });
      this.subscriptionsToRemove.push(this.gameSubscription);

      this.publishInterval = setInterval(function() {
        var state,
          keys = self.getKeys(),
          upArrow = keys[38],
          downArrow = keys[40];
        if (upArrow && !downArrow) {
          state = 'up';
        } else if (!upArrow && downArrow) {
          state = 'down';
        } else {
          state = 'stop';
        }
        self.gameSubscription.perform('paddle', { paddle_state: state });
      }, 20);
    },
    updateDimensions: function(gameObjects) {
      // To do: have server assign every dimension specifically to add
      // flexibility for what can happen in a game. For example maybe
      // paddles change size during the game.
      var width = gameObjects.level.width,
        height = gameObjects.level.height,
        ballWidth = gameObjects.ball.width;

      this.findChildElements();

      this.element.style.width = width + 'px';
      this.element.style.height = height + 'px';

      this.paddle1El.style.width = ballWidth + 'px';
      this.paddle1El.style.height = (2 * ballWidth) + 'px';

      this.paddle2El.style.width = ballWidth + 'px';
      this.paddle2El.style.height = (2 * ballWidth) + 'px';
      this.paddle2El.style.left = (width - ballWidth) + 'px';

      this.ballEl.style.width = ballWidth + 'px';
      this.ballEl.style.height = ballWidth + 'px';
      this.ballEl.style.left = ((width - ballWidth) / 2) + 'px';

      this.element.classList.remove('hidden');
      this.messageEl.classList.add('hidden');
    },
    updatePositions: function(gameObjectPositions) {
      var paddle1 = gameObjectPositions.paddle1,
        paddle2 = gameObjectPositions.paddle2,
        ball = gameObjectPositions.ball;

      this.findChildElements();

      this.paddle1El.style.top = paddle1.y + 'px';
      this.paddle2El.style.top = paddle2.y + 'px';
      this.ballEl.style.left = ball.x + 'px';
      this.ballEl.style.top = ball.y + 'px';

      this.element.classList.remove('hidden');
      this.messageEl.classList.add('hidden');
    },
    findChildElements: function() {
      this.paddle1El = this.paddle1El || this.element.querySelector('.paddle-1');
      this.paddle2El = this.paddle2El || this.element.querySelector('.paddle-2');
      this.ballEl = this.ballEl || this.element.querySelector('.ball');
    },
    initializeEventHandlers: function() {
      var self = this;

      var minEl = this.matchMakingElement.querySelector('input[name=min_velocity]');
      var maxEl = this.matchMakingElement.querySelector('input[name=max_velocity]');
      var startEl = this.matchMakingElement.querySelector('button.start');
      var stopEl = this.matchMakingElement.querySelector('button.stop');

      var clickStart = function() {
        (self.getMatchMakingSubscription()).perform('join_game', {
          min_velocity: minEl.value,
          max_velocity: maxEl.value
        });
        self.messageEl.classList.remove('hidden');
      };
      startEl.addEventListener('click', clickStart);
      this.eventHandlersToRemove.push([startEl, 'click', clickStart]);

      var clickQuit = function() {
        (self.getGameSubscription()).perform('stop');
      };
      stopEl.addEventListener('click', clickQuit);
      this.eventHandlersToRemove.push([stopEl, 'click', clickQuit]);

      var keyDown = function(e) {
        self.getKeys()[e.keyCode] = true;
      };
      document.addEventListener('keydown', keyDown, false);
      this.eventHandlersToRemove.push([document, 'keydown', keyDown]);

      var keyUp = function(e) {
        self.getKeys()[e.keyCode] = false;
      };
      document.addEventListener('keyup', keyUp, false);
      this.eventHandlersToRemove.push([document, 'keyup', keyUp]);
    },
    getMatchMakingSubscription: function() {
      return this.matchMakingSubscription;
    },
    getGameSubscription: function() {
      return this.gameSubscription;
    },
    keys: [],
    getKeys: function() {
      return this.keys;
    },
    setOnEndCallback: function(callback) {
      var self = this;
      this.onEndCallback = function() {
        self.destroy();
        alert('Game over!');
        callback();
      }
    },
    getOnEndCallback: function() {
      return this.onEndCallback;
    },
    destroy: function() {
      var i;

      this.element.classList.add('hidden');

      for (i = 0; i < this.subscriptionsToRemove.length; i++) {
        this.subscriptionsToRemove[i].unsubscribe();
      }

      for (i = 0; i < this.eventHandlersToRemove.length; i++) {
        var element = this.eventHandlersToRemove[i][0];
        var type = this.eventHandlersToRemove[i][1];
        var handler = this.eventHandlersToRemove[i][2];

        element.removeEventListener(type, handler);
      }

      for (i = 0; i < this.intervalsToRemove.length; i++) {
        clearInterval(this.intervalsToRemove[i]);
      }
    },
    subscriptionsToRemove: [],
    eventHandlersToRemove: [],
    intervalsToRemove: []
  };
  game.initialize(options);
  return game;
};
