//= require cable

// TODO show player names on their sides of the field.
// TODO show number of returns counter during game.
// TODO implement high scores page.
App.newGame = function(options) {
  var game = {
    initialize: function(options) {
      this.element = options.gameElement;
      this.matchMakingElement = options.matchMakingElement;
      this.messageEl = this.matchMakingElement.querySelector('.message');
      this.gameOverEl = this.matchMakingElement.querySelector('.game-over-message');
      this.subscribeToMatchMaking();
      this.initializeEventHandlers();
    },
    // TODO move matchmaking subscription out of game "class" and share it between
    // game instances to avoid race condition with unsubscribing and re-subscribing
    // too close together.
    //
    // I think a possible race condition could lead to being in an erroneous
    // unsubscribed state, because the unsubscribe message may sometimes arrive after
    // the re-subscribe message. At least, I've seen a behavior for which that seems
    // like a potential explanation. After a game has ended, something prevents a new
    // game from starting, and this error occurs every time a client sends a game
    // update message:
    //
    // Could not execute command from ({"command"=>"message", "identifier"=>"{\"channel\":\"GameChannel\"}", "data"=>"{\"paddle_state\":\"stop\",\"action\":\"paddle\"}"}) [RuntimeError - Unable to find subscription with identifier: {"channel":"GameChannel"}]
    //
    // Either there are multiple action cable workers processing the messages concurrently
    // (I haven't checked) or action cable web socket messages can arrive out of order (I
    // haven't researched that yet). Or there is another explanation for that behavior and
    // error.
    //
    // I'm running Puma with the default 5 threads, and I wouldn't be surprised if
    // Puma is written in such a way that multiple threads could process the messages
    // coming in on a single web socket connection at the same time. (That would be the
    // highest performance design after all.)
    subscribeToMatchMaking: function() {
      if (this.subscribedToMatchMaking) {
        return;
      }
      this.subscribedToMatchMaking = true;

      var self = this;

      this.matchMakingSubscription = App.createCableSubscription('MatchMakingChannel', {
        received: function(data) {
          if (data.new_game_id) {
            self.subscribeToGame(data.new_game_id);
          }
        }
      });
      this.subscriptionsToRemove.push(this.matchMakingSubscription);
    },
    subscribeToGame: function(gameId) {
      if (this.subscribedToGame) {
        return;
      }
      this.subscribedToGame = true;

      var self = this;

      this.gameSubscription = App.createCableSubscription(
        {
          channel: 'GameChannel',
          game_id: gameId
        },
        {
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
        }
      );
      this.subscriptionsToRemove.push(this.gameSubscription);

      var publishInterval = setInterval(function() {
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
      this.intervalsToRemove.push(publishInterval);
    },
    updateDimensions: function(gameObjects) {
      var level = gameObjects.level,
        ball = gameObjects.ball,
        paddle = gameObjects.paddle;

      this.findChildElements();

      this.element.style.width = level.width + 'px';
      this.element.style.height = level.height + 'px';

      this.paddle1El.style.width = paddle.width + 'px';
      this.paddle1El.style.height = paddle.height + 'px';

      this.paddle2El.style.width = paddle.width + 'px';
      this.paddle2El.style.height = paddle.height + 'px';

      this.ballEl.style.width = ball.width + 'px';
      this.ballEl.style.height = ball.height + 'px';

      this.element.classList.remove('hidden');
      this.messageEl.classList.add('hidden');
    },
    updatePositions: function(gameObjectPositions) {
      var paddle1 = gameObjectPositions.paddle1,
        paddle2 = gameObjectPositions.paddle2,
        ball = gameObjectPositions.ball;

      this.findChildElements();

      this.paddle1El.style.left = paddle1.x + 'px';
      this.paddle1El.style.top = paddle1.y + 'px';
      this.paddle2El.style.left = paddle2.x + 'px';
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
        self.gameOverEl.classList.remove('hidden');
        setTimeout(function() {
          self.gameOverEl.classList.add('hidden');
        }, 1000);
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
