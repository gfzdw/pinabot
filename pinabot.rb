require 'bundler/setup'
require 'i18n'

Bundler.require
Dotenv.load

# open our SQLite database for storing replies and managing unsubscribe requests
DB = SQLite3::Database.new('db/development.sqlite3')

### THESE VARIABLES MUST BE CONFIGURED PRIOR TO RUNNING ###
VERSION  = '0.0.1' # you should increment this on major changes
AUTHOR   = ''      # reddit username of bot's author/handler
BOTNAME  = ''      # you can use this to stylize the bot's name since reddit doesn't allow accents in usernames
OPTOUT   = ''      # bot handles opt-outs and this is the trigger word
SUB      = ''      # subreddit to monitor (unfortunately only one at this time)

# these are ideally set via environment variables or using the .env file (see README.md), but can be hardwired here
REDD_CLIENT   = ENV['REDD_CLIENT']
REDD_SECRET   = ENV['REDD_SECRET']
REDD_USERNAME = ENV['REDD_USERNAME']
REDD_PASSWORD = ENV['REDD_PASSWORD']

# here's the general template for what the bot posts when triggered (uses Reddit markdown syntax)
REPLY_TEMPLATE = <<-ENDTEMPLATE
You activated #{BOTNAME}, %{commenter}!

%{reply}

---

^^Suggestions? ^^Shoot ^^a ^^message ^^to ^^[#{AUTHOR}](https://www.reddit.com/message/compose/?to=#{AUTHOR}). ^^Reply ^^`#{OPTOUT}` ^^to ^^this ^^message ^^to ^^unsubscribe. ^^Thanks!
ENDTEMPLATE

# set up a session using environment variables or hardcoded variables above
SESSION = Redd.it(
  user_agent: "redd:#{I18n.transliterate(BOTNAME).downcase}:v#{VERSION} (by /u/#{AUTHOR})",
  client_id:  REDD_CLIENT,
  secret:     REDD_SECRET,
  username:   REDD_USERNAME,
  password:   REDD_PASSWORD
)

# here are the sets of triggers and their replies
DICTIONARY = [
  {
    # Yuli the Piña
    triggers: [
      'pina',
      'piña',
      'pineapple',
      'yuli',
      'gurriel'
    ],
    replies: [
      '[Mmm... pineapple!](https://i.imgur.com/gw7lBej.jpg)',
      '[Did somebody mention *la piña*?](https://i.imgur.com/LNpv5pL.jpg)',
      '[(⌐■_■)](https://i.imgur.com/GkpzeKx.jpg)',
      '[Piña!](https://i.imgur.com/VkpGOCw.jpg)',
      '[Piña Power?](https://i.imgur.com/QqGHuuq.jpg)',
      '[Piña Power!](https://i.imgur.com/8z7Ds5g.jpg)',
      '[Beach piña!](https://i.imgur.com/7aMkyX7.jpg)',
      '[Suited up?](https://i.imgur.com/LCrfDbw.jpg)'
    ]
  },
  {
    # Take It Back!
    triggers: [
      '#takeitback',
      'takeitback',
      'take it back'
    ],
    replies: [
      '[Verlander wants to \#TakeItBack!](https://i.imgur.com/ycNuaUv.jpg)',
      '[Altuve wants to \#TakeItBack!](https://i.imgur.com/A9te6cQ.jpg)',
      '[Houston wants to \#TakeItBack!](https://i.imgur.com/W4BG341.jpg)',
      '[Reddick wants to \#TakeItBack!](https://i.imgur.com/Iblpwpb.jpg)',
      '[Diaz wants to \#TakeItBack!](https://i.imgur.com/aSs3ozC.jpg)',
      '[Verlander wants to \#TakeItBack!](https://i.imgur.com/yiifafW.jpg)'
    ]
  }
]

# convert the triggers into useable regular expression object
DICTIONARY.each do |d|
  # add word boundary to regular expressions
  d[:regex] = Regexp.union(d[:triggers])
end

# rotate the comments array and pick the first (roundrobin instead of random)
def trigger_a_comment(body)
  DICTIONARY.each do |d|
    return d[:replies].rotate!.first if body =~ /\b#{d[:regex].source}\b/i
  end

  nil
end

# save space in the database by trimming off '/r/subreddit/comments/'
def trim_permalink(link)
  link.sub!(/^(\/r.*comments\/)/, '')
  link
end

# don't reply to the bot's comments or users who have unsubscribed
def unsubscribed?(username)
  return true if username == REDD_USERNAME.downcase ||
    DB.get_first_value('select count(*) from unsubscribed where LOWER(username) = ?', username) > 0
end

# wait ten seconds from script start to actually start processing comments (we only want new comments)
READY_TIME = Time.now.utc + 10

SESSION.subreddit(SUB).comment_stream( {limit: 0} ) do |comment|
  next if Time.now.utc < READY_TIME # wait for number of seconds after script starts

  # handle unsubscribes
  if comment.body =~ /#{OPTOUT}/i && !unsubscribed?(comment.author.name.downcase)
    begin
      DB.execute 'insert into unsubscribed (username) values (?)', [comment.author.name.downcase]
      puts "#{comment.author.name} unsubscribed."
    rescue SQLite3::ConstraintException
      puts "#{comment.author.name} already unsubscribed."
    end

    next
  end

  # only reply if user hasn't unsubscribed and the comment includes a trigger word
  if (reply = trigger_a_comment(comment.body)) && !unsubscribed?(comment.author.name.downcase)
    permalink = trim_permalink(comment.permalink) # save space in database by trimming permalink

    # only reply if we haven't replied already
    unless DB.get_first_value('select count(*) from permalinks where link = ?', permalink) > 0
      puts "#{comment.author.name} triggered."

      # keep track of this comment, so we don't reply to it again
      begin
        DB.execute 'insert into permalinks (link) values (?)', [permalink]
      rescue
        puts "SQLite error saving #{permalink}"
      end

      # attempt to post comment -- retry if problem with reddit API
      handler = Proc.new do |exception, attempt_number, total_delay|
        puts "Handler saw a #{exception.class}; retry attempt #{attempt_number}; #{total_delay} seconds have passed."
      end
      with_retries(:max_tries => 5, :handler => handler) do |attempt|
        # interpolate our custom reply into the reply template and reply to the comment
        comment.reply REPLY_TEMPLATE % {commenter: comment.author.name, reply: reply}
      end
    end
  end
end