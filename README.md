# Web Socket Tennis

Like Pong.

## Ruby version

See the .ruby-version file.

## System dependencies

Recommend using Postgres.app for PostgreSQL because it's connection configuration just works out of the box with the configuration in `config/database.yml`.

PostgreSQL 9.5 or above is required. Postgres.app lets you launch any of several PostgreSQL versions at any time. (PostgreSQL 9.5 or above is required because the MatchMakingChannel class in this app uses the `SKIP LOCKED` parameter with `SELECT FOR UPDATE`, which is only available in PostgreSQL 9.5 and above.)

On OS X I recommend installing things that ruby and gems depend on with homebrew. (I don't know what all the dependencies are for this app because I haven't gone through the full install process for this app myself yet with a completely fresh environment.)

I recommend installing ruby with rbenv and ruby-build.

```
brew install redis
brew services start redis

rbenv install $(cat .ruby-version)

gem install bundler
bundle install
```

For some reason `bundle exec rails` is printing a bunch of 'already initialized constant' warnings. Use the bin stubs: `bin/rails`, `bin/rake`, etc. However there currently is no binstub in this app for some things, like sidekiq.

Remember, if you're changing things and the behavior of the app doesn't change as you expect, and you're really confused, then you might want to try `bin/spring stop`. (Sometimes spring gets stuck in a state and no longer reloads your code changes. spring will start again automatically next time you run any binstub, and maybe also for `bundle exec rails ...`.)

## Configuration

Nothing yet.

## Database initialization

```
bin/rake db:create db:schema:load
```

## How to run the test suite

```
bin/rake db:test:prepare
bin/rails test
```

## Services (job queues, cache servers, search engines, etc.)

### Rails

```
bin/rails s
```

### Sidekiq

The game does not work if sidekiq is not running, including in development.

```
bundle exec sidekiq
```

Expect to see this print a bunch of 'already initialized constant' warnings. It has always worked anyway for this app so far.

sidekiq doesn't seem to pick up code changes you make. You may need to restart it.

TODO: run sidekiq and rails server at the same time with foreman. Although, then all the output gets mixed together, and there is a lot of output.

## Known bugs

- Starting a new game after finishing a game sometimes does not work. I think this is due to a race condition during attempts to unsubscribe and then immediately subscribe again to the same MatchMakingChannel. See comment in JavaScript for more details and intended fix.

