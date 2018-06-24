class HardWorker
  include Sidekiq::Worker

  def perform(*args)
    open('a', 'a') {|f| f.puts Time.now }
  end
end