- When a user specifies a higher speed, that does not necessarily increase difficulty. Ideally it would.
  - The vertical velocity of the ball can be changed by hitting the ball close to the end of a paddle. This does not influence the horizontal velocity, so the speed of the ball can change. (This isn't physically realistic, but it is fun.) However, horizontal ball velocity and paddle speed are both specified by users, and choosing a low speed provides slow paddles, which make it more difficult to intercept a ball that is moving vertically at high velocity. Maybe it would be better to keep the ball speed constant after all.

## Deployment instructions

Work in progress.

## Development tips

- Might need to refresh browser pages or truncate the database occasionally. I've been doing that with `rake db:schema:load`. There might be a more specific command for truncating. Hopefully the issues making this necessary will be fixed soon.
- Might need to truncate redis occasionally with `redis-cli flushall` if there is an orphan game job, but hopefully such jobs will be smart enough to detect that they should exit without error to remove the job from the queue. Also there might be a more targeted way to find and delete just one sidekiq job from redis.
- Chrome developer console network tab will show websocket messages if you select the WS filter (instead of all, xhr, etc.).
- If something is mysteriously not working check the rails server and sidekiq output or logs. The game messages sent by clients fill up the log, and can make it difficult to see more useful information, including errors. (TODO: consider filtering those client messages from the logs.) Sometimes it can help to increase the interval in the game JavaScript to reduce the frequency of messages.
- I often write debugging info (sometimes just line numbers so I can tell what code is being executed) to a file and `tail` that file, especially in the sidekiq jobs since I don't know how to start a debugger there.

## Plans

I'd like to write a web app that allows users to play a pong-like game with other users over the Internet.

A matchmaking system would prompt users for the difficulty level they want to play at and put 2 players into a game if their desired difficulty levels match.

To prevent cheating, the server will simulate the game and tell clients where the ball and paddles are, moving the paddles as directed by the clients.

For the first version of the game, matchmaking and game simulations will occur inside delayed job workers. This will limit the number of active games to the number of workers, because a worker can't support more than one game at a time. For better scalability, a potential future version would implement some kind of long term job processing that uses server resources optimally, such as by having workers that read queues and pass the work off to threads. (I think Ruby's global interpreter lock prevents threads from running at the same time, which means they can't be used to better leverage all cores on a multicore processor, but they can be used to more fully utilize a single core by continuing to do useful work when another thread is blocked waiting on network IO, for example. I think. Theoretically. Also, a thread pool might be better than continually creating and deleting threads.) It doesn't seem like any Ruby gem that I know of (Resque, Delayed Job, Puma) provides that particular kind of feature...

Just kidding, sidekiq is threaded. It looks like it is not easy to configure the number of sidekiq processes, but it is possible. (I would want multiple processes to take advantage of a server's multiple cores, which can't be done with threads as noted above.) For example, you can create one systemd file per process if using systemd, according to the example linked from here: https://github.com/mperham/sidekiq/wiki/Deployment#running-your-own-process

So never mind, let's use sidekiq.

Later edit: maybe sidekiq is not the ideal solution after all. Following the implementation mentioned above for running multiple sidekiq processes with systemd means the processes do not share any memory. Ideally a single sidekiq process would load the Ruby app and then fork several times to create multiple sidekiq processes. That way the processes can share the memory occupied by the Ruby app after it finishes loading. I think Ruby apps tend to use hundreds of megabytes of memory that could be shared, so I think this is not an insignificant consideration. There is a commercial version of sidekiq that supports multiple processes (I would assume with shared memory) but it's expensive. So to solve this problem, I might need to wrap sidekiq in some code that supports multiple processes with shared memory, or create my own solution with redis-rb pub/sub, or find another gem that has all the features I need. However, this is not really a problem that I should be trying to solve at this stage. This pong-like game is just for fun anyway. It might be interesting to study how puma does process forking, for example, and then try implementing sidekiq process forking, but it's likely to be a whole lot more complicated and difficult than I would hope, so it's not really a good time investment now. For now, if needed, I can scale sidekiq processes without them sharing any memory. (Also, if you think about it, launching an additional host for sidekiq, paying for the commercial sidekiq, or building it myself would probably all work out to cost fairly similar amounts of time or money. Although launching multiple additional hosts that would not otherwise be needed does become more costly than the other options. Also running more computers when you can do the same work by being smarter feels wrong.)

Important to note that without running multiple sidekiq processes the thing will only ever take advantage of one core, because it is a Ruby process and the threads never run simeltaneously due to the global interpreter lock.

Also, Delayed Job may not use threads and therefore can't be as light weight for reducing idel IO waits, but I think it does provide running multiple workers with shared memory out of the box, so it might not be a bad option after all.

TODO: I read that jruby and rubinius do not have a GIL, so that may be something worth trying!

It looks like the number of threads is configurable but limited: https://github.com/mperham/sidekiq/wiki/Advanced-Options#concurrency That means that the number of games that can occur at the same time is limited. Which is fine because at some point the core running a sidekiq process will be overwhelmed and that would limit the number of games anyway. It also makes knowing when to scale the number of servers easier, assuming the configured number of threads has been optimized and sidekiq let's you discover how many threads are busy (so you can scale when most are busy and the trend is such that they will be busy later too).

Hmm, here's a problem: when a client sends an "I moved my paddle" message, how do I efficiently make that known to the process running the simulation? The message could trigger an insertion into redis to store the data in a location that is accessible to the simulator, but then the simulator also needs to know to read the new data from redis. The simulator could constantly poll redis, but that will slow it down and add cost. The web process that receives the message from the client could send a signal to the simulator process (or, if that process is on another server, send a request to a web process on that server and that can send the signal). Hmm... This might make a good argument to have the web socket server and sidekiq on the same host.

Some kind of pub/sub setup would be nice. I guess sidekiq is a pub/sub thing because it subscribes to queues. But what I mean is, if a single process could subscribe for multiple things at once, and an incoming event could affect the the processing of another event, then that would be useful. Anyway, this looks like it might be relevant: https://cloud.google.com/ruby/getting-started/using-pub-sub At the end of the `run_worker!` method, sleep is called. This makes me think that maybe more than one subscription could be listened to by a single worker. If so, then they might be running in threads, and might be able to share some global state that is scoped to a game id. Google::Cloud::Pubsub probably only works with Google Cloud services. But something similar with Redis, RabbitMQ, or SQS might also work.

This looks interesting: https://github.com/jondot/sneakers

redis-rb has a pub-sub feature that looks like it might be the right solution. Subscriptions to client events could be created from inside a sidekiq worker thread and destroyed when a game ends.

There are many ways the clients could communicate state to the simulator, and many ways they could be tested for reliability, including AB testing. One implementation I'd like to try is to have the clients send the current paddle state (moving up, moving down, or not moving) to the simulator many times per second (as much as 60). Another possibility is to only send a message when state changes, but I wonder if this might cause state changes to be missed by the simulator, either because the web socket connection doesn't guarantee all messages to arrive and to arrive in order (I'm not sure if it does or does not) or because the simulator misses an event published by redis (I'm not sure what happens if an event is published and the simulator thread is not actively listening at the time, or if such a thing (not actively listening while subscribed) is even possible). And there are other possible implementations, and it might make sense to send key events from the client instead of more abstract state events (but probably only for games that are more complex than this pong-like game).

I wonder, if instead of having a sidekiq thread tied down for a whole game, it should instead do some updates, persist the game state (maybe in redis), and then push a new game update job into a sidekiq queue, and then the sidekiq thread could be free to pull a new job. This would have the advantage of eliminating the limit on games from having only one game per thread, but it would have the disadvantages of passing the game state back and forth to redis constantly instead of keeping it in the sidekiq worker's memory, and reducing control over frequency of game state updates. (A higher and more consistent game state update frequency provides a better game play experience. For example the ball can move more smoothly because its position can be updated more often, and the ball can be allowed to move faster because collision detection can be executed more often, allowing the ball to move at higher speeds without occasionally passing right through a paddle. Though that assumes collision detection is performed by checking if the ball and paddle overlap during a game loop iteration. There may be other collision detection algorithms that would prevent the ball passing through the paddle, even at high speeds, and thus make state update frequency less important.)

## About Pong

I'm pretty sure Pong is trademarked or copyrighted or something. I don't own it, and that's why I'm trying to be careful not to call this software "Pong". It's not Pong. It's a game like Pong.
